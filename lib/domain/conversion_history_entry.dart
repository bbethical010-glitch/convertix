import 'package:path/path.dart' as p;

import 'conversion_preset.dart';
import 'conversion_type.dart';

/// A single entry in the conversion history.
class ConversionHistoryEntry {
  ConversionHistoryEntry({
    required this.inputPath,
    required this.inputName,
    required this.inputPaths,
    required this.inputNames,
    required this.sourceFormat,
    required this.outputPath,
    required this.outputFormat,
    required this.conversionType,
    required this.preset,
    this.secondaryInputPath,
    this.secondaryInputName,
    required this.completedAt,
  });

  final String inputPath;
  final String inputName;
  final List<String> inputPaths;
  final List<String> inputNames;
  final String sourceFormat;
  final String outputPath;
  final String outputFormat;
  final ConversionType conversionType;
  final ConversionPreset preset;
  final String? secondaryInputPath;
  final String? secondaryInputName;
  final DateTime completedAt;

  /// Just the file name portion of the output path.
  String get outputName => p.basename(outputPath);

  /// e.g. "photo.jpg → photo.png"
  String get summary {
    return '$inputName  →  ${outputName.toUpperCase().split('.').last}';
  }

  Map<String, dynamic> toJson() {
    return {
      'inputPath': inputPath,
      'inputName': inputName,
      'inputPaths': inputPaths,
      'inputNames': inputNames,
      'sourceFormat': sourceFormat,
      'outputPath': outputPath,
      'outputFormat': outputFormat,
      'conversionType': conversionType.name,
      'preset': preset.name,
      'secondaryInputPath': secondaryInputPath,
      'secondaryInputName': secondaryInputName,
      'completedAt': completedAt.toIso8601String(),
    };
  }

  factory ConversionHistoryEntry.fromJson(Map<String, dynamic> json) {
    return ConversionHistoryEntry(
      inputPath: json['inputPath'] as String? ?? '',
      inputName: json['inputName'] as String? ?? '',
      inputPaths: (json['inputPaths'] as List<dynamic>? ?? const [])
          .map((item) => item.toString())
          .toList(),
      inputNames: (json['inputNames'] as List<dynamic>? ?? const [])
          .map((item) => item.toString())
          .toList(),
      sourceFormat: json['sourceFormat'] as String? ?? 'UNKNOWN',
      outputPath: json['outputPath'] as String? ?? '',
      outputFormat: json['outputFormat'] as String? ?? '',
      conversionType: ConversionType.values.byName(
        json['conversionType'] as String? ?? ConversionType.audioToAudio.name,
      ),
      preset: ConversionPreset.values.byName(
        json['preset'] as String? ?? ConversionPreset.balanced.name,
      ),
      secondaryInputPath: json['secondaryInputPath'] as String?,
      secondaryInputName: json['secondaryInputName'] as String?,
      completedAt: DateTime.tryParse(json['completedAt'] as String? ?? '') ??
          DateTime.fromMillisecondsSinceEpoch(0),
    );
  }
}
