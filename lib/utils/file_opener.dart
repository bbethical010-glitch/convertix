import 'dart:io';

import 'package:android_intent_plus/android_intent.dart';
import 'package:flutter/foundation.dart';
import 'package:open_filex/open_filex.dart';

import 'file_manager.dart';

/// Centralised helper for opening files and folders on Android.
class FileOpener {
  FileOpener._();

  // ---------------------------------------------------------------------------
  // Open a converted file
  // ---------------------------------------------------------------------------

  static Future<void> openFile(String path) async {
    try {
      final result = await OpenFilex.open(path);
      debugPrint(
          '[FileOpener] open file result: ${result.type} – ${result.message}');
    } catch (e) {
      debugPrint('[FileOpener] open file error: $e');
    }
  }

  // ---------------------------------------------------------------------------
  // Open the AllFormatConverter folder in the system file manager
  // ---------------------------------------------------------------------------

  static Future<void> openConverterFolder() async {
    if (!Platform.isAndroid) return;

    // Get the actual output directory path
    final fm = FileManager();
    final outputPath = await fm.getActiveOutputDirectoryPath();
    debugPrint('[FileOpener] Attempting to open folder: $outputPath');

    // Ensure the folder exists
    final dir = Directory(outputPath);
    if (!dir.existsSync()) {
      try {
        dir.createSync(recursive: true);
      } catch (e) {
        debugPrint('[FileOpener] Cannot create dir: $e');
      }
    }

    // Strategy 1: Open with Documents UI using the tree URI
    final strategies = <Future<bool> Function()>[
      // Open the specific AllFormatConverter folder
      () => _launchDocumentUri(
          'content://com.android.externalstorage.documents/document/primary%3AAllFormatConverter'),
      // Open the root of primary storage
      () => _launchDocumentUri(
          'content://com.android.externalstorage.documents/document/primary%3A'),
      // Generic file manager intent
      () => _launchFileManager(),
    ];

    for (final strategy in strategies) {
      try {
        final success = await strategy();
        if (success) return;
      } catch (e) {
        debugPrint('[FileOpener] Strategy failed: $e');
      }
    }

    debugPrint('[FileOpener] All strategies failed.');
  }

  static Future<bool> _launchDocumentUri(String uri) async {
    try {
      final intent = AndroidIntent(
        action: 'android.intent.action.VIEW',
        data: uri,
        type: 'vnd.android.document/root',
        flags: const <int>[0x10000000], // FLAG_ACTIVITY_NEW_TASK
      );
      await intent.launch();
      debugPrint('[FileOpener] Launched document URI: $uri');
      return true;
    } catch (e) {
      debugPrint('[FileOpener] Document URI failed ($uri): $e');

      // Retry without MIME type
      try {
        final intent = AndroidIntent(
          action: 'android.intent.action.VIEW',
          data: uri,
          flags: const <int>[0x10000000],
        );
        await intent.launch();
        debugPrint('[FileOpener] Launched without MIME: $uri');
        return true;
      } catch (e2) {
        debugPrint('[FileOpener] Retry also failed: $e2');
        return false;
      }
    }
  }

  static Future<bool> _launchFileManager() async {
    try {
      // Try to open the built-in file manager
      const intent = AndroidIntent(
        action: 'android.intent.action.MAIN',
        category: 'android.intent.category.APP_FILES',
        flags: <int>[0x10000000],
      );
      await intent.launch();
      debugPrint('[FileOpener] Launched system file manager');
      return true;
    } catch (e) {
      debugPrint('[FileOpener] File manager launch failed: $e');
      // Last resort: try com.android.documentsui
      try {
        const intent = AndroidIntent(
          action: 'android.intent.action.MAIN',
          package: 'com.android.documentsui',
          componentName: 'com.android.documentsui.files.FilesActivity',
          flags: <int>[0x10000000],
        );
        await intent.launch();
        return true;
      } catch (e2) {
        debugPrint('[FileOpener] DocumentsUI launch failed: $e2');
        return false;
      }
    }
  }
}
