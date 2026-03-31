import 'package:lucide_icons/lucide_icons.dart';
import 'package:file_picker/file_picker.dart';

import 'dart:io';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../controllers/conversion_controller.dart';
import '../../domain/conversion_preset.dart';
import '../../domain/conversion_task.dart';
import '../../domain/conversion_type.dart';
import '../../domain/media_type.dart';
import '../../theme/design_system.dart';
import '../../services/conversion_router.dart';
import '../../services/media_type_detector.dart';
import '../../utils/file_manager.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import '../../controllers/premium_controller.dart';
import '../../utils/ad_helper.dart';
import '../widgets/conversion_success_dialog.dart';
import '../widgets/premium_widgets.dart';
import '../widgets/cx_animations.dart';

enum ConversionEntryPoint {
  convertMedia,
  extractAudio,
  createGif,
  compressVideo,
  imageTools,
}

class ConversionFlowScreen extends StatefulWidget {
  const ConversionFlowScreen({
    super.key,
    required this.entryPoint,
    required this.preset,
  });

  final ConversionEntryPoint entryPoint;
  final ConversionPreset preset;

  @override
  State<ConversionFlowScreen> createState() => _ConversionFlowScreenState();
}

class _ConversionFlowScreenState extends State<ConversionFlowScreen>
    with SingleTickerProviderStateMixin {
  final FileManager _fileManager = FileManager();
  final MediaTypeDetector _detector = const MediaTypeDetector();
  final ConversionRouter _router = const ConversionRouter();

  List<PickedFileInfo> _selectedFiles = [];
  MediaType? _inputType;
  OutputTypeCategory? _selectedOutputCategory;
  String? _selectedFormat;
  PickedFileInfo? _selectedBackgroundImage;
  bool _isBatchModeEnabled = false;

  BannerAd? _bannerAd;
  bool _isBannerLoaded = false;
  bool _isAdSummoning = false;
  String? _saveLocation;
  final GlobalKey _keyHero = GlobalKey();

  late ConversionPreset _currentPreset;

  late final AnimationController _entranceCtrl;
  late final AnimationController _shimmerCtrl;
  late final Animation<double> _shimmerAnimation;


  @override
  void initState() {
    super.initState();
    _currentPreset = widget.preset;
    _loadPresetPreference();
    _loadSaveLocation();
    _entranceCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    )..forward();

    _shimmerCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    )..repeat();
    _shimmerAnimation = Tween<double>(begin: -0.5, end: 1.5).animate(_shimmerCtrl);

    _loadBannerAd();
  }

  Future<void> _loadSaveLocation() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getString('allformat_save_location_${widget.entryPoint.name}');
    if (saved != null) {
      if (mounted) {
        setState(() {
          _saveLocation = saved;
        });
      }
    }
  }

  Future<void> _saveSaveLocation(String path) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('allformat_save_location_${widget.entryPoint.name}', path);
  }

  Future<void> _selectSaveLocation() async {
    try {
      String? result = await FilePicker.platform.getDirectoryPath();
      if (result != null) {
        setState(() {
          _saveLocation = result;
        });
        await _saveSaveLocation(result);
      }
    } catch (e) {
      debugPrint('Error picking directory: $e');
    }
  }

  Future<void> _loadPresetPreference() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getString('quality_preset_${widget.entryPoint.name}');
    if (saved != null) {
      if (mounted) {
        setState(() {
          _currentPreset = ConversionPreset.values.byName(saved);
        });
      }
    }
  }

  Future<void> _savePresetPreference(ConversionPreset preset) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('quality_preset_${widget.entryPoint.name}', preset.name);
  }

  @override
  void dispose() {
    _entranceCtrl.dispose();
    _shimmerCtrl.dispose();
    _bannerAd?.dispose();
    super.dispose();
  }

  Animation<double> _fade(int i) {
    final b = (i * 0.1).clamp(0.0, 0.6);
    return CurvedAnimation(
      parent: _entranceCtrl,
      curve: Interval(b, (b + 0.4).clamp(0.0, 1.0), curve: Curves.easeOut),
    );
  }

  Animation<Offset> _slide(int i) {
    final b = (i * 0.1).clamp(0.0, 0.6);
    return Tween<Offset>(begin: const Offset(0, 0.12), end: Offset.zero).animate(
      CurvedAnimation(
        parent: _entranceCtrl,
        curve: Interval(b, (b + 0.4).clamp(0.0, 1.0), curve: Curves.easeOutCubic),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final cx = CxColors.of(context);
    final compressVideoOnly =
        widget.entryPoint == ConversionEntryPoint.compressVideo;
    final outputCategories = _inputType == null
        ? const <OutputTypeCategory>[]
        : (compressVideoOnly
            ? const [OutputTypeCategory.video]
            : _router.outputCategoriesFor(_inputType!));
    final formats = (_inputType == null || _selectedOutputCategory == null)
        ? const <String>[]
        : _router.outputFormatsFor(
            inputType: _inputType!,
            outputCategory: _selectedOutputCategory!,
            compressVideoOnly: compressVideoOnly,
          );
    final resolvedType = _resolveConversionType();
    final needsBackground =
        resolvedType != null && _router.requiresBackgroundImage(resolvedType);

    return Scaffold(
      backgroundColor: cx.background,
      bottomNavigationBar: _isBannerLoaded
          ? Container(
              alignment: Alignment.center,
              width: _bannerAd!.size.width.toDouble(),
              height: _bannerAd!.size.height.toDouble(),
              child: AdWidget(ad: _bannerAd!),
            )
          : null,
      body: Stack(
        children: [
          _buildBgOrbs(cx),
          Consumer<ConversionController>(
            builder: (context, ctrl, _) {
              _maybeShowSuccessDialog(ctrl.lastCompletedTask);
              int sectionIdx = 0;
              return CustomScrollView(
                slivers: [
                  // ── App Bar ──
                  SliverToBoxAdapter(
                    child: SafeArea(
                      bottom: false,
                      child: SlideTransition(
                        position: _slide(sectionIdx),
                        child: FadeTransition(
                          opacity: _fade(sectionIdx++),
                          child: Padding(
                            padding: const EdgeInsets.fromLTRB(8, 8, 20, 0),
                            child: Row(
                              children: [
                                IconButton(
                                  onPressed: () => Navigator.pop(context),
                                  icon: Container(
                                    width: 38, height: 38,
                                    decoration: BoxDecoration(
                                      borderRadius: BorderRadius.circular(12),
                                      color: cx.surfaceContainer,
                                    ),
                                    child: Icon(Icons.arrow_back,
                                        color: cx.onSurfaceVariant, size: 20),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  _titleForEntryPoint(widget.entryPoint),
                                  style: Theme.of(context).textTheme.titleMedium
                                      ?.copyWith(fontWeight: FontWeight.w800),
                                ),
                                const Spacer(),
                                ShaderMask(
                                  shaderCallback: (bounds) => LinearGradient(
                                    colors: [cx.primary, AppColors.primaryDim],
                                  ).createShader(bounds),
                                  child: const Text('Convertix',
                                    style: TextStyle(fontWeight: FontWeight.w800,
                                        fontSize: 14, color: Colors.white)),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),

                  // ── Upload Zone ──
                  SliverToBoxAdapter(
                    child: SlideTransition(
                      position: _slide(sectionIdx),
                      child: FadeTransition(
                        opacity: _fade(sectionIdx++),
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
                          child: Column(
                            children: [
                              _buildUploadZone(context, cx),
                              if (_selectedFiles.isNotEmpty)
                                const SizedBox(height: 12),
                              if (_selectedFiles.isNotEmpty)
                                _buildSelectedFilesList(context, cx),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),

                  // ── Smart Suggestions ──
                  if (_inputType != null)
                    SliverToBoxAdapter(
                      child: FadeTransition(
                        opacity: _fade(sectionIdx++),
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
                          child: Wrap(
                            spacing: 8, runSpacing: 8,
                            children: _router.smartSuggestions(_inputType!).map((s) => GestureDetector(
                              onTap: () => _applySuggestion(s.conversionType),
                              child: AnimatedPressEffect(
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(10),
                                    color: cx.primary.withValues(alpha: 0.1),
                                    border: Border.all(color: cx.primary.withValues(alpha: 0.2)),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(Icons.auto_awesome, size: 14, color: cx.primary),
                                      const SizedBox(width: 6),
                                      Text(s.title, style: TextStyle(fontSize: 12,
                                          fontWeight: FontWeight.w600, color: cx.primary)),
                                    ],
                                  ),
                                ),
                              ),
                            )).toList(),
                          ),
                        ),
                      ),
                    ),

                  // ── Output Type ──
                  if (outputCategories.isNotEmpty)
                    SliverToBoxAdapter(
                      child: SlideTransition(
                        position: _slide(sectionIdx),
                        child: FadeTransition(
                          opacity: _fade(sectionIdx++),
                          child: Padding(
                            padding: const EdgeInsets.fromLTRB(20, 24, 20, 0),
                            child: _buildSection(context, cx,
                              title: 'Output Type',
                              subtitle: '${outputCategories.length} types available',
                              child: Wrap(
                                spacing: 10, runSpacing: 10,
                                children: outputCategories.map((cat) {
                                  final selected = _selectedOutputCategory == cat;
                                  return GestureDetector(
                                    onTap: _inputType == null ? null : () {
                                      setState(() { _selectedOutputCategory = cat; _selectedFormat = null; _ensureFormatDefaults(); });
                                    },
                                    child: AnimatedPressEffect(
                                      child: AnimatedContainer(
                                        duration: const Duration(milliseconds: 200),
                                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                                        decoration: BoxDecoration(
                                          borderRadius: BorderRadius.circular(14),
                                          color: selected ? cx.primary.withValues(alpha: 0.15) : cx.surfaceContainerHigh,
                                          border: Border.all(color: selected
                                              ? cx.primary.withValues(alpha: 0.3)
                                              : cx.outlineVariant.withValues(alpha: 0.2)),
                                          boxShadow: selected ? [BoxShadow(color: cx.primary.withValues(alpha: 0.1), blurRadius: 15)] : null,
                                        ),
                                        child: Text(_categoryLabel(cat),
                                          style: TextStyle(fontWeight: FontWeight.w700,
                                              color: selected ? cx.primary : cx.onSurfaceVariant)),
                                      ),
                                    ),
                                  );
                                }).toList(),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),

                  // ── Format Chips ──
                  if (formats.isNotEmpty)
                    SliverToBoxAdapter(
                      child: SlideTransition(
                        position: _slide(sectionIdx),
                        child: FadeTransition(
                          opacity: _fade(sectionIdx++),
                          child: Padding(
                            padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
                            child: _buildSection(context, cx,
                              title: 'Output Format',
                              subtitle: '${formats.length} formats available',
                              child: Wrap(
                                spacing: 10, runSpacing: 10,
                                children: formats.map((fmt) {
                                  final selected = _selectedFormat == fmt;
                                  return GestureDetector(
                                    onTap: () => setState(() => _selectedFormat = fmt),
                                    child: AnimatedPressEffect(
                                      child: AnimatedContainer(
                                        duration: const Duration(milliseconds: 200),
                                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                                        decoration: BoxDecoration(
                                          borderRadius: BorderRadius.circular(14),
                                          color: selected ? cx.primary.withValues(alpha: 0.15) : cx.surfaceContainerHigh,
                                          border: Border.all(color: selected
                                              ? cx.primary.withValues(alpha: 0.3)
                                              : cx.outlineVariant.withValues(alpha: 0.2)),
                                          boxShadow: selected ? [BoxShadow(color: cx.primary.withValues(alpha: 0.1), blurRadius: 15)] : null,
                                        ),
                                        child: Text(fmt.toUpperCase(),
                                          style: TextStyle(fontWeight: FontWeight.w700, letterSpacing: 0.5,
                                              color: selected ? cx.primary : cx.onSurfaceVariant)),
                                      ),
                                    ),
                                  );
                                }).toList(),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),

                  // ── Background Image ──
                  if (needsBackground)
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
                        child: _buildSection(context, cx,
                          title: 'Background Image',
                          subtitle: 'Required for audio → video',
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                _selectedBackgroundImage == null
                                    ? 'No image selected'
                                    : 'Selected: ${_selectedBackgroundImage!.name}',
                                style: TextStyle(color: cx.onSurfaceVariant, fontSize: 13),
                              ),
                              const SizedBox(height: 12),
                              _buildOutlineButton(cx, icon: LucideIcons.image,
                                  label: 'Select Background Image', onTap: _pickBackgroundImage),
                            ],
                          ),
                        ),
                      ),
                    ),

                  // ── Batch Mode Toggle ──
                  if (_selectedFiles.length > 1)
                    SliverToBoxAdapter(
                      child: SlideTransition(
                        position: _slide(sectionIdx),
                        child: FadeTransition(
                          opacity: _fade(sectionIdx++),
                          child: Padding(
                            padding: const EdgeInsets.fromLTRB(20, 24, 20, 0),
                            child: _buildBatchModeSection(context, cx),
                          ),
                        ),
                      ),
                    ),

                  // ── Quality Slider ──
                  SliverToBoxAdapter(
                    child: SlideTransition(
                      position: _slide(sectionIdx),
                      child: FadeTransition(
                        opacity: _fade(sectionIdx++),
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(20, 24, 20, 0),
                          child: _buildQualitySlider(context, cx),
                        ),
                      ),
                    ),
                  ),

                  // ── Save Location ──
                  SliverToBoxAdapter(
                    child: SlideTransition(
                      position: _slide(sectionIdx),
                      child: FadeTransition(
                        opacity: _fade(sectionIdx++),
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(20, 24, 20, 0),
                          child: _buildSaveLocationSection(context, cx),
                        ),
                      ),
                    ),
                  ),

                  // ── Start Button ──
                  SliverToBoxAdapter(
                    child: SlideTransition(
                      position: _slide(sectionIdx),
                      child: FadeTransition(
                        opacity: _fade(sectionIdx++),
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(20, 28, 20, 0),
                          child: _buildStartButton(context, ctrl, cx),
                        ),
                      ),
                    ),
                  ),

                  // ── Progress ──
                  if (ctrl.activeTask != null)
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
                        child: _buildProgressSection(context, ctrl, cx),
                      ),
                    ),

                  const SliverToBoxAdapter(child: SizedBox(height: 40)),
                ],
              );
            },
          ),
          if (_isAdSummoning) _buildPreparingOverlay(cx),
        ],
      ),
    );
  }

  // ── Upload Zone ──

  Widget _buildUploadZone(BuildContext context, CxColors cx) {
    return GestureDetector(
      onTap: _pickSourceFiles,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 300),
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 40),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(24),
              border: Border.all(
                color: _selectedFiles.isEmpty
                    ? cx.outlineVariant.withValues(alpha: 0.2)
                    : cx.primary.withValues(alpha: 0.3),
                width: 1.5,
              ),
              color: _selectedFiles.isEmpty
                  ? cx.surfaceContainer.withValues(alpha: 0.3)
                  : cx.primary.withValues(alpha: 0.05),
            ),
            child: Column(
              children: [
                AnimatedSwitcher(
                  duration: const Duration(milliseconds: 300),
                  child: Container(
                    key: ValueKey(_selectedFiles.isEmpty),
                    width: 64, height: 64,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(20),
                      color: cx.primary.withValues(alpha: 0.1),
                    ),
                    child: Icon(
                      _selectedFiles.isEmpty ? LucideIcons.uploadCloud : LucideIcons.checkCircle,
                      size: 32, color: cx.primary,
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Text(_selectedFiles.isEmpty ? 'Upload File' : '${_selectedFiles.length} file(s) selected',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800)),
                const SizedBox(height: 6),
                if (_selectedFiles.isEmpty)
                  Text('Tap to browse your files', style: TextStyle(color: cx.onSurfaceVariant, fontSize: 13))
                else
                  ..._selectedFiles.take(3).map((f) => Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 2),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(LucideIcons.file, size: 14, color: cx.primary),
                        const SizedBox(width: 6),
                        Flexible(child: Text(f.name, maxLines: 1, overflow: TextOverflow.ellipsis,
                          style: TextStyle(fontSize: 12, color: cx.onSurfaceVariant))),
                      ],
                    ),
                  )),
                if (_selectedFiles.length > 3)
                  Text('+ ${_selectedFiles.length - 3} more',
                    style: TextStyle(fontSize: 11, color: cx.primary, fontWeight: FontWeight.w600)),
                const SizedBox(height: 16),
                AnimatedPressEffect(
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(10),
                      color: cx.surfaceContainerHigh,
                      boxShadow: [
                        BoxShadow(
                          color: cx.primary.withValues(alpha: 0.1),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Text(_selectedFiles.isEmpty ? 'Browse' : 'Change File(s)',
                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: cx.primary)),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ── Section Builder ──

  Widget _buildSection(BuildContext context, CxColors cx, {
    required String title, required String subtitle, required Widget child,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(title.toUpperCase(), style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700,
                letterSpacing: 1.5, color: cx.onSurfaceVariant)),
            Text(subtitle.toUpperCase(), style: TextStyle(fontSize: 9, fontWeight: FontWeight.w600,
                letterSpacing: 1, color: cx.primary)),
          ],
        ),
        const SizedBox(height: 12),
        child,
      ],
    );
  }

  // ── Quality Slider ──

  Widget _buildQualitySlider(BuildContext context, CxColors cx) {
    return _buildSection(context, cx,
      title: 'Compression Quality',
      subtitle: _currentPreset.label,
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: SliderTheme(
                  data: SliderTheme.of(context).copyWith(
                    activeTrackColor: cx.primary,
                    inactiveTrackColor: cx.surfaceContainerHigh,
                    thumbColor: cx.primary,
                    overlayColor: cx.primary.withValues(alpha: 0.1),
                    trackHeight: 4,
                  ),
                  child: Slider(
                    value: _currentPreset.index.toDouble(),
                    min: 0,
                    max: 2,
                    divisions: 2,
                    onChanged: (val) {
                      final newPreset = ConversionPreset.values[val.toInt()];
                      setState(() => _currentPreset = newPreset);
                      _savePresetPreference(newPreset);
                    },
                  ),
                ),
              ),
              if (_currentPreset == ConversionPreset.highQuality)
                const Padding(
                  padding: EdgeInsets.only(left: 8.0),
                  child: ProSessionBadge(),
                ),
            ],
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Low', style: TextStyle(fontSize: 10, color: cx.onSurfaceVariant)),
                Text('Medium', style: TextStyle(fontSize: 10, color: cx.onSurfaceVariant)),
                Text('High', style: TextStyle(fontSize: 10, color: cx.onSurfaceVariant)),
              ],
            ),
          )
        ],
      ),
    );
  }

  // ── Start Button ──

  Widget _buildStartButton(BuildContext context, ConversionController ctrl, CxColors cx) {
    return AnimatedPressEffect(
      onTap: ctrl.isConverting ? null : _startConversion,
      child: Stack(
        children: [
          AnimatedContainer(
            duration: const Duration(milliseconds: 300),
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 18),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(20),
              gradient: LinearGradient(
                colors: ctrl.isConverting
                    ? [cx.surfaceContainerHigh, cx.surfaceContainerHigh]
                    : [cx.primary, AppColors.primaryDim],
              ),
              boxShadow: ctrl.isConverting ? [] : [
                BoxShadow(color: cx.primary.withValues(alpha: 0.25), blurRadius: 30, offset: const Offset(0, 10)),
              ],
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(ctrl.isConverting ? LucideIcons.loader2 : LucideIcons.playCircle,
                  color: ctrl.isConverting ? cx.onSurfaceVariant : Colors.white, size: 22),
                const SizedBox(width: 10),
                Text(ctrl.isConverting ? 'Converting...' : 'Start Conversion',
                  style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16,
                      color: ctrl.isConverting ? cx.onSurfaceVariant : Colors.white)),
                if (!ctrl.isConverting) ...[
                  Consumer<PremiumController>(
                    builder: (context, premium, _) {
                      final isBatch = _isBatchModeEnabled && _selectedFiles.length > 1;
                      final isHighQuality = widget.preset != ConversionPreset.fast;
                      
                      // Feature is locked if (it's a pro feature) AND (user hasn't paid) AND (not unlocked for this session)
                      final isLocked = (isBatch || isHighQuality) && 
                                       !premium.isPermanentPremium && 
                                       !ctrl.isProFeatureUnlocked;

                      if (!isLocked) {
                        return const SizedBox.shrink();
                      }

                      return Padding(
                        padding: const EdgeInsets.only(left: 8),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: const Row(
                            children: [
                              Icon(LucideIcons.lock, color: Colors.white, size: 12),
                              SizedBox(width: 4),
                              Text('UNLOCK',
                                  style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 8,
                                      fontWeight: FontWeight.w900,
                                      letterSpacing: 0.5)),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ],
              ],
            ),
          ),
          if (!ctrl.isConverting)
            Positioned.fill(
              child: IgnorePointer(
                child: AnimatedBuilder(
                  animation: _shimmerAnimation,
                  builder: (context, child) {
                    return CustomPaint(
                      painter: ShimmerSweepPainter(
                        progress: _shimmerAnimation.value,
                        shimmerColor: Colors.white,
                      ),
                    );
                  },
                ),
              ),
            ),
        ],
      ),
    );
  }

  // ── Progress ──

  Widget _buildProgressSection(BuildContext context, ConversionController ctrl, CxColors cx) {
    final active = ctrl.activeTask!;
    final pct = (active.progress * 100).toStringAsFixed(0);
    return ClipRRect(
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
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Converting...', style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700)),
                      const SizedBox(height: 2),
                      Text('PROCESSING', style: TextStyle(fontSize: 9, fontWeight: FontWeight.w600,
                          letterSpacing: 1.5, color: cx.onSurfaceVariant)),
                    ],
                  ),
                  Text('$pct%', style: TextStyle(fontSize: 28, fontWeight: FontWeight.w900, color: cx.primary)),
                ],
              ),
              const SizedBox(height: 16),
              ClipRRect(
                borderRadius: BorderRadius.circular(6),
                child: LinearProgressIndicator(
                  value: active.progress > 0 ? active.progress : null,
                  minHeight: 8, backgroundColor: cx.surfaceContainerHighest, color: cx.primary,
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Container(width: 6, height: 6,
                    decoration: BoxDecoration(shape: BoxShape.circle, color: cx.primary)),
                  const SizedBox(width: 8),
                  Expanded(child: Text(ctrl.statusLine,
                    style: TextStyle(fontSize: 11, color: cx.onSurfaceVariant),
                    maxLines: 1, overflow: TextOverflow.ellipsis)),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── Outline Button ──

  Widget _buildOutlineButton(CxColors cx, {required IconData icon, required String label, required VoidCallback onTap}) {
    return AnimatedPressEffect(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: cx.outlineVariant.withValues(alpha: 0.3)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 18, color: cx.primary),
            const SizedBox(width: 8),
            Text(label, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: cx.primary)),
          ],
        ),
      ),
    );
  }

  // ── BG Orbs ──

  Widget _buildBgOrbs(CxColors cx) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    if (!isDark) return const SizedBox.shrink();
    return IgnorePointer(
      child: Stack(
        children: [
          Positioned(top: -50, right: -50,
            child: Container(width: 200, height: 200,
              decoration: BoxDecoration(shape: BoxShape.circle,
                  color: AppColors.primary.withValues(alpha: 0.06)))),
          Positioned(bottom: 100, left: -30,
            child: Container(width: 150, height: 150,
              decoration: BoxDecoration(shape: BoxShape.circle,
                  color: AppColors.tertiary.withValues(alpha: 0.04)))),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  //  Logic (unchanged)
  // ═══════════════════════════════════════════════════════════════════════════

  Future<void> _pickSourceFiles() async {
    final premium = context.read<PremiumController>();
    // allowMultiple is true for everyone to select, but processing it is gated.
    final files = switch (widget.entryPoint) {
      ConversionEntryPoint.extractAudio => await _fileManager.pickFiles(MediaType.video, allowMultiple: true),
      ConversionEntryPoint.createGif => await _fileManager.pickFiles(MediaType.video, allowMultiple: true),
      ConversionEntryPoint.compressVideo => await _fileManager.pickFiles(MediaType.video, allowMultiple: true),
      ConversionEntryPoint.imageTools => await _fileManager.pickFiles(MediaType.image, allowMultiple: true),
      ConversionEntryPoint.convertMedia => await _fileManager.pickAnyFiles(allowMultiple: true),
    };
    if (files.isEmpty) return;
    
    final detectedType = _detector.detect(files.first.path);
    if (detectedType == null) { _showMessage('Unsupported file type selected.'); return; }
    
    final mixed = files.any((f) => _detector.detect(f.path) != detectedType);
    if (mixed) {
      _showMessage('Please select files of the same media type in one batch.');
      return;
    }

    setState(() {
      _selectedFiles = files;
      _inputType = detectedType;
      _selectedBackgroundImage = null;
      _selectedOutputCategory = _defaultCategoryFor(detectedType);
      _selectedFormat = null;
      _ensureFormatDefaults();
    });
  }

  Future<void> _pickBackgroundImage() async {
    final image = await _fileManager.pickFile(MediaType.image);
    if (image == null) return;
    setState(() => _selectedBackgroundImage = image);
  }

  void _applySuggestion(ConversionType type) {
    if (_inputType == null) return;
    setState(() {
      switch (type) {
        case ConversionType.videoToAudio: _selectedOutputCategory = OutputTypeCategory.audio; _selectedFormat = 'mp3'; break;
        case ConversionType.videoCompress: _selectedOutputCategory = OutputTypeCategory.video; _selectedFormat = 'mp4'; break;
        case ConversionType.videoToGif: _selectedOutputCategory = OutputTypeCategory.image; _selectedFormat = 'gif'; break;
        case ConversionType.audioToVideo: _selectedOutputCategory = OutputTypeCategory.video; _selectedFormat = 'mp4'; break;
        case ConversionType.imageToPdf: _selectedOutputCategory = OutputTypeCategory.document; _selectedFormat = 'pdf'; break;
        default: break;
      }
      _ensureFormatDefaults();
    });
  }

  OutputTypeCategory _defaultCategoryFor(MediaType inputType) {
    return switch (widget.entryPoint) {
      ConversionEntryPoint.extractAudio => OutputTypeCategory.audio,
      ConversionEntryPoint.createGif => OutputTypeCategory.image,
      ConversionEntryPoint.compressVideo => OutputTypeCategory.video,
      ConversionEntryPoint.imageTools => OutputTypeCategory.document,
      ConversionEntryPoint.convertMedia => _router.outputCategoriesFor(inputType).first,
    };
  }

  void _ensureFormatDefaults() {
    if (_inputType == null || _selectedOutputCategory == null) return;
    final formats = _router.outputFormatsFor(
      inputType: _inputType!, outputCategory: _selectedOutputCategory!,
      compressVideoOnly: widget.entryPoint == ConversionEntryPoint.compressVideo,
    );
    if (formats.isEmpty) { _selectedFormat = null; return; }
    if (_selectedFormat == null || !formats.contains(_selectedFormat)) { _selectedFormat = formats.first; }
  }

  ConversionType? _resolveConversionType() {
    if (_inputType == null || _selectedOutputCategory == null || _selectedFormat == null) return null;
    return _router.resolveType(
      inputType: _inputType!, outputCategory: _selectedOutputCategory!,
      outputFormat: _selectedFormat!,
      compressVideoOnly: widget.entryPoint == ConversionEntryPoint.compressVideo,
    );
  }

  void _startConversion() {
    final ctrl = context.read<ConversionController>();
    if (ctrl.isConverting) return;

    final premium = context.read<PremiumController>();
    final isBatch = _isBatchModeEnabled && _selectedFiles.length > 1;
    final isHighQuality = _currentPreset == ConversionPreset.highQuality;
    
    // Ad is required if (it's a pro feature) AND (not permanent premium) AND (not currently unlocked for session)
    final adRequired = (isBatch || isHighQuality) && 
                       !premium.isPermanentPremium && 
                       !premium.isProSessionActive;

    if (!adRequired) {
      _executeConversion();
      return;
    }

    setState(() => _isAdSummoning = true);

    premium.unlockProSession().then((success) async {
      if (!mounted) return;
      setState(() => _isAdSummoning = false);
      if (success) {
        await _executeConversion();
      }
    });
  }

  Future<void> _executeConversion() async {
    final ctrl = context.read<ConversionController>();
    final type = _resolveConversionType();

    if (_selectedFiles.isEmpty || type == null || _selectedFormat == null) {
      _showMessage('Complete all required steps before starting conversion.');
      return;
    }

    if (_router.requiresBackgroundImage(type) && _selectedBackgroundImage == null) {
      _showMessage('Select a background image for audio to video conversion.');
      return;
    }

    final filesToProcess = _isBatchModeEnabled ? _selectedFiles : [_selectedFiles.first];
    final startTime = DateTime.now();
    int successCount = 0;
    int failCount = 0;
    List<String> failedFiles = [];

    // Process sequentially to avoid memory pressure
    for (final file in filesToProcess) {
      try {
        await ctrl.enqueueAndStart(
          files: [file],
          conversionType: type,
          outputExtension: _selectedFormat!,
          preset: _currentPreset,
          secondaryFile: _selectedBackgroundImage,
          customOutputDir: _saveLocation, // Passing custom save location
        );

        if (ctrl.lastError == null) {
          successCount++;
        } else {
          failCount++;
          failedFiles.add(file.name);
        }
      } catch (e) {
        failCount++;
        failedFiles.add(file.name);
      }
    }

    if (filesToProcess.length > 1 && mounted) {
      final duration = DateTime.now().difference(startTime);
      _showBatchSummary(successCount, failCount, failedFiles, duration);
    } else if (ctrl.lastError != null && mounted) {
      _showMessage(ctrl.lastError!);
    }
  }

  void _showBatchSummary(int success, int fail, List<String> failedFiles, Duration duration) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.grey[900],
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Batch Summary', style: TextStyle(color: Colors.white)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Successfully converted: $success', style: const TextStyle(color: Colors.green)),
            if (fail > 0) Text('Failed: $fail', style: const TextStyle(color: Colors.red)),
            const SizedBox(height: 8),
            Text('Time taken: ${duration.inSeconds}s', style: const TextStyle(color: Colors.white70)),
            if (failedFiles.isNotEmpty) ...[
              const SizedBox(height: 12),
              const Text('Failed files:', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
              for (var f in failedFiles) Text('• $f', style: const TextStyle(color: Colors.white54, fontSize: 12)),
            ]
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('OK')),
        ],
      ),
    );
  }

  String _titleForEntryPoint(ConversionEntryPoint point) {
    switch (point) {
      case ConversionEntryPoint.convertMedia: return 'Convert Media';
      case ConversionEntryPoint.extractAudio: return 'Extract Audio';
      case ConversionEntryPoint.createGif: return 'Create GIF';
      case ConversionEntryPoint.compressVideo: return 'Compress Video';
      case ConversionEntryPoint.imageTools: return 'Image Tools';
    }
  }

  String _categoryLabel(OutputTypeCategory category) {
    switch (category) {
      case OutputTypeCategory.audio: return 'Audio';
      case OutputTypeCategory.video: return 'Video';
      case OutputTypeCategory.image: return 'Image';
      case OutputTypeCategory.document: return 'Document';
    }
  }

  void _maybeShowSuccessDialog(ConversionTask? task) {
    if (task == null) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      context.read<ConversionController>().consumeLastCompletedTask();

      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (_) => ConversionSuccessDialog(task: task),
      ).then((_) {
        // Trigger interstitial simulation after dialog dismissal
        if (mounted) {
           AdHelper.simulateInterstitialAd();
        }
      });
    });
  }

  Widget _buildSelectedFilesList(BuildContext context, CxColors cx) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: cx.surfaceContainerLow.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: cx.glassBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Selected Files (${_selectedFiles.length})', 
                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
              GestureDetector(
                onTap: () => setState(() { _selectedFiles = []; _inputType = null; }),
                child: Text('Clear All', style: TextStyle(fontSize: 11, color: cx.primary, fontWeight: FontWeight.w600)),
              ),
            ],
          ),
          const SizedBox(height: 8),
          ConstrainedBox(
            constraints: const BoxConstraints(maxHeight: 120),
            child: ListView.separated(
              shrinkWrap: true,
              padding: EdgeInsets.zero,
              itemCount: _selectedFiles.length,
              separatorBuilder: (_, __) => Divider(color: cx.outlineVariant.withValues(alpha: 0.1), height: 1),
              itemBuilder: (context, index) {
                final file = _selectedFiles[index];
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: Row(
                    children: [
                      Icon(LucideIcons.file, size: 14, color: cx.onSurfaceVariant),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(file.name, 
                          maxLines: 1, overflow: TextOverflow.ellipsis,
                          style: TextStyle(fontSize: 12, color: cx.onSurface)),
                      ),
                      GestureDetector(
                        onTap: () => setState(() {
                          _selectedFiles.removeAt(index);
                          if (_selectedFiles.isEmpty) _inputType = null;
                        }),
                        child: Icon(LucideIcons.x, size: 14, color: AppColors.error),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSaveLocationSection(BuildContext context, CxColors cx) {
    return _buildSection(context, cx,
      title: 'Save Location',
      subtitle: 'Where to save the converted files',
      child: InkWell(
        onTap: _selectSaveLocation,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: cx.surfaceContainerHigh,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: cx.glassBorder),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: cx.primary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(LucideIcons.folder, color: cx.primary, size: 20),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(_saveLocation == null ? 'Default Folder' : 'Custom Folder',
                        style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
                    const SizedBox(height: 2),
                    Text(_saveLocation ?? 'AllFormatConverter (Internal)',
                        style: TextStyle(fontSize: 11, color: cx.onSurfaceVariant),
                        maxLines: 1, overflow: TextOverflow.ellipsis),
                  ],
                ),
              ),
              Icon(LucideIcons.chevronRight, color: cx.onSurfaceVariant, size: 16),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBatchModeSection(BuildContext context, CxColors cx) {
    final premium = context.watch<PremiumController>();
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cx.surfaceContainerLow,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: cx.outlineVariant.withValues(alpha: 0.1)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: cx.primary.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(Icons.auto_awesome_motion_rounded, color: cx.primary, size: 20),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text('Batch Mode',
                        style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14, color: cx.onSurface)),
                    if (!premium.isBatchUnlocked)
                      Container(
                        margin: const EdgeInsets.only(left: 8),
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                            color: Colors.amber.withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(4)),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.workspace_premium_rounded, color: Colors.amber, size: 10),
                            SizedBox(width: 4),
                            Text('PRO',
                                style: TextStyle(color: Colors.amber, fontSize: 8, fontWeight: FontWeight.w900, letterSpacing: 0.5)),
                          ],
                        ),
                      ),
                  ],
                ),
                Text('Convert multiple files at once',
                    style: TextStyle(color: cx.onSurfaceVariant, fontSize: 11)),
              ],
            ),
          ),
          Switch(
            value: _isBatchModeEnabled,
            onChanged: (val) {
              if (premium.isProSessionActive || premium.isPermanentPremium) {
                setState(() => _isBatchModeEnabled = val);
              } else {
                AdUnlockSheet.show(context, 'Batch Mode');
              }
            },
            activeColor: cx.primary,
          ),
        ],
      ),
    );
  }

  void _loadBannerAd() async {
    final ad = await AdHelper.loadAnchoredAdaptiveBanner(context);
    if (ad != null) {
      setState(() {
        _bannerAd = ad;
        _isBannerLoaded = true;
      });
    }
  }

  void _showRewardedAdForBatch() {
     AdUnlockSheet.show(context, 'Batch Mode');
  }

  void _showMessage(String text) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
  }

  Widget _buildPreparingOverlay(CxColors cx) {
    return Container(
      color: Colors.black.withValues(alpha: 0.6),
      child: Center(
        child: ClipRRect(
          borderRadius: BorderRadius.circular(24),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 32),
              decoration: BoxDecoration(
                color: cx.glassCard,
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: cx.glassBorder),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const CircularProgressIndicator(),
                  const SizedBox(height: 24),
                  Text('Summoning Ad...',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800)),
                  const SizedBox(height: 8),
                  Text('Powering up FFmpeg engines',
                      style: TextStyle(color: cx.onSurfaceVariant, fontSize: 13)),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
