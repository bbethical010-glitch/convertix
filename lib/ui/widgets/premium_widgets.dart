import 'package:lucide_icons/lucide_icons.dart';
import 'package:flutter/material.dart';
import '../../controllers/premium_controller.dart';
import 'package:provider/provider.dart';
import '../../theme/design_system.dart';

class AdUnlockSheet extends StatelessWidget {
  const AdUnlockSheet({super.key, required this.featureName});
  final String featureName;

  static void show(BuildContext context, String feature) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => AdUnlockSheet(featureName: feature),
    );
  }

  @override
  Widget build(BuildContext context) {
    final cx = CxColors.of(context);
    final premium = context.watch<PremiumController>();

    return Container(
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(
        color: cx.surfaceContainerLow,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
        border: Border.all(color: cx.glassBorder),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 40, height: 4,
            decoration: BoxDecoration(color: cx.onSurfaceVariant.withValues(alpha: 0.2), borderRadius: BorderRadius.circular(2)),
          ),
          const SizedBox(height: 24),
          const Icon(Icons.stars_rounded, size: 64, color: AppColors.tertiary),
          const SizedBox(height: 16),
          Text(
            'Unlock PRO Features',
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w900, color: cx.primary),
          ),
          const SizedBox(height: 12),
          Text(
            'Watch a short ad to unlock $featureName and all other PRO features for this session.',
            textAlign: TextAlign.center,
            style: TextStyle(color: cx.onSurfaceVariant, height: 1.5),
          ),
          const SizedBox(height: 32),
          SizedBox(
            width: double.infinity,
            height: 60,
            child: ElevatedButton.icon(
              onPressed: premium.isSimulating ? null : () async {
                final success = await premium.unlockProSession();
                if (success && context.mounted) {
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('PRO Features Unlocked for this session!'), backgroundColor: AppColors.tertiary),
                  );
                }
              },
              icon: premium.isSimulating 
                ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                : const Icon(LucideIcons.playCircle),
              label: Text(premium.isSimulating ? 'Summoning Ad...' : 'Watch Ad to Unlock'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.tertiary,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              ),
            ),
          ),
          const SizedBox(height: 12),
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Maybe Later', style: TextStyle(color: cx.onSurfaceVariant)),
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }
}

class ProSessionBadge extends StatelessWidget {
  const ProSessionBadge({super.key});

  @override
  Widget build(BuildContext context) {
    final premium = context.watch<PremiumController>();
    if (!premium.isProSessionActive) return const SizedBox.shrink();

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: AppColors.tertiary.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.tertiary.withValues(alpha: 0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.stars_rounded, size: 14, color: AppColors.tertiary),
          SizedBox(width: 6),
          Text(
            'PRO ACTIVE',
            style: TextStyle(color: AppColors.tertiary, fontSize: 10, fontWeight: FontWeight.w900, letterSpacing: 0.5),
          ),
        ],
      ),
    );
  }
}
