import 'package:lucide_icons/lucide_icons.dart';
import 'dart:io';
import 'dart:math';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/physics.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';

import '../../controllers/conversion_controller.dart';
import '../../controllers/premium_controller.dart';
import '../../controllers/theme_controller.dart';
import '../../domain/conversion_history_entry.dart';
import '../../domain/conversion_preset.dart';
import '../../domain/conversion_task.dart';
import '../../theme/design_system.dart';
import '../../services/device_capability_service.dart';
import '../../utils/file_manager.dart';
import '../../utils/file_opener.dart';
import '../../services/media_type_detector.dart';
import '../../services/conversion_router.dart';
import '../widgets/conversion_success_dialog.dart';
import '../widgets/glass_showcase.dart';
import '../widgets/storage_dashboard_sheet.dart';
import '../widgets/premium_widgets.dart';
import '../../services/thumbnail_service.dart';
import 'conversion_flow_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});
  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with TickerProviderStateMixin {
  int _currentIndex = 0;
  late final PageController _pageCtrl;
  late final DeviceCapabilityService _deviceService;
  ConversionPreset _selectedPreset = ConversionPreset.balanced;

  // Sliding pill animation
  late final AnimationController _pillCtrl;
  late Animation<double> _pillPosition;
  
  // Showcase Keys
  final GlobalKey _keyMenu = GlobalKey();
  final GlobalKey _keyHistory = GlobalKey();
  final GlobalKey _keyVideo = GlobalKey(debugLabel: 'video');
  final GlobalKey _keyAudio = GlobalKey(debugLabel: 'audio');
  final GlobalKey _keyImage = GlobalKey(debugLabel: 'image');
  final GlobalKey _keyCompress = GlobalKey(debugLabel: 'compress');
  final GlobalKey _keyGif = GlobalKey(debugLabel: 'gif');
  final GlobalKey _keyExtract = GlobalKey(debugLabel: 'extract');
  final GlobalKey _keyHero = GlobalKey(debugLabel: 'hero');

  @override
  void initState() {
    super.initState();
    _deviceService = DeviceCapabilityService();
    _selectedPreset = _deviceService.detect().recommendedPreset;
    _pageCtrl = PageController();
    _pillCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 500));
    _pillPosition = AlwaysStoppedAnimation(0.0);
  }

  @override
  void dispose() {
    _pageCtrl.dispose();
    _pillCtrl.dispose();
    super.dispose();
  }

  void _switchTab(int index) {
    if (index == _currentIndex) return;
    final old = _currentIndex.toDouble();
    _currentIndex = index;
    _pillPosition = Tween<double>(begin: old, end: index.toDouble())
        .animate(CurvedAnimation(parent: _pillCtrl, curve: Curves.easeOutBack));
    _pillCtrl.forward(from: 0);
    _pageCtrl.animateToPage(index,
        duration: const Duration(milliseconds: 450), curve: Curves.easeOutCubic);
  }

  void _onPageChanged(int index) {
    if (index == _currentIndex) return;
    final old = _currentIndex.toDouble();
    setState(() => _currentIndex = index);
    _pillPosition = Tween<double>(begin: old, end: index.toDouble())
        .animate(CurvedAnimation(parent: _pillCtrl, curve: Curves.easeOutBack));
    _pillCtrl.forward(from: 0);
  }

  @override
  Widget build(BuildContext context) {
    final cx = CxColors.of(context);
    return Scaffold(
      backgroundColor: cx.background,
      body: Stack(
        children: [
          _BackgroundOrbs(),
          PageView(
            controller: _pageCtrl,
            onPageChanged: _onPageChanged,
            physics: const BouncingScrollPhysics(),
            children: [
              _HomeTab(
                selectedPreset: _selectedPreset, 
                onOpenFlow: _openFlow,
                keyMenu: _keyMenu,
                keyHistory: _keyHistory,
                keyVideo: _keyVideo,
                keyAudio: _keyAudio,
                keyImage: _keyImage,
                keyCompress: _keyCompress,
                keyGif: _keyGif,
                keyExtract: _keyExtract,
                keyHero: _keyHero,
              ),
              _HistoryTab(),
              _SettingsTab(selectedPreset: _selectedPreset,
                  onPresetChanged: (p) => setState(() => _selectedPreset = p)),
            ],
          ),
        ],
      ),
      bottomNavigationBar: _buildGlassNav(cx),
    );
  }

  Widget _buildGlassNav(CxColors cx) {
    return ClipRRect(
      borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 40, sigmaY: 40),
        child: Container(
          height: 82,
          decoration: BoxDecoration(
            color: cx.bottomNavBg,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
            border: Border(top: BorderSide(color: cx.glassBorder, width: 0.5)),
          ),
          child: AnimatedBuilder(
            animation: _pillCtrl,
            builder: (context, _) {
              return LayoutBuilder(builder: (context, constraints) {
                final tabW = constraints.maxWidth / 3;
                final pillW = tabW * 0.7;
                final pos = _pillPosition.value;
                final pillLeft = tabW * pos + (tabW - pillW) / 2;
                return Stack(
                  children: [
                    // Sliding glass pill
                    Positioned(
                      left: pillLeft, top: 8, width: pillW, height: 50,
                      child: Container(
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(16),
                          color: cx.primary.withValues(alpha: 0.12),
                          border: Border.all(color: cx.primary.withValues(alpha: 0.15)),
                          boxShadow: [BoxShadow(color: cx.primary.withValues(alpha: 0.08),
                              blurRadius: 20, spreadRadius: 2)],
                        ),
                      ),
                    ),
                    // Tab items
                    Row(
                      children: [
                        Expanded(child: KeyedSubtree(key: _keyMenu, child: _NavItem(icon: LucideIcons.home, label: 'Home',
                            isActive: _currentIndex == 0, onTap: () => _switchTab(0)))),
                        Expanded(child: KeyedSubtree(key: _keyHistory, child: _NavItem(icon: LucideIcons.history, label: 'History',
                            isActive: _currentIndex == 1, onTap: () => _switchTab(1)))),
                        Expanded(child: _NavItem(icon: LucideIcons.settings, label: 'Settings',
                            isActive: _currentIndex == 2, onTap: () => _switchTab(2))),
                      ],
                    ),
                  ],
                );
              });
            },
          ),
        ),
      ),
    );
  }

  Future<void> _openFlow(ConversionEntryPoint entryPoint) async {
    await Navigator.of(context).push(
      PageRouteBuilder(
        pageBuilder: (_, __, ___) => ConversionFlowScreen(
            entryPoint: entryPoint, preset: _selectedPreset),
        transitionDuration: const Duration(milliseconds: 500),
        reverseTransitionDuration: const Duration(milliseconds: 350),
        transitionsBuilder: (_, anim, __, child) {
          final curved = CurvedAnimation(parent: anim, curve: Curves.easeOutExpo);
          return FadeTransition(
            opacity: curved,
            child: ScaleTransition(
              scale: Tween<double>(begin: 0.92, end: 1.0).animate(curved),
              child: child,
            ),
          );
        },
      ),
    );
  }
}

class _BackgroundOrbs extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    if (Theme.of(context).brightness != Brightness.dark) return const SizedBox.shrink();
    return IgnorePointer(child: Stack(children: [
      Positioned(top: -80, left: -80, child: _orb(250, AppColors.primary, 0.08)),
      Positioned(top: 200, right: -50, child: _orb(200, AppColors.tertiary, 0.04)),
      Positioned(bottom: 100, left: 80, child: _orb(150, AppColors.primaryDim, 0.08)),
    ]));
  }
  Widget _orb(double s, Color c, double a) => Container(width: s, height: s,
      decoration: BoxDecoration(shape: BoxShape.circle, color: c.withValues(alpha: a)));
}

class _NavItem extends StatelessWidget {
  const _NavItem({required this.icon, required this.label, required this.isActive, required this.onTap});
  final IconData icon; final String label; final bool isActive; final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final cx = CxColors.of(context);
    return Expanded(
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.only(top: 8, bottom: 24),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            AnimatedScale(
              scale: isActive ? 1.15 : 1.0,
              duration: const Duration(milliseconds: 300),
              curve: Curves.easeOutBack,
              child: Icon(icon, color: isActive ? cx.primary : cx.onSurfaceVariant.withValues(alpha: 0.45), size: 24),
            ),
            const SizedBox(height: 5),
            AnimatedDefaultTextStyle(
              duration: const Duration(milliseconds: 250),
              style: TextStyle(fontSize: 9, fontWeight: FontWeight.w700, letterSpacing: 1.5,
                  color: isActive ? cx.primary : cx.onSurfaceVariant.withValues(alpha: 0.45)),
              child: Text(label.toUpperCase()),
            ),
          ]),
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
//  HOME TAB
// ═══════════════════════════════════════════════════════════════════════════════

class _HomeTab extends StatefulWidget {
  const _HomeTab({
    required this.selectedPreset, 
    required this.onOpenFlow,
    required this.keyMenu,
    required this.keyHistory,
    required this.keyVideo,
    required this.keyAudio,
    required this.keyImage,
    required this.keyCompress,
    required this.keyGif,
    required this.keyExtract,
    required this.keyHero,
  });

  final ConversionPreset selectedPreset;
  final Future<void> Function(ConversionEntryPoint) onOpenFlow;
  
  final GlobalKey keyMenu;
  final GlobalKey keyHistory;
  final GlobalKey keyVideo;
  final GlobalKey keyAudio;
  final GlobalKey keyImage;
  final GlobalKey keyCompress;
  final GlobalKey keyGif;
  final GlobalKey keyExtract;
  final GlobalKey keyHero;

  @override State<_HomeTab> createState() => _HomeTabState();
}

class _HomeTabState extends State<_HomeTab> with SingleTickerProviderStateMixin {
  late final AnimationController _stagger;

  // Local UI keys (not shared with global showcase)
  final _keyMagicWand = GlobalKey();
  final _keyProfile = GlobalKey();

  @override
  void initState() { 
    super.initState(); 
    _stagger = AnimationController(vsync: this, duration: const Duration(milliseconds: 900))..forward(); 
    _checkTutorial();
  }

  Future<void> _checkTutorial() async {
    final seen = await GlassShowcase.hasSeenTutorial();
    if (!seen) {
      Future.delayed(const Duration(milliseconds: 1200), () {
        if (!mounted) return;
        GlassShowcase.show(context, [
          ShowcaseItem(key: widget.keyHero, title: 'Welcome to Convertix', description: 'Your all-in-one studio suite for media conversion. Let\'s take a quick hand-guided tour!'),
          ShowcaseItem(key: widget.keyMenu, title: 'Main Menu', description: 'Access more power tools, themes, and configuration here.'),
          ShowcaseItem(key: widget.keyHistory, title: 'Conversion History', description: 'Quickly track and review your past studio conversion sessions.'),
          ShowcaseItem(key: _keyMagicWand, title: 'Quick Actions', description: 'Automated one-tap magical tools to speed up your workflow.'),
          ShowcaseItem(key: widget.keyImage, title: 'Image Converter', description: 'Convert between JPG, PNG, WEBP and more with high-fidelity encoding.'),
          ShowcaseItem(key: widget.keyExtract, title: 'Image to PDF', description: 'Combine multiple images into a single professional PDF document.'),
          ShowcaseItem(key: widget.keyVideo, title: 'Universal Video Converter', description: 'Convert videos between MP4, MKV, AVI and other formats on the fly.'),
          ShowcaseItem(key: widget.keyAudio, title: 'Audio Converter', description: 'Lossless audio conversion suite supporting FLAC, OGG, AAC and more.'),
          ShowcaseItem(key: widget.keyCompress, title: 'Video Compressor', description: 'Tap here to compress large video files securely without noticeable quality loss.'),
          ShowcaseItem(key: widget.keyGif, title: 'GIF Creator', description: 'Transform any video clip into a lightweight, shareable GIF animation.'),
        ]);
      });
    }
  }

  @override
  void dispose() { _stagger.dispose(); super.dispose(); }

  void _showQuickActionsOverlay() {
    final RenderBox renderBox = _keyMagicWand.currentContext!.findRenderObject() as RenderBox;
    final size = renderBox.size;
    final offset = renderBox.localToGlobal(Offset.zero);

    late OverlayEntry overlayEntry;
    void closeOverlay() => overlayEntry.remove();

    overlayEntry = OverlayEntry(
      builder: (context) {
        final cx = CxColors.of(context);
        final ctrl = context.read<ConversionController>();
        final premium = context.read<PremiumController>();
        final hasHistory = ctrl.history.isNotEmpty;
        final recentExt = hasHistory ? ctrl.history.first.outputFormat.toLowerCase() : '';
        final isValidRecent = ['mp4','mkv','avi','mov','webm','3gp','ts','m4v','jpg','jpeg','png','webp','bmp','gif','mp3','aac','wav','flac','ogg','m4a','pdf'].contains(recentExt);

        return Stack(
          children: [
            GestureDetector(
              onTap: closeOverlay,
              child: Container(color: Colors.black.withValues(alpha: 0.1)),
            ),
            Positioned(
              top: offset.dy + size.height + 12,
              left: offset.dx - 180 + size.width,
              child: Material(
                color: Colors.transparent,
                child: TweenAnimationBuilder<double>(
                  duration: const Duration(milliseconds: 250),
                  curve: Curves.easeOutCubic,
                  tween: Tween(begin: 0.0, end: 1.0),
                  builder: (context, val, child) {
                    return Transform.scale(
                      scale: 0.9 + 0.1 * val,
                      alignment: Alignment.topRight,
                      child: Opacity(
                        opacity: val,
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(20),
                          child: BackdropFilter(
                            filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
                            child: Container(
                              width: 200,
                              decoration: BoxDecoration(
                                color: cx.glassCard,
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(color: cx.glassBorder),
                                boxShadow: [
                                  BoxShadow(
                                    color: cx.primary.withValues(alpha: 0.1),
                                    blurRadius: 20,
                                    offset: const Offset(0, 10),
                                  ),
                                ],
                              ),
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  _QuickActionTile(
                                    icon: LucideIcons.zap,
                                    label: 'Quick Convert',
                                    onTap: () async {
                                      closeOverlay();
                                      final fm = FileManager();
                                      final files = await fm.pickAnyFiles(allowMultiple: false);
                                      if (files.isNotEmpty) {
                                        final type = const MediaTypeDetector().detect(files.first.path);
                                        if (type != null && mounted) {
                                          final cat = const ConversionRouter().outputCategoriesFor(type).first;
                                          final ep = cat == OutputTypeCategory.video ? ConversionEntryPoint.compressVideo : ConversionEntryPoint.convertMedia;
                                          widget.onOpenFlow(ep);
                                        }
                                      }
                                    },
                                  ),
                                  Divider(height: 1, color: cx.glassBorder),
                                  _QuickActionTile(
                                    icon: LucideIcons.history,
                                    label: 'Recent File',
                                    enabled: hasHistory && isValidRecent,
                                    onTap: () {
                                      closeOverlay();
                                      if (hasHistory && isValidRecent) {
                                        FileOpener.openFile(ctrl.history.first.outputPath);
                                      }
                                    },
                                  ),
                                  Divider(height: 1, color: cx.glassBorder),
                                  _QuickActionTile(
                                    icon: Icons.stars_rounded,
                                    label: 'Unlock PRO',
                                    color: AppColors.tertiary,
                                    onTap: () {
                                      closeOverlay();
                                      if (!premium.isProSessionActive && !premium.isPermanentPremium) {
                                        AdUnlockSheet.show(context, 'Unlock Pro');
                                      }
                                    },
                                    enabled: !premium.isProSessionActive && !premium.isPermanentPremium,
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
            ),
          ],
        );
      },
    );
    Overlay.of(context).insert(overlayEntry);
  }

  Animation<double> _fade(int i) {
    final b = (i * 0.08).clamp(0.0, 0.6);
    return CurvedAnimation(parent: _stagger, curve: Interval(b, (b+0.35).clamp(0.0,1.0), curve: Curves.easeOutCubic));
  }
  Animation<Offset> _slide(int i) {
    final b = (i * 0.08).clamp(0.0, 0.6);
    return Tween<Offset>(begin: const Offset(0, 0.18), end: Offset.zero).animate(
        CurvedAnimation(parent: _stagger, curve: Interval(b, (b+0.4).clamp(0.0,1.0), curve: Curves.easeOutCubic)));
  }

  @override
  Widget build(BuildContext context) {
    final cx = CxColors.of(context);
    return Consumer<ConversionController>(builder: (context, ctrl, _) {
      _maybeShowSuccess(context, ctrl.lastCompletedTask);
      return SafeArea(child: CustomScrollView(slivers: [
        SliverToBoxAdapter(child: SlideTransition(position: _slide(0),
            child: FadeTransition(opacity: _fade(0), child: _buildTopBar(context, cx)))),
        if (ctrl.isConverting || ctrl.lastError != null || ctrl.lastSuccess != null)
          SliverToBoxAdapter(child: Padding(padding: const EdgeInsets.fromLTRB(20,0,20,0),
              child: _buildStatus(context, ctrl, cx))),
        SliverToBoxAdapter(child: SlideTransition(position: _slide(1),
            child: FadeTransition(opacity: _fade(1),
                child: Padding(padding: const EdgeInsets.fromLTRB(20,12,20,24), child: KeyedSubtree(key: widget.keyHero, child: _buildHero(context, cx)))))),
        SliverToBoxAdapter(child: FadeTransition(opacity: _fade(2),
            child: Padding(padding: const EdgeInsets.fromLTRB(22,0,22,16), child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                Text('Studio Tools', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800)),
                Text('6 ACTIVE MODULES', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700,
                    letterSpacing: 1.5, color: cx.primary)),
              ])))),
        SliverPadding(padding: const EdgeInsets.fromLTRB(20,0,20,120),
          sliver: SliverGrid(
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2, mainAxisSpacing: 14, crossAxisSpacing: 14, childAspectRatio: 0.9),
            delegate: SliverChildListDelegate([
              KeyedSubtree(key: widget.keyImage, child: _aCard(3, LucideIcons.image, 'Image Converter', 'JPG, PNG, WEBP...',
                  AppColors.secondary, () => widget.onOpenFlow(ConversionEntryPoint.imageTools))),
              KeyedSubtree(key: widget.keyExtract, child: _aCard(4, LucideIcons.fileText, 'Image to PDF', 'Combine into PDF',
                  AppColors.tertiary, () => widget.onOpenFlow(ConversionEntryPoint.imageTools))),
              KeyedSubtree(key: widget.keyVideo, child: _aCard(5, LucideIcons.video, 'Video to Audio', 'Extract MP3/WAV',
                  AppColors.secondary, () => widget.onOpenFlow(ConversionEntryPoint.extractAudio))),
              KeyedSubtree(key: widget.keyAudio, child: _aCard(6, LucideIcons.fileAudio, 'Audio Converter', 'MP3, WAV, FLAC...',
                  cx.primary, () => widget.onOpenFlow(ConversionEntryPoint.convertMedia))),
              KeyedSubtree(key: widget.keyCompress, child: _aCard(7, LucideIcons.minimize, 'Video Compressor', 'Reduce file size',
                  cx.primary, () => widget.onOpenFlow(ConversionEntryPoint.compressVideo))),
              KeyedSubtree(key: widget.keyGif, child: _aCard(8, LucideIcons.film, 'Video Converter', 'MP4, MKV, AVI...',
                  AppColors.tertiary, () => widget.onOpenFlow(ConversionEntryPoint.convertMedia))),
            ]))),
      ]));
    });
  }

  Widget _aCard(int i, IconData ic, String t, String s, Color c, VoidCallback onTap) =>
      SlideTransition(position: _slide(i), child: FadeTransition(opacity: _fade(i),
          child: _ToolCard(icon: ic, title: t, subtitle: s, color: c, onTap: onTap)));

  Widget _buildTopBar(BuildContext context, CxColors cx) => Padding(
    padding: const EdgeInsets.fromLTRB(20,16,20,8), child: Row(children: [
      Container(width: 42, height: 42, decoration: BoxDecoration(shape: BoxShape.circle,
          gradient: LinearGradient(colors: [cx.primary, AppColors.primaryDim])),
        child: const Icon(LucideIcons.user, color: Colors.white, size: 22)),
      const SizedBox(width: 12),
      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(
          children: [
            Text('WELCOME BACK', style: TextStyle(fontSize: 9, fontWeight: FontWeight.w700,
                letterSpacing: 1.5, color: cx.onSurfaceVariant)),
            const SizedBox(width: 8),
            const ProSessionBadge(),
          ],
        ),
        const SizedBox(height: 2),
        ShaderMask(shaderCallback: (b) => LinearGradient(colors: [cx.primary, AppColors.primaryDim]).createShader(b),
          child: Text('Convertix', style: Theme.of(context).textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.w800, color: Colors.white, letterSpacing: -0.5))),
      ])),
      KeyedSubtree(key: _keyMagicWand, child: GestureDetector(
        onTap: _showQuickActionsOverlay,
        child: Container(width: 40, height: 40, decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12), color: cx.surfaceContainerHigh),
          child: Icon(Icons.auto_awesome, color: cx.primary, size: 20)),
      )),
    ]));

  Widget _buildHero(BuildContext context, CxColors cx) => ClipRRect(
    borderRadius: BorderRadius.circular(24),
    child: BackdropFilter(filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
      child: Container(padding: const EdgeInsets.all(24), decoration: BoxDecoration(
        color: cx.glassCard, borderRadius: BorderRadius.circular(24),
        border: Border.all(color: cx.glassBorder),
        boxShadow: [BoxShadow(color: cx.primary.withValues(alpha: 0.06), blurRadius: 32, offset: const Offset(0,8))]),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('Transform your media', style: Theme.of(context).textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.w800, letterSpacing: -0.3, height: 1.2)),
          ShaderMask(shaderCallback: (b) => LinearGradient(colors: [cx.primary, AppColors.primaryDim]).createShader(b),
            child: Text('with precision.', style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.w800, color: Colors.white, letterSpacing: -0.3, height: 1.2))),
          const SizedBox(height: 12),
          Text('Select a tool from our pro-studio suite to begin your conversion.',
            style: TextStyle(color: cx.onSurfaceVariant, fontSize: 14, height: 1.5)),
        ]))));

  Widget _buildStatus(BuildContext context, ConversionController ctrl, CxColors cx) {
    if (!ctrl.isConverting && ctrl.lastError != null) return Container(margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10), decoration: BoxDecoration(
        color: AppColors.error.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.error.withValues(alpha: 0.3))),
      child: Row(children: [const Icon(LucideIcons.info, color: AppColors.error, size: 20), const SizedBox(width: 8),
        Expanded(child: Text(ctrl.lastError!, style: const TextStyle(color: AppColors.error, fontSize: 13), maxLines: 2, overflow: TextOverflow.ellipsis)),
        IconButton(icon: const Icon(LucideIcons.x, size: 18, color: AppColors.error), onPressed: ctrl.clearCompleted, padding: EdgeInsets.zero, constraints: const BoxConstraints())]));
    if (!ctrl.isConverting && ctrl.lastSuccess != null) return Container(margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10), decoration: BoxDecoration(
        color: Colors.green.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.green.withValues(alpha: 0.3))),
      child: Row(children: [const Icon(LucideIcons.checkCircle, color: Colors.green, size: 20), const SizedBox(width: 8),
        Expanded(child: Text(ctrl.lastSuccess!, style: const TextStyle(color: Colors.green, fontSize: 13))),
        IconButton(icon: const Icon(LucideIcons.x, size: 18, color: Colors.green), onPressed: ctrl.clearCompleted, padding: EdgeInsets.zero, constraints: const BoxConstraints())]));
    final a = ctrl.activeTask;
    return Container(margin: const EdgeInsets.only(bottom: 12), padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: cx.glassCard, borderRadius: BorderRadius.circular(20), border: Border.all(color: cx.glassBorder)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: cx.primary)),
          const SizedBox(width: 10), Expanded(child: Text(ctrl.statusLine, style: TextStyle(color: cx.onSurface, fontSize: 13), maxLines: 1, overflow: TextOverflow.ellipsis))]),
        const SizedBox(height: 10),
        ClipRRect(borderRadius: BorderRadius.circular(6), child: LinearProgressIndicator(
          value: a != null && a.progress > 0 ? a.progress : null, minHeight: 6,
          backgroundColor: cx.surfaceContainerHighest, color: cx.primary))]));
  }

  void _maybeShowSuccess(BuildContext ctx, ConversionTask? task) {
    if (task == null) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!ctx.mounted) return;
      ctx.read<ConversionController>().consumeLastCompletedTask();
      ScaffoldMessenger.of(ctx).showSnackBar(const SnackBar(content: Text('Saved to output folder'), duration: Duration(seconds: 3)));
      showDialog(context: ctx, builder: (_) => ConversionSuccessDialog(task: task));
    });
  }
}

// ── Tool Card with spring bounce ──

class _ToolCard extends StatefulWidget {
  const _ToolCard({required this.icon, required this.title, required this.subtitle, required this.color, required this.onTap});
  final IconData icon; final String title; final String subtitle; final Color color; final VoidCallback onTap;
  @override State<_ToolCard> createState() => _ToolCardState();
}

class _ToolCardState extends State<_ToolCard> with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _scale;
  late final Animation<double> _glow;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 200));
    _scale = Tween<double>(begin: 1.0, end: 0.93).animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeInOutCubic));
    _glow = Tween<double>(begin: 0.0, end: 1.0).animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeIn));
  }

  @override void dispose() { _ctrl.dispose(); super.dispose(); }

  void _onTapDown(_) => _ctrl.forward();
  void _onTapUp(_) { _ctrl.reverse(); widget.onTap(); }
  void _onTapCancel() => _ctrl.reverse();

  @override
  Widget build(BuildContext context) {
    final cx = CxColors.of(context);
    return GestureDetector(
      onTapDown: _onTapDown, onTapUp: _onTapUp, onTapCancel: _onTapCancel,
      child: AnimatedBuilder(animation: _ctrl, builder: (_, __) => Transform.scale(
        scale: _scale.value,
        child: ClipRRect(borderRadius: BorderRadius.circular(20),
          child: BackdropFilter(filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
            child: Container(padding: const EdgeInsets.all(18), decoration: BoxDecoration(
              color: cx.glassCard, borderRadius: BorderRadius.circular(20),
              border: Border.all(color: Color.lerp(cx.glassBorder, widget.color.withValues(alpha: 0.3), _glow.value)!),
              boxShadow: [BoxShadow(color: widget.color.withValues(alpha: 0.06 + _glow.value * 0.12),
                  blurRadius: 24 + _glow.value * 16, offset: const Offset(0, 4))]),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Container(width: 48, height: 48, decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(14), color: widget.color.withValues(alpha: 0.1)),
                  child: Icon(widget.icon, color: widget.color, size: 26)),
                const Spacer(),
                Text(widget.title, maxLines: 2, style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w800, fontSize: 15)),
                const SizedBox(height: 4),
                Text(widget.subtitle, style: TextStyle(color: cx.onSurfaceVariant, fontSize: 12)),
                const SizedBox(height: 8),
                Row(children: [
                  Text('LAUNCH TOOL', style: TextStyle(fontSize: 9, fontWeight: FontWeight.w700, letterSpacing: 1.5, color: cx.primary)),
                  const SizedBox(width: 4), Icon(Icons.arrow_forward_ios, size: 9, color: cx.primary),
                ]),
              ])))))));
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
//  HISTORY TAB
// ═══════════════════════════════════════════════════════════════════════════════

class _HistoryTab extends StatelessWidget {
  @override Widget build(BuildContext context) {
    final cx = CxColors.of(context); final ctrl = context.watch<ConversionController>(); final h = ctrl.history;
    return SafeArea(child: CustomScrollView(slivers: [
      SliverToBoxAdapter(child: Padding(padding: const EdgeInsets.fromLTRB(22,20,22,8), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('ACTIVITY LEDGER', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, letterSpacing: 2, color: cx.primary)),
        const SizedBox(height: 6),
        Text('Recent Activity', style: Theme.of(context).textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.w800)),
      ]))),
      SliverToBoxAdapter(child: Padding(padding: const EdgeInsets.fromLTRB(20,16,20,20), child: _StorageStatsRow())),
      if (h.isEmpty) SliverFillRemaining(child: Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
        Icon(LucideIcons.clock, size: 48, color: cx.outlineVariant), const SizedBox(height: 12),
        Text('No conversions yet', style: TextStyle(color: cx.onSurfaceVariant))])))
      else SliverPadding(padding: const EdgeInsets.fromLTRB(20,0,20,120),
        sliver: SliverList(delegate: SliverChildBuilderDelegate((c,i) {
          final entry = h[i];
          return Dismissible(
            key: ValueKey(entry.completedAt.toIso8601String() + entry.outputName),
            direction: DismissDirection.endToStart,
            background: Container(
              alignment: Alignment.centerRight,
              padding: const EdgeInsets.only(right: 20),
              margin: const EdgeInsets.only(bottom: 10),
              decoration: BoxDecoration(
                color: AppColors.error.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(16),
              ),
              child: const Icon(Icons.delete_sweep_rounded, color: AppColors.error),
            ),
            onDismissed: (direction) {
              final index = i;
              ctrl.removeHistoryEntry(entry);
              ScaffoldMessenger.of(context).hideCurrentSnackBar();
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('Removed ${entry.outputName} from history'),
                  action: SnackBarAction(
                    label: 'UNDO',
                    onPressed: () => ctrl.insertHistoryEntry(index, entry),
                  ),
                ),
              );
            },
            child: _HistoryCard(entry: entry, ctrl: ctrl),
          );
        }, childCount: h.length))),
    ]));
  }
}

class _StorageStatsRow extends StatefulWidget { @override State<_StorageStatsRow> createState() => _StorageStatsRowState(); }
class _StorageStatsRowState extends State<_StorageStatsRow> {
  final _fm = FileManager(); int _fc = 0; int _tb = 0;
  @override void initState() { super.initState(); _load(); }
  Future<void> _load() async { final (c,b) = await _fm.getStorageStats(); if (mounted) setState(() { _fc = c; _tb = b; }); }
  @override Widget build(BuildContext context) { final cx = CxColors.of(context);
    return Row(children: [
      Expanded(flex: 2, child: _GlassStat(icon: Icons.cloud_done_rounded, iconColor: AppColors.tertiary,
          label: 'Storage Used', value: ConversionTask.formatBytes(_tb), showBar: true,
          barFraction: _tb == 0 ? 0 : (_tb / (2*1024*1024*1024)).clamp(0.0,1.0))),
      const SizedBox(width: 14),
      Expanded(child: _GlassStat(icon: LucideIcons.history, iconColor: cx.primary, label: 'Total Files', value: '$_fc')),
    ]); }
}

class _GlassStat extends StatelessWidget {
  const _GlassStat({required this.icon, required this.iconColor, required this.label, required this.value, this.showBar=false, this.barFraction=0.0});
  final IconData icon; final Color iconColor; final String label; final String value; final bool showBar; final double barFraction;
  @override Widget build(BuildContext context) { final cx = CxColors.of(context);
    return ClipRRect(borderRadius: BorderRadius.circular(16), child: BackdropFilter(filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
      child: Container(padding: const EdgeInsets.all(18), constraints: const BoxConstraints(minHeight: 140),
        decoration: BoxDecoration(color: cx.glassCard, borderRadius: BorderRadius.circular(16), border: Border.all(color: cx.glassBorder)),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [Icon(icon, color: iconColor, size: 28),
            Text(label.toUpperCase(), style: TextStyle(fontSize: 8, fontWeight: FontWeight.w700, letterSpacing: 1.2, color: cx.onSurfaceVariant))]),
          const SizedBox(height: 12),
          Text(value, style: Theme.of(context).textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.w900)),
          if (showBar) ...[const SizedBox(height: 10), ClipRRect(borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(value: barFraction, minHeight: 5, backgroundColor: cx.surfaceContainerHighest, valueColor: AlwaysStoppedAnimation<Color>(cx.primary)))],
        ])))); }
}

class _HistoryCard extends StatelessWidget {
  const _HistoryCard({required this.entry, required this.ctrl});
  final ConversionHistoryEntry entry; final ConversionController ctrl;
  @override Widget build(BuildContext context) { final cx = CxColors.of(context); final exists = File(entry.outputPath).existsSync();
    return Padding(padding: const EdgeInsets.only(bottom: 10), child: ClipRRect(borderRadius: BorderRadius.circular(16),
      child: BackdropFilter(filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Container(padding: const EdgeInsets.all(16), decoration: BoxDecoration(color: cx.glassCard, borderRadius: BorderRadius.circular(16), border: Border.all(color: cx.glassBorder)),
          child: Row(children: [
            _ThumbnailPreview(entry: entry),
            const SizedBox(width: 14),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(entry.outputName, maxLines: 1, overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700)),
              const SizedBox(height: 4),
              Text('${entry.sourceFormat} → ${entry.outputFormat}  •  ${_t(entry.completedAt)}',
                style: TextStyle(fontSize: 11, color: cx.primary, fontWeight: FontWeight.w500)),
            ])),
            if (exists) GestureDetector(onTap: () => Share.shareXFiles([XFile(entry.outputPath)], subject: 'Convertix'),
              child: Padding(padding: const EdgeInsets.all(8), child: Icon(LucideIcons.share2, size: 20, color: cx.onSurfaceVariant))),
            GestureDetector(onTap: () => ctrl.removeHistoryEntry(entry),
              child: Padding(padding: const EdgeInsets.all(8), child: Icon(Icons.delete_outline, size: 20, color: AppColors.error.withValues(alpha: 0.7)))),
          ]))))); }
  static String _t(DateTime t) => '${t.day.toString().padLeft(2,'0')}/${t.month.toString().padLeft(2,'0')} ${t.hour.toString().padLeft(2,'0')}:${t.minute.toString().padLeft(2,'0')}';
  static IconData _ico(String e) { switch(e.toLowerCase()) { case 'mp4': case 'mkv': case 'avi': case 'mov': case 'webm': case 'gif': return Icons.movie_rounded;
    case 'mp3': case 'aac': case 'ogg': case 'wav': case 'flac': case 'm4a': return LucideIcons.fileAudio; case 'pdf': return LucideIcons.fileText; default: return LucideIcons.image; } }
  static Color _clr(String e) { switch(e.toLowerCase()) { case 'mp4': case 'mkv': case 'avi': case 'mov': case 'webm': case 'gif': return AppColors.primary;
    case 'mp3': case 'aac': case 'ogg': case 'wav': case 'flac': case 'm4a': return AppColors.tertiary; case 'pdf': return const Color(0xFFA5B4FC); default: return AppColors.primaryDim; } }
}

class _ThumbnailPreview extends StatefulWidget {
  const _ThumbnailPreview({required this.entry});
  final ConversionHistoryEntry entry;
  @override State<_ThumbnailPreview> createState() => _ThumbnailPreviewState();
}
class _ThumbnailPreviewState extends State<_ThumbnailPreview> {
  String? _thumbPath;
  @override void initState() { super.initState(); _load(); }
  void _load() {
    final e = widget.entry.outputFormat.toLowerCase();
    final isVideo = ['mp4','mkv','avi','mov','webm','3gp','ts','m4v'].contains(e);
    final isImage = ['jpg','jpeg','png','webp','bmp','gif'].contains(e);
    
    if (isImage) {
      if (File(widget.entry.outputPath).existsSync()) {
        if (mounted) setState(() => _thumbPath = widget.entry.outputPath);
      }
    } else if (isVideo) {
      if (File(widget.entry.outputPath).existsSync()) {
        ThumbnailService.getVideoThumbnail(widget.entry.outputPath).then((path) {
          if (mounted && path != null) setState(() => _thumbPath = path);
        });
      }
    }
  }

  @override Widget build(BuildContext context) {
    final cx = CxColors.of(context);
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 300),
      child: _thumbPath != null
          ? ClipRRect(
              key: const ValueKey('thumb'),
              borderRadius: BorderRadius.circular(12),
              child: Image.file(File(_thumbPath!), width: 48, height: 48, fit: BoxFit.cover),
            )
          : Container(
              key: const ValueKey('icon'),
              width: 48, height: 48, decoration: BoxDecoration(borderRadius: BorderRadius.circular(12), color: cx.surfaceContainerHighest),
              child: Icon(_HistoryCard._ico(widget.entry.outputFormat), size: 26, color: _HistoryCard._clr(widget.entry.outputFormat)),
            ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
//  SETTINGS TAB
// ═══════════════════════════════════════════════════════════════════════════════

class _SettingsTab extends StatelessWidget {
  const _SettingsTab({required this.selectedPreset, required this.onPresetChanged});
  final ConversionPreset selectedPreset; final ValueChanged<ConversionPreset> onPresetChanged;

  @override Widget build(BuildContext context) {
    final cx = CxColors.of(context); final tc = context.watch<ThemeController>();
    final premium = context.watch<PremiumController>();
    return SafeArea(child: ListView(padding: const EdgeInsets.fromLTRB(20,20,20,120), children: [
      Text('PREFERENCES', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, letterSpacing: 2, color: cx.primary)),
      const SizedBox(height: 6),
      Text('Settings', style: Theme.of(context).textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.w800)),
      const SizedBox(height: 24),
      _Section(title: 'Appearance', icon: Icons.palette_rounded, children: [
        _Tile(title: 'Theme Mode', subtitle: tc.themeMode.name[0].toUpperCase()+tc.themeMode.name.substring(1),
          icon: switch(tc.themeMode){ThemeMode.light=>Icons.light_mode,ThemeMode.dark=>Icons.dark_mode,ThemeMode.system=>Icons.brightness_auto},
          onTap: () => _themePicker(context, tc)),
      ]),
      const SizedBox(height: 16),
      _Section(title: 'Automations', icon: LucideIcons.zap, children: [
        _Tile(
          title: 'Auto-Delete Originals',
          subtitle: 'Delete source file after successful conversion',
          icon: Icons.auto_delete_rounded,
          trailing: Switch(
            value: context.read<ConversionController>().autoDeleteOriginals,
            onChanged: (v) => context.read<ConversionController>().setAutoDeleteOriginals(v),
            activeColor: cx.primary,
          ),
        ),
      ]),
      const SizedBox(height: 16),
      _Section(title: 'Conversion Quality', icon: Icons.speed_rounded, children: [
        ...ConversionPreset.values.map((p) {
          final isLocked = !premium.isUnlocked(p);
          return _Tile(
            title: p.label,
            subtitle: p == ConversionPreset.fast ? 'Free forever' : (isLocked ? 'Premium quality' : 'Unlocked'),
            icon: p == ConversionPreset.fast ? Icons.flash_on : p == ConversionPreset.balanced ? Icons.balance : Icons.high_quality,
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (isLocked)
                  Container(
                    margin: const EdgeInsets.only(right: 12),
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: AppColors.tertiary.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Text('PRO', style: TextStyle(color: AppColors.tertiary, fontSize: 9, fontWeight: FontWeight.w900)),
                  ),
                Radio<ConversionPreset>(
                  value: p, groupValue: selectedPreset,
                  onChanged: isLocked ? null : (v) => onPresetChanged(v!),
                  activeColor: cx.primary,
                ),
              ],
            ),
            onTap: () {
              if (isLocked) {
                AdUnlockSheet.show(context, 'High-Quality Presets');
              } else {
                onPresetChanged(p);
              }
            },
          );
        }),
      ]),
      const SizedBox(height: 16),
      _Section(title: 'Storage', icon: LucideIcons.database, children: [
        _Tile(title: 'Storage Dashboard', subtitle: 'View, manage and clear converted files',
          icon: Icons.pie_chart_rounded, onTap: () => StorageDashboardSheet.show(context)),
        _Tile(title: 'Open Output Folder', icon: LucideIcons.folderOpen,
          onTap: () => FileOpener.openConverterFolder()),
      ]),
      const SizedBox(height: 16),
      _Section(title: 'About', icon: Icons.info_outline_rounded, children: [
        _Tile(title: 'App Version', subtitle: '1.0.0', icon: Icons.verified_rounded),
      ]),
    ]));
  }

  void _themePicker(BuildContext ctx, ThemeController c) {
    final cx = CxColors.of(ctx);
    showModalBottomSheet(context: ctx, backgroundColor: cx.surfaceContainer,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => Padding(padding: const EdgeInsets.all(24), child: Column(mainAxisSize: MainAxisSize.min, children: [
        Text('Choose Theme', style: Theme.of(ctx).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
        const SizedBox(height: 16),
        ...ThemeMode.values.map((m) => ListTile(
          leading: Icon(m==ThemeMode.light?Icons.light_mode:m==ThemeMode.dark?Icons.dark_mode:Icons.brightness_auto,
            color: c.themeMode==m?cx.primary:cx.onSurfaceVariant),
          title: Text(m.name[0].toUpperCase()+m.name.substring(1)),
          trailing: c.themeMode==m?Icon(Icons.check, color: cx.primary):null,
          onTap: (){c.setThemeMode(m);Navigator.pop(ctx);})),
        const SizedBox(height: 16)])));
  }
}

class _Section extends StatelessWidget {
  const _Section({required this.title, required this.icon, required this.children});
  final String title; final IconData icon; final List<Widget> children;
  @override Widget build(BuildContext context) { final cx = CxColors.of(context);
    return ClipRRect(borderRadius: BorderRadius.circular(20),
      child: BackdropFilter(filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Container(decoration: BoxDecoration(color: cx.glassCard, borderRadius: BorderRadius.circular(20), border: Border.all(color: cx.glassBorder)),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Padding(padding: const EdgeInsets.fromLTRB(18,16,18,8), child: Row(children: [
              Icon(icon, size: 18, color: cx.primary), const SizedBox(width: 8),
              Text(title.toUpperCase(), style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, letterSpacing: 1.5, color: cx.primary))])),
            ...children,
          ])))); }
}

class _Tile extends StatelessWidget {
  const _Tile({required this.title, required this.icon, this.subtitle, this.trailing, this.onTap});
  final String title; final String? subtitle; final IconData icon; final Widget? trailing; final VoidCallback? onTap;
  @override Widget build(BuildContext context) { final cx = CxColors.of(context);
    return InkWell(onTap: onTap, child: Padding(padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
      child: Row(children: [Icon(icon, size: 20, color: cx.onSurfaceVariant), const SizedBox(width: 14),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(title, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
          if (subtitle != null) Text(subtitle!, style: TextStyle(fontSize: 12, color: cx.onSurfaceVariant)),
        ])),
        if (trailing != null) trailing!,
        if (trailing == null && onTap != null) Icon(Icons.chevron_right, size: 20, color: cx.onSurfaceVariant),
      ]))); }
}

class _QuickActionTile extends StatelessWidget {
  const _QuickActionTile({
    required this.icon,
    required this.label,
    required this.onTap,
    this.enabled = true,
    this.color,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool enabled;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final cx = CxColors.of(context);
    final c = color ?? cx.primary;
    return InkWell(
      onTap: enabled ? onTap : null,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          children: [
            Icon(icon, color: enabled ? c : cx.onSurfaceVariant.withValues(alpha: 0.5), size: 20),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                label,
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 14,
                  color: enabled ? cx.onSurface : cx.onSurfaceVariant.withValues(alpha: 0.5),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
