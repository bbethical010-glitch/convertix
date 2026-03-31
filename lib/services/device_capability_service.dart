import 'dart:io';

import '../domain/conversion_preset.dart';

class DeviceProfile {
  const DeviceProfile({
    required this.cpuCores,
    required this.recommendedPreset,
  });
  final int cpuCores;
  final ConversionPreset recommendedPreset;
}

/// Detects basic device capabilities and recommends a conversion preset.
class DeviceCapabilityService {
  DeviceProfile detect() {
    final cores = Platform.numberOfProcessors;

    // Simple heuristic: low-end (<=4 cores) -> fast,
    // mid (5-6) -> balanced, high (7+) -> balanced too (highQuality
    // is only chosen explicitly by the user because it is very slow).
    ConversionPreset preset;
    if (cores <= 4) {
      preset = ConversionPreset.fast;
    } else {
      preset = ConversionPreset.balanced;
    }

    return DeviceProfile(
      cpuCores: cores,
      recommendedPreset: preset,
    );
  }
}
