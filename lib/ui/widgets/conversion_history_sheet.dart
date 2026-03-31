import 'package:lucide_icons/lucide_icons.dart';
import 'dart:io';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';

import '../../controllers/conversion_controller.dart';
import '../../domain/conversion_history_entry.dart';
import '../../theme/design_system.dart';
import '../../services/storage_permission_handler.dart';
import '../../utils/file_opener.dart';

class ConversionHistorySheet extends StatelessWidget {
  const ConversionHistorySheet({super.key});

  static void show(BuildContext context) {
    final cx = CxColors.of(context);
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: cx.surfaceContainer,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => const ConversionHistorySheet(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final cx = CxColors.of(context);
    final ctrl = context.watch<ConversionController>();
    final history = ctrl.history;

    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.6,
      maxChildSize: 0.92,
      builder: (_, scrollController) {
        return Column(
          children: [
            Container(
              margin: const EdgeInsets.only(top: 12, bottom: 4),
              width: 40, height: 4,
              decoration: BoxDecoration(color: cx.outlineVariant, borderRadius: BorderRadius.circular(2)),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 16, 4),
              child: Row(
                children: [
                  Icon(LucideIcons.history, color: cx.primary),
                  const SizedBox(width: 10),
                  Text('Recent Conversions',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
                  const Spacer(),
                  GestureDetector(
                    onTap: () => FileOpener.openConverterFolder(),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(10),
                        color: cx.primary.withValues(alpha: 0.1),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(LucideIcons.folderOpen, size: 16, color: cx.primary),
                          const SizedBox(width: 6),
                          Text('Open Folder', style: TextStyle(fontSize: 12,
                              fontWeight: FontWeight.w600, color: cx.primary)),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Divider(color: cx.glassBorder, height: 1),
            if (history.isEmpty)
              Expanded(child: Center(child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(LucideIcons.clock, size: 48, color: cx.outlineVariant),
                  const SizedBox(height: 12),
                  Text('No conversions yet', style: TextStyle(color: cx.onSurfaceVariant)),
                ],
              )))
            else
              Expanded(
                child: ListView.builder(
                  controller: scrollController,
                  itemCount: history.length,
                  itemBuilder: (_, i) => _buildTile(context, history[i], ctrl, cx),
                ),
              ),
          ],
        );
      },
    );
  }

  Widget _buildTile(BuildContext context, ConversionHistoryEntry entry,
      ConversionController ctrl, CxColors cx) {
    final exists = File(entry.outputPath).existsSync();
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(14),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 5, sigmaY: 5),
          child: Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: cx.glassCard,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: cx.glassBorder),
            ),
            child: Row(
              children: [
                Container(
                  width: 40, height: 40,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(10),
                    color: cx.surfaceContainerHighest,
                  ),
                  child: Icon(_iconForExt(entry.outputFormat), size: 20, color: cx.primary),
                ),
                const SizedBox(width: 12),
                Expanded(child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(entry.inputName, maxLines: 1, overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                    const SizedBox(height: 2),
                    Text('${entry.sourceFormat} → ${entry.outputFormat} • ${_formatTime(entry.completedAt)}',
                      maxLines: 1, overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontSize: 11, color: cx.primary)),
                  ],
                )),
                IconButton(tooltip: 'Re-run',
                  icon: Icon(LucideIcons.refreshCcw, size: 18, color: cx.onSurfaceVariant),
                  onPressed: () => ctrl.rerunHistoryEntry(entry)),
                if (exists) IconButton(tooltip: 'Open',
                  icon: Icon(LucideIcons.externalLink, size: 18, color: cx.onSurfaceVariant),
                  onPressed: () async {
                    final granted = await StoragePermissionHandler.requestStoragePermission(context);
                    if (granted) { await FileOpener.openFile(entry.outputPath); }
                    else if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Storage permission required.'),
                          action: SnackBarAction(label: 'Settings', onPressed: openAppSettings)));
                    }
                  }),
                if (exists) IconButton(tooltip: 'Share',
                  icon: Icon(LucideIcons.share2, size: 18, color: cx.onSurfaceVariant),
                  onPressed: () async {
                    await Share.shareXFiles([XFile(entry.outputPath)], subject: 'Converted by Convertix');
                  }),
                IconButton(tooltip: 'Remove',
                  icon: Icon(LucideIcons.x, size: 16, color: cx.onSurfaceVariant),
                  onPressed: () => ctrl.removeHistoryEntry(entry)),
              ],
            ),
          ),
        ),
      ),
    );
  }

  String _formatTime(DateTime t) {
    final h = t.hour.toString().padLeft(2, '0');
    final m = t.minute.toString().padLeft(2, '0');
    final d = t.day.toString().padLeft(2, '0');
    final mo = t.month.toString().padLeft(2, '0');
    return '$d/$mo $h:$m';
  }

  IconData _iconForExt(String ext) {
    switch (ext.toLowerCase()) {
      case 'mp4': case 'mkv': case 'avi': case 'mov': case 'webm': case 'gif': return LucideIcons.video;
      case 'mp3': case 'aac': case 'ogg': case 'wav': case 'flac': case 'm4a': return LucideIcons.music;
      case 'pdf': return LucideIcons.fileText;
      default: return LucideIcons.image;
    }
  }
}
