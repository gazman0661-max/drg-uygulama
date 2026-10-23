import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

/// Bağlantıyı uygulama içinde (Chrome Custom Tabs) açar; desteklenmezse
/// harici tarayıcıya düşer. Açılamazsa kullanıcıya mesaj gösterir.
Future<void> openLink(BuildContext context, String url) async {
  final messenger = ScaffoldMessenger.of(context);
  if (url.isEmpty) {
    messenger.showSnackBar(
        const SnackBar(content: Text('Bağlantı yakında eklenecek.')));
    return;
  }
  final uri = Uri.parse(url);
  var ok = false;
  try {
    ok = await launchUrl(uri, mode: LaunchMode.inAppBrowserView);
  } catch (_) {
    ok = false;
  }
  if (!ok) {
    try {
      ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (_) {
      ok = false;
    }
  }
  if (!ok) {
    messenger
        .showSnackBar(const SnackBar(content: Text('Bağlantı açılamadı.')));
  }
}
