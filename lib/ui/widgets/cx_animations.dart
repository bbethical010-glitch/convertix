import 'package:flutter/material.dart';

/// A wrapper that adds a subtle scale-down effect when pressed.
class AnimatedPressEffect extends StatefulWidget {
  final Widget child;
  final VoidCallback? onTap;
  final double scaleAmount;

  const AnimatedPressEffect({
    super.key,
    required this.child,
    this.onTap,
    this.scaleAmount = 0.96,
  });

  @override
  State<AnimatedPressEffect> createState() => _AnimatedPressEffectState();
}

class _AnimatedPressEffectState extends State<AnimatedPressEffect>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _scale;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 100),
    );
    _scale = Tween<double>(begin: 1.0, end: widget.scaleAmount).animate(
      CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  void _handleTapDown(TapDownDetails _) => _ctrl.forward();
  void _handleTapUp(TapUpDetails _) {
    _ctrl.reverse();
    widget.onTap?.call();
  }
  void _handleTapCancel() => _ctrl.reverse();

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: widget.onTap == null ? null : _handleTapDown,
      onTapUp: widget.onTap == null ? null : _handleTapUp,
      onTapCancel: widget.onTap == null ? null : _handleTapCancel,
      child: ScaleTransition(
        scale: _scale,
        child: widget.child,
      ),
    );
  }
}

/// A wrapper that adds a subtle glow effect around the child.
class HoverGlowEffect extends StatelessWidget {
  final Widget child;
  final Color glowColor;
  final bool isGlowActive;

  const HoverGlowEffect({
    super.key,
    required this.child,
    required this.glowColor,
    this.isGlowActive = true,
  });

  @override
  Widget build(BuildContext context) {
    if (!isGlowActive) return child;

    return Container(
      decoration: BoxDecoration(
        boxShadow: [
          BoxShadow(
            color: glowColor.withValues(alpha: 0.1),
            blurRadius: 20,
            spreadRadius: 2,
          ),
        ],
      ),
      child: child,
    );
  }
}

/// A shimmer sweep effect for buttons.
class ShimmerSweepPainter extends CustomPainter {
  final double progress;
  final Color shimmerColor;

  ShimmerSweepPainter({required this.progress, required this.shimmerColor});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        stops: [
          (progress - 0.2).clamp(0.0, 1.0),
          progress.clamp(0.0, 1.0),
          (progress + 0.2).clamp(0.0, 1.0),
        ],
        colors: [
          Colors.transparent,
          shimmerColor.withValues(alpha: 0.2),
          Colors.transparent,
        ],
      ).createShader(Rect.fromLTWH(0, 0, size.width, size.height));

    canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height), paint);
  }

  @override
  bool shouldRepaint(ShimmerSweepPainter oldDelegate) => oldDelegate.progress != progress;
}
