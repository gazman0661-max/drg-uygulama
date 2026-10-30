import 'package:flutter/material.dart' hide Text;
import '../l10n/app_text.dart';
import 'package:provider/provider.dart';

import '../state/app_state.dart';
import 'app_dialog.dart';

/// Konum izni AYRI ve isteğe bağlı bir adımdır. Kullanıcı vermezse uygulama
/// seçili il/ilçenin koordinatıyla çalışmaya devam eder. Yalnızca bir kez sorulur.
Future<void> maybeAskLocation(BuildContext context) async {
  final app = context.read<AppState>();
  if (!await app.shouldAskLocationPermission()) return;
  if (!context.mounted) return;
  final allow = await showDialog<bool>(
    context: context,
    barrierDismissible: false,
    builder: (_) => AppDialog(
      title: 'Konum İzni',
      primaryLabel: 'İzin Ver',
      onPrimary: () => Navigator.of(context, rootNavigator: true).pop(true),
      secondaryLabel: 'Şimdi Değil',
      onSecondary: () => Navigator.of(context, rootNavigator: true).pop(false),
      child: const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Kıble yönünü bulunduğunuz yere göre daha doğru hesaplamak '
              'için konumunuzu kullanabiliriz. Bu isteğe bağlıdır.'),
          SizedBox(height: 10),
          Text('Konumunuz yalnızca cihazınızda kullanılır, sunucuya '
              'gönderilmez. İzin vermezseniz uygulama seçtiğiniz il/ilçeye '
              'göre çalışmaya devam eder; dilerseniz daha sonra Kıble '
              'sayfasından açabilirsiniz.'),
        ],
      ),
    ),
  );
  await app.markLocationAsked();
  if (allow == true) {
    await app.requestLocation();
  } else {
    app.declineLocation();
  }
}
