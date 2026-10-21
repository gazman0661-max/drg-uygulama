import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../data/book_data.dart';
import '../state/app_state.dart';
import '../theme/app_theme.dart';
import '../widgets/prayer_strip.dart';

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
            crossAxisCount: 2,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            mainAxisSpacing: 12,
            crossAxisSpacing: 12,
            childAspectRatio: 1.3,
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
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppRadius.card),
            border: Border.all(color: AppColors.goldSoft),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(icon, style: const TextStyle(fontSize: 26)),
              const SizedBox(height: 6),
              Text(
                label,
                style: const TextStyle(
                  fontFamily: 'Amiri',
                  fontSize: 16,
                  color: AppColors.ink,
                  fontWeight: FontWeight.w600,
                ),
              ),
              Text(
                sub,
                style: const TextStyle(fontSize: 11, color: AppColors.danger),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
