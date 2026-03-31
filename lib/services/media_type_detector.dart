import 'dart:io';

import 'package:path/path.dart' as p;

import '../domain/media_type.dart';

class MediaTypeDetector {
  const MediaTypeDetector();

  static const int _maxVideoBytes = 2 * 1024 * 1024 * 1024; // 2 GB
  static const int _maxAudioBytes = 500 * 1024 * 1024; // 500 MB
  static const int _maxImageBytes = 50 * 1024 * 1024; // 50 MB

  MediaType? detect(String filePath) {
    return MediaTypeFormats.detect(filePath);
  }

  String detectExtension(String filePath) {
    final ext = p.extension(filePath);
    if (ext.isEmpty) return '';
    return ext.replaceFirst('.', '').toLowerCase();
  }

  int maxSizeFor(MediaType type) {
    switch (type) {
      case MediaType.video:
        return _maxVideoBytes;
      case MediaType.audio:
        return _maxAudioBytes;
      case MediaType.image:
        return _maxImageBytes;
    }
  }

  bool exceedsMaxSize({
    required String filePath,
    required MediaType mediaType,
  }) {
    final file = File(filePath);
    if (!file.existsSync()) return false;
    return file.lengthSync() > maxSizeFor(mediaType);
  }
}
