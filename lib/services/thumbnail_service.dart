import 'dart:io';
import 'package:ffmpeg_kit_flutter_new/ffmpeg_kit.dart';
import 'package:ffmpeg_kit_flutter_new/return_code.dart';
import 'package:path_provider/path_provider.dart';

class ThumbnailService {
  static final Map<String, String> _cache = {};

  static Future<String?> getVideoThumbnail(String videoPath) async {
    if (_cache.containsKey(videoPath)) return _cache[videoPath];

    try {
      final cacheDir = await getTemporaryDirectory();
      final outPath = '${cacheDir.path}/thumb_${videoPath.hashCode}.jpg';
      
      if (File(outPath).existsSync()) {
        _cache[videoPath] = outPath;
        return outPath;
      }

      final command = '-y -ss 00:00:01 -i "$videoPath" -vframes 1 -q:v 2 "$outPath"';
      final session = await FFmpegKit.execute(command);
      final returnCode = await session.getReturnCode();

      if (ReturnCode.isSuccess(returnCode)) {
        if (File(outPath).existsSync()) {
          _cache[videoPath] = outPath;
          return outPath;
        }
      }
      return null;
    } catch (_) {
      return null;
    }
  }
}
