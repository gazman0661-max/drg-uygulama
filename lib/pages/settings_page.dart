import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../config/links.dart';
import '../data/il_ilce_data.dart';
import '../state/app_state.dart';
import '../theme/app_theme.dart';
import '../utils/turkish.dart';

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
          // 1) Bildirim aç/kapat
          _Card(
            title: 'Bildirimler',
            subtitle: 'Ezan vakti ve vakit hatırlatma bildirimleri.',
            child: SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(state.notificationsEnabled ? 'Açık' : 'Kapalı',
                  style: const TextStyle(color: AppColors.ink)),
              value: state.notificationsEnabled,
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

          // 2) İl / ilçe
          const _LocationCard(),
          const SizedBox(height: 14),

          // 3) Sesli / sessiz
          _Card(
            title: 'Bildirim Sesi',
            subtitle: 'Namaz vakti girdiğinde ezan sesiyle mi, sessiz mi '
                'haber verilsin?',
            child: SizedBox(
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
                onSelectionChanged: state.notificationsEnabled
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

          // Gizlilik / Kullanım şartları
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _LinkButton(label: 'Gizlilik Politikası', url: privacyPolicyUrl),
              Container(
                  width: 1,
                  height: 18,
                  margin: const EdgeInsets.symmetric(horizontal: 8),
                  color: AppColors.goldSoft),
              _LinkButton(label: 'Kullanım Şartları', url: termsOfUseUrl),
            ],
          ),
          const SizedBox(height: 12),
        ],
      ),
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

class _LinkButton extends StatelessWidget {
  const _LinkButton({required this.label, required this.url});
  final String label;
  final String url;

  Future<void> _open(BuildContext context) async {
    if (url.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Bağlantı yakında eklenecek.')));
      return;
    }
    // Uygulama içinde (Chrome Custom Tabs) açılır; desteklenmezse tarayıcıya düşer.
    final uri = Uri.parse(url);
    var ok = false;
    try {
      ok = await launchUrl(uri, mode: LaunchMode.inAppBrowserView);
    } catch (_) {
      ok = false;
    }
    if (!ok) {
      ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
    if (!ok && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Bağlantı açılamadı.')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return TextButton(
      onPressed: () => _open(context),
      child: Text(label,
          style: const TextStyle(
              color: AppColors.ink,
              fontSize: 13,
              decoration: TextDecoration.underline)),
    );
  }
}
