import 'dart:async';

import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';

/// Firebase Analytics sarmalayıcısı.
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

  static Future<void> init() async {
    try {
      await Firebase.initializeApp().timeout(const Duration(seconds: 8));
      _fa = FirebaseAnalytics.instance;
      await _fa!.setAnalyticsCollectionEnabled(true);
      _ready = true;
    } catch (e) {
      _ready = false;
      debugPrint('Firebase Analytics başlatılmadı (google-services.json yok?): $e');
    }
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
