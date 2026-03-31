import 'package:lucide_icons/lucide_icons.dart';
import 'dart:ui';
import 'package:flutter/material.dart';
import '../../theme/design_system.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ShowcaseItem {
  final GlobalKey key;
  final String title;
  final String description;

  ShowcaseItem({required this.key, required this.title, required this.description});
}

class GlassShowcase {
  static Future<bool> hasSeenTutorial() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool('has_seen_tutorial') ?? false;
  }

  static Future<void> markTutorialSeen() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('has_seen_tutorial', true);
  }

  static Future<void> resetTutorial() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('has_seen_tutorial', false);
  }

  static void show(BuildContext context, List<ShowcaseItem> items) {
    if (items.isEmpty) return;
    
    OverlayState? overlayState = Overlay.of(context);
    OverlayEntry? overlayEntry;

    overlayEntry = OverlayEntry(
      builder: (context) => _GlassShowcaseOverlay(
        items: items,
        onComplete: () {
          markTutorialSeen();
          overlayEntry?.remove();
        },
      ),
    );

    overlayState.insert(overlayEntry);
  }
}

class _GlassShowcaseOverlay extends StatefulWidget {
  final List<ShowcaseItem> items;
  final VoidCallback onComplete;

  const _GlassShowcaseOverlay({required this.items, required this.onComplete});

  @override
  State<_GlassShowcaseOverlay> createState() => _GlassShowcaseOverlayState();
}

class _GlassShowcaseOverlayState extends State<_GlassShowcaseOverlay> with TickerProviderStateMixin {
  int _currentIndex = 0;
  Rect? _targetRect;
  
  late final AnimationController _ctrl;
  late final AnimationController _pulseCtrl;
  late final Animation<double> _fade;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 350))..forward();
    _pulseCtrl = AnimationController(vsync: this, duration: const Duration(seconds: 2))..repeat();
    _fade = CurvedAnimation(parent: _ctrl, curve: Curves.easeOutExpo);
    WidgetsBinding.instance.addPostFrameCallback((_) => _calculateRect());
  }

  @override
  void dispose() {
    _ctrl.dispose();
    _pulseCtrl.dispose();
    super.dispose();
  }

  void _calculateRect() {
    final key = widget.items[_currentIndex].key;
    if (key.currentContext != null) {
      final RenderBox box = key.currentContext!.findRenderObject() as RenderBox;
      final offset = box.localToGlobal(Offset.zero);
      setState(() {
        _targetRect = Rect.fromLTWH(offset.dx - 12, offset.dy - 12, box.size.width + 24, box.size.height + 24);
      });
    } else {
      WidgetsBinding.instance.addPostFrameCallback((_) => _next());
    }
  }

  void _next() {
    if (_currentIndex < widget.items.length - 1) {
      _ctrl.reverse().then((_) {
        if (!mounted) return;
        setState(() => _currentIndex++);
        _calculateRect();
        _ctrl.forward();
      });
    } else {
      _skip();
    }
  }

  void _skip() {
    _ctrl.reverse().then((_) {
      if (mounted) widget.onComplete();
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_targetRect == null) return const SizedBox.shrink();
    
    final cx = CxColors.of(context);
    final item = widget.items[_currentIndex];
    final screen = MediaQuery.of(context).size;

    final bool showBelow = _targetRect!.bottom + 220 < screen.height;
    final double tooltipTop = showBelow ? _targetRect!.bottom + 32 : _targetRect!.top - 200;

    return Material(
      color: Colors.transparent,
      child: Stack(
        children: [
          // Background Hole with Pulse
          AnimatedBuilder(
            animation: Listenable.merge([_fade, _pulseCtrl]),
            builder: (context, child) => CustomPaint(
              size: screen,
              painter: _HolePainter(
                rect: _targetRect!,
                opacity: _fade.value * 0.8,
                primaryColor: cx.primary,
                pulse: _pulseCtrl.value,
              ),
            ),
          ),
          
          // Fullscreen hit detector
          Positioned.fill(
            child: GestureDetector(
              onTap: _next,
              behavior: HitTestBehavior.translucent,
            ),
          ),

          // Bouncing Finger/Arrow Indicator
          AnimatedBuilder(
            animation: Listenable.merge([_fade, _pulseCtrl]),
            builder: (context, _) {
              final val = (Curves.easeInOut.transform(_pulseCtrl.value) - 0.5).abs() * 2;
              final offset = (showBelow ? -15.0 : 15.0) * val;
              final arrowTop = showBelow ? _targetRect!.bottom + 10 : _targetRect!.top - 40;
              
              return Positioned(
                top: arrowTop + offset,
                left: _targetRect!.center.dx - 15,
                child: Opacity(
                  opacity: _fade.value,
                  child: Icon(
                    showBelow ? LucideIcons.chevronsUp : LucideIcons.chevronsDown,
                    color: cx.primary, size: 30,
                  ),
                ),
              );
            },
          ),

          // Tooltip
          Positioned(
            left: 20,
            right: 20,
            top: tooltipTop,
            child: AnimatedBuilder(
              animation: _fade,
              builder: (context, child) {
                return Opacity(
                  opacity: _fade.value,
                  child: Transform.translate(
                    offset: Offset(0, 15 * (1 - _fade.value)),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(24),
                      child: BackdropFilter(
                        filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
                        child: Container(
                          padding: const EdgeInsets.all(22),
                          decoration: BoxDecoration(
                            color: cx.glassCard,
                            borderRadius: BorderRadius.circular(24),
                            border: Border.all(color: cx.glassBorder),
                            boxShadow: [
                              BoxShadow(color: cx.primary.withValues(alpha: 0.1), blurRadius: 30, offset: const Offset(0, 8))
                            ],
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Row(
                                children: [
                                  Container(
                                    width: 32, height: 32,
                                    decoration: BoxDecoration(shape: BoxShape.circle, color: cx.primary.withValues(alpha: 0.1)),
                                    child: Icon(Icons.auto_awesome, color: cx.primary, size: 16),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Text(
                                      item.title,
                                      style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w900, letterSpacing: -0.5),
                                    ),
                                  ),
                                  Text(
                                    '${_currentIndex + 1}/${widget.items.length}',
                                    style: TextStyle(fontWeight: FontWeight.w800, color: cx.primary, fontSize: 13),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 16),
                              Text(item.description, style: TextStyle(color: cx.onSurface, fontSize: 14.5, height: 1.6)),
                              const SizedBox(height: 28),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  TextButton(
                                    onPressed: _skip,
                                    style: TextButton.styleFrom(
                                      foregroundColor: cx.onSurfaceVariant,
                                      padding: const EdgeInsets.symmetric(horizontal: 16),
                                    ),
                                    child: const Text('Skip Tour', style: TextStyle(fontWeight: FontWeight.w600)),
                                  ),
                                  Container(
                                    height: 48,
                                    padding: const EdgeInsets.symmetric(horizontal: 4),
                                    decoration: BoxDecoration(
                                      gradient: LinearGradient(colors: [cx.primary, AppColors.primaryDim]),
                                      borderRadius: BorderRadius.circular(16),
                                      boxShadow: [BoxShadow(color: cx.primary.withValues(alpha: 0.3), blurRadius: 12, offset: const Offset(0, 4))],
                                    ),
                                    child: ElevatedButton(
                                      onPressed: _next,
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: Colors.transparent,
                                        foregroundColor: Colors.white,
                                        elevation: 0,
                                        padding: const EdgeInsets.symmetric(horizontal: 24),
                                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                                      ),
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Text(_currentIndex == widget.items.length - 1 ? 'Start Using' : 'Got it',
                                            style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15)),
                                          const SizedBox(width: 8),
                                          const Icon(LucideIcons.arrowRight, size: 18),
                                        ],
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _HolePainter extends CustomPainter {
  final Rect rect;
  final double opacity;
  final Color primaryColor;
  final double pulse;

  _HolePainter({required this.rect, required this.opacity, required this.primaryColor, required this.pulse});

  @override
  void paint(Canvas canvas, Size size) {
    if (opacity <= 0.0) return;
    
    final bgPaint = Paint()..color = Colors.black.withValues(alpha: opacity);
    final bgRect = Offset.zero & size;
    
    canvas.saveLayer(bgRect, Paint());
    canvas.drawRect(bgRect, bgPaint);

    final holePaint = Paint()..blendMode = BlendMode.clear;
    final rRect = RRect.fromRectAndRadius(rect, const Radius.circular(24));
    canvas.drawRRect(rRect, holePaint);

    // Static border
    final borderPaint = Paint()
      ..color = primaryColor.withValues(alpha: opacity * 0.9)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0;
    canvas.drawRRect(rRect, borderPaint);

    // Pulsing border
    final pulseVal = Curves.easeOut.transform(pulse);
    final pulsePaint = Paint()
      ..color = primaryColor.withValues(alpha: (1 - pulseVal) * opacity)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0 + (pulseVal * 30);
    
    final pulseRRect = RRect.fromRectAndRadius(
      rect.inflate(pulseVal * 15),
      Radius.circular(24 + (pulseVal * 15)),
    );
    canvas.drawRRect(pulseRRect, pulsePaint);

    // Subtle glow on the inside
    final glowPaint = Paint()
      ..color = primaryColor.withValues(alpha: opacity * (0.1 + (0.1 * (1-pulseVal))))
      ..style = PaintingStyle.stroke
      ..strokeWidth = 10.0
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 12.0);
    canvas.drawRRect(rRect, glowPaint);

    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _HolePainter oldDelegate) {
    return oldDelegate.rect != rect || oldDelegate.opacity != opacity || oldDelegate.pulse != pulse;
  }
}

