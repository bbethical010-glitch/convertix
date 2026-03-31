import 'package:lucide_icons/lucide_icons.dart';
import 'dart:io';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;
import 'package:permission_handler/permission_handler.dart';
import 'package:share_plus/share_plus.dart';

import '../../domain/conversion_task.dart';
import '../../domain/conversion_type.dart';
import '../../theme/design_system.dart';
import '../../services/storage_permission_handler.dart';
import '../../utils/file_opener.dart';

class ConversionSuccessDialog extends StatelessWidget {
  const ConversionSuccessDialog({super.key, required this.task});
  final ConversionTask task;

  @override
  Widget build(BuildContext context) {
    final cx = CxColors.of(context);
    final theme = Theme.of(context);
    final outputName = p.basename(task.outputPath);
    final relativePath = 'AllFormatConverter/${task.conversionType.outputMediaFolder}/$outputName';

    return Dialog(
      backgroundColor: cx.surfaceContainer,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
          child: Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: cx.glassCard,
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: cx.glassBorder),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 40, height: 40,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(12),
                        color: Colors.green.withValues(alpha: 0.15),
                      ),
                      child: const Icon(LucideIcons.checkCircle, color: Colors.green, size: 24),
                    ),
                    const SizedBox(width: 12),
                    Text('Conversion Complete',
                      style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800)),
                  ],
                ),
                const SizedBox(height: 20),
                Text('File saved to:', style: TextStyle(fontSize: 11, color: cx.onSurfaceVariant)),
                const SizedBox(height: 6),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  decoration: BoxDecoration(
                    color: cx.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Row(
                    children: [
                      Icon(LucideIcons.folder, size: 16, color: cx.primary),
                      const SizedBox(width: 8),
                      Expanded(child: Text(relativePath,
                        style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: cx.onSurface),
                        overflow: TextOverflow.ellipsis)),
                    ],
                  ),
                ),
                if (task.inputSizeBytes != null && task.outputSizeBytes != null) ...[
                  const SizedBox(height: 16),
                  _sizeRow(cx, 'Original', ConversionTask.formatBytes(task.inputSizeBytes!), LucideIcons.upload),
                  const SizedBox(height: 4),
                  _sizeRow(cx, 'Converted', ConversionTask.formatBytes(task.outputSizeBytes!), LucideIcons.download),
                  if (task.savedPercent != null) ...[
                    const SizedBox(height: 10),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        color: task.savedPercent! > 0 ? Colors.green.withValues(alpha: 0.1) : Colors.orange.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: task.savedPercent! > 0 ? Colors.green.withValues(alpha: 0.2) : Colors.orange.withValues(alpha: 0.2)),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(task.savedPercent! > 0 ? LucideIcons.trendingDown : LucideIcons.trendingUp,
                            size: 16, color: task.savedPercent! > 0 ? Colors.green : Colors.orange),
                          const SizedBox(width: 6),
                          Text(task.savedPercent! > 0
                                ? 'Saved ${task.savedPercent!.toStringAsFixed(0)}%'
                                : 'Size increased ${(-task.savedPercent!).toStringAsFixed(0)}%',
                            style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13,
                              color: task.savedPercent! > 0 ? Colors.green : Colors.orange)),
                        ],
                      ),
                    ),
                  ],
                ],
                const SizedBox(height: 24),
                Row(
                  children: [
                    Expanded(child: _ActionButton(icon: LucideIcons.externalLink, label: 'Open', isPrimary: true,
                      onTap: () async {
                        Navigator.of(context).pop();
                        final granted = await StoragePermissionHandler.requestStoragePermission(context);
                        if (granted) { await FileOpener.openFile(task.outputPath); }
                        else if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Storage permission required.'),
                              action: SnackBarAction(label: 'Settings', onPressed: openAppSettings)));
                        }
                      })),
                    const SizedBox(width: 10),
                    Expanded(child: _ActionButton(icon: LucideIcons.share2, label: 'Share',
                      onTap: () async {
                        Navigator.of(context).pop();
                        if (File(task.outputPath).existsSync()) {
                          await Share.shareXFiles([XFile(task.outputPath)], subject: 'Converted by Convertix');
                        }
                      })),
                    const SizedBox(width: 10),
                    Expanded(child: _ActionButton(icon: LucideIcons.folderOpen, label: 'Folder',
                      onTap: () { Navigator.of(context).pop(); FileOpener.openConverterFolder(); })),
                  ],
                ),
                const SizedBox(height: 12),
                Center(child: GestureDetector(
                  onTap: () => Navigator.of(context).pop(),
                  child: Text('OK', style: TextStyle(color: cx.primary, fontWeight: FontWeight.w600)))),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _sizeRow(CxColors cx, String label, String size, IconData icon) {
    return Row(
      children: [
        Icon(icon, size: 16, color: cx.onSurfaceVariant),
        const SizedBox(width: 8),
        Text('$label: ', style: TextStyle(fontSize: 12, color: cx.onSurfaceVariant)),
        Text(size, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: cx.onSurface)),
      ],
    );
  }
}

class _ActionButton extends StatelessWidget {
  const _ActionButton({required this.icon, required this.label, required this.onTap, this.isPrimary = false});
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool isPrimary;

  @override
  Widget build(BuildContext context) {
    final cx = CxColors.of(context);
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(14),
          gradient: isPrimary ? LinearGradient(colors: [cx.primary, AppColors.primaryDim]) : null,
          color: isPrimary ? null : cx.surfaceContainerHigh,
          border: isPrimary ? null : Border.all(color: cx.outlineVariant.withValues(alpha: 0.3)),
        ),
        child: Column(
          children: [
            Icon(icon, size: 18, color: isPrimary ? Colors.white : cx.onSurfaceVariant),
            const SizedBox(height: 4),
            Text(label, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600,
                color: isPrimary ? Colors.white : cx.onSurfaceVariant)),
          ],
        ),
      ),
    );
  }
}
