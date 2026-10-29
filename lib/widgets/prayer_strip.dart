import 'package:flutter/material.dart' hide Text;
import '../l10n/app_text.dart';
import 'package:provider/provider.dart';

import '../state/app_state.dart';
import '../theme/app_theme.dart';

/// Orijinal HTML'deki .prayer-strip - vakitleri (Güneş dahil) yatay şerit
/// halinde gösterir, sıradaki namaz vaktini altın renkle vurgular.
class PrayerStrip extends StatelessWidget {
  const PrayerStrip({super.key});

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final times = state.times;

    if (times == null) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 16),
        child: Text('Vakitler henüz yüklenemedi.',
            style: TextStyle(color: AppColors.ink, fontSize: 13)),
      );
    }

    final ordered = times.toJson();

    return Row(
      children: stripOrder.map((key) {
        final isNow = key == state.nextPrayerKey;
        return Expanded(
          child: Container(
            margin: const EdgeInsets.symmetric(horizontal: 3),
            padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 2),
            decoration: BoxDecoration(
              color: isNow ? AppColors.gold : AppColors.ivory,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.goldSoft),
            ),
            child: Column(
              children: [
                Text(
                  prayerLabels[key]!,
                  style: TextStyle(
                    fontSize: 11,
                    color: isNow ? AppColors.deep : AppColors.ink.withValues(alpha: 0.75),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  ordered[key]! as String,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: isNow ? AppColors.deep : AppColors.ink,
                  ),
                ),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }
}
