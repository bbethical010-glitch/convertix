enum ConversionType {
  audioToAudio,
  videoToVideo,
  videoCompress,
  imageToImage,
  videoToAudio,
  videoToGif,
  audioToVideo,
  imageToPdf,
}

extension ConversionTypeX on ConversionType {
  String get label {
    switch (this) {
      case ConversionType.audioToAudio:
        return 'Audio → Audio';
      case ConversionType.videoToVideo:
        return 'Video → Video';
      case ConversionType.videoCompress:
        return 'Compress Video';
      case ConversionType.imageToImage:
        return 'Image → Image';
      case ConversionType.videoToAudio:
        return 'Video → Audio';
      case ConversionType.videoToGif:
        return 'Video → GIF';
      case ConversionType.audioToVideo:
        return 'Audio + Image → Video';
      case ConversionType.imageToPdf:
        return 'Image → PDF';
    }
  }

  String get outputMediaFolder {
    switch (this) {
      case ConversionType.audioToAudio:
      case ConversionType.videoToAudio:
        return 'audio';
      case ConversionType.videoToVideo:
      case ConversionType.videoCompress:
      case ConversionType.audioToVideo:
        return 'video';
      case ConversionType.imageToPdf:
        return 'documents';
      case ConversionType.imageToImage:
      case ConversionType.videoToGif:
        return 'images';
    }
  }
}
