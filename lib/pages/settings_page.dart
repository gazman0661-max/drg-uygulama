import 'package:flutter/material.dart' hide Text;
import 'package:flutter/material.dart' as m show Text;
import '../l10n/app_text.dart';
import '../l10n/l10n.dart';
import 'package:provider/provider.dart';

import '../utils/open_link.dart';
import '../config/links.dart';
import '../data/il_ilce_data.dart';
import '../state/app_state.dart';
import '../theme/app_theme.dart';
import '../utils/turkish.dart';
import '../services/log_service.dart';
import 'log_page.dart';
import 'our_apps_page.dart';
import 'reminders_page.dart';

class SettingsPage extends StatelessWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();

    return Scaffold(
      backgroundColor: AppColors.paper,
      appBar: AppBar(title: const Text('Ayarlar')),
      body: ListView(
        padding: const EdgeInsets.all(18),
        children: [
          // Oyunlarımız ve Uygulamalarımız (en üstte)
          const _OurAppsButton(),
          const SizedBox(height: 16),

          // 0) Dil seçimi
          const _LanguageCard(),
          const SizedBox(height: 14),

          // 1) Bildirim aç/kapat
          _Card(
            title: 'Bildirimler',
            subtitle: 'Ezan vakti ve vakit hatırlatma bildirimleri.',
            child: SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(state.notificationsActive ? 'Açık' : 'Kapalı',
                  style: const TextStyle(color: AppColors.ink)),
              value: state.notificationsActive,
              onChanged: (v) async {
                final ok =
                    await context.read<AppState>().setNotificationsEnabled(v);
                if (!ok && context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                      content: Text(
                          'Bildirim izni verilmedi. Telefon ayarlarından izin verin.')));
                }
              },
            ),
          ),
          const SizedBox(height: 14),

          // 1b) Hatırlatıcılar
          _Card(
            title: 'Hatırlatıcılar',
            subtitle: 'Sahur, teheccüt, Pazartesi/Perşembe orucu ve Cuma '
                'namazı için hatırlatma kurun.',
            child: SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                icon: const Icon(Icons.alarm_add_outlined),
                label: const Text('Hatırlatıcıları düzenle'),
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute(
                    settings: const RouteSettings(name: 'HatirlaticilarSayfasi'),
                    builder: (_) => const RemindersPage()),
                ),
              ),
            ),
          ),
          const SizedBox(height: 14),

          // 2) İl / ilçe
          const _LocationCard(),
          const SizedBox(height: 14),

          // 3) Sesli / sessiz
          _Card(
            title: 'Bildirim Sesi',
            subtitle: 'Sesli: ezan, uygulamanın kendi oynatıcısıyla çalar; '
                'telefonun bildirim ses ayarlarına bağlı değildir. '
                'Sessiz: sadece bildirim gelir.',
            child: Column(children: [
            SizedBox(
              width: double.infinity,
              child: SegmentedButton<bool>(
                showSelectedIcon: false,
                segments: const [
                  ButtonSegment(
                      value: true,
                      icon: Icon(Icons.volume_up_outlined),
                      label: Text('Sesli')),
                  ButtonSegment(
                      value: false,
                      icon: Icon(Icons.volume_off_outlined),
                      label: Text('Sessiz')),
                ],
                selected: {state.soundEnabled},
                onSelectionChanged: state.notificationsActive
                    ? (s) => context.read<AppState>().setSoundEnabled(s.first)
                    : null,
                style: ButtonStyle(
                  backgroundColor: WidgetStateProperty.resolveWith((st) =>
                      st.contains(WidgetState.selected)
                          ? AppColors.gold
                          : AppColors.ivory),
                  foregroundColor: WidgetStateProperty.resolveWith((st) =>
                      st.contains(WidgetState.selected)
                          ? AppColors.deep
                          : AppColors.ink),
                  side: const WidgetStatePropertyAll(
                      BorderSide(color: AppColors.goldSoft)),
                ),
              ),
            ),
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                icon: const Icon(Icons.play_circle_outline),
                label: const Text('Ezanı dene'),
                onPressed: (state.notificationsActive && state.soundEnabled)
                    ? () async {
                        final ok = await context.read<AppState>().testAdhan();
                        if (!ok && context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                  content: Text('Ses başlatılamadı.')));
                        }
                      }
                    : null,
              ),
            ),
            ]),
          ),
          const SizedBox(height: 14),

          // 3b) Ezan ses kanalı + ses yüksekliği
          _Card(
            title: 'Ezan Ses Kanalı ve Yüksekliği',
            subtitle: 'Alarm (önerilen): telefon sessiz moddayken de ezan '
                'duyulur. Medya: medya ses seviyesinden çalar. Bildirim: '
                'telefonun sessiz modunu izler. "Rahatsız etme" modunda '
                'telefonun kendi ayarı geçerli olabilir.',
            child: Column(
              children: [
                SizedBox(
                  width: double.infinity,
                  child: SegmentedButton<String>(
                    showSelectedIcon: false,
                    segments: const [
                      ButtonSegment(
                          value: 'alarm',
                          icon: Icon(Icons.alarm),
                          label: Text('Alarm')),
                      ButtonSegment(
                          value: 'media',
                          icon: Icon(Icons.music_note_outlined),
                          label: Text('Medya')),
                      ButtonSegment(
                          value: 'notification',
                          icon: Icon(Icons.notifications_outlined),
                          label: Text('Bildirim')),
                    ],
                    selected: {state.ezanStream},
                    onSelectionChanged:
                        (state.notificationsActive && state.soundEnabled)
                            ? (v) =>
                                context.read<AppState>().setEzanStream(v.first)
                            : null,
                    style: _segStyle,
                  ),
                ),
                const SizedBox(height: 8),
                _VolumeSlider(
                  initial: state.ezanVolume,
                  enabled: state.notificationsActive && state.soundEnabled,
                  onEnd: (v) => context.read<AppState>().setEzanVolume(v),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),

          // 3c) Vakit bazlı ezan
          _Card(
            title: 'Hangi Vakitlerde Ezan Gelsin?',
            subtitle: 'Kapattığınız vakitte ezan bildirimi gelmez. Sabah ezanı '
                'normal aylarda Güneş\'ten 45 dakika önce, Ramazan ayında İmsak '
                'vaktinde gelir.',
            child: Column(
              children: [
                for (final k in prayerOrder)
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    dense: true,
                    title: Text('${prayerLabels[k]} ezanı',
                        style: const TextStyle(color: AppColors.ink)),
                    value: state.adhanEnabled[k] ?? true,
                    onChanged: state.notificationsActive
                        ? (v) => context.read<AppState>().setAdhanEnabled(k, v)
                        : null,
                  ),
              ],
            ),
          ),
          const SizedBox(height: 14),

          // 3d) Vakit düzeltme
          _Card(
            title: 'Vakit Düzeltme',
            subtitle: 'Vakitleri dakika olarak ileri/geri alabilirsiniz '
                '(ör. yaz-kış saati ya da cami vaktine uyum için).',
            child: Column(
              children: [
                for (final k in stripOrder)
                  _Stepper(
                    label: prayerLabels[k] ?? k,
                    value: state.timeOffsets[k] ?? 0,
                    unit: tr('dk'),
                    min: -30,
                    max: 30,
                    onChanged: (v) =>
                        context.read<AppState>().setTimeOffset(k, v),
                  ),
                const Divider(height: 18, color: AppColors.goldSoft),
                _Stepper(
                  label: 'Hicri gün',
                  value: state.hijriOffset,
                  unit: tr('gün'),
                  min: -2,
                  max: 2,
                  onChanged: (v) =>
                      context.read<AppState>().setHijriOffset(v),
                ),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  dense: true,
                  title: const Text('Hicri günü akşam vaktinde değiştir',
                      style: TextStyle(color: AppColors.ink)),
                  value: state.hijriAtMaghrib,
                  onChanged: (v) =>
                      context.read<AppState>().setHijriAtMaghrib(v),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),

          // 3e) Kerahat süresi
          _Card(
            title: 'Kerahat Süresi',
            subtitle: 'Kerahat vakitleri için kabul edilen süre '
                '(Güneşin doğuşu, istiva ve batış öncesi).',
            child: DropdownButton<int>(
              isExpanded: true,
              value: const [30, 40, 45, 50, 60].contains(state.kerahatMinutes)
                  ? state.kerahatMinutes
                  : 45,
              items: const [30, 40, 45, 50, 60]
                  .map((m) =>
                      DropdownMenuItem(value: m, child: Text('$m dakika')))
                  .toList(),
              onChanged: (v) {
                if (v != null) context.read<AppState>().setKerahatMinutes(v);
              },
            ),
          ),
          const SizedBox(height: 14),

          // 3f) İftar sayacı
          _Card(
            title: 'İftar Sayacı',
            subtitle: 'Ramazan ayında ana sayfada iftara (Akşam vaktine) kalan '
                'süre gösterilir.',
            child: SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(state.iftarCounterEnabled ? 'Açık' : 'Kapalı',
                  style: const TextStyle(color: AppColors.ink)),
              value: state.iftarCounterEnabled,
              onChanged: (v) => context.read<AppState>().setIftarCounter(v),
            ),
          ),
          const SizedBox(height: 14),

          // 4) Bildirim çubuğu widget'ı
          _Card(
            title: 'Bildirim Çubuğu Widget\'ı',
            subtitle: 'Sıradaki vakte kalan süre ve günün vakitleri bildirim '
                'çubuğunda sürekli görünsün.',
            child: SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(state.panelEnabled ? 'Açık' : 'Kapalı',
                  style: const TextStyle(color: AppColors.ink)),
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
          ),
          const SizedBox(height: 14),

          // 5) Bildirimler vaktinde gelmiyorsa
          _Card(
            title: 'Bildirimler vaktinde gelmiyorsa',
            subtitle: 'Bazı telefonlar (Xiaomi, Samsung, Huawei, Oppo, Vivo) '
                'pil tasarrufu için uygulamayı arka planda kısıtlar. '
                'Ezanın tam vaktinde gelmesi için:',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  '1. Aşağıdaki butonla uygulama ayarlarını açın.\n'
                  '2. "Pil" bölümünden "Kısıtlama yok" (veya "Sınırsız") seçin.\n'
                  '3. Varsa "Otomatik başlatma" ve "Arka planda çalışmaya izin"i açın.\n'
                  '4. "Bildirimler" bölümünde tüm kanalların açık olduğundan emin olun.',
                  style:
                      TextStyle(fontSize: 12.5, color: AppColors.ink, height: 1.4),
                ),
                const SizedBox(height: 10),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    icon: const Icon(Icons.settings_applications_outlined),
                    label: const Text('Uygulama ayarlarını aç'),
                    onPressed: () async {
                      final ok = await context.read<AppState>().openAppSettings();
                      if (!ok && context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                            content: Text(
                                'Ayarlar açılamadı. Telefon Ayarlar > Uygulamalar > Dergah-ı Kadirî yolunu izleyin.')));
                      }
                    },
                  ),
                ),
                const SizedBox(height: 8),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    icon: const Icon(Icons.alarm_on_outlined),
                    label: const Text('Tam zamanlı alarm ayarı'),
                    onPressed: () =>
                        context.read<AppState>().openExactAlarmSettings(),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 28),

          // Hakkında: gizlilik + kullanım şartları + (gizli) log ekranı
          const _AboutSection(),
          const SizedBox(height: 12),
        ],
      ),
    );
  }
}

final ButtonStyle _segStyle = ButtonStyle(
  backgroundColor: WidgetStateProperty.resolveWith((st) =>
      st.contains(WidgetState.selected) ? AppColors.gold : AppColors.ivory),
  foregroundColor: WidgetStateProperty.resolveWith((st) =>
      st.contains(WidgetState.selected) ? AppColors.deep : AppColors.ink),
  side: const WidgetStatePropertyAll(BorderSide(color: AppColors.goldSoft)),
);

/// Ses yüksekliği kaydırıcısı: sürüklerken yerel değer, bırakınca kaydeder
class _VolumeSlider extends StatefulWidget {
  const _VolumeSlider(
      {required this.initial, required this.enabled, required this.onEnd});
  final double initial;
  final bool enabled;
  final ValueChanged<double> onEnd;

  @override
  State<_VolumeSlider> createState() => _VolumeSliderState();
}

class _VolumeSliderState extends State<_VolumeSlider> {
  late double _v = widget.initial;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        const Icon(Icons.volume_down, color: AppColors.ink),
        Expanded(
          child: Slider(
            value: _v,
            min: 0.1,
            max: 1.0,
            divisions: 9,
            label: '%${(_v * 100).round()}',
            activeColor: AppColors.gold,
            inactiveColor: AppColors.goldSoft,
            onChanged:
                widget.enabled ? (v) => setState(() => _v = v) : null,
            onChangeEnd: widget.enabled ? widget.onEnd : null,
          ),
        ),
        const Icon(Icons.volume_up, color: AppColors.ink),
      ],
    );
  }
}

/// "−  +3 dk  +" biçiminde artır/azalt satırı
class _Stepper extends StatelessWidget {
  const _Stepper({
    required this.label,
    required this.value,
    required this.unit,
    required this.min,
    required this.max,
    required this.onChanged,
  });
  final String label;
  final int value;
  final String unit;
  final int min;
  final int max;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    final txt = value > 0 ? '+$value $unit' : '$value $unit';
    return Row(
      children: [
        Expanded(
            child: Text(label, style: const TextStyle(color: AppColors.ink))),
        IconButton(
          visualDensity: VisualDensity.compact,
          icon: const Icon(Icons.remove_circle_outline),
          onPressed: value > min ? () => onChanged(value - 1) : null,
        ),
        SizedBox(
          width: 64,
          child: Text(txt,
              textAlign: TextAlign.center,
              style: TextStyle(
                  fontWeight: FontWeight.w600,
                  color: value == 0 ? AppColors.ink : AppColors.danger)),
        ),
        IconButton(
          visualDensity: VisualDensity.compact,
          icon: const Icon(Icons.add_circle_outline),
          onPressed: value < max ? () => onChanged(value + 1) : null,
        ),
      ],
    );
  }
}

class _Card extends StatelessWidget {
  const _Card({required this.title, required this.child, this.subtitle});
  final String title;
  final String? subtitle;
  final Widget child;

  @override
  Widget build(BuildContext context) {
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
          Text(title,
              style: const TextStyle(
                  fontFamily: 'Amiri', fontSize: 17, color: AppColors.ink)),
          if (subtitle != null) ...[
            const SizedBox(height: 4),
            Text(subtitle!,
                style: const TextStyle(fontSize: 12, color: AppColors.ink)),
          ],
          const SizedBox(height: 6),
          child,
        ],
      ),
    );
  }
}

/// Dil seçimi: butona basınca diller listelenir, kullanıcı birini seçer.
class _LanguageCard extends StatelessWidget {
  const _LanguageCard();

  static const _systemKey = 'system';

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final current = state.languageOverride;
    final label =
        current == null ? tr('Cihaz dili (otomatik)') : (L.names[current] ?? current);

    return _Card(
      title: 'Dil',
      subtitle: 'Uygulama dilini seçin.',
      child: SizedBox(
        width: double.infinity,
        child: OutlinedButton.icon(
          icon: const Icon(Icons.language),
          label: Row(
            children: [
              Expanded(child: m.Text(label)),
              const Icon(Icons.arrow_drop_down),
            ],
          ),
          onPressed: () => _pick(context, current),
        ),
      ),
    );
  }

  Future<void> _pick(BuildContext context, String? current) async {
    final chosen = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: AppColors.ivory,
      showDragHandle: true,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (final e in L.names.entries)
              ListTile(
                title: m.Text(e.value,
                    style: const TextStyle(color: AppColors.ink)),
                trailing: current == e.key
                    ? const Icon(Icons.check, color: AppColors.deep)
                    : null,
                onTap: () => Navigator.of(ctx).pop(e.key),
              ),
            ListTile(
              title: Text('Cihaz dili (otomatik)',
                  style: const TextStyle(color: AppColors.ink)),
              trailing: current == null
                  ? const Icon(Icons.check, color: AppColors.deep)
                  : null,
              onTap: () => Navigator.of(ctx).pop(_systemKey),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
    if (chosen == null || !context.mounted) return;
    await context
        .read<AppState>()
        .setLanguage(chosen == _systemKey ? null : chosen);
  }
}

class _LocationCard extends StatefulWidget {
  const _LocationCard();

  @override
  State<_LocationCard> createState() => _LocationCardState();
}

class _LocationCardState extends State<_LocationCard> {
  late String _il;
  late String _ilce;

  @override
  void initState() {
    super.initState();
    final s = context.read<AppState>();
    _il = s.il;
    _ilce = s.ilce;
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final iller = ilIlceData.keys.toList()..sort(trCompare);
    final ilceler = (ilIlceData[_il] ?? []).toList()..sort(trCompare);
    if (!ilceler.contains(_ilce) && ilceler.isNotEmpty) _ilce = ilceler.first;

    return _Card(
      title: 'İl / İlçe Seçimi',
      subtitle: 'Seçili yer: ${trTitle(state.ilce)}, ${trTitle(state.il)}',
      child: Column(
        children: [
          Row(
            children: [
              const Expanded(flex: 2, child: Text('İl')),
              Expanded(
                flex: 3,
                child: DropdownButton<String>(
                  isExpanded: true,
                  value: _il,
                  items: iller
                      .map((i) =>
                          DropdownMenuItem(value: i, child: Text(trTitle(i))))
                      .toList(),
                  onChanged: (v) {
                    if (v == null) return;
                    setState(() {
                      _il = v;
                      final l = (ilIlceData[v] ?? []).toList()
                        ..sort(trCompare);
                      _ilce = l.isNotEmpty ? l.first : '';
                    });
                  },
                ),
              ),
            ],
          ),
          Row(
            children: [
              const Expanded(flex: 2, child: Text('İlçe')),
              Expanded(
                flex: 3,
                child: DropdownButton<String>(
                  isExpanded: true,
                  value: ilceler.contains(_ilce) ? _ilce : null,
                  items: ilceler
                      .map((i) =>
                          DropdownMenuItem(value: i, child: Text(trTitle(i))))
                      .toList(),
                  onChanged: (v) {
                    if (v == null) return;
                    setState(() => _ilce = v);
                  },
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: state.loading
                  ? null
                  : () async {
                      await context.read<AppState>().setIlIlce(_il, _ilce);
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                            content: Text(
                                'Konum güncellendi: ${trTitle(_ilce)}, ${trTitle(_il)}')));
                      }
                    },
              child: state.loading
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2))
                  : const Text('Kaydet'),
            ),
          ),
        ],
      ),
    );
  }
}

/// "HAKKINDA" bölümü. Başlığa 7 kez (2 sn içinde arka arkaya) dokunmak gizli
/// log ekranını açar; kullanıcıya hiçbir ipucu gösterilmez.
class _AboutSection extends StatefulWidget {
  const _AboutSection();

  @override
  State<_AboutSection> createState() => _AboutSectionState();
}

class _AboutSectionState extends State<_AboutSection> {
  static const _needed = 7;
  int _taps = 0;
  DateTime _last = DateTime.fromMillisecondsSinceEpoch(0);

  void _onHeaderTap() {
    final now = DateTime.now();
    _taps = now.difference(_last) > const Duration(seconds: 2) ? 1 : _taps + 1;
    _last = now;
    if (_taps >= _needed) {
      _taps = 0;
      AppLog.i('ayar', 'gizli log ekrani acildi (7 dokunus)');
      Navigator.of(context).push(MaterialPageRoute(
        settings: const RouteSettings(name: 'LogSayfasi'),
        builder: (_) => const LogPage(),
      ));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: _onHeaderTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 14),
            child: Text('HAKKINDA',
                style: TextStyle(
                    color: AppColors.ink.withValues(alpha: 0.75),
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 2)),
          ),
        ),
        const SizedBox(height: 4),
        const _AboutButton(label: 'Kullanım Şartları', url: termsOfUseUrl),
        const SizedBox(height: 12),
        const _AboutButton(label: 'Gizlilik Politikası', url: privacyPolicyUrl),
        const SizedBox(height: 18),
        m.Text('Dergah-ı Kadirî  •  v${AppLog.appVersion}',
            style: TextStyle(
                color: AppColors.ink.withValues(alpha: 0.6),
                fontSize: 12.5,
                fontWeight: FontWeight.w600)),
      ],
    );
  }
}

/// Uygulama temasına uyumlu (zümrüt zemin, altın çerçeve) tam genişlik buton.
class _AboutButton extends StatelessWidget {
  const _AboutButton({required this.label, required this.url});
  final String label;
  final String url;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.deep,
      elevation: 2,
      shadowColor: Colors.black45,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () {
          AppLog.i('ayar', 'baglanti acildi: $label');
          openLink(context, url);
        },
        child: Container(
          width: double.infinity,
          height: 54,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.gold, width: 1.5),
          ),
          child: Text(label,
              style: const TextStyle(
                  color: AppColors.ivory,
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.3)),
        ),
      ),
    );
  }
}

/// Ayarların en üstündeki geniş, 2 satırlık "Oyunlarımız ve Uygulamalarımız"
/// butonu (altın gradyan, zümrüt yazı: uygulama temasıyla uyumlu).
class _OurAppsButton extends StatelessWidget {
  const _OurAppsButton();

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      elevation: 3,
      shadowColor: Colors.black38,
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: () {
          AppLog.i('ayar', 'oyunlarimiz ve uygulamalarimiz acildi');
          Navigator.of(context).push(MaterialPageRoute(
            settings: const RouteSettings(name: 'UygulamalarimizSayfasi'),
            builder: (_) => const OurAppsPage(),
          ));
        },
        child: Container(
          width: double.infinity,
          constraints: const BoxConstraints(minHeight: 88),
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            gradient: const LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Color(0xFFE3C26A), AppColors.gold],
            ),
            border: Border.all(color: AppColors.deep, width: 2),
          ),
          child: Row(
            children: [
              const Icon(Icons.apps_rounded, size: 34, color: AppColors.deep),
              const SizedBox(width: 12),
              const Expanded(
                child: Text('Oyunlarımız ve Uygulamalarımız',
                    textAlign: TextAlign.center,
                    maxLines: 2,
                    style: TextStyle(
                        color: AppColors.deep,
                        fontSize: 20,
                        height: 1.2,
                        fontWeight: FontWeight.w800)),
              ),
              const SizedBox(width: 46),
            ],
          ),
        ),
      ),
    );
  }
}
