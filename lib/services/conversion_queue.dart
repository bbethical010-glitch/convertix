import 'dart:async';
import 'dart:collection';

import 'package:flutter/foundation.dart';

/// A singleton sequential task queue.
///
/// Conversions are enqueued and processed one at a time.
/// This prevents memory spikes from parallel FFmpeg sessions and
/// ensures stable processing even for large batches.
class ConversionQueue {
  static final ConversionQueue _instance = ConversionQueue._internal();
  factory ConversionQueue() => _instance;
  ConversionQueue._internal();

  final Queue<_QueuedTask> _tasks = Queue();
  bool _isProcessing = false;

  int get pendingCount => _tasks.length;
  bool get isProcessing => _isProcessing;

  /// Add a task to the queue. Starts processing automatically.
  void addTask(Future<void> Function() task, {String label = ''}) {
    debugPrint(
        '[ConversionQueue] Task added: "$label"  (queue size: ${_tasks.length + 1})');
    _tasks.add(_QueuedTask(task: task, label: label));
    _processQueue();
  }

  Future<void> _processQueue() async {
    if (_isProcessing) return;

    _isProcessing = true;
    debugPrint('[ConversionQueue] Processing started');

    while (_tasks.isNotEmpty) {
      final item = _tasks.removeFirst();
      debugPrint('[ConversionQueue] Running: "${item.label}"');

      try {
        await item.task();
        debugPrint('[ConversionQueue] Finished: "${item.label}"');
      } catch (e, stack) {
        // Crash-safe: catch all exceptions so the queue never stops.
        debugPrint('[ConversionQueue] ERROR in "${item.label}": $e');
        debugPrint('[ConversionQueue] $stack');
      }
    }

    _isProcessing = false;
    debugPrint('[ConversionQueue] Processing complete');
  }

  void clear() {
    _tasks.clear();
    debugPrint('[ConversionQueue] Cleared');
  }
}

class _QueuedTask {
  const _QueuedTask({required this.task, required this.label});
  final Future<void> Function() task;
  final String label;
}
