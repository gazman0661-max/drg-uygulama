import 'log_service.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// ==========================================================
/// BİLDİRİM İZNİ + ESKİ ALARM TEMİZLİĞİ
///
/// Ezan, hatırlatma ve bildirim çubuğu paneli artık Android tarafında
/// (Kotlin: AlertScheduler) "zincirleme alarm" ile çalışır: sadece SIRADAKİ
/// alarm kurulur, çalınca bir sonrakini kurar. Bu yüzden uygulamanın belli
/// aralıkla açılması gerekmez. Bu sınıf yalnızca bildirim iznini ister ve
/// eski sürümlerin kurduğu alarmları bir kez temizler.
/// ==========================================================
class NotificationService {
  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();

  bool _ready = false;
  Future<void>? _legacyFuture;

  Future<void> init() async {
    const initSettings = InitializationSettings(
      android: AndroidInitializationSettings('@drawable/ic_stat_dergah'),
      iOS: DarwinInitializationSettings(),
    );
    await _plugin.initialize(settings: initSettings);
    _ready = true;
  }

  /// Bildirim iznini (Android 13+/iOS) ister; Android'de ayrıca "tam zamanlı
  /// alarm" izni kapalıysa ilgili sistem ayarı ekranını açar. İzin varsa true.
  Future<bool> requestPermission({bool askExact = true}) async {
    if (!_ready) return false;
    var granted = true;

    final android = _plugin.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();
    if (android != null) {
      final r = await android.requestNotificationsPermission();
      final enabled = await android.areNotificationsEnabled();
      granted = enabled ?? r ?? false;
      if (granted) {
        final canExact = await android.canScheduleExactNotifications();
        if (canExact == false && askExact) {
          await android.requestExactAlarmsPermission();
        }
      }
    }

    final ios = _plugin.resolvePlatformSpecificImplementation<
        IOSFlutterLocalNotificationsPlugin>();
    if (ios != null) {
      final r =
          await ios.requestPermissions(alert: true, badge: true, sound: true);
      granted = r ?? false;
    }
    return granted;
  }

  /// Bildirim izni şu an açık mı? (izin penceresi göstermeden sorar)
  Future<bool> areEnabled() async {
    if (!_ready) return false;
    try {
      final android = _plugin.resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>();
      if (android != null) return (await android.areNotificationsEnabled()) ?? false;
    } catch (lerr) { AppLog.w('bildirim', 'yutulan hata: $lerr'); }
    return true;
  }

  /// Önceki sürümlerin eklenti üzerinden kurduğu zamanlanmış bildirimleri
  /// (ve açık panelini) bir kez siler; yoksa eski + yeni alarmlar çift çalar.
  ///
  /// Tüm çağıranlar AYNI temizliği bekler (yarış yok) ve temizlik kurulum başına
  /// yalnızca BİR kez yapılır; her açılışta cancelAll() çalışıp paneli
  /// silmesin diye bayrak kalıcı saklanır.
  Future<void> clearLegacyOnce() {
    if (!_ready) return Future.value();
    return _legacyFuture ??= _clearLegacy();
  }

  Future<void> _clearLegacy() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      if (prefs.getBool('dergah_legacy_temizlendi') ?? false) return;
      await _plugin.cancelAll();
      await prefs.setBool('dergah_legacy_temizlendi', true);
    } catch (e) {
      debugPrint('Eski bildirimler temizlenemedi: $e');
    }
  }
}
