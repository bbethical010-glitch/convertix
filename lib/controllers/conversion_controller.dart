import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;

import '../domain/conversion_history_entry.dart';
import '../domain/conversion_preset.dart';
import '../domain/conversion_task.dart';
import '../domain/conversion_type.dart';
import '../domain/media_type.dart';
import '../controllers/premium_controller.dart';
import '../services/conversion_queue.dart';
import '../services/conversion_state.dart';
import '../services/media_conversion_service.dart';
import '../services/media_type_detector.dart';
import '../utils/file_manager.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:provider/provider.dart';
import '../theme/design_system.dart';

class ConversionController extends ChangeNotifier {
  ConversionController({
    required this.conversionService,
    required this.fileManager,
    required this.premiumController,
  }) {
    unawaited(_restoreHistory());
    unawaited(_loadSettings());
  }

  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    _autoDeleteOriginals = prefs.getBool('auto_delete_originals') ?? false;
    notifyListeners();
  }

  Future<void> setAutoDeleteOriginals(bool value) async {
    _autoDeleteOriginals = value;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('auto_delete_originals', value);
    notifyListeners();
  }

  static const int maxSimultaneousConversions = 10;
  static const int _maxHistory = 50;

  final FFmpegService conversionService;
  final FileManager fileManager;
  final MediaTypeDetector _detector = const MediaTypeDetector();
  final _queue = ConversionQueue();

  final List<ConversionTask> _tasks = [];
  final List<ConversionHistoryEntry> _history = [];

  StreamSubscription<ConversionProgress>? _progressSub;
  String? _lastError;
  String? _lastSuccess;
  ConversionTask? _lastCompletedTask;
  final PremiumController premiumController;
  bool _autoDeleteOriginals = false;
  bool get autoDeleteOriginals => _autoDeleteOriginals;


  bool get isProFeatureUnlocked => premiumController.isProSessionActive || premiumController.isPermanentPremium;

  void unlockProFeatures() {
    // This is now handled by PremiumController directly via AdUnlockSheet
    // but we keep this for backwards compatibility if needed.
    premiumController.unlockProSession();
  }

  void lockProFeatures() {
    premiumController.lockProSession();
  }

  List<ConversionTask> get queue => List.unmodifiable(_tasks);
  List<ConversionHistoryEntry> get history => List.unmodifiable(_history);
  bool get isConverting => ConversionState.isRunning;
  String? get lastError => _lastError;
  String? get lastSuccess => _lastSuccess;
  ConversionTask? get lastCompletedTask => _lastCompletedTask;

  ConversionTask? get activeTask => _tasks.cast<ConversionTask?>().firstWhere(
        (t) => t?.status == TaskStatus.running,
        orElse: () => null,
      );

  String get statusLine {
    final active = activeTask;
    if (active == null) return '';
    final pct = (active.progress * 100).toStringAsFixed(0);
    final speed = active.speed != null ? '  ${active.speed}' : '';
    final eta = active.eta != null ? '  ETA ${active.eta}' : '';
    return '${active.inputName}  →  .${active.outputExtension}   $pct%$speed$eta';
  }

  void consumeLastCompletedTask() {
    _lastCompletedTask = null;
    notifyListeners();
  }

  void removeHistoryEntry(ConversionHistoryEntry entry) {
    _history.remove(entry);
    unawaited(_persistHistory());
    notifyListeners();
  }

  void insertHistoryEntry(int index, ConversionHistoryEntry entry) {
    _history.insert(index.clamp(0, _history.length), entry);
    unawaited(_persistHistory());
    notifyListeners();
  }

  Future<void> rerunHistoryEntry(ConversionHistoryEntry entry) async {
    final sources = <PickedFileInfo>[];
    for (var i = 0; i < entry.inputPaths.length; i++) {
      final path = entry.inputPaths[i];
      final name =
          i < entry.inputNames.length ? entry.inputNames[i] : p.basename(path);
      if (File(path).existsSync()) {
        sources.add(PickedFileInfo(path: path, name: name));
      }
    }
    if (sources.isEmpty) {
      _lastError = 'Original source files are no longer available.';
      notifyListeners();
      return;
    }

    PickedFileInfo? secondary;
    if (entry.secondaryInputPath != null && entry.secondaryInputName != null) {
      if (File(entry.secondaryInputPath!).existsSync()) {
        secondary = PickedFileInfo(
          path: entry.secondaryInputPath!,
          name: entry.secondaryInputName!,
        );
      }
    }

    await enqueueAndStart(
      files: sources,
      conversionType: entry.conversionType,
      outputExtension: entry.outputFormat.toLowerCase(),
      preset: entry.preset,
      secondaryFile: secondary,
    );
  }

  Future<void> enqueueAndStart({
    required List<PickedFileInfo> files,
    required ConversionType conversionType,
    required String outputExtension,
    required ConversionPreset preset,
    PickedFileInfo? secondaryFile,
    String? customOutputDir,
  }) async {
    _lastError = null;
    _lastSuccess = null;

    if (files.isEmpty) {
      _lastError = 'Select at least one source file.';
      notifyListeners();
      return;
    }
    if (files.length > maxSimultaneousConversions) {
      _lastError =
          'You can start up to $maxSimultaneousConversions conversions at once.';
      notifyListeners();
      return;
    }

    final sizeError = _validateFileSizes(
      files: files,
      conversionType: conversionType,
      secondaryFile: secondaryFile,
    );
    if (sizeError != null) {
      _lastError = sizeError;
      notifyListeners();
      return;
    }

    List<ConversionTask> tasks;
    try {
      tasks = await _buildTasks(
        files: files,
        conversionType: conversionType,
        outputExtension: outputExtension,
        preset: preset,
        secondaryFile: secondaryFile,
        customOutputDir: customOutputDir,
      );
    } catch (e) {
      _lastError = 'Unable to create output folder: $e';
      notifyListeners();
      return;
    }

    if (tasks.isEmpty) {
      _lastError = 'Could not build conversion tasks for the selected files.';
      notifyListeners();
      return;
    }

    _tasks.addAll(tasks);
    notifyListeners();

    for (final task in tasks) {
      _queue.addTask(
        () => _executeSingleTask(task),
        label: '${task.inputName} → .${task.outputExtension}',
      );
    }
  }

  String? _validateFileSizes({
    required List<PickedFileInfo> files,
    required ConversionType conversionType,
    PickedFileInfo? secondaryFile,
  }) {
    MediaType primaryType;
    switch (conversionType) {
      case ConversionType.videoToAudio:
      case ConversionType.videoToGif:
      case ConversionType.videoToVideo:
      case ConversionType.videoCompress:
        primaryType = MediaType.video;
      case ConversionType.audioToAudio:
      case ConversionType.audioToVideo:
        primaryType = MediaType.audio;
      case ConversionType.imageToImage:
      case ConversionType.imageToPdf:
        primaryType = MediaType.image;
    }

    for (final file in files) {
      if (_detector.exceedsMaxSize(
          filePath: file.path, mediaType: primaryType)) {
        final max =
            ConversionTask.formatBytes(_detector.maxSizeFor(primaryType));
        return '${file.name} exceeds the $max limit for ${primaryType.name} inputs.';
      }
    }

    if (conversionType == ConversionType.audioToVideo &&
        secondaryFile != null) {
      if (_detector.exceedsMaxSize(
        filePath: secondaryFile.path,
        mediaType: MediaType.image,
      )) {
        final max =
            ConversionTask.formatBytes(_detector.maxSizeFor(MediaType.image));
        return '${secondaryFile.name} exceeds the $max image size limit.';
      }
    }
    return null;
  }

  Future<List<ConversionTask>> _buildTasks({
    required List<PickedFileInfo> files,
    required ConversionType conversionType,
    required String outputExtension,
    required ConversionPreset preset,
    PickedFileInfo? secondaryFile,
    String? customOutputDir,
  }) async {
    final built = <ConversionTask>[];

    if (conversionType == ConversionType.imageToPdf) {
      final first = files.first;
      final outputFile = await fileManager.buildOutputFilePath(
        inputPath: first.path,
        outputExtension: outputExtension,
        customOutputDir: customOutputDir,
        baseNameOverride:
            '${p.basenameWithoutExtension(first.name)}_${DateTime.now().millisecondsSinceEpoch}',
      );
      built.add(
        ConversionTask(
          inputPath: first.path,
          inputName: '${files.length} image(s)',
          inputPaths: files.map((f) => f.path).toList(),
          inputNames: files.map((f) => f.name).toList(),
          outputPath: outputFile.path,
          mediaType: MediaType.image,
          conversionType: conversionType,
          outputExtension: outputExtension,
          preset: preset,
        ),
      );
      return built;
    }

    for (final file in files) {
      final outputFile = await fileManager.buildOutputFilePath(
        inputPath: file.path,
        outputExtension: outputExtension,
        customOutputDir: customOutputDir,
      );
      final mediaType = _detector.detect(file.path) ?? MediaType.audio;
      built.add(
        ConversionTask(
          inputPath: file.path,
          inputName: file.name,
          inputPaths: [file.path],
          inputNames: [file.name],
          outputPath: outputFile.path,
          mediaType: mediaType,
          conversionType: conversionType,
          outputExtension: outputExtension,
          preset: preset,
          secondaryInputPath: secondaryFile?.path,
          secondaryInputName: secondaryFile?.name,
        ),
      );
    }

    return built;
  }

  void clearCompleted() {
    _tasks.removeWhere(
      (t) => t.status == TaskStatus.done || t.status == TaskStatus.failed,
    );
    _lastError = null;
    _lastSuccess = null;
    notifyListeners();
  }

  Future<void> _executeSingleTask(ConversionTask task) async {
    task.status = TaskStatus.running;
    task.progress = 0.0;
    ConversionState.markStarted();
    notifyListeners();

    _progressSub = conversionService.progressStream.listen((prog) {
      if (task.status == TaskStatus.running) {
        task.progress = prog.percent;
        task.speed = prog.speed;
        task.eta = prog.eta;
        notifyListeners();
      }
    });

    try {
      final inputPaths = <String>[...task.inputPaths];
      if (task.conversionType == ConversionType.audioToVideo &&
          task.secondaryInputPath != null) {
        inputPaths
          ..clear()
          ..add(task.inputPath)
          ..add(task.secondaryInputPath!);
      }

      final result = await conversionService.convert(
        conversionType: task.conversionType,
        inputPaths: inputPaths,
        outputPath: task.outputPath,
        preset: task.preset,
        isPro: premiumController.isProSessionActive, // Pass pro status
      );

      if (result.success) {
        task.status = TaskStatus.done;
        task.progress = 1.0;

        try {
          task.inputSizeBytes = File(task.inputPath).lengthSync();
          task.outputSizeBytes = File(task.outputPath).lengthSync();
        } catch (_) {}

        _lastSuccess = 'Saved ${p.basename(task.outputPath)}';

        if (_autoDeleteOriginals) {
          try {
            for (final path in task.inputPaths) {
              final f = File(path);
              if (f.existsSync()) f.deleteSync();
            }
          } catch (_) {}
        }

        _history.insert(
          0,
          ConversionHistoryEntry(
            inputPath: task.inputPath,
            inputName: task.inputName,
            inputPaths: task.inputPaths,
            inputNames: task.inputNames,
            sourceFormat: _sourceFormatForTask(task),
            outputPath: task.outputPath,
            outputFormat: task.outputExtension.toUpperCase(),
            conversionType: task.conversionType,
            preset: task.preset,
            secondaryInputPath: task.secondaryInputPath,
            secondaryInputName: task.secondaryInputName,
            completedAt: DateTime.now(),
          ),
        );
        if (_history.length > _maxHistory) _history.removeLast();
        unawaited(_persistHistory());
        _lastCompletedTask = task;
        ConversionState.markFinished();
      } else {
        task.status = TaskStatus.failed;
        task.errorMessage = result.message;
        task.progress = 0.0;
        _lastError = result.message;
        ConversionState.markFailed(result.message);
      }
    } catch (e) {
      task.status = TaskStatus.failed;
      task.errorMessage = 'Exception: $e';
      task.progress = 0.0;
      _lastError = 'Exception: $e';
      ConversionState.markFailed('$e');
    } finally {
      await _progressSub?.cancel();
      _progressSub = null;

      if (!_tasks.any((t) => t.status == TaskStatus.running)) {
        try {
          await fileManager.cleanupTempFiles();
        } catch (_) {}
      }

      notifyListeners();

      // Only lock if there are no more running or pending tasks
      final hasActive = _tasks.any((t) => t.status == TaskStatus.running || t.status == TaskStatus.pending);
      if (!hasActive) {
        lockProFeatures();
      }
    }
  }

  String _sourceFormatForTask(ConversionTask task) {
    final formats = task.inputNames
        .map((name) => p.extension(name).replaceFirst('.', '').toUpperCase())
        .where((ext) => ext.isNotEmpty)
        .toSet();
    if (formats.isEmpty) return 'UNKNOWN';
    if (formats.length == 1) return formats.first;
    return 'MULTI';
  }

  Future<void> _restoreHistory() async {
    final records = await fileManager.loadHistoryRecords();
    if (records.isEmpty) return;

    final restored = <ConversionHistoryEntry>[];
    for (final record in records) {
      try {
        final entry = ConversionHistoryEntry.fromJson(record);
        if (entry.outputPath.isNotEmpty) {
          restored.add(entry);
        }
      } catch (_) {}
    }

    restored.sort((a, b) => b.completedAt.compareTo(a.completedAt));
    _history
      ..clear()
      ..addAll(restored.take(_maxHistory));
    notifyListeners();
  }

  Future<void> _persistHistory() async {
    await fileManager.saveHistoryRecords(
      _history.take(_maxHistory).map((entry) => entry.toJson()).toList(),
    );
  }

  @override
  void dispose() {
    _progressSub?.cancel();
    conversionService.dispose();
    super.dispose();
  }
}
