import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';

import '../domain/media_type.dart';

class PickedFileInfo {
  PickedFileInfo({required this.path, required this.name});
  final String path;
  final String name;
}

class FileManager {
  static const String converterFolderName = 'AllFormatConverter';
  static const String converterOutputDirPrimary =
      '/storage/emulated/0/AllFormatConverter';
  static const String converterOutputDir = converterOutputDirPrimary;

  // Method channel to the native Kotlin file picker
  static const _channel = MethodChannel('com.allformat.converter/filepicker');

  // ---------------------------------------------------------------------------
  // File picking — uses native Android file picker via method channel.
  // This bypasses the file_picker plugin entirely and uses Android's native
  // registerForActivityResult with OpenDocument() contract.
  // ---------------------------------------------------------------------------

  /// Pick a single file constrained to the given [mediaType].
  Future<PickedFileInfo?> pickFile(MediaType mediaType) async {
    final files = await pickFiles(mediaType, allowMultiple: false);
    return files.isNotEmpty ? files.first : null;
  }

  /// Pick one or more files of [mediaType].
  Future<List<PickedFileInfo>> pickFiles(
    MediaType mediaType, {
    bool allowMultiple = true,
  }) async {
    try {
      final result = await _channel.invokeMethod('pickFiles', {
        'allowMultiple': allowMultiple,
      });

      if (result == null) return [];

      final List<dynamic> fileList = result as List<dynamic>;
      final allowedExts = mediaType.allowedPickerExtensions;

      return fileList.map((item) {
        final map = Map<String, String>.from(item as Map);
        return PickedFileInfo(
          path: map['path']!,
          name: map['name']!,
        );
      }).where((f) {
        final ext = f.name.split('.').last.toLowerCase();
        return allowedExts.contains(ext);
      }).toList();
    } on PlatformException catch (e) {
      debugPrint('Native file picker error: ${e.message}');
      return [];
    } catch (e) {
      debugPrint('File picker error: $e');
      return [];
    }
  }

  /// Pick any media file regardless of type — useful for "smart detect" mode.
  Future<List<PickedFileInfo>> pickAnyFiles({bool allowMultiple = true}) async {
    try {
      final result = await _channel.invokeMethod('pickFiles', {
        'allowMultiple': allowMultiple,
      });

      if (result == null) return [];

      final List<dynamic> fileList = result as List<dynamic>;

      return fileList.map((item) {
        final map = Map<String, String>.from(item as Map);
        return PickedFileInfo(
          path: map['path']!,
          name: map['name']!,
        );
      }).toList();
    } on PlatformException catch (e) {
      debugPrint('Native file picker error: ${e.message}');
      return [];
    } catch (e) {
      debugPrint('File picker error: $e');
      return [];
    }
  }

  // ---------------------------------------------------------------------------
  // Smart format detection
  // ---------------------------------------------------------------------------

  /// Detect [MediaType] from a file path's extension.
  MediaType? detectMediaType(String filePath) {
    return MediaTypeFormats.detect(filePath);
  }

  // ---------------------------------------------------------------------------

  static const String audioSubfolder = 'audio';
  static const String videoSubfolder = 'video';
  static const String imagesSubfolder = 'images';
  static const String documentsSubfolder = 'documents';

  static const Set<String> _audioExtensions = {
    'mp3',
    'aac',
    'wav',
    'flac',
    'ogg',
    'm4a',
    'amr',
    'wma',
  };
  static const Set<String> _videoExtensions = {
    'mp4',
    'mkv',
    'avi',
    'mov',
    'flv',
    'webm',
    '3gp',
    'ts',
    'm4v',
  };
  static const Set<String> _documentExtensions = {'pdf'};

  Future<File> buildOutputFilePath({
    required String inputPath,
    required String outputExtension,
    String? baseNameOverride,
    String? customOutputDir,
  }) async {
    final safeExt = outputExtension.replaceFirst('.', '').toLowerCase();
    final dirPath = customOutputDir ?? (await _getConverterDirectory()).path;
    final baseName = baseNameOverride ?? p.basenameWithoutExtension(inputPath);
    final fullExt = '.$safeExt';

    var filePath = p.join(dirPath, '$baseName$fullExt');

    // Avoid overwriting — append (1), (2), etc.
    var counter = 1;
    while (File(filePath).existsSync()) {
      filePath = p.join(dirPath, '$baseName ($counter)$fullExt');
      counter++;
    }

    return File(filePath);
  }

  // ---------------------------------------------------------------------------
  // Temp file management
  // ---------------------------------------------------------------------------

  Future<File> getTempFilePath(String fileName) async {
    final tempDir = await getTemporaryDirectory();
    return File(p.join(tempDir.path, fileName));
  }

  Future<void> cleanupTempFiles() async {
    try {
      final tempDir = await getTemporaryDirectory();
      final entries = tempDir.listSync();
      for (final entry in entries) {
        if (entry is File) {
          await entry.delete();
        }
      }
    } catch (_) {}
  }

  // ---------------------------------------------------------------------------
  // Output directory
  // ---------------------------------------------------------------------------

  Future<Directory> _getConverterDirectory() async {
    final basePath = await getOutputDirectory('');
    return Directory(basePath);
  }

  Future<Directory> _getConverterSubDirectory(String subfolder) async {
    final path = await getOutputDirectory(subfolder);
    final dir = Directory(path);
    if (!dir.existsSync()) dir.createSync(recursive: true);
    return dir;
  }

  Future<String> getActiveOutputDirectoryPath() async {
    final dir = await _getConverterDirectory();
    return dir.path;
  }

  Future<String> getOutputDirectory(String subFolder) async {
    if (Platform.isAndroid) {
      final extDir = Directory(
        p.join(converterOutputDirPrimary, subFolder),
      );
      final hasPermission =
          await Permission.manageExternalStorage.status.isGranted;

      if (hasPermission) {
        try {
          if (!extDir.existsSync()) {
            extDir.createSync(recursive: true);
          }
          return extDir.path;
        } catch (_) {}
      }

      final fallback = await getExternalStorageDirectory();
      if (fallback != null) {
        final fallbackDir = Directory(
          p.join(fallback.path, converterFolderName, subFolder),
        );
        if (!fallbackDir.existsSync()) fallbackDir.createSync(recursive: true);
        return fallbackDir.path;
      }
    }

    final dir = await getApplicationDocumentsDirectory();
    final target = Directory(p.join(dir.path, converterFolderName, subFolder));
    if (!target.existsSync()) target.createSync(recursive: true);
    return target.path;
  }

  String _subfolderForExtension(String extension) {
    final ext = extension.toLowerCase();
    if (_audioExtensions.contains(ext)) return audioSubfolder;
    if (_videoExtensions.contains(ext)) return videoSubfolder;
    if (_documentExtensions.contains(ext)) return documentsSubfolder;
    return imagesSubfolder;
  }

  // ---------------------------------------------------------------------------
  // Storage stats
  // ---------------------------------------------------------------------------

  /// Returns (fileCount, totalBytes) for the converter directory.
  Future<(int, int)> getStorageStats() async {
    final dir = await _getConverterDirectory();
    if (!dir.existsSync()) return (0, 0);

    int count = 0;
    int totalBytes = 0;
    for (final entry in dir.listSync(recursive: true)) {
      if (entry is File) {
        count++;
        totalBytes += entry.lengthSync();
      }
    }
    return (count, totalBytes);
  }

  /// Delete all converted files.
  Future<void> clearConvertedFiles() async {
    final dir = await _getConverterDirectory();
    if (!dir.existsSync()) return;
    for (final entry in dir.listSync(recursive: true)) {
      if (entry is File) {
        try {
          await entry.delete();
        } catch (_) {}
      }
    }
  }

  Future<List<Map<String, dynamic>>> loadHistoryRecords() async {
    try {
      final file = await _getHistoryFile();
      if (!file.existsSync()) return const [];
      final raw = await file.readAsString();
      if (raw.trim().isEmpty) return const [];
      final decoded = jsonDecode(raw);
      if (decoded is! List) return const [];
      return decoded
          .whereType<Map>()
          .map((item) => Map<String, dynamic>.from(item))
          .toList();
    } catch (_) {
      return const [];
    }
  }

  Future<void> saveHistoryRecords(List<Map<String, dynamic>> records) async {
    final file = await _getHistoryFile();
    if (!file.parent.existsSync()) {
      file.parent.createSync(recursive: true);
    }
    await file.writeAsString(jsonEncode(records), flush: true);
  }

  Future<File> _getHistoryFile() async {
    final dir = await getApplicationSupportDirectory();
    return File(p.join(dir.path, 'conversion_history.json'));
  }
}
