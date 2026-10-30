import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';

import '../services/log_service.dart';
import '../theme/app_theme.dart';

/// Gizli log ekranı. Ayarlar > "Hakkında" başlığına 7 kez dokununca açılır.
/// (Bilerek çeviri/l10n kullanmaz: yalnızca geliştirici içindir.)
class LogPage extends StatefulWidget {
  const LogPage({super.key});

  @override
  State<LogPage> createState() => _LogPageState();
}

class _LogPageState extends State<LogPage> {
  int _tab = 0; // 0 bu oturum, 1 hatalar, 2 önceki
  final _scroll = ScrollController();
  bool _stick = true;
  Timer? _refreshTimer;

  /// Ekranda yalnızca SON satırlar gösterilir (binlerce satırlık tek metin donar).
  /// Kopyala / Paylaş, açık sekmenin tamamını (sınır dahilinde) verir.
  static const int _showLines = 500;

  @override
  void initState() {
    super.initState();
    AppLog.viewerOpen = true;
    AppLog.changes.addListener(_onChange);
  }

  @override
  void dispose() {
    AppLog.viewerOpen = false;
    _refreshTimer?.cancel();
    AppLog.changes.removeListener(_onChange);
    _scroll.dispose();
    super.dispose();
  }

  // Her log satırında yeniden çizmek ekranı donduruyordu: en fazla 1 sn'de bir yenile.
  void _onChange() {
    if (!mounted || _refreshTimer != null) return;
    _refreshTimer = Timer(const Duration(seconds: 1), () {
      _refreshTimer = null;
      if (mounted) setState(() {});
    });
  }

  String get _text {
    switch (_tab) {
      case 1:
        return AppLog.currentText(errorsOnly: true);
      case 2:
        return AppLog.previousText();
      default:
        return AppLog.currentText();
    }
  }

  String _tail(String full) {
    final lines = full.split('\n');
    if (lines.length <= _showLines) return full;
    final skipped = lines.length - _showLines;
    return '... ($skipped eski satır ekranda gizli; KOPYALA/PAYLAŞ tamamını verir)\n'
        '${lines.sublist(lines.length - _showLines).join('\n')}';
  }

  /// Uzun metinde AÇILIŞ satırları (boot teşhisi) kaybolmasın: baştan 20.000 + sondan kalan.
  String _limit(String t, int max) {
    if (t.length <= max) return t;
    const head = 20000;
    final tail = max - head;
    return '${t.substring(0, head)}\n... (${t.length - max} karakter ortadan kesildi) ...\n'
        '${t.substring(t.length - tail)}';
  }

  void _toast(String m) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(
          content: Text(m), duration: const Duration(seconds: 2)));
  }

  Future<void> _copy() async {
    // Panoya ~1 MB'tan büyük veri gitmez (TransactionTooLargeException).
    final t = _limit(_text, 150000);
    await Clipboard.setData(ClipboardData(text: t));
    _toast('Kopyalandı (${t.length} karakter)');
  }

  Future<void> _share() async {
    final t = _limit(_text, 60000);
    try {
      await SharePlus.instance.share(ShareParams(
        text: t,
        subject: 'Dergah log ${DateTime.now().toIso8601String()}',
      ));
    } catch (e) {
      _toast('Paylaşılamadı: $e');
    }
  }

  Future<void> _clear() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Kayıtlar silinsin mi?'),
        content: const Text('Bu oturum, hatalar ve önceki oturum kayıtları silinir.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Vazgeç')),
          TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Sil')),
        ],
      ),
    );
    if (ok == true) {
      await AppLog.clearAll();
      if (mounted) setState(() {});
    }
  }

  @override
  Widget build(BuildContext context) {
    final text = _text;
    if (_stick && _tab != 2) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_scroll.hasClients) _scroll.jumpTo(_scroll.position.maxScrollExtent);
      });
    }
    return Scaffold(
      backgroundColor: AppColors.paper,
      appBar: AppBar(title: const Text('Hata Kayıtları')),
      body: Padding(
        padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
        child: Column(
          children: [
            Row(
              children: [
                _tabBtn(0, 'Bu oturum'),
                const SizedBox(width: 8),
                _tabBtn(1, 'Hatalar (${AppLog.problemCount})'),
                const SizedBox(width: 8),
                _tabBtn(2, 'Önceki'),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                _actBtn(Icons.copy, 'Kopyala', _copy),
                const SizedBox(width: 8),
                _actBtn(Icons.share, 'Paylaş', _share),
                const SizedBox(width: 8),
                _actBtn(Icons.delete_outline, 'Temizle', _clear),
              ],
            ),
            const SizedBox(height: 12),
            Expanded(
              child: Container(
                width: double.infinity,
                decoration: BoxDecoration(
                  color: const Color(0xFF1E1E1E),
                  borderRadius: BorderRadius.circular(AppRadius.card),
                ),
                padding: const EdgeInsets.all(12),
                child: NotificationListener<UserScrollNotification>(
                  onNotification: (n) {
                    if (_scroll.hasClients) {
                      _stick = _scroll.position.pixels >=
                          _scroll.position.maxScrollExtent - 40;
                    }
                    return false;
                  },
                  child: Scrollbar(
                    controller: _scroll,
                    child: SingleChildScrollView(
                      controller: _scroll,
                      child: SelectableText(
                        _tail(text),
                        style: const TextStyle(
                            color: Color(0xFFDADADA),
                            fontFamily: 'monospace',
                            fontSize: 11.5,
                            height: 1.3),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _tabBtn(int i, String label) {
    final sel = _tab == i;
    return Expanded(
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: () {
          setState(() {
            _tab = i;
            _stick = true;
          });
        },
        child: Container(
          height: 44,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: sel ? AppColors.gold : AppColors.ivory,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
                color: sel ? AppColors.gold : AppColors.goldSoft, width: 1.5),
          ),
          child: Text(label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                  color: sel ? AppColors.deep : AppColors.ink,
                  fontWeight: FontWeight.w700,
                  fontSize: 13)),
        ),
      ),
    );
  }

  Widget _actBtn(IconData icon, String label, VoidCallback onTap) {
    return Expanded(
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: Container(
          height: 46,
          decoration: BoxDecoration(
            color: AppColors.deep,
            borderRadius: BorderRadius.circular(14),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 18, color: AppColors.ivory),
              const SizedBox(width: 6),
              Text(label,
                  style: const TextStyle(
                      color: AppColors.ivory,
                      fontWeight: FontWeight.w600,
                      fontSize: 13)),
            ],
          ),
        ),
      ),
    );
  }
}
