import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../state/app_state.dart';
import '../theme/app_theme.dart';

/// Hatırlatıcılar: sahur, teheccüt, Pazartesi/Perşembe orucu, Cuma namazı.
/// Bildirimler "Bildirimler" ayarı açıkken gelir; ses ayarı genel ses
/// ayarını (sesli/sessiz) izler.
class RemindersPage extends StatelessWidget {
  const RemindersPage({super.key});

  @override
  Widget build(BuildContext context) {
    final s = context.watch<AppState>();
    return Scaffold(
      backgroundColor: AppColors.paper,
      appBar: AppBar(title: const Text('Hatırlatıcılar')),
      body: ListView(
        padding: const EdgeInsets.all(18),
        children: [
          if (!s.notificationsEnabled)
            Container(
              margin: const EdgeInsets.only(bottom: 14),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.ivory,
                borderRadius: BorderRadius.circular(AppRadius.card),
                border: Border.all(color: AppColors.danger),
              ),
              child: const Text(
                'Bildirimler kapalı olduğu için hatırlatıcılar çalışmaz. '
                'Ana sayfadaki zil simgesinden bildirimleri açın.',
                style: TextStyle(fontSize: 12.5, color: AppColors.ink),
              ),
            ),
          _ReminderCard(
            keyName: 'sahur',
            title: 'Sahur uyarısı',
            desc: 'İmsaktan önce sahura kalkmanız için haber verir.',
            options: const [15, 30, 45, 60, 90],
          ),
          const SizedBox(height: 14),
          _ReminderCard(
            keyName: 'teheccud',
            title: 'Teheccüt uyandırma',
            desc: 'İmsaktan önce teheccüt için uyandırır.',
            options: const [60, 90, 120, 150, 180],
          ),
          const SizedBox(height: 14),
          _ReminderCard(
            keyName: 'oruc',
            title: 'Pazartesi / Perşembe orucu',
            desc: 'Pazartesi ve Perşembe günleri imsaktan önce hatırlatır.',
            options: const [30, 45, 60, 90],
            extra: SwitchListTile(
              contentPadding: EdgeInsets.zero,
              dense: true,
              title: const Text('Bir gün önce de hatırlat',
                  style: TextStyle(color: AppColors.ink)),
              subtitle: const Text('Pazar ve Çarşamba yatsı vaktinde',
                  style: TextStyle(fontSize: 11.5)),
              value: s.orucOneDayBefore,
              onChanged: s.extraOn['oruc'] == true
                  ? (v) => context.read<AppState>().setOrucOneDayBefore(v)
                  : null,
            ),
          ),
          const SizedBox(height: 14),
          _ReminderCard(
            keyName: 'cuma',
            title: 'Cuma namazı hatırlatma',
            desc: 'Cuma günü öğle vaktinden önce hatırlatır.',
            options: const [30, 45, 60, 90, 120],
            baseLabel: 'Öğleden',
          ),
        ],
      ),
    );
  }
}

class _ReminderCard extends StatelessWidget {
  const _ReminderCard({
    required this.keyName,
    required this.title,
    required this.desc,
    required this.options,
    this.extra,
    this.baseLabel = 'İmsaktan',
  });
  final String keyName;
  final String title;
  final String desc;
  final List<int> options;
  final Widget? extra;
  final String baseLabel;

  @override
  Widget build(BuildContext context) {
    final s = context.watch<AppState>();
    final on = s.extraOn[keyName] ?? false;
    final minutes = s.extraMin[keyName] ?? options.first;
    final value = options.contains(minutes) ? minutes : options.first;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.ivory,
        borderRadius: BorderRadius.circular(AppRadius.card),
        border: Border.all(color: AppColors.goldSoft),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(title,
                    style: const TextStyle(
                        fontFamily: 'Amiri',
                        fontSize: 17,
                        color: AppColors.ink)),
              ),
              Switch(
                value: on,
                onChanged: (v) => context
                    .read<AppState>()
                    .setExtraReminder(keyName, on: v),
              ),
            ],
          ),
          Text(desc,
              style: const TextStyle(fontSize: 12, color: AppColors.ink)),
          const SizedBox(height: 8),
          Row(
            children: [
              Text(baseLabel,
                  style: const TextStyle(color: AppColors.ink)),
              const SizedBox(width: 12),
              Expanded(
                child: DropdownButton<int>(
                  isExpanded: true,
                  value: value,
                  items: options
                      .map((m) => DropdownMenuItem(
                          value: m, child: Text('$m dk önce')))
                      .toList(),
                  onChanged: on
                      ? (v) {
                          if (v != null) {
                            context
                                .read<AppState>()
                                .setExtraReminder(keyName, minutes: v);
                          }
                        }
                      : null,
                ),
              ),
            ],
          ),
          if (extra != null) extra!,
        ],
      ),
    );
  }
}
