enum MediaType { audio, video, image }

/// Format recommendation with a reason tag.
class FormatRecommendation {
  const FormatRecommendation(this.extension, this.badge);
  final String extension;
  final String badge; // e.g. "Best for Web", "Smallest Size"
}

extension MediaTypeFormats on MediaType {
  List<String> get outputExtensions {
    switch (this) {
      case MediaType.audio:
        return const ['mp3', 'aac', 'wav', 'flac', 'ogg', 'm4a', 'amr', 'wma'];
      case MediaType.video:
        return const [
          'mp4',
          'mkv',
          'avi',
          'mov',
          'flv',
          'webm',
          '3gp',
          'ts',
          'm4v'
        ];
      case MediaType.image:
        return const ['jpg', 'png', 'webp', 'bmp', 'gif'];
    }
  }

  List<String> get inputExtensions {
    switch (this) {
      case MediaType.audio:
        return const [
          'mp3',
          'aac',
          'wav',
          'flac',
          'ogg',
          'm4a',
          'amr',
          'wma',
          'opus',
          'ac3',
          'aiff',
        ];
      case MediaType.video:
        return const [
          'mp4',
          'mkv',
          'avi',
          'mov',
          'flv',
          'webm',
          '3gp',
          'ts',
          'm4v',
          'wmv',
          'mpg',
          'mpeg',
          'vob',
        ];
      case MediaType.image:
        return const [
          'jpg',
          'jpeg',
          'png',
          'webp',
          'bmp',
          'gif',
          'heic',
          'heif',
          'tiff',
          'tif',
          'svg',
        ];
    }
  }

  List<String> get allowedPickerExtensions => inputExtensions;

  /// Recommended output formats for this media type.
  List<FormatRecommendation> get recommendations {
    switch (this) {
      case MediaType.image:
        return const [
          FormatRecommendation('webp', 'Best for Web'),
          FormatRecommendation('png', 'Best Quality'),
          FormatRecommendation('jpg', 'Smallest Size'),
        ];
      case MediaType.video:
        return const [
          FormatRecommendation('mp4', 'Best Compatibility'),
          FormatRecommendation('webm', 'Best Compression'),
          FormatRecommendation('mov', 'Best Quality'),
        ];
      case MediaType.audio:
        return const [
          FormatRecommendation('mp3', 'Most Compatible'),
          FormatRecommendation('flac', 'Lossless Quality'),
          FormatRecommendation('aac', 'Smallest Size'),
        ];
    }
  }

  static MediaType? detect(String filePath) {
    final ext = filePath.split('.').last.toLowerCase();
    for (final type in MediaType.values) {
      if (type.inputExtensions.contains(ext)) {
        return type;
      }
    }
    return null;
  }
}
