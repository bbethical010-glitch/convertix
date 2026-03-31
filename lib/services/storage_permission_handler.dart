import 'dart:io';

import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';

class StoragePermissionHandler {
  static Future<bool> requestStoragePermission(BuildContext context) async {
    if (!Platform.isAndroid) return true;

    final androidVersion = await _getAndroidVersion();

    if (androidVersion >= 30) {
      final status = await Permission.manageExternalStorage.status;
      if (status.isGranted) return true;
      if (!context.mounted) return false;

      final shouldOpen = await _showPermissionDialog(context);
      if (shouldOpen) {
        await Permission.manageExternalStorage.request();
        return await Permission.manageExternalStorage.status.isGranted;
      }
      return false;
    } else {
      final status = await Permission.storage.request();
      return status.isGranted;
    }
  }

  static Future<bool> _showPermissionDialog(BuildContext context) async {
    return await showDialog<bool>(
          context: context,
          barrierDismissible: false,
          builder: (context) => AlertDialog(
            title: const Text('Storage Access Required'),
            content: const Text(
              'AllFormat needs access to your storage to save converted files. '
              'Please tap "Open Settings" and enable "Allow access to manage all files".',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text('Open Settings'),
              ),
            ],
          ),
        ) ??
        false;
  }

  static Future<int> _getAndroidVersion() async {
    try {
      final info = await DeviceInfoPlugin().androidInfo;
      return info.version.sdkInt;
    } catch (_) {
      return 30;
    }
  }
}
