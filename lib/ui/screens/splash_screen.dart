import 'package:lucide_icons/lucide_icons.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:provider/provider.dart';
import 'dart:async';

import '../../controllers/theme_controller.dart';
import '../../theme/design_system.dart';
import '../../utils/ad_helper.dart';
import 'home_screen.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _fadeAnimation;
  late Animation<double> _scaleAnimation;

  String _loadingText = 'Preparing Media Engines...';

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    );

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: const Interval(0.0, 0.5, curve: Curves.easeIn)),
    );

    _scaleAnimation = Tween<double>(begin: 0.8, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: const Interval(0.0, 0.5, curve: Curves.easeOutBack)),
    );

    _controller.forward();
    _initializeApp();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _initializeApp() async {
    final stopwatch = Stopwatch()..start();

    // 1. Initialize AdMob
    try {
      setState(() => _loadingText = 'Summoning Ad Engines...');
      await MobileAds.instance.initialize();
      // Pre-load the ad for immediate availability
      AdHelper.loadRewardedInterstitialAd();
    } catch (e) {
      debugPrint('AdMob Init Error: $e');
    }

    // 2. Request Permissions
    setState(() => _loadingText = 'Checking Permissions...');
    await _requestPermissions();

    // 3. Ensure a minimum splash time of 3.5 seconds
    final elapsed = stopwatch.elapsedMilliseconds;
    const minSplashTime = 3500;
    if (elapsed < minSplashTime) {
      await Future.delayed(Duration(milliseconds: minSplashTime - elapsed));
    }

    if (mounted) {
      Navigator.pushReplacement(
        context,
        PageRouteBuilder(
          pageBuilder: (context, animation, secondaryAnimation) => const HomeScreen(),
          transitionsBuilder: (context, animation, secondaryAnimation, child) {
            return FadeTransition(opacity: animation, child: child);
          },
          transitionDuration: const Duration(milliseconds: 800),
        ),
      );
    }
  }

  Future<void> _requestPermissions() async {
    Map<Permission, PermissionStatus> statuses = await [
      Permission.storage,
      Permission.manageExternalStorage,
      Permission.mediaLibrary, // Added media library
    ].request();
    
    debugPrint('Storage Permission: ${statuses[Permission.storage]}');
    debugPrint('Manage Storage: ${statuses[Permission.manageExternalStorage]}');
    debugPrint('Media Library: ${statuses[Permission.mediaLibrary]}');
  }

  @override
  Widget build(BuildContext context) {
    final cx = CxColors.of(context);
    
    return Scaffold(
      backgroundColor: cx.background,
      body: Stack(
        children: [
          // Background subtle orbs
          Positioned(
            top: -100,
            right: -100,
            child: Container(
              width: 300,
              height: 300,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: cx.primary.withValues(alpha: 0.05),
              ),
            ),
          ),
          Positioned(
            bottom: -50,
            left: -50,
            child: Container(
              width: 250,
              height: 250,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppColors.tertiary.withValues(alpha: 0.03),
              ),
            ),
          ),
          
          Center(
            child: AnimatedBuilder(
              animation: _controller,
              builder: (context, child) {
                return FadeTransition(
                  opacity: _fadeAnimation,
                  child: ScaleTransition(
                    scale: _scaleAnimation,
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        // App Logo Placeholder (using Icon for now as per design system)
                        Container(
                          width: 100,
                          height: 100,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(28),
                            gradient: LinearGradient(
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                              colors: [cx.primary, AppColors.primaryDim],
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: cx.primary.withValues(alpha: 0.3),
                                blurRadius: 40,
                                offset: const Offset(0, 10),
                              ),
                            ],
                          ),
                          child: const Icon(
                            LucideIcons.shuffle,
                            size: 50,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(height: 32),
                        Text(
                          'CONVERTIX',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 28,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 4,
                            color: cx.onSurface,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'ULTIMATE MEDIA CONVERTER',
                          style: GoogleFonts.inter(
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 2,
                            color: cx.primary,
                          ),
                        ),
                        const SizedBox(height: 60),
                        SizedBox(
                          width: 40,
                          height: 40,
                          child: CircularProgressIndicator(
                            strokeWidth: 3,
                            valueColor: AlwaysStoppedAnimation<Color>(cx.primary),
                          ),
                        ),
                        const SizedBox(height: 24),
                        Text(
                          _loadingText,
                          style: TextStyle(
                            color: cx.onSurfaceVariant,
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
          
          // Version Number at bottom
          Positioned(
            bottom: 40,
            left: 0,
            right: 0,
            child: Center(
              child: Text(
                'v 1.0.0',
                style: TextStyle(
                  color: cx.onSurfaceVariant.withValues(alpha: 0.5),
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
