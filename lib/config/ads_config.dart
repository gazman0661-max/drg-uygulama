import 'dart:io' show Platform;

/// LevelPlay reklam ayarları.
///
/// Anahtarlardan biri BOŞ olursa o özellik kapalı kalır: app key boşsa hiç
/// reklam yok, banner kimliği boşsa banner görünmez, ödüllü kimlik boşsa
/// "Destek Ol" kartı yerine "Kitap" kartı gösterilir.
/// Değerler LevelPlay panelinden (Dergah-ı Kadiri, Android) alınmıştır.
class AdsConfig {
  /// LevelPlay Android app key.
  static const String androidAppKey = '29645390d';

  /// Banner reklam birimi (ad unit) kimliği.
  static const String bannerAdUnitId = 'sg1fhlsas5psy8nk'; // banner_main

  /// Ödüllü reklam birimi (ad unit) kimliği.
  static const String rewardedAdUnitId = 'csrdkz6moaynx2by'; // rewarded_main

  static bool get _platformOk => Platform.isAndroid;

  /// SDK'nın başlatılabilmesi için app key gerekir.
  static bool get sdkEnabled => _platformOk && androidAppKey.isNotEmpty;

  static bool get bannerEnabled => sdkEnabled && bannerAdUnitId.isNotEmpty;

  static bool get rewardedEnabled => sdkEnabled && rewardedAdUnitId.isNotEmpty;
}
