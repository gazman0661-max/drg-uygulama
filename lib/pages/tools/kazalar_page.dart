import 'package:flutter/material.dart' hide Text;
import '../../l10n/app_text.dart';
import '../../l10n/l10n.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../theme/app_theme.dart';

/// Kaza namazı ve kaza orucu takip sayacı. Rakamlar telefonda saklanır.
class KazalarPage extends StatefulWidget {
  const KazalarPage({super.key});

  @override
  State<KazalarPage> createState() => _KazalarPageState();
}

class _KazalarPageState extends State<KazalarPage> {
  static const _items = [
    'Sabah', 'Öğle', 'İkindi', 'Akşam', 'Yatsı', 'Vitir', 'Oruç (gün)'
  ];
  SharedPreferences? _prefs;
  final List<int> _counts = List.filled(_items.length, 0);

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
      for (var i = 0; i < _items.length; i++) {
        _counts[i] = p.getInt('dergah_kaza_$i') ?? 0;
      }
    });
  }

  void _set(int i, int v) {
    final nv = v < 0 ? 0 : v;
    setState(() => _counts[i] = nv);
    _prefs?.setInt('dergah_kaza_$i', nv);
  }

  Future<void> _edit(int i) async {
    final ctrl = TextEditingController(text: '${_counts[i]}');
    final result = await showDialog<int>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('${_items[i]} kazası: toplam borç'),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          keyboardType: TextInputType.number,
          decoration: InputDecoration(hintText: tr('Örn. 120')),
          onSubmitted: (v) => Navigator.pop(ctx, int.tryParse(v)),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Vazgeç')),
          TextButton(
              onPressed: () => Navigator.pop(ctx, int.tryParse(ctrl.text)),
              child: const Text('Kaydet')),
        ],
      ),
    );
    if (result != null) _set(i, result);
  }

  @override
  Widget build(BuildContext context) {
    final total = _counts.take(6).fold<int>(0, (a, b) => a + b);
    return Scaffold(
      backgroundColor: AppColors.paper,
      appBar: AppBar(title: const Text('Kazalar')),
      body: ListView(
        padding: const EdgeInsets.all(18),
        children: [
          const Text(
            'Kılmanız gereken kaza sayısını yazın. Her kıldığınızda "−" '
            'ile bir azaltın. Sayıya dokunarak doğrudan değer girebilirsiniz.',
            style: TextStyle(fontSize: 12.5, color: AppColors.ink),
          ),
          const SizedBox(height: 14),
          for (var i = 0; i < _items.length; i++) ...[
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                color: AppColors.ivory,
                borderRadius: BorderRadius.circular(AppRadius.card),
                border: Border.all(color: AppColors.goldSoft),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Text(_items[i],
                        style: const TextStyle(
                            fontFamily: 'Amiri',
                            fontSize: 18,
                            color: AppColors.ink)),
                  ),
                  IconButton(
                    icon: const Icon(Icons.remove_circle_outline),
                    onPressed:
                        _counts[i] > 0 ? () => _set(i, _counts[i] - 1) : null,
                  ),
                  InkWell(
                    onTap: () => _edit(i),
                    borderRadius: BorderRadius.circular(8),
                    child: Container(
                      constraints: const BoxConstraints(minWidth: 56),
                      padding: const EdgeInsets.symmetric(vertical: 6),
                      alignment: Alignment.center,
                      child: Text('${_counts[i]}',
                          style: const TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.w700,
                              color: AppColors.ink)),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.add_circle_outline),
                    onPressed: () => _set(i, _counts[i] + 1),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 10),
            if (i == 5) const SizedBox(height: 6),
          ],
          const SizedBox(height: 6),
          Center(
            child: Text('Toplam kaza namazı: $total',
                style: const TextStyle(
                    color: AppColors.danger, fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
  }
}
