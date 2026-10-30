import 'package:flutter/material.dart' hide Text;
import 'package:flutter/material.dart' as m show Text;
import 'package:url_launcher/url_launcher.dart';

import '../data/our_apps.dart';
import '../l10n/app_text.dart';
import '../services/log_service.dart';
import '../theme/app_theme.dart';

/// Diğer uygulama/oyunlarımızın listesi; dokununca Google Play sayfası açılır.
class OurAppsPage extends StatelessWidget {
  const OurAppsPage({super.key});

  Future<void> _openStore(BuildContext context, OurApp app) async {
    AppLog.i('uygulamalarimiz', 'play store acilis: ${app.name}');
    final messenger = ScaffoldMessenger.of(context);
    if (app.url.isEmpty) {
      messenger.showSnackBar(
          const SnackBar(content: Text('Bağlantı yakında eklenecek.')));
      return;
    }
    final uri = Uri.parse(app.url);
    var ok = false;
    try {
      // Play Store uygulamasını doğrudan açmayı dene
      ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (e) {
      AppLog.w('uygulamalarimiz', 'externalApplication basarisiz: $e');
    }
    if (!ok) {
      try {
        ok = await launchUrl(uri, mode: LaunchMode.inAppBrowserView);
      } catch (e) {
        AppLog.w('uygulamalarimiz', 'inAppBrowserView basarisiz: $e');
      }
    }
    if (!ok) {
      AppLog.e('uygulamalarimiz', 'baglanti acilamadi: ${app.url}');
      messenger.showSnackBar(
          const SnackBar(content: Text('Bağlantı açılamadı.')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.paper,
      appBar: AppBar(title: const Text('Oyunlarımız ve Uygulamalarımız')),
      body: ourApps.isEmpty
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Text('Yakında burada olacak.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                        color: AppColors.ink.withValues(alpha: 0.7),
                        fontSize: 16,
                        fontWeight: FontWeight.w600)),
              ),
            )
          : ListView.separated(
              padding: const EdgeInsets.all(18),
              itemCount: ourApps.length,
              separatorBuilder: (_, __) => const SizedBox(height: 14),
              itemBuilder: (context, i) => _AppCard(
                app: ourApps[i],
                onTap: () => _openStore(context, ourApps[i]),
              ),
            ),
    );
  }
}

class _AppCard extends StatelessWidget {
  const _AppCard({required this.app, required this.onTap});
  final OurApp app;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.ivory,
      elevation: 2,
      shadowColor: Colors.black26,
      borderRadius: BorderRadius.circular(22),
      child: InkWell(
        borderRadius: BorderRadius.circular(22),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(22),
            border: Border.all(color: AppColors.gold, width: 2),
          ),
          child: Row(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(18),
                child: Image.asset(
                  app.icon,
                  width: 76,
                  height: 76,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => Container(
                    width: 76,
                    height: 76,
                    color: AppColors.deep,
                    child: const Icon(Icons.apps, color: AppColors.gold),
                  ),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Uygulama adı çevrilmez (marka adı)
                    m.Text(app.name,
                        style: const TextStyle(
                            color: AppColors.deep,
                            fontSize: 18,
                            fontWeight: FontWeight.w800)),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        const Icon(Icons.shop_2_outlined,
                            size: 20, color: Color(0xFF2E7D32)),
                        const SizedBox(width: 6),
                        Flexible(
                          child: Text("Google Play'de aç",
                              style: const TextStyle(
                                  color: Color(0xFF2E7D32),
                                  fontSize: 14.5,
                                  fontWeight: FontWeight.w700)),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right, color: AppColors.gold, size: 30),
            ],
          ),
        ),
      ),
    );
  }
}
