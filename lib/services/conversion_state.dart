import 'package:flutter/foundation.dart';

/// Lightweight global state flag for conversion status.
///
/// Used to disable the Convert button and show progress UI.
/// The ConversionController (Provider) holds the authoritative state;
/// this class is a simple backup for code paths outside the widget tree.
class ConversionState {
  ConversionState._();

  static bool _isRunning = false;

  static bool get isRunning => _isRunning;

  static void markStarted() {
    _isRunning = true;
    debugPrint('[ConversionState] Conversion STARTED');
  }

  static void markFinished() {
    _isRunning = false;
    debugPrint('[ConversionState] Conversion FINISHED');
  }

  static void markFailed(String reason) {
    _isRunning = false;
    debugPrint('[ConversionState] Conversion FAILED: $reason');
  }
}
