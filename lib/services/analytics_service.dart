import 'dart:async';
import 'dart:ui' show PlatformDispatcher;

import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:flutter/foundation.dart';

/// Firebase Analytics + Crashlytics (çökme raporu) sarmalayıcısı.
///
/// İkisi de yalnızca kullanıcı gizlilik/şartları kabul ettikten sonra başlar
/// (bkz. consent_dialog.dart). AndroidManifest'te otomatik toplama kapalıdır.
///
/// ÇÖKMEZ: google-services.json henüz eklenmemişse (veya Firebase herhangi bir
/// nedenle başlamazsa) hata yutulur, tüm log çağrıları sessizce yok sayılır.
/// Dosya eklenip yeniden derlenince kendiliğinden çalışmaya başlar.
///
/// D0 / D1 / D3 / D7 / D30 elde tutma (retention) için ayrıca kod gerekmez:
/// Firebase, `first_open` ve oturum olaylarından Konsol > Analytics >
/// Retention (Elde tutma) raporunu kendisi üretir.
class AnalyticsService {
  static bool _ready = false;
  static FirebaseAnalytics? _fa;
  static FirebaseCrashlytics? _crash;

  static Future<void> init() async {
    try {
      await Firebase.initializeApp().timeout(const Duration(seconds: 8));
      _fa = FirebaseAnalytics.instance;
      await _fa!.setAnalyticsCollectionEnabled(true);
      _ready = true;
      await _initCrashlytics();
    } catch (e) {
      _ready = false;
      debugPrint('Firebase Analytics başlatılmadı (google-services.json yok?): $e');
    }
  }

  /// Çökme raporlama: Flutter hataları + yakalanmamış asenkron hatalar +
  /// (Android) yerel çökmeler. Geliştirme (debug) derlemesinde kapalıdır.
  static Future<void> _initCrashlytics() async {
    try {
      final c = FirebaseCrashlytics.instance;
      await c.setCrashlyticsCollectionEnabled(!kDebugMode);
      if (kDebugMode) return;
      FlutterError.onError = c.recordFlutterFatalError;
      PlatformDispatcher.instance.onError = (error, stack) {
        c.recordError(error, stack, fatal: true);
        return true;
      };
      _crash = c;
    } catch (e) {
      debugPrint('Crashlytics başlatılamadı: $e');
    }
  }

  /// Yakalanıp yutulan (uygulamayı çökertmeyen) hataları rapora ekler.
  static void recordError(Object error, StackTrace? stack, {String? reason}) {
    final c = _crash;
    if (c == null) return;
    try {
      unawaited(c
          .recordError(error, stack, reason: reason, fatal: false)
          .catchError((Object _) {}));
    } catch (_) {}
  }

  /// SADECE test için (hiçbir yere bağlı değil): Crashlytics kurulumunu doğrulamak
  /// için bilerek çökertir. Konsolda ilk raporu görmek için geçici çağırın.
  static void testCrash() {
    _crash?.crash();
  }

  static void event(String name, [Map<String, Object>? params]) {
    if (!_ready) return;
    try {
      unawaited(_fa!
          .logEvent(name: name, parameters: params)
          .catchError((Object e) => debugPrint('Analytics hata: $e')));
    } catch (_) {}
  }

  static void screen(String name) {
    if (!_ready) return;
    try {
      unawaited(_fa!
          .logScreenView(screenName: name)
          .catchError((Object e) => debugPrint('Analytics hata: $e')));
    } catch (_) {}
  }
}
