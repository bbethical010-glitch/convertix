import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

class AdHelper {
  // Production IDs
  static String get bannerAdUnitId => 'ca-app-pub-3940256099942544/6300978111';
  static String get interstitialAdUnitId => 'ca-app-pub-2093403233028868/9869646614';
  static String get rewardedAdUnitId => 'ca-app-pub-3940256099942544/5224354917';
  static String get rewardedInterstitialAdUnitId => 'ca-app-pub-2093403233028868/9869646614';

  static InterstitialAd? _interstitialAd;
  static bool _isInterstitialAdLoading = false;

  static DateTime? _lastInterstitialTime;
  static DateTime? _lastRewardedTime;

  /// Guardrail: Interstitial once every 3 mins.
  /// 5 min cooldown after a rewarded ad.
  static bool canShowInterstitial() {
    final now = DateTime.now();
    if (_lastRewardedTime != null) {
      if (now.difference(_lastRewardedTime!) < const Duration(minutes: 5)) {
        debugPrint('AdHelper: Interstitial blocked by rewarded cooldown (5m)');
        return false;
      }
    }
    if (_lastInterstitialTime != null) {
      if (now.difference(_lastInterstitialTime!) < const Duration(minutes: 3)) {
        debugPrint('AdHelper: Interstitial blocked by frequency guardrail (3m)');
        return false;
      }
    }
    return true;
  }

  /// PRO Feature Unlock Simulation (Rewarded)
  static Future<bool> simulateRewardedAd() async {
    debugPrint('AdHelper: Simulating Rewarded Ad...');
    // 2-3 second delay
    await Future.delayed(const Duration(milliseconds: 2500));
    _lastRewardedTime = DateTime.now();
    debugPrint('AdHelper: Rewarded Ad Simulation Complete');
    return true; // Success
  }

  /// Post-Conversion Simulation (Interstitial)
  static Future<bool> simulateInterstitialAd() async {
    if (!canShowInterstitial()) return false;

    debugPrint('AdHelper: Simulating Interstitial Ad...');
    // 2-3 second delay
    await Future.delayed(const Duration(milliseconds: 2200));
    _lastInterstitialTime = DateTime.now();
    debugPrint('AdHelper: Interstitial Ad Simulation Complete');
    return true; // Success
  }

  /// Loads an anchored adaptive banner ad.
  static Future<BannerAd?> loadAnchoredAdaptiveBanner(BuildContext context) async {
    // ... existing SDK code ...
    final AdSize? size = await AdSize.getCurrentOrientationAnchoredAdaptiveBannerAdSize(
      MediaQuery.of(context).size.width.truncate(),
    );

    if (size == null) return null;

    final Completer<BannerAd?> completer = Completer<BannerAd?>();
    final BannerAd bannerAd = BannerAd(
      adUnitId: bannerAdUnitId,
      size: size,
      request: const AdRequest(),
      listener: BannerAdListener(
        onAdLoaded: (Ad ad) => completer.complete(ad as BannerAd),
        onAdFailedToLoad: (Ad ad, LoadAdError error) {
          ad.dispose();
          completer.complete(null);
        },
      ),
    );

    await bannerAd.load();
    return completer.future;
  }

  // --- Real AdMob SDK Methods (Kept for drop-in readiness) ---
  // Note: These are currently secondary to the simulation stubs used in the app.
  
  static void loadInterstitialAd({
    required Function(InterstitialAd ad) onAdLoaded,
    Function(LoadAdError error)? onAdFailedToLoad,
  }) {
    InterstitialAd.load(
      adUnitId: interstitialAdUnitId,
      request: const AdRequest(),
      adLoadCallback: InterstitialAdLoadCallback(
        onAdLoaded: (ad) => onAdLoaded(ad),
        onAdFailedToLoad: (error) => onAdFailedToLoad?.call(error),
      ),
    );
  }

  static void loadRewardedInterstitialAd() {
    if (_interstitialAd != null || _isInterstitialAdLoading) return;
    _isInterstitialAdLoading = true;
    InterstitialAd.load(
      adUnitId: rewardedInterstitialAdUnitId,
      request: const AdRequest(),
      adLoadCallback: InterstitialAdLoadCallback(
        onAdLoaded: (ad) {
          _interstitialAd = ad;
          _isInterstitialAdLoading = false;
        },
        onAdFailedToLoad: (error) {
          _interstitialAd = null;
          _isInterstitialAdLoading = false;
        },
      ),
    );
  }
}
