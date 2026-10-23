import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../data/book_data.dart';
import '../state/app_state.dart';
import '../theme/app_theme.dart';
import '../services/analytics_service.dart';
import '../widgets/prayer_strip.dart';
import 'settings_page.dart';
import 'tools/esma_page.dart';
import 'tools/kazalar_page.dart';
import 'tools/zekatmatik_page.dart';
import 'tools/zikirmatik_page.dart';
import 'package:url_launcher/url_launcher.dart';

class HomePage extends StatelessWidget {
  const HomePage({super.key, required this.onNavigate});

  /// Alt navigasyon indeksine geçiş yapmak için (Kitap/Kıble/Sohbetler/Vakitler
  /// karolarına tıklandığında ilgili sekmeye geçer)
  final void Function(int index) onNavigate;

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();

    return SingleChildScrollView(
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _HeroCard(state: state),
          const SizedBox(height: 16),
          const PrayerStrip(),
          const SizedBox(height: 16),
          GridView.count(
            crossAxisCount: 3,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            mainAxisSpacing: 10,
            crossAxisSpacing: 10,
            childAspectRatio: 0.92,
            children: [
              _Tile(
                icon: '📖',
                label: 'Kitap',
                sub: '$bookPageCount sayfa',
                onTap: () => onNavigate(3),
              ),
              _Tile(
                icon: '🧭',
                label: 'Kıble',
                sub: state.qiblaKnown
                    ? '${state.qiblaDeg.toStringAsFixed(0)}°'
                    : '—',
                onTap: () => onNavigate(2),
              ),
              _Tile(
                icon: '🎬',
                label: 'Sohbetler',
                sub: 'Video arşivi',
                onTap: () => onNavigate(4),
              ),
              _Tile(
                icon: '🕌',
                label: 'Namaz Vakitleri',
                sub: 'Tüm gün',
                onTap: () => onNavigate(1),
              ),
              _Tile(
                icon: '📿',
                label: 'Zikirmatik',
                sub: 'Zikir sayacı',
                onTap: () => _open(context, 'zikirmatik', const ZikirmatikPage()),
              ),
              _Tile(
                icon: '📅',
                label: 'Kazalar',
                sub: 'Kaza takibi',
                onTap: () => _open(context, 'kazalar', const KazalarPage()),
              ),
              _Tile(
                icon: '🧮',
                label: 'Zekatmatik',
                sub: 'Zekat hesabı',
                onTap: () => _open(context, 'zekatmatik', const ZekatmatikPage()),
              ),
              _Tile(
                icon: '✨',
                label: 'Esmâü\'l-Hüsnâ',
                sub: '99 isim',
                onTap: () => _open(context, 'esma', const EsmaPage()),
              ),
              _Tile(
                icon: '📍',
                label: 'Yakın Camiler',
                sub: 'Haritada aç',
                onTap: () => _openMosques(context),
              ),
              _Tile(
                icon: '⚙️',
                label: 'Ayarlar',
                sub: 'Bildirim ve vakit',
                onTap: () => _open(context, 'ayarlar', const SettingsPage()),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Text(
            state.locationNote,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 12, color: AppColors.ink),
          ),
        ],
      ),
    );
  }
}

class _HeroCard extends StatelessWidget {
  const _HeroCard({required this.state});
  final AppState state;

  String _fmtDuration(Duration? d) {
    if (d == null) return '--:--:--';
    final h = d.inHours.toString().padLeft(2, '0');
    final m = (d.inMinutes % 60).toString().padLeft(2, '0');
    final s = (d.inSeconds % 60).toString().padLeft(2, '0');
    return '$h:$m:$s';
  }

  @override
  Widget build(BuildContext context) {
    final nextLabel = prayerLabels[state.nextPrayerKey] ?? '—';

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 26, horizontal: 22),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(AppRadius.card),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [AppColors.deep, Color(0xFF14453E)],
        ),
        boxShadow: const [
          BoxShadow(
              color: Color.fromRGBO(13, 43, 39, 0.12),
              blurRadius: 20,
              offset: Offset(0, 6)),
        ],
      ),
      child: Column(
        children: [
          Text(
            state.gregorianDateText,
            style: const TextStyle(
              fontFamily: 'Amiri',
              color: AppColors.ivory,
              fontSize: 14,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 3),
          Text(
            state.hijriDateText,
            style: const TextStyle(
              fontFamily: 'Cormorant Garamond',
              fontStyle: FontStyle.italic,
              color: AppColors.goldSoft,
              fontSize: 17,
            ),
          ),
          const SizedBox(height: 6),
          const Text(
            'Sıradaki Vakit',
            style: TextStyle(
              fontFamily: 'Amiri',
              color: AppColors.ivory,
              fontSize: 15,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            nextLabel,
            style: const TextStyle(
              fontFamily: 'Amiri',
              color: AppColors.ivory,
              fontSize: 32,
              fontWeight: FontWeight.w700,
            ),
          ),
          Text(
            _fmtDuration(state.remaining),
            style: const TextStyle(
              color: AppColors.ivory,
              fontSize: 38,
              fontWeight: FontWeight.w700,
              letterSpacing: 1,
              fontFeatures: [FontFeature.tabularFigures()],
            ),
          ),
          if (state.iftarRemaining != null) ...[
            const SizedBox(height: 10),
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
              decoration: BoxDecoration(
                color: AppColors.gold.withValues(alpha: 0.18),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: AppColors.gold.withValues(alpha: 0.6)),
              ),
              child: Text(
                '🌙 İftara kalan: ${_fmtDuration(state.iftarRemaining)}',
                style: const TextStyle(
                  color: AppColors.ivory,
                  fontSize: 13.5,
                  fontWeight: FontWeight.w600,
                  fontFeatures: [FontFeature.tabularFigures()],
                ),
              ),
            ),
          ],
          if (state.kerahatUyarisi != null) ...[
            const SizedBox(height: 10),
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: AppColors.danger.withValues(alpha: 0.16),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: AppColors.danger.withValues(alpha: 0.4)),
              ),
              child: Text(
                '⚠️ ${state.kerahatUyarisi}',
                style: const TextStyle(
                  color: AppColors.ivory,
                  fontSize: 12.5,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _Tile extends StatelessWidget {
  const _Tile({
    required this.icon,
    required this.label,
    required this.sub,
    required this.onTap,
  });

  final String icon;
  final String label;
  final String sub;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.ivory,
      borderRadius: BorderRadius.circular(AppRadius.card),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadius.card),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 10),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppRadius.card),
            border: Border.all(color: AppColors.goldSoft),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(icon, style: const TextStyle(fontSize: 28)),
              const SizedBox(height: 6),
              Text(
                label,
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontFamily: 'Amiri',
                  fontSize: 14.5,
                  height: 1.1,
                  color: AppColors.ink,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                sub,
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 10.5, color: AppColors.danger),
              ),
            ],
          ),
        ),
      ),
    );
  }
}


void _open(BuildContext context, String name, Widget page) {
  AnalyticsService.event('arac_ac', {'ad': name});
  Navigator.of(context).push(MaterialPageRoute(builder: (_) => page));
}

/// Telefondaki harita uygulamasında "cami" arar (bulunduğunuz konuma göre).
Future<void> _openMosques(BuildContext context) async {
  AnalyticsService.event('arac_ac', {'ad': 'yakin_camiler'});
  final messenger = ScaffoldMessenger.of(context);
  var ok = false;
  try {
    ok = await launchUrl(Uri.parse('geo:0,0?q=cami'),
        mode: LaunchMode.externalApplication);
  } catch (_) {}
  if (!ok) {
    try {
      ok = await launchUrl(
          Uri.parse('https://www.google.com/maps/search/?api=1&query=cami'),
          mode: LaunchMode.externalApplication);
    } catch (_) {}
  }
  if (!ok) {
    messenger.showSnackBar(
        const SnackBar(content: Text('Harita uygulaması açılamadı.')));
  }
}
