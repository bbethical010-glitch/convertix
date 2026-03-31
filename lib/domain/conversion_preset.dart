/// Encoding presets that balance speed vs. compression quality.
enum ConversionPreset { fast, balanced, highQuality }

extension ConversionPresetExt on ConversionPreset {
  String get label {
    switch (this) {
      case ConversionPreset.fast:
        return 'Low';
      case ConversionPreset.balanced:
        return 'Medium';
      case ConversionPreset.highQuality:
        return 'High';
    }
  }

  /// The FFmpeg `-preset` value.  Only meaningful for codecs that honour it
  /// (x264/x265, some AAC encoders).  For other codecs the flag is ignored.
  String get ffmpegFlag {
    switch (this) {
      case ConversionPreset.fast:
        return 'ultrafast';
      case ConversionPreset.balanced:
        return 'medium';
      case ConversionPreset.highQuality:
        return 'slow';
    }
  }

  /// Audio bitrate associated with this preset.
  String get audioBitrate {
    switch (this) {
      case ConversionPreset.fast:
        return '96k';
      case ConversionPreset.balanced:
        return '192k';
      case ConversionPreset.highQuality:
        return '320k';
    }
  }
}
