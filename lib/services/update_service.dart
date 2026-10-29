import 'package:flutter/foundation.dart';
import 'package:in_app_update/in_app_update.dart';

/// Google Play "uygulama içi güncelleme" (tam ekran / immediate).
/// Yeni sürüm Play'de yayınlandıysa uygulama açılınca Play Store'un tam ekran
/// güncelleme ekranı çıkar. Yalnızca Play Store'dan kurulmuş uygulamada çalışır;
/// APK ile elle kurulmuşsa sessizce atlanır.
class UpdateService {
  static Future<void> checkAndUpdate() async {
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) return;
    try {
      final info = await InAppUpdate.checkForUpdate();
      final available =
          info.updateAvailability == UpdateAvailability.updateAvailable ||
              info.updateAvailability ==
                  UpdateAvailability.developerTriggeredUpdateInProgress;
      if (available && info.immediateUpdateAllowed) {
        await InAppUpdate.performImmediateUpdate();
      }
    } catch (e) {
      // Play dışından kurulum, internet yok vb.: sessizce geç.
      debugPrint('Güncelleme kontrolü atlandı: $e');
    }
  }
}
