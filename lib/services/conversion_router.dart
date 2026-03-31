import '../domain/conversion_type.dart';
import '../domain/media_type.dart';

enum OutputTypeCategory { audio, video, image, document }

class ConversionSuggestion {
  const ConversionSuggestion({
    required this.title,
    required this.conversionType,
  });

  final String title;
  final ConversionType conversionType;
}

class ConversionRouter {
  const ConversionRouter();

  List<OutputTypeCategory> outputCategoriesFor(MediaType inputType) {
    switch (inputType) {
      case MediaType.video:
        return const [
          OutputTypeCategory.image,
          OutputTypeCategory.audio,
          OutputTypeCategory.video,
        ];
      case MediaType.audio:
        return const [
          OutputTypeCategory.audio,
          OutputTypeCategory.video,
        ];
      case MediaType.image:
        return const [
          OutputTypeCategory.image,
          OutputTypeCategory.document,
        ];
    }
  }

  List<String> outputFormatsFor({
    required MediaType inputType,
    required OutputTypeCategory outputCategory,
    bool compressVideoOnly = false,
  }) {
    if (compressVideoOnly) {
      return const ['mp4', 'mov', 'mkv'];
    }
    if (inputType == MediaType.video &&
        outputCategory == OutputTypeCategory.audio) {
      return const ['mp3', 'wav', 'aac'];
    }
    if (inputType == MediaType.video &&
        outputCategory == OutputTypeCategory.image) {
      return const ['gif'];
    }
    if (inputType == MediaType.audio &&
        outputCategory == OutputTypeCategory.video) {
      return const ['mp4', 'mov'];
    }
    if (inputType == MediaType.image &&
        outputCategory == OutputTypeCategory.document) {
      return const ['pdf'];
    }

    switch (inputType) {
      case MediaType.audio:
        return outputCategory == OutputTypeCategory.audio
            ? MediaType.audio.outputExtensions
            : const [];
      case MediaType.video:
        return outputCategory == OutputTypeCategory.video
            ? MediaType.video.outputExtensions
            : const [];
      case MediaType.image:
        return outputCategory == OutputTypeCategory.image
            ? MediaType.image.outputExtensions
            : const [];
    }
  }

  ConversionType resolveType({
    required MediaType inputType,
    required OutputTypeCategory outputCategory,
    required String outputFormat,
    bool compressVideoOnly = false,
  }) {
    final format = outputFormat.toLowerCase();
    if (compressVideoOnly && inputType == MediaType.video) {
      return ConversionType.videoCompress;
    }
    if (inputType == MediaType.video &&
        outputCategory == OutputTypeCategory.audio) {
      return ConversionType.videoToAudio;
    }
    if (inputType == MediaType.video &&
        outputCategory == OutputTypeCategory.image &&
        format == 'gif') {
      return ConversionType.videoToGif;
    }
    if (inputType == MediaType.audio &&
        outputCategory == OutputTypeCategory.video) {
      return ConversionType.audioToVideo;
    }
    if (inputType == MediaType.image &&
        outputCategory == OutputTypeCategory.document &&
        format == 'pdf') {
      return ConversionType.imageToPdf;
    }

    switch (inputType) {
      case MediaType.audio:
        return ConversionType.audioToAudio;
      case MediaType.video:
        return ConversionType.videoToVideo;
      case MediaType.image:
        return ConversionType.imageToImage;
    }
  }

  List<ConversionSuggestion> smartSuggestions(MediaType inputType) {
    switch (inputType) {
      case MediaType.video:
        return const [
          ConversionSuggestion(
            title: 'Extract Audio',
            conversionType: ConversionType.videoToAudio,
          ),
          ConversionSuggestion(
            title: 'Convert to GIF',
            conversionType: ConversionType.videoToGif,
          ),
        ];
      case MediaType.audio:
        return const [
          ConversionSuggestion(
            title: 'Create Video with Background',
            conversionType: ConversionType.audioToVideo,
          ),
        ];
      case MediaType.image:
        return const [
          ConversionSuggestion(
            title: 'Convert to PDF',
            conversionType: ConversionType.imageToPdf,
          ),
        ];
    }
  }

  bool requiresBackgroundImage(ConversionType type) {
    return type == ConversionType.audioToVideo;
  }
}
