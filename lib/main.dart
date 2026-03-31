import 'dart:async';
import 'package:ffmpeg_kit_flutter_new/ffmpeg_kit_config.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:provider/provider.dart';
import 'package:animations/animations.dart';


import 'controllers/conversion_controller.dart';
import 'controllers/premium_controller.dart';
import 'controllers/theme_controller.dart';
import 'services/media_conversion_service.dart';
import 'ui/screens/home_screen.dart';
import 'ui/screens/splash_screen.dart';
import 'utils/file_manager.dart';
import 'utils/ad_helper.dart';
import 'theme/design_system.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  try {
    final version = await FFmpegKitConfig.getFFmpegVersion();
    debugPrint('[Startup] ✅ FFmpegKit initialized. Version: $version');
  } catch (e) {
    debugPrint('[Startup] ⚠️ FFmpegKit NOT registered: $e');
  }

  final conversionService = MediaConversionService();
  final fileManager = FileManager();

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => ThemeController()),
        ChangeNotifierProvider(create: (_) => PremiumController()),
        ChangeNotifierProxyProvider<PremiumController, ConversionController>(
          create: (context) => ConversionController(
            conversionService: conversionService,
            fileManager: fileManager,
            premiumController: Provider.of<PremiumController>(context, listen: false),
          ),
          update: (_, __, previous) => previous!,
        ),
      ],
      child: const AllFormatMediaConverterApp(),
    ),
  );
}

// ── Design System Colors ──────────────────────────────────────────────────────
// (Moved to lib/theme/design_system.dart)

class AllFormatMediaConverterApp extends StatelessWidget {
  const AllFormatMediaConverterApp({super.key});

  @override
  Widget build(BuildContext context) {
    final themeController = context.watch<ThemeController>();

    final darkTextTheme = _buildTextTheme(Brightness.dark);
    final lightTextTheme = _buildTextTheme(Brightness.light);

    return MaterialApp(
      title: 'Convertix',
      debugShowCheckedModeBanner: false,
      themeMode: themeController.themeMode,

      // ── LIGHT THEME ──
      theme: ThemeData(
        useMaterial3: true,
        brightness: Brightness.light,
        scaffoldBackgroundColor: AppColors.backgroundLight,
        textTheme: lightTextTheme,
        colorScheme: const ColorScheme.light(
          primary: AppColors.primaryLight,
          onPrimary: Colors.white,
          secondary: AppColors.secondary,
          tertiary: AppColors.tertiary,
          error: AppColors.error,
          surface: AppColors.surfaceContainerLight,
          onSurface: AppColors.onSurfaceLight,
          onSurfaceVariant: AppColors.onSurfaceVariantLight,
          outlineVariant: AppColors.outlineVariantLight,
          primaryContainer: AppColors.surfaceContainerHighestLight,
          onPrimaryContainer: AppColors.primaryLight,
          surfaceContainerHighest: AppColors.surfaceContainerHighestLight,
        ),
        cardTheme: CardThemeData(
          color: AppColors.surfaceContainerLight,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: BorderSide(color: AppColors.glassBorderLight),
          ),
        ),
        appBarTheme: const AppBarTheme(
          backgroundColor: Colors.transparent,
          elevation: 0,
        ),
        pageTransitionsTheme: const PageTransitionsTheme(
          builders: {
            TargetPlatform.android: SharedAxisPageTransitionsBuilder(
              transitionType: SharedAxisTransitionType.horizontal,
            ),
            TargetPlatform.iOS: SharedAxisPageTransitionsBuilder(
              transitionType: SharedAxisTransitionType.horizontal,
            ),
          },
        ),
      ),

      // ── DARK THEME ──
      darkTheme: ThemeData(
        useMaterial3: true,
        brightness: Brightness.dark,
        scaffoldBackgroundColor: AppColors.backgroundDark,
        textTheme: darkTextTheme,
        colorScheme: const ColorScheme.dark(
          primary: AppColors.primary,
          onPrimary: AppColors.onPrimary,
          secondary: AppColors.secondary,
          tertiary: AppColors.tertiary,
          error: AppColors.error,
          surface: AppColors.surfaceContainerDark,
          onSurface: AppColors.onSurfaceDark,
          onSurfaceVariant: AppColors.onSurfaceVariantDark,
          outlineVariant: AppColors.outlineVariantDark,
          primaryContainer: AppColors.surfaceContainerHighestDark,
          onPrimaryContainer: AppColors.primary,
          surfaceContainerHighest: AppColors.surfaceContainerHighestDark,
        ),
        cardTheme: CardThemeData(
          color: AppColors.surfaceContainerHighDark,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: BorderSide(color: AppColors.glassBorderDark),
          ),
        ),
        appBarTheme: const AppBarTheme(
          backgroundColor: Colors.transparent,
          elevation: 0,
        ),
        pageTransitionsTheme: const PageTransitionsTheme(
          builders: {
            TargetPlatform.android: SharedAxisPageTransitionsBuilder(
              transitionType: SharedAxisTransitionType.horizontal,
            ),
            TargetPlatform.iOS: SharedAxisPageTransitionsBuilder(
              transitionType: SharedAxisTransitionType.horizontal,
            ),
          },
        ),
      ),
      home: const SplashScreen(),
    );
  }

  TextTheme _buildTextTheme(Brightness brightness) {
    final base = brightness == Brightness.dark
        ? ThemeData.dark().textTheme
        : ThemeData.light().textTheme;
        
    final jakarta = GoogleFonts.plusJakartaSansTextTheme(base);
    
    return jakarta.copyWith(
      // Screen titles: 20sp, FontWeight.w700
      titleLarge: jakarta.titleLarge?.copyWith(fontSize: 20, fontWeight: FontWeight.w700),
      // Section headers: 16sp, FontWeight.w600
      titleMedium: jakarta.titleMedium?.copyWith(fontSize: 16, fontWeight: FontWeight.w600),
      // Body / descriptions: 14sp, FontWeight.w400
      bodyMedium: jakarta.bodyMedium?.copyWith(fontSize: 14, fontWeight: FontWeight.w400),
      // Captions / badges: 11sp, FontWeight.w500
      labelSmall: jakarta.labelSmall?.copyWith(fontSize: 11, fontWeight: FontWeight.w500),
    );
  }
}
