import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:unity_levelplay_mediation/unity_levelplay_mediation.dart';

import '../config/ads_config.dart';
import '../utils/gdpr_region.dart';
import 'log_service.dart';

/// LevelPlay başlatma + ödüllü reklam yönetimi.
///
/// Anahtarlar boşsa hiçbir şey yapmaz. Tüm çağrılar try/catch içindedir:
/// reklam tarafındaki bir hata uygulamayı asla çökertmez.
class AdsService extends ChangeNotifier
    with LevelPlayInitListener, LevelPlayRewardedAdListener {
  AdsService._();
  static final AdsService instance = AdsService._();

  /// GDPR açık onayı (yalnızca AB/AEA/UK/İsviçre'de anlamlı). İlk açılış
  /// penceresindeki kutu ve Ayarlar > Reklam Rızasını Yönet bunu yazar.
  static const String gdprPrefKey = 'legal_gdpr_consent_v1';

  bool _initStarted = false;
  bool ready = false;

  /// Şu anki GDPR açık onayı (bölge dışında hep false, kullanılmaz).
  bool gdprConsent = false;

  LevelPlayRewardedAd? _rewarded;
  Timer? _retry;
  bool _earned = false;
  VoidCallback? _onRewarded;

  /// LevelPlay'i kurar. BEKLENMEZ; hata olursa uygulama etkilenmez.
  /// GDPR bayrağı yalnızca AB/AEA/UK/İsviçre'de ve init'ten ÖNCE verilir.
  Future<void> init() async {
    if (!AdsConfig.sdkEnabled || _initStarted) return;
    _initStarted = true;
    try {
      final prefs = await SharedPreferences.getInstance();
      gdprConsent = prefs.getBool(gdprPrefKey) ?? false;
      if (gdprApplies) {
        try {
          await LevelPlayPrivacySettings.setGDPRConsent(gdprConsent);
        } catch (e) {
          AppLog.w('reklam', 'GDPR bayragi verilemedi: $e');
        }
      }
      // Geliştirme sürümünde (flutter run) entegrasyon doğrulaması Logcat'e yazılır.
      if (!kReleaseMode) {
        try {
          await LevelPlay.setAdaptersDebug(true);
          LevelPlay.validateIntegration();
        } catch (e) {
          AppLog.w('reklam', 'debug acilamadi: $e');
        }
      }
      final request =
          LevelPlayInitRequest.builder(AdsConfig.androidAppKey).build();
      AppLog.i('reklam',
          'LevelPlay init (gdprBolgesi=$gdprApplies, onay=$gdprConsent)');
      await LevelPlay.init(initRequest: request, initListener: this);
    } catch (e, st) {
      _initStarted = false;
      AppLog.e('reklam', 'LevelPlay init hatasi: $e', st);
    }
  }

  /// Ayarlar > Reklam Rızasını Yönet: onayı saklar ve LevelPlay'e iletir.
  Future<void> setGdprConsent(bool value) async {
    gdprConsent = value;
    notifyListeners();
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(gdprPrefKey, value);
      if (AdsConfig.sdkEnabled && gdprApplies) {
        await LevelPlayPrivacySettings.setGDPRConsent(value);
      }
    } catch (e, st) {
      AppLog.e('reklam', 'GDPR onayi kaydedilemedi: $e', st);
    }
  }

  void _loadRewarded() {
    try {
      _rewarded?.loadAd();
    } catch (e, st) {
      AppLog.e('reklam', 'odullu yukleme hatasi: $e', st);
    }
  }

  void _scheduleRetry() {
    _retry?.cancel();
    _retry = Timer(const Duration(seconds: 30), _loadRewarded);
  }

  /// Ödüllü reklamı gösterir. Reklam hazır değilse false döner.
  /// [onRewarded]: kullanıcı reklamı izleyip kapattıktan sonra çağrılır.
  Future<bool> showRewarded({required VoidCallback onRewarded}) async {
    final ad = _rewarded;
    if (!ready || ad == null) return false;
    try {
      if (!await ad.isAdReady()) {
        _loadRewarded();
        return false;
      }
      _earned = false;
      _onRewarded = onRewarded;
      ad.showAd();
      return true;
    } catch (e, st) {
      AppLog.e('reklam', 'odullu gosterme hatasi: $e', st);
      return false;
    }
  }

  // ---- LevelPlayInitListener ----
  @override
  void onInitSuccess(LevelPlayConfiguration configuration) {
    AppLog.i('reklam', 'LevelPlay init basarili');
    ready = true;
    if (AdsConfig.rewardedEnabled) {
      _rewarded = LevelPlayRewardedAd(adUnitId: AdsConfig.rewardedAdUnitId);
      _rewarded!.setListener(this);
      _loadRewarded();
    }
    notifyListeners();
  }

  @override
  void onInitFailed(LevelPlayInitError error) {
    AppLog.w('reklam', 'LevelPlay init basarisiz: $error');
    _initStarted = false; // sonraki açılışta tekrar denenir
  }

  // ---- LevelPlayRewardedAdListener ----
  @override
  void onAdLoaded(LevelPlayAdInfo adInfo) {
    AppLog.i('reklam', 'odullu reklam hazir');
  }

  @override
  void onAdLoadFailed(LevelPlayAdError error) {
    AppLog.w('reklam', 'odullu reklam yuklenemedi: $error');
    _scheduleRetry();
  }

  @override
  void onAdDisplayed(LevelPlayAdInfo adInfo) {}

  @override
  void onAdDisplayFailed(LevelPlayAdError error, LevelPlayAdInfo adInfo) {
    AppLog.w('reklam', 'odullu reklam gosterilemedi: $error');
    _onRewarded = null;
    _loadRewarded();
  }

  @override
  void onAdClicked(LevelPlayAdInfo adInfo) {}

  @override
  void onAdInfoChanged(LevelPlayAdInfo adInfo) {}

  @override
  void onAdRewarded(LevelPlayReward reward, LevelPlayAdInfo adInfo) {
    _earned = true;
  }

  @override
  void onAdClosed(LevelPlayAdInfo adInfo) {
    final cb = _onRewarded;
    final earned = _earned;
    _onRewarded = null;
    _earned = false;
    _loadRewarded(); // bir sonraki için hazırla
    if (earned) cb?.call();
  }
}
