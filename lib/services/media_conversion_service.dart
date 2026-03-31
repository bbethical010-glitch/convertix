import 'dart:async';
import 'dart:io';

import 'package:ffmpeg_kit_flutter_new/ffmpeg_kit.dart';
import 'package:ffmpeg_kit_flutter_new/ffmpeg_kit_config.dart';
import 'package:ffmpeg_kit_flutter_new/ffprobe_kit.dart';
import 'package:ffmpeg_kit_flutter_new/log.dart';
import 'package:ffmpeg_kit_flutter_new/return_code.dart';
import 'package:flutter/foundation.dart';
import 'package:image/image.dart' as img;
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../domain/conversion_preset.dart';
import '../domain/conversion_type.dart';

class ConversionResult {
  ConversionResult({required this.success, required this.message});
  final bool success;
  final String message;
}

class ConversionProgress {
  const ConversionProgress({
    this.percent = 0.0,
    this.speed,
    this.eta,
  });
  final double percent;
  final String? speed;
  final String? eta;
}

class FFmpegService {
  FFmpegService() {
    FFmpegKitConfig.enableStatisticsCallback((statistics) {
      final totalMs = _currentTotalDurationMs;
      if (totalMs == null || totalMs <= 0) return;

      final currentMs = statistics.getTime();
      if (currentMs <= 0) return;

      final percent = (currentMs / totalMs).clamp(0.0, 0.99).toDouble();
      _progressController.add(ConversionProgress(
        percent: percent,
        speed: _lastSpeed,
        eta: _estimateEta(percent),
      ));
    });

    FFmpegKitConfig.enableLogCallback((Log log) {
      _parseLogLine(log.getMessage());
    });
  }

  final StreamController<ConversionProgress> _progressController =
      StreamController<ConversionProgress>.broadcast();

  Stream<ConversionProgress> get progressStream => _progressController.stream;

  int? _currentTotalDurationMs;
  String? _lastSpeed;
  DateTime? _conversionStartTime;

  Future<ConversionResult> convert({
    required ConversionType conversionType,
    required List<String> inputPaths,
    required String outputPath,
    ConversionPreset preset = ConversionPreset.balanced,
    bool isPro = false,
  }) async {
    if (inputPaths.isEmpty) {
      return ConversionResult(
          success: false, message: 'No input file provided.');
    }

    if (conversionType == ConversionType.imageToPdf) {
      return _createPdfFromImages(inputPaths, outputPath);
    }

    final command = _buildCommand(
      conversionType: conversionType,
      inputPaths: inputPaths,
      outputPath: outputPath,
      preset: preset,
      isPro: isPro,
    );

    if (command == null) {
      return ConversionResult(
        success: false,
        message: 'Unsupported conversion combination.',
      );
    }

    _progressController.add(const ConversionProgress(percent: 0.0));
    _currentTotalDurationMs = await _probeDurationMs(inputPaths.first);
    _conversionStartTime = DateTime.now();
    _lastSpeed = null;

    try {
      final completer = Completer<ConversionResult>();
      await FFmpegKit.executeAsync(
        command,
        (session) async {
          final returnCode = await session.getReturnCode();
          final allLogs = await session.getAllLogs();

          if (ReturnCode.isSuccess(returnCode)) {
            _progressController.add(const ConversionProgress(percent: 1.0));
            _reset();
            completer.complete(
              ConversionResult(
                success: true,
                message: 'Conversion completed successfully.',
              ),
            );
          } else if (ReturnCode.isCancel(returnCode)) {
            _reset();
            completer.complete(
              ConversionResult(
                  success: false, message: 'Conversion was cancelled.'),
            );
          } else {
            final errorMsg = _extractErrorMessage(allLogs);
            _progressController.add(const ConversionProgress(percent: 0.0));
            _reset();
            completer.complete(
              ConversionResult(
                success: false,
                message: 'FFmpeg error (code $returnCode): $errorMsg',
              ),
            );
          }
        },
      );

      return await completer.future;
    } catch (e, stackTrace) {
      debugPrint('[FFmpeg] EXCEPTION: $e');
      debugPrint('[FFmpeg] $stackTrace');
      _reset();
      return ConversionResult(success: false, message: 'FFmpeg exception: $e');
    }
  }

  Future<ConversionResult> _createPdfFromImages(
    List<String> imagePaths,
    String outputPath,
  ) async {
    if (imagePaths.isEmpty) {
      return ConversionResult(
        success: false,
        message: 'No image files selected for PDF conversion.',
      );
    }

    try {
      _progressController.add(const ConversionProgress(percent: 0.0));
      final doc = pw.Document();
      final total = imagePaths.length;
      var processed = 0;

      for (final path in imagePaths) {
        final file = File(path);
        if (!file.existsSync()) continue;
        final bytes = await file.readAsBytes();
        final normalized = _normalizePdfImage(bytes, path);
        final provider = pw.MemoryImage(normalized);
        doc.addPage(
          pw.Page(
            pageFormat: PdfPageFormat.a4,
            build: (_) => pw.Center(
              child: pw.Image(provider, fit: pw.BoxFit.contain),
            ),
          ),
        );
        processed++;
        final p = total == 0 ? 0.0 : (processed / total).clamp(0.0, 1.0);
        _progressController.add(ConversionProgress(percent: p));
      }

      if (processed == 0) {
        return ConversionResult(
          success: false,
          message: 'None of the selected images could be read.',
        );
      }

      final out = File(outputPath);
      await out.parent.create(recursive: true);
      await out.writeAsBytes(await doc.save(), flush: true);
      _progressController.add(const ConversionProgress(percent: 1.0));
      return ConversionResult(
        success: true,
        message: 'PDF created successfully.',
      );
    } catch (e) {
      return ConversionResult(
        success: false,
        message: 'PDF conversion failed: $e',
      );
    } finally {
      _reset();
    }
  }

  Uint8List _normalizePdfImage(Uint8List bytes, String path) {
    final ext = path.split('.').last.toLowerCase();
    if (ext != 'webp') return bytes;

    final decoded = img.decodeImage(bytes);
    if (decoded == null) return bytes;
    return Uint8List.fromList(img.encodePng(decoded));
  }

  void dispose() {
    _progressController.close();
  }

  void _parseLogLine(String line) {
    final speedMatch = RegExp(r'speed=\s*([\d.]+)x').firstMatch(line);
    if (speedMatch != null) {
      _lastSpeed = '${speedMatch.group(1)}x';
    }
  }

  String? _estimateEta(double percent) {
    if (_conversionStartTime == null || percent <= 0.01) return null;
    final elapsed = DateTime.now().difference(_conversionStartTime!).inSeconds;
    if (elapsed < 2) return null;
    final totalEstimated = elapsed / percent;
    final remaining = (totalEstimated - elapsed).round();
    if (remaining <= 0) return null;
    if (remaining < 60) return '${remaining}s';
    return '${remaining ~/ 60}m ${remaining % 60}s';
  }

  void _reset() {
    _currentTotalDurationMs = null;
    _conversionStartTime = null;
    _lastSpeed = null;
  }

  String _extractErrorMessage(List<Log> logs) {
    final allText = logs.map((l) => l.getMessage()).join('\n').toLowerCase();
    if (allText.contains('codec not currently supported') ||
        (allText.contains('decoder') && allText.contains('not found'))) {
      return 'Unsupported codec: input uses a codec not supported on this device.';
    }
    if (allText.contains('invalid data found') ||
        allText.contains('moov atom not found') ||
        allText.contains('end of file')) {
      return 'The input file appears to be corrupted or incomplete.';
    }
    if (allText.contains('permission denied')) {
      return 'Permission denied: cannot read input or write output file.';
    }
    if (allText.contains('no such file')) {
      return 'File not found: the selected input file is no longer available.';
    }

    for (final log in logs.reversed) {
      final msg = log.getMessage().trim();
      if (msg.isNotEmpty && msg.length > 5) return msg;
    }
    return 'Conversion failed with an unknown error.';
  }

  Future<int?> _probeDurationMs(String inputPath) async {
    try {
      final session = await FFprobeKit.getMediaInformation(inputPath);
      final info = session.getMediaInformation();
      if (info == null) return null;
      final raw = info.getDuration();
      if (raw == null) return null;
      final seconds = double.tryParse(raw);
      if (seconds == null || seconds <= 0) return null;
      return (seconds * 1000).round();
    } catch (_) {
      return null;
    }
  }

  String? _buildCommand({
    required ConversionType conversionType,
    required List<String> inputPaths,
    required String outputPath,
    required ConversionPreset preset,
    bool isPro = false,
  }) {
    final ext = outputPath.split('.').last.toLowerCase();
    switch (conversionType) {
      case ConversionType.audioToAudio:
        return _buildAudioCommand(inputPaths.first, outputPath, ext, preset, isPro);
      case ConversionType.videoToVideo:
        return _buildVideoCommand(inputPaths.first, outputPath, ext, preset, isPro);
      case ConversionType.videoCompress:
        return _buildVideoCompressionCommand(
          inputPaths.first,
          outputPath,
          ext,
          preset,
          isPro,
        );
      case ConversionType.imageToImage:
        return _buildImageCommand(inputPaths.first, outputPath, ext, preset, isPro);
      case ConversionType.videoToAudio:
        return _buildVideoToAudioCommand(inputPaths.first, outputPath, ext, isPro);
      case ConversionType.videoToGif:
        return '-y -i "${inputPaths.first}" -vf "fps=12,scale=480:-1:flags=lanczos" "$outputPath"';
      case ConversionType.audioToVideo:
        if (inputPaths.length < 2) return null;
        final audioPath = inputPaths.first;
        final imagePath = inputPaths[1];
        return '-y -loop 1 -i "$imagePath" -i "$audioPath" -c:v libx264 -c:a aac -shortest "$outputPath"';
      case ConversionType.imageToPdf:
        return null;
    }
  }

  String _buildVideoToAudioCommand(String i, String o, String ext, bool isPro) {
    const threads = '-threads 0';
    if (isPro && ext == 'mp3') {
        return '-y $threads -i "$i" -vn -ar 44100 -ac 2 -b:a 320k "$o"';
    }
    switch (ext) {
      case 'mp3':
        return '-y $threads -i "$i" -vn -ar 44100 -ac 2 -b:a 192k "$o"';
      case 'wav':
        return '-y $threads -i "$i" -map a -acodec pcm_s16le "$o"';
      case 'aac':
        return '-y $threads -i "$i" -map a -c:a aac -b:a 192k "$o"';
      default:
        return '-y $threads -i "$i" -map a "$o"';
    }
  }

  String _buildAudioCommand(
    String i,
    String o,
    String ext,
    ConversionPreset p,
    bool isPro,
  ) {
    final bitrate = isPro ? '320k' : p.audioBitrate;
    const threads = '-threads 0';
    switch (ext) {
      case 'mp3':
        return '-y $threads -i "$i" -vn -ar 44100 -ac 2 -b:a $bitrate "$o"';
      case 'wav':
        return '-y $threads -i "$i" -vn -acodec pcm_s16le -ar 44100 -ac 2 "$o"';
      case 'aac':
        return '-y $threads -i "$i" -vn -c:a aac -b:a $bitrate "$o"';
      case 'flac':
        return '-y $threads -i "$i" -vn -c:a flac "$o"';
      case 'ogg':
        return '-y $threads -i "$i" -vn -c:a libvorbis -qscale:a 5 "$o"';
      case 'm4a':
        return '-y $threads -i "$i" -vn -c:a aac -b:a $bitrate "$o"';
      case 'amr':
        return '-y $threads -i "$i" -vn -ar 8000 -ac 1 -c:a libopencore_amrnb -b:a 12.2k "$o"';
      case 'wma':
        return '-y $threads -i "$i" -vn -c:a wmav2 -b:a $bitrate "$o"';
      default:
        return '-y $threads -i "$i" -vn "$o"';
    }
  }

  String _buildVideoCommand(
    String i,
    String o,
    String ext,
    ConversionPreset p,
    bool isPro,
  ) {
    const threads = '-threads 0';
    final qv = isPro ? '2' : switch (p) {
      ConversionPreset.fast => '8',
      ConversionPreset.balanced => '5',
      ConversionPreset.highQuality => '3',
    };

    const videoCodec = '-c:v mpeg4';
    final audioCodec = '-c:a aac -b:a ${p.audioBitrate}';

    switch (ext) {
      case 'mp4':
        return '-y $threads -i "$i" $videoCodec -q:v $qv $audioCodec "$o"';
      case 'mov':
        return '-y $threads -i "$i" $videoCodec -q:v $qv $audioCodec "$o"';
      case 'mkv':
        return '-y $threads -i "$i" $videoCodec -q:v $qv $audioCodec "$o"';
      case 'avi':
        return '-y $threads -i "$i" -c:v mpeg4 -q:v $qv -c:a mp3 -b:a ${p.audioBitrate} "$o"';
      case 'webm':
        if (isPro) {
            return '-y $threads -i "$i" -c:v libvpx -b:v 2M -c:a libvorbis "$o"';
        }
        return '-y $threads -i "$i" -c:v libvpx -b:v 1M -c:a libvorbis "$o"';
      case 'flv':
        return '-y $threads -i "$i" -c:v flv1 -q:v $qv -c:a mp3 -b:a 192k "$o"';
      case '3gp':
        return '-y $threads -i "$i" -c:v mpeg4 -b:v 500k -c:a aac -b:a 64k -ar 22050 -ac 1 "$o"';
      case 'ts':
        return '-y $threads -i "$i" -c:v mpeg2video -q:v $qv -c:a mp2 -b:a 192k "$o"';
      case 'm4v':
        return '-y $threads -i "$i" -c:v mpeg4 -q:v $qv -c:a aac -b:a 192k "$o"';
      default:
        return '-y $threads -i "$i" "$o"';
    }
  }

  String _buildVideoCompressionCommand(
    String i,
    String o,
    String ext,
    ConversionPreset p,
    bool isPro,
  ) {
    const threads = '-threads 0';
    final crf = isPro ? '20' : switch (p) {
      ConversionPreset.fast => '32',
      ConversionPreset.balanced => '28',
      ConversionPreset.highQuality => '24',
    };

    final preset = switch (p) {
      ConversionPreset.fast => 'veryfast',
      ConversionPreset.balanced => 'medium',
      ConversionPreset.highQuality => 'slow',
    };

    switch (ext) {
      case 'mp4':
      case 'mov':
      case 'mkv':
        return '-y $threads -i "$i" -c:v libx264 -preset $preset -crf $crf -c:a aac -b:a ${p.audioBitrate} "$o"';
      default:
        return '-y $threads -i "$i" -c:v libx264 -preset $preset -crf $crf -c:a aac -b:a ${p.audioBitrate} "$o"';
    }
  }

  String _buildImageCommand(String i, String o, String ext, ConversionPreset p, bool isPro) {
    switch (ext) {
      case 'jpg':
      case 'jpeg':
        final qv = isPro ? '2' : (p == ConversionPreset.fast ? '8' : '5');
        return '-y -i "$i" -q:v $qv "$o"';
      case 'png':
        final compression = isPro ? '0' : (p == ConversionPreset.fast ? '6' : '2');
        return '-y -i "$i" -compression_level $compression "$o"';
      case 'webp':
        return '-y -i "$i" -q:v 50 "$o"';
      case 'bmp':
        return '-y -i "$i" "$o"';
      case 'gif':
        return '-y -i "$i" -vf "fps=10,scale=480:-1:flags=lanczos" "$o"';
      default:
        return '-y -i "$i" "$o"';
    }
  }
}

class MediaConversionService extends FFmpegService {}
