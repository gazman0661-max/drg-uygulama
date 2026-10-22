import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../data/il_ilce_data.dart';
import '../state/app_state.dart';
import '../theme/app_theme.dart';
import '../utils/turkish.dart';

class TimesPage extends StatefulWidget {
  const TimesPage({super.key});

  @override
  State<TimesPage> createState() => _TimesPageState();
}

class _TimesPageState extends State<TimesPage> {
  late String _selectedIl;
  late String _selectedIlce;

  // AppState'teki il/ilçe değiştiğinde (ör. ilk açılış seçimi) dropdown'lar
  // da güncellensin diye en son görülen değerler tutulur.
  String? _seenIl;
  String? _seenIlce;

  @override
  void initState() {
    super.initState();
    final state = context.read<AppState>();
    _selectedIl = state.il;
    _selectedIlce = state.ilce;
  }

  String _toTitle(String s) => trTitle(s);

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    if (state.il != _seenIl || state.ilce != _seenIlce) {
      _seenIl = state.il;
      _seenIlce = state.ilce;
      _selectedIl = state.il;
      _selectedIlce = state.ilce;
    }
    final iller = ilIlceData.keys.toList()..sort(trCompare);
    final ilceler =
        (ilIlceData[_selectedIl] ?? []).toList()..sort(trCompare);
    if (!ilceler.contains(_selectedIlce) && ilceler.isNotEmpty) {
      _selectedIlce = ilceler.first;
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text('Namaz Vakitleri',
              style: TextStyle(
                  fontFamily: 'Amiri', fontSize: 22, color: AppColors.ink)),
          const SizedBox(height: 14),
          _TimesTable(state: state),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AppColors.ivory,
              borderRadius: BorderRadius.circular(AppRadius.card),
              border: Border.all(color: AppColors.goldSoft),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Vakit kaynağı: Aladhan API\'nin Türkiye Diyanet İşleri Başkanlığı yöntemine göre hazırladığı vakitler. '
                  'Bu uygulama Diyanet İşleri Başkanlığı\'nın resmi uygulaması değildir.',
                  style: TextStyle(fontSize: 12.5, color: AppColors.ink),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    const Expanded(flex: 2, child: Text('İl')),
                    Expanded(
                      flex: 3,
                      child: DropdownButton<String>(
                        isExpanded: true,
                        value: _selectedIl,
                        items: iller
                            .map((il) => DropdownMenuItem(
                                value: il, child: Text(_toTitle(il))))
                            .toList(),
                        onChanged: (v) {
                          if (v == null) return;
                          setState(() {
                            _selectedIl = v;
                            final newIlceler =
                                (ilIlceData[v] ?? []).toList()
                                  ..sort(trCompare);
                            _selectedIlce = newIlceler.isNotEmpty
                                ? newIlceler.first
                                : '';
                          });
                        },
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    const Expanded(flex: 2, child: Text('İlçe')),
                    Expanded(
                      flex: 3,
                      child: DropdownButton<String>(
                        isExpanded: true,
                        value: ilceler.contains(_selectedIlce)
                            ? _selectedIlce
                            : null,
                        items: ilceler
                            .map((i) => DropdownMenuItem(
                                value: i, child: Text(_toTitle(i))))
                            .toList(),
                        onChanged: (v) {
                          if (v == null) return;
                          setState(() => _selectedIlce = v);
                        },
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                OutlinedButton(
                  onPressed: state.loading
                      ? null
                      : () => context
                          .read<AppState>()
                          .setIlIlce(_selectedIl, _selectedIlce),
                  child: state.loading
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2))
                      : const Text('Bu il/ilçe için vakitleri getir'),
                ),
                const SizedBox(height: 10),
                Text(
                  state.vakitKaynakNote,
                  style: const TextStyle(fontSize: 12, color: AppColors.ink),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          const _KerahatCard(),
          const SizedBox(height: 16),
          const _PanelCard(),
          const SizedBox(height: 16),
          const _ReminderCard(),
        ],
      ),
    );
  }
}

class _KerahatCard extends StatelessWidget {
  const _KerahatCard();

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final kerahat = state.kerahatVakitleri;

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
          const Text('Kerahat Vakitleri',
              style: TextStyle(
                  fontFamily: 'Amiri', fontSize: 17, color: AppColors.ink)),
          const SizedBox(height: 4),
          const Text(
            'Namaz kılınması mekruh olan yaklaşık süreler '
            '(yaklaşık 45 dakika kabul edilir).',
            style: TextStyle(fontSize: 12, color: AppColors.ink),
          ),
          const SizedBox(height: 10),
          if (kerahat == null)
            const Text('Vakitler yüklenince burada görünecek.',
                style: TextStyle(fontSize: 12.5, color: AppColors.ink))
          else
            ...kerahat.entries.map((e) => Padding(
                  padding: const EdgeInsets.symmetric(vertical: 5),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(e.key,
                            style:
                                const TextStyle(color: AppColors.ink)),
                      ),
                      Text(
                        e.value,
                        style: const TextStyle(
                            fontWeight: FontWeight.w600,
                            color: AppColors.danger),
                      ),
                    ],
                  ),
                )),
        ],
      ),
    );
  }
}

class _PanelCard extends StatelessWidget {
  const _PanelCard();

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();

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
          const Text('Bildirim Çubuğu Paneli',
              style: TextStyle(
                  fontFamily: 'Amiri', fontSize: 17, color: AppColors.ink)),
          const SizedBox(height: 4),
          const Text(
            'Sıradaki vakte kalan süre ve günün tüm vakitleri bildirim '
            'çubuğunda sürekli görünsün. Dilediğiniz zaman kapatabilirsiniz.',
            style: TextStyle(fontSize: 12, color: AppColors.ink),
          ),
          const SizedBox(height: 6),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Bildirim çubuğunda göster',
                style: TextStyle(color: AppColors.ink)),
            value: state.panelEnabled,
            onChanged: (v) async {
              final ok = await context.read<AppState>().setPanelEnabled(v);
              if (!ok && context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                    content: Text(
                        'Bildirim izni verilmedi. Telefon ayarlarından izin verin.')));
              }
            },
          ),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Kerahat vakitlerini göster',
                style: TextStyle(color: AppColors.ink)),
            value: state.panelKerahat,
            onChanged: state.panelEnabled
                ? (v) => context.read<AppState>().setPanelKerahat(v)
                : null,
          ),
        ],
      ),
    );
  }
}

class _ReminderCard extends StatelessWidget {
  const _ReminderCard();

  String _optionLabel(int minutes) =>
      minutes == 0 ? 'Kapalı' : '$minutes dk önce';

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();

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
          const Text('Hatırlatma Bildirimleri',
              style: TextStyle(
                  fontFamily: 'Amiri', fontSize: 17, color: AppColors.ink)),
          const SizedBox(height: 4),
          const Text(
            'Her vakit için, vakit girmeden belirli bir süre önce ayrı bir '
            'hatırlatma bildirimi alın.',
            style: TextStyle(fontSize: 12, color: AppColors.ink),
          ),
          const SizedBox(height: 10),
          ...stripOrder.map((key) {
            final selected = state.reminderMinutes[key] ?? 0;
            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Row(
                children: [
                  Expanded(
                    flex: 2,
                    child: Text(prayerLabels[key] ?? key,
                        style: const TextStyle(color: AppColors.ink)),
                  ),
                  Expanded(
                    flex: 2,
                    child: DropdownButton<int>(
                      isExpanded: true,
                      value: selected,
                      items: reminderOptions
                          .map((m) => DropdownMenuItem(
                              value: m, child: Text(_optionLabel(m))))
                          .toList(),
                      onChanged: (v) {
                        if (v == null) return;
                        context.read<AppState>().setReminderMinutes(key, v);
                      },
                    ),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }
}

class _TimesTable extends StatelessWidget {
  const _TimesTable({required this.state});
  final AppState state;

  @override
  Widget build(BuildContext context) {
    final times = state.times;
    // Namaz vakitleri tablosunda Güneş de gösterilir (orijinal HTML'deki
    // PRAYER_ORDER + Güneş kombinasyonu ile aynı - tam vakit tablosu)
    const order = ['Sabah', 'Gunes', 'Ogle', 'Ikindi', 'Aksam', 'Yatsi'];
    const labels = {
      'Sabah': 'İmsak',
      'Gunes': 'Güneş',
      'Ogle': 'Öğle',
      'Ikindi': 'İkindi',
      'Aksam': 'Akşam',
      'Yatsi': 'Yatsı',
    };
    final values = times?.toJson() ?? {};

    return Table(
      border: TableBorder(
          horizontalInside: BorderSide(color: AppColors.goldSoft)),
      children: order.map((key) {
        return TableRow(children: [
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 10),
            child: Text(labels[key]!,
                style: const TextStyle(color: AppColors.ink)),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 10),
            child: Text(
              values[key] ?? '--:--',
              textAlign: TextAlign.right,
              style: const TextStyle(
                  fontWeight: FontWeight.w600, color: AppColors.ink),
            ),
          ),
        ]);
      }).toList(),
    );
  }
}
