import 'package:lucide_icons/lucide_icons.dart';
import 'dart:ui';

import 'package:flutter/material.dart';

import '../../domain/conversion_task.dart';
import '../../theme/design_system.dart';
import '../../utils/file_manager.dart';
import '../../utils/file_opener.dart';

class StorageDashboardSheet extends StatefulWidget {
  const StorageDashboardSheet({super.key});

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
      builder: (_) => const StorageDashboardSheet(),
    );
  }

  @override
  State<StorageDashboardSheet> createState() => _StorageDashboardSheetState();
}

class _StorageDashboardSheetState extends State<StorageDashboardSheet> {
  final _fm = FileManager();
  int _fileCount = 0;
  int _totalBytes = 0;
  String _outputPath = FileManager.converterOutputDir;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadStats();
  }

  Future<void> _loadStats() async {
    setState(() => _loading = true);
    final (count, bytes) = await _fm.getStorageStats();
    final outputPath = await _fm.getActiveOutputDirectoryPath();
    if (mounted) {
      setState(() { _fileCount = count; _totalBytes = bytes; _outputPath = outputPath; _loading = false; });
    }
  }

  Future<void> _clearFiles() async {
    final cx = CxColors.of(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: cx.surfaceContainer,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Clear All Converted Files?'),
        content: Text('This will permanently delete $_fileCount file(s) (${ConversionTask.formatBytes(_totalBytes)}).'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Delete All')),
        ],
      ),
    );
    if (confirmed == true) { await _fm.clearConvertedFiles(); await _loadStats(); }
  }

  @override
  Widget build(BuildContext context) {
    final cx = CxColors.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            margin: const EdgeInsets.only(bottom: 16),
            width: 40, height: 4,
            decoration: BoxDecoration(color: cx.outlineVariant, borderRadius: BorderRadius.circular(2)),
          ),
          Row(
            children: [
              Icon(LucideIcons.database, color: cx.primary),
              const SizedBox(width: 10),
              Text('Storage Dashboard',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
            ],
          ),
          const SizedBox(height: 20),
          if (_loading)
            Padding(padding: const EdgeInsets.all(24),
              child: CircularProgressIndicator(color: cx.primary))
          else ...[
            Row(
              children: [
                Expanded(child: _StatCard(icon: LucideIcons.file,
                    label: 'Total Files', value: '$_fileCount', color: cx.primary)),
                const SizedBox(width: 12),
                Expanded(child: _StatCard(icon: LucideIcons.hardDrive,
                    label: 'Storage Used', value: ConversionTask.formatBytes(_totalBytes), color: AppColors.tertiary)),
              ],
            ),
            const SizedBox(height: 20),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(color: cx.surfaceContainerHighest, borderRadius: BorderRadius.circular(12)),
              child: Row(
                children: [
                  Icon(LucideIcons.folder, size: 18, color: cx.primary),
                  const SizedBox(width: 8),
                  Expanded(child: Text(_outputPath,
                    style: TextStyle(fontSize: 12, color: cx.onSurfaceVariant), overflow: TextOverflow.ellipsis)),
                ],
              ),
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(child: _ActionBtn(icon: LucideIcons.folderOpen, label: 'Open Folder',
                    onTap: () => FileOpener.openConverterFolder())),
                const SizedBox(width: 12),
                Expanded(child: _ActionBtn(icon: LucideIcons.trash2, label: 'Clear Files',
                    isDestructive: true, onTap: _fileCount > 0 ? _clearFiles : null)),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  const _StatCard({required this.icon, required this.label, required this.value, required this.color});
  final IconData icon;
  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final cx = CxColors.of(context);
    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: color.withValues(alpha: 0.15)),
          ),
          child: Column(
            children: [
              Icon(icon, color: color, size: 28),
              const SizedBox(height: 8),
              Text(value, style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold, color: color)),
              const SizedBox(height: 4),
              Text(label, style: TextStyle(fontSize: 12, color: cx.onSurfaceVariant)),
            ],
          ),
        ),
      ),
    );
  }
}

class _ActionBtn extends StatelessWidget {
  const _ActionBtn({required this.icon, required this.label, this.onTap, this.isDestructive = false});
  final IconData icon;
  final String label;
  final VoidCallback? onTap;
  final bool isDestructive;

  @override
  Widget build(BuildContext context) {
    final cx = CxColors.of(context);
    final color = isDestructive ? AppColors.error : cx.primary;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: onTap == null ? cx.outlineVariant.withValues(alpha: 0.2) : color.withValues(alpha: 0.3)),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 18, color: onTap == null ? cx.outlineVariant : color),
            const SizedBox(width: 8),
            Text(label, style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13,
                color: onTap == null ? cx.outlineVariant : color)),
          ],
        ),
      ),
    );
  }
}
