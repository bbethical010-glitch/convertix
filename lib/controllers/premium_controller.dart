import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../domain/conversion_preset.dart';
import '../utils/ad_helper.dart';

class PremiumController extends ChangeNotifier {
  PremiumController() {
    _loadPermanentStatus();
  }

  static const String _keyPermanentPremium = 'is_permanent_premium';

  bool _isPermanentPremium = false;
  bool _isProSessionActive = false; // Memory-only session state
  bool _isSimulating = false;

  bool get isPermanentPremium => _isPermanentPremium;
  bool get isProSessionActive => _isProSessionActive;
  bool get isBatchUnlocked => _isProSessionActive || _isPermanentPremium;
  bool get isSimulating => _isSimulating;

  /// 'Fast' is always free. Others require a PRO session.
  bool isUnlocked(ConversionPreset preset) {
    if (preset == ConversionPreset.fast) return true;
    return _isPermanentPremium || _isProSessionActive;
  }

  Future<void> _loadPermanentStatus() async {
    final prefs = await SharedPreferences.getInstance();
    _isPermanentPremium = prefs.getBool(_keyPermanentPremium) ?? false;
    notifyListeners();
  }

  /// Unlocks PRO features for the current session via ad simulation.
  Future<bool> unlockProSession() async {
    _isSimulating = true;
    notifyListeners();

    final success = await AdHelper.simulateRewardedAd();
    if (success) {
      _isProSessionActive = true;
    }

    _isSimulating = false;
    notifyListeners();
    return success;
  }

  /// Re-locks PRO features (called after conversion task completion).
  void lockProSession() {
    if (_isProSessionActive) {
      _isProSessionActive = false;
      debugPrint('PremiumController: PRO session expired.');
      notifyListeners();
    }
  }

  // --- Purchase Simulation (Kept for completeness) ---

  Future<bool> simulatePayment() async {
    _isSimulating = true;
    notifyListeners();
    await Future.delayed(const Duration(seconds: 2));
    _isPermanentPremium = true;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keyPermanentPremium, true);
    _isSimulating = false;
    notifyListeners();
    return true;
  }
}
