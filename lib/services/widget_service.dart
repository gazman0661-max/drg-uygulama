import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import 'diyanet_service.dart';

/// Android tarafına (Kotlin) vakit verisini ve bildirim ayarlarını gönderir.
/// Orada hem ana ekran widget'ı hem de ezan/hatırlatma/panel için zincirleme
/// alarm bu veriyle kendi başına (uygulama kapalıyken de) çalışır.
class WidgetService {
  static const MethodChannel _channel = MethodChannel('dergah/widget');

  Future<void> push({
    required String place,
    required Map<DateTime, GunlukVakitler> days,
    required Map<String, int> reminders,
    required bool panel,
    required bool panelKerahat,
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
        }),
      );
    } catch (e) {
      // Platform kanalı hazır değilse sessizce geç.
      debugPrint('Android verisi gönderilemedi: $e');
    }
  }
}
