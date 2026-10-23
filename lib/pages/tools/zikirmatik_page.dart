import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../theme/app_theme.dart';

/// Zikirmatik: ekrana dokundukça sayar, hedefe ulaşınca güçlü titreşim verir.
/// Sayaç ve hedef kapanınca da saklanır.
class ZikirmatikPage extends StatefulWidget {
  const ZikirmatikPage({super.key});

  @override
  State<ZikirmatikPage> createState() => _ZikirmatikPageState();
}

class _ZikirmatikPageState extends State<ZikirmatikPage> {
  static const _kCount = 'dergah_zikir_sayac';
  static const _kTarget = 'dergah_zikir_hedef';
  static const _kHistory = 'dergah_zikir_gecmis';
  static const _targets = [33, 99, 100, 500, 1000, 0]; // 0 = hedefsiz

  SharedPreferences? _prefs;
  int _count = 0;
  int _target = 33;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final p = await SharedPreferences.getInstance();
    if (!mounted) return;
    setState(() {
      _prefs = p;
      _count = p.getInt(_kCount) ?? 0;
      _target = p.getInt(_kTarget) ?? 33;
    });
  }

  void _tap() {
    setState(() => _count++);
    _prefs?.setInt(_kCount, _count);
    if (_target > 0 && _count % _target == 0) {
      HapticFeedback.heavyImpact();
    } else {
      HapticFeedback.selectionClick();
    }
  }

  void _undo() {
    if (_count == 0) return;
    setState(() => _count--);
    _prefs?.setInt(_kCount, _count);
  }

  Future<void> _reset() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Sayaç sıfırlansın mı?'),
        content: const Text('Şu anki sayı Zikir Geçmişi\'ne kaydedilir.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Vazgeç')),
          TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Sıfırla')),
        ],
      ),
    );
    if (ok == true) {
      await _saveHistory();
      setState(() => _count = 0);
      _prefs?.setInt(_kCount, 0);
    }
  }

  /// Sıfırlamadan önce sayıyı geçmişe yazar ("zaman|sayı|hedef").
  Future<void> _saveHistory() async {
    final p = _prefs;
    if (p == null || _count <= 0) return;
    final list = p.getStringList(_kHistory) ?? <String>[];
    list.insert(0, '${DateTime.now().toIso8601String()}|$_count|$_target');
    if (list.length > 200) list.removeRange(200, list.length);
    await p.setStringList(_kHistory, list);
  }

  void _setTarget(int t) {
    setState(() => _target = t);
    _prefs?.setInt(_kTarget, t);
  }

  @override
  Widget build(BuildContext context) {
    final progress =
        _target > 0 ? (_count % _target) / _target : 0.0;
    final rounds = _target > 0 ? _count ~/ _target : 0;

    return Scaffold(
      backgroundColor: AppColors.paper,
      appBar: AppBar(
        title: const Text('Zikirmatik'),
        actions: [
          IconButton(
            tooltip: 'Zikir geçmişi',
            icon: const Icon(Icons.history),
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const ZikirHistoryPage()),
            ),
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            const SizedBox(height: 28),
            Expanded(
              child: Center(
                child: GestureDetector(
                  onTap: _tap,
                  child: SizedBox(
                    width: 270,
                    height: 270,
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        SizedBox(
                          width: 270,
                          height: 270,
                          child: CircularProgressIndicator(
                            value: _target > 0 ? progress : 1,
                            strokeWidth: 9,
                            color: AppColors.gold,
                            backgroundColor: AppColors.goldSoft,
                          ),
                        ),
                        Container(
                          width: 236,
                          height: 236,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: AppColors.deep,
                            boxShadow: const [
                              BoxShadow(
                                  color: Color(0x330D2B27),
                                  blurRadius: 18,
                                  offset: Offset(0, 8)),
                            ],
                          ),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text('$_count',
                                  style: const TextStyle(
                                      color: AppColors.ivory,
                                      fontSize: 64,
                                      fontWeight: FontWeight.w700)),
                              const SizedBox(height: 4),
                              Text(
                                  _target > 0
                                      ? 'Hedef $_target • Tur $rounds'
                                      : 'Serbest sayım',
                                  style: const TextStyle(
                                      color: AppColors.goldSoft,
                                      fontSize: 14)),
                              const SizedBox(height: 6),
                              const Text('dokunun',
                                  style: TextStyle(
                                      color: AppColors.gold, fontSize: 12)),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            Wrap(
              spacing: 8,
              runSpacing: 6,
              alignment: WrapAlignment.center,
              children: [
                for (final t in _targets)
                  ChoiceChip(
                    label: Text(t == 0 ? 'Serbest' : '$t'),
                    selected: _target == t,
                    selectedColor: AppColors.gold,
                    backgroundColor: AppColors.ivory,
                    side: const BorderSide(color: AppColors.goldSoft),
                    labelStyle: TextStyle(
                        color: _target == t ? AppColors.deep : AppColors.ink),
                    onSelected: (_) => _setTarget(t),
                  ),
              ],
            ),
            Padding(
              padding: const EdgeInsets.all(18),
              child: Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _count > 0 ? _undo : null,
                      icon: const Icon(Icons.undo),
                      label: const Text('Geri al'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _count > 0 ? _reset : null,
                      icon: const Icon(Icons.restart_alt),
                      label: const Text('Sıfırla'),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}


/// Zikir geçmişi: sıfırlanan sayaçların tarihli listesi.
class ZikirHistoryPage extends StatefulWidget {
  const ZikirHistoryPage({super.key});

  @override
  State<ZikirHistoryPage> createState() => _ZikirHistoryPageState();
}

class _ZikirHistoryPageState extends State<ZikirHistoryPage> {
  static const _kHistory = 'dergah_zikir_gecmis';
  SharedPreferences? _prefs;
  List<String> _items = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final p = await SharedPreferences.getInstance();
    if (!mounted) return;
    setState(() {
      _prefs = p;
      _items = p.getStringList(_kHistory) ?? <String>[];
    });
  }

  Future<void> _clear() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Geçmiş silinsin mi?'),
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
      await _prefs?.remove(_kHistory);
      if (mounted) setState(() => _items = []);
    }
  }

  String _fmt(DateTime d) {
    String two(int v) => v.toString().padLeft(2, '0');
    return '${two(d.day)}.${two(d.month)}.${d.year}  ${two(d.hour)}:${two(d.minute)}';
  }

  @override
  Widget build(BuildContext context) {
    final total = _items.fold<int>(0, (a, e) {
      final p = e.split('|');
      return a + (p.length > 1 ? int.tryParse(p[1]) ?? 0 : 0);
    });
    return Scaffold(
      backgroundColor: AppColors.paper,
      appBar: AppBar(
        title: const Text('Zikir Geçmişi'),
        actions: [
          if (_items.isNotEmpty)
            IconButton(
              tooltip: 'Geçmişi sil',
              icon: const Icon(Icons.delete_outline),
              onPressed: _clear,
            ),
        ],
      ),
      body: _items.isEmpty
          ? const Center(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: Text(
                  'Henüz kayıt yok. Zikirmatik\'te "Sıfırla"ya bastığınızda '
                  'sayı buraya kaydedilir.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: AppColors.ink),
                ),
              ),
            )
          : ListView(
              padding: const EdgeInsets.all(18),
              children: [
                Center(
                  child: Text('Toplam: $total',
                      style: const TextStyle(
                          fontFamily: 'Amiri',
                          fontSize: 20,
                          color: AppColors.ink)),
                ),
                const SizedBox(height: 12),
                for (final e in _items)
                  Builder(builder: (context) {
                    final p = e.split('|');
                    final d = DateTime.tryParse(p[0]) ?? DateTime.now();
                    final n = p.length > 1 ? p[1] : '0';
                    final t = p.length > 2 ? int.tryParse(p[2]) ?? 0 : 0;
                    return Container(
                      margin: const EdgeInsets.only(bottom: 8),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 12),
                      decoration: BoxDecoration(
                        color: AppColors.ivory,
                        borderRadius: BorderRadius.circular(AppRadius.card),
                        border: Border.all(color: AppColors.goldSoft),
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(_fmt(d),
                                style: const TextStyle(color: AppColors.ink)),
                          ),
                          Text(
                              t > 0 ? '$n  (hedef $t)' : n,
                              style: const TextStyle(
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.ink)),
                        ],
                      ),
                    );
                  }),
              ],
            ),
    );
  }
}
