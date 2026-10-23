import 'package:flutter/material.dart';

import '../../theme/app_theme.dart';

/// Zekatmatik: nisap ve zekat miktarını hesaplar. Bilgilendirme amaçlıdır.
/// Nisap: 80,18 gram altın değeri. Zekat oranı: %2,5 (kırkta bir).
class ZekatmatikPage extends StatefulWidget {
  const ZekatmatikPage({super.key});

  @override
  State<ZekatmatikPage> createState() => _ZekatmatikPageState();
}

class _ZekatmatikPageState extends State<ZekatmatikPage> {
  static const double _nisabGram = 80.18;

  final _altinFiyat = TextEditingController();
  final _nakit = TextEditingController();
  final _altinGram = TextEditingController();
  final _ticaret = TextEditingController();
  final _alacak = TextEditingController();
  final _borc = TextEditingController();

  @override
  void dispose() {
    for (final c in [_altinFiyat, _nakit, _altinGram, _ticaret, _alacak, _borc]) {
      c.dispose();
    }
    super.dispose();
  }

  double _v(TextEditingController c) =>
      double.tryParse(c.text.trim().replaceAll('.', '').replaceAll(',', '.')) ??
      0;

  String _fmt(double v) {
    final s = v.toStringAsFixed(2);
    final parts = s.split('.');
    final intPart = parts[0];
    final buf = StringBuffer();
    for (var i = 0; i < intPart.length; i++) {
      if (i > 0 && (intPart.length - i) % 3 == 0) buf.write('.');
      buf.write(intPart[i]);
    }
    return '$buf,${parts[1]} ₺';
  }

  Widget _field(String label, TextEditingController c, {String? hint}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: TextField(
        controller: c,
        keyboardType: const TextInputType.numberWithOptions(decimal: true),
        onChanged: (_) => setState(() {}),
        decoration: InputDecoration(
          labelText: label,
          hintText: hint,
          filled: true,
          fillColor: AppColors.ivory,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: AppColors.goldSoft),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final fiyat = _v(_altinFiyat);
    final toplam =
        _v(_nakit) + _v(_altinGram) * fiyat + _v(_ticaret) + _v(_alacak);
    final net = toplam - _v(_borc);
    final nisab = _nisabGram * fiyat;
    final hesaplanabilir = fiyat > 0;
    final verilir = hesaplanabilir && net >= nisab;
    final zekat = verilir ? net * 0.025 : 0.0;

    return Scaffold(
      backgroundColor: AppColors.paper,
      appBar: AppBar(title: const Text('Zekatmatik')),
      body: ListView(
        padding: const EdgeInsets.all(18),
        children: [
          const Text(
            'Zekat için malınızın nisap miktarına ulaşmış olması ve üzerinden '
            'bir yıl geçmesi gerekir. Aşağıya birikimlerinizi yazın.',
            style: TextStyle(fontSize: 12.5, color: AppColors.ink),
          ),
          const SizedBox(height: 14),
          _field('Altının gram fiyatı (₺)', _altinFiyat, hint: 'Örn. 3000'),
          _field('Nakit ve banka hesapları (₺)', _nakit),
          _field('Altın (gram)', _altinGram),
          _field('Ticaret malı (₺)', _ticaret),
          _field('Alacaklar (₺)', _alacak),
          _field('Borçlar (₺)', _borc),
          const SizedBox(height: 6),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.deep,
              borderRadius: BorderRadius.circular(AppRadius.card),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _row('Toplam varlık', hesaplanabilir ? _fmt(toplam) : '—'),
                _row('Net (borç düşülmüş)', hesaplanabilir ? _fmt(net) : '—'),
                _row('Nisap (80,18 gr altın)',
                    hesaplanabilir ? _fmt(nisab) : '—'),
                const Divider(color: AppColors.gold, height: 24),
                Text(
                  !hesaplanabilir
                      ? 'Altın gram fiyatını girin.'
                      : verilir
                          ? 'Verilmesi gereken zekat'
                          : 'Nisaba ulaşılmadı: zekat gerekmiyor.',
                  style: const TextStyle(color: AppColors.goldSoft),
                ),
                if (verilir)
                  Text(_fmt(zekat),
                      style: const TextStyle(
                          color: AppColors.ivory,
                          fontSize: 30,
                          fontWeight: FontWeight.w700)),
              ],
            ),
          ),
          const SizedBox(height: 12),
          const Text(
            'Bu hesaplama bilgilendirme amaçlıdır; zekat oranı %2,5 (kırkta '
            'bir) alınmıştır. Güncel nisap ve kesin hüküm için müftülüğe veya '
            'bir dînî bilgi kaynağına danışın.',
            style: TextStyle(fontSize: 11.5, color: AppColors.ink),
          ),
        ],
      ),
    );
  }

  Widget _row(String l, String r) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 3),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(l, style: const TextStyle(color: AppColors.goldSoft)),
            Text(r,
                style: const TextStyle(
                    color: AppColors.ivory, fontWeight: FontWeight.w600)),
          ],
        ),
      );
}
