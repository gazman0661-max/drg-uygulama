import 'log_service.dart';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import 'diyanet_service.dart';

/// Android tarafına (Kotlin) vakit verisini ve bildirim ayarlarını gönderir.
/// Orada hem ana ekran widget'ı hem de ezan/hatırlatma/panel için zincirleme
/// alarm bu veriyle kendi başına (uygulama kapalıyken de) çalışır.
class WidgetService {
  static const MethodChannel _channel = MethodChannel('dergah/widget');

  /// Ezanı uygulamanın kendi ses servisiyle çalar (ses denemesi).
  Future<bool> testAdhan({required String stream, required double volume}) async {
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) return false;
    try {
      return await _channel.invokeMethod<bool>(
              'testAdhan', {'stream': stream, 'volume': volume}) ??
          false;
    } catch (lerr) {
      AppLog.w('widget', 'yutulan hata: $lerr');
      return false;
    }
  }

  /// Telefonun bu uygulamaya ait ayar sayfasını açar (pil, izinler, bildirimler).
  Future<bool> openAppSettings() async {
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) return false;
    try {
      return await _channel.invokeMethod<bool>('openAppSettings') ?? false;
    } catch (lerr) {
      AppLog.w('widget', 'yutulan hata: $lerr');
      return false;
    }
  }

  /// "Tam zamanlı alarm" ayar ekranını açar (Android 12+); yoksa false.
  Future<bool> openExactAlarmSettings() async {
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) return false;
    try {
      return await _channel.invokeMethod<bool>('openExactAlarmSettings') ??
          false;
    } catch (lerr) {
      AppLog.w('widget', 'yutulan hata: $lerr');
      return false;
    }
  }

  Future<void> push({
    required String place,
    required Map<DateTime, GunlukVakitler> days,
    required Map<String, int> reminders,
    required bool panel,
    required bool panelKerahat,
    required bool notify,
    required bool sound,
    required Map<String, bool> adhan,
    required bool alarmStream,
    required int kerahatMin,
    required String stream,
    required double volume,
    required List<Map<String, Object>> extras,
    required Map<DateTime, String> sabahEzan,
    Map<DateTime, String>? hijri,
  }) async {
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) return;
    try {
      String two(int n) => n.toString().padLeft(2, '0');
      final dates = days.keys.toList()..sort();
      final list = <Map<String, dynamic>>[
        for (final d in dates)
          {
            'd': '${d.year}-${two(d.month)}-${two(d.day)}',
            ...days[d]!.toJson(),
            'SabahEzan': sabahEzan[d] ?? days[d]!.sabah,
            'h': hijri?[d] ?? '',
          },
      ];
      await _channel.invokeMethod(
        'saveSchedule',
        jsonEncode({
          'place': place,
          'days': list,
          'reminders': reminders,
          'panel': panel,
          'panelKerahat': panelKerahat,
          'notify': notify,
          'sound': sound,
          'adhan': adhan,
          'alarmStream': alarmStream,
          'kerahatMin': kerahatMin,
          'stream': stream,
          'volume': volume,
          'extras': extras,
        }),
      );
    } catch (e) {
      // Platform kanalı hazır değilse sessizce geç.
      AppLog.e('widget', 'Android verisi gonderilemedi: $e');
    }
  }
}
