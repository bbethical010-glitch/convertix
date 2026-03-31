import 'media_type.dart';
import 'conversion_preset.dart';
import 'conversion_type.dart';

enum TaskStatus { pending, running, done, failed }

class ConversionTask {
  ConversionTask({
    required this.inputPath,
    required this.inputName,
    required this.inputPaths,
    required this.inputNames,
    required this.outputPath,
    required this.mediaType,
    required this.conversionType,
    required this.outputExtension,
    this.preset = ConversionPreset.balanced,
    this.secondaryInputPath,
    this.secondaryInputName,
    this.status = TaskStatus.pending,
    this.progress = 0.0,
    this.speed,
    this.eta,
    this.errorMessage,
    this.inputSizeBytes,
    this.outputSizeBytes,
  });

  final String inputPath;
  final String inputName;
  final List<String> inputPaths;
  final List<String> inputNames;
  final String outputPath;
  final MediaType mediaType;
  final ConversionType conversionType;
  final String outputExtension;
  final ConversionPreset preset;
  final String? secondaryInputPath;
  final String? secondaryInputName;

  TaskStatus status;
  double progress;
  String? speed;
  String? eta;
  String? errorMessage;

  /// File sizes (populated after conversion for size reduction display).
  int? inputSizeBytes;
  int? outputSizeBytes;

  /// Human-readable size string.
  static String formatBytes(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    if (bytes < 1024 * 1024 * 1024) {
      return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    }
    return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(1)} GB';
  }

  /// Percentage saved (positive = smaller output).
  double? get savedPercent {
    if (inputSizeBytes == null ||
        outputSizeBytes == null ||
        inputSizeBytes == 0) {
      return null;
    }
    return ((inputSizeBytes! - outputSizeBytes!) / inputSizeBytes!) * 100;
  }
}
