import 'package:flutter/material.dart' hide Text;
import '../l10n/app_text.dart';
import 'package:provider/provider.dart';

import '../state/app_state.dart';
import 'app_dialog.dart';

/// Bildirim izni istenmeden ÖNCE, neden gerektiğini anlatan tema uyumlu pencere.
/// İzin zaten verilmişse pencere gösterilmez.
Future<void> maybeExplainAndAskNotifications(BuildContext context) async {
  final app = context.read<AppState>();
  if (!app.notificationsEnabled || app.firstLaunchNeedsSelection) {
    await app.askPermissionsOnLaunch();
    return;
  }
  final granted = await app.notificationsGranted();
  if (!granted && context.mounted) {
    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AppDialog(
        title: 'Bildirim İzni',
        primaryLabel: 'Devam',
        onPrimary: () => Navigator.of(ctx, rootNavigator: true).pop(),
        child: const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Namaz vakti girdiğinde ezanla haber verebilmemiz ve vakit '
                'öncesi hatırlatma yapabilmemiz için bildirim iznine ihtiyaç '
                'var.'),
            SizedBox(height: 10),
            Text('Bir sonraki ekranda "İzin ver"i seçin. Bildirimleri '
                'istediğiniz zaman Ayarlar\'dan kapatabilirsiniz.'),
          ],
        ),
      ),
    );
  }
  await app.askPermissionsOnLaunch();
}

/// Bir kez gösterilen pil/arka plan ipucu: ezanın tam vaktinde gelmesi için.
Future<void> maybeShowBatteryTip(BuildContext context) async {
  final app = context.read<AppState>();
  if (!app.notificationsEnabled) return;
  if (await app.batteryTipShown()) return;
  if (!await app.notificationsGranted()) return;
  if (!context.mounted) return;
  final open = await showDialog<bool>(
    context: context,
    barrierDismissible: false,
    builder: (ctx) => AppDialog(
      title: 'Ezan Tam Vaktinde Gelsin',
      primaryLabel: 'Ayarları Aç',
      onPrimary: () => Navigator.of(ctx, rootNavigator: true).pop(true),
      secondaryLabel: 'Sonra',
      onSecondary: () => Navigator.of(ctx, rootNavigator: true).pop(false),
      child: const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Bazı telefonlar pil tasarrufu için uygulamaları arka planda '
              'kısıtlar. Bu durumda ezan geç gelebilir.'),
          SizedBox(height: 10),
          Text('Açılan ekranda "Pil" bölümünden "Kısıtlama yok" seçmeniz '
              'önerilir. Bunu daha sonra Ayarlar sayfasından da yapabilirsiniz.'),
        ],
      ),
    ),
  );
  await app.markBatteryTipShown();
  if (open == true) await app.openAppSettings();
}
