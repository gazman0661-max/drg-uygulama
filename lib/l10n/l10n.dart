import 'dart:ui' show Locale, PlatformDispatcher;

import 'strings_ar.dart';
import 'strings_en.dart';

/// Uygulama dili: cihaz diline göre Türkçe (tr), İngilizce (en) veya Arapça (ar).
/// Desteklenmeyen dillerde İngilizce kullanılır.
///
/// Çeviri yöntemi: uygulamadaki metinler Türkçe yazılmıştır; [tr] bu Türkçe
/// metni anahtar alıp geçerli dildeki karşılığını döndürür. Karşılığı yoksa
/// metin olduğu gibi (Türkçe) kalır. Yeni metin eklerken lib/l10n/strings_*.dart
/// dosyalarına karşılığını eklemeyi unutmayın.
class L {
  static const supported = ['tr', 'en', 'ar'];
  static String lang = 'en';

  /// Kullanıcının Ayarlar'dan seçtiği dil (tr/en/ar). null = cihaz dilini izle.
  static String? override;

  /// Dil seçici listesi: kod → kendi dilindeki ad.
  static const Map<String, String> names = {
    'tr': 'Türkçe',
    'en': 'English',
    'ar': 'العربية',
  };

  static String resolve(String code) => supported.contains(code) ? code : 'en';

  static void initFromPlatform() {
    final o = override;
    lang = (o != null && supported.contains(o))
        ? o
        : resolve(PlatformDispatcher.instance.locale.languageCode);
    _cache.clear();
  }

  static bool get isRtl => lang == 'ar';
  static Locale get locale => Locale(lang);

  static final Map<String, String> _cache = {};
}

class _Pat {
  _Pat(this.re, this.out, this.n, this.lit);
  final RegExp re;
  final String out;
  final int n;
  final int lit;
}

final Map<String, List<_Pat>> _patCache = {};
final RegExp _hasLetter = RegExp(r'[A-Za-zÇĞİÖŞÜçğıöşü]');

List<_Pat> _patterns(String lang) => _patCache.putIfAbsent(lang, () {
      final table = lang == 'ar' ? kAr : kEn;
      final list = <_Pat>[];
      table.forEach((k, v) {
        if (!k.contains('{}')) return;
        final parts = k.split('{}');
        final lit = parts.join().replaceAll(RegExp(r'\s'), '');
        if (lit.length < 2) return; // çok genel kalıpları atla
        final src = parts.map(RegExp.escape).join('(.+?)');
        list.add(_Pat(RegExp('^$src\$', dotAll: true), v, parts.length - 1,
            lit.length));
      });
      list.sort((a, b) => b.lit.compareTo(a.lit));
      return list;
    });

String _fill(String out, Match m, int n) {
  var r = out;
  for (var i = n; i >= 1; i--) {
    r = r.replaceAll('{$i}', tr(m.group(i) ?? ''));
  }
  return r;
}

/// Türkçe metni geçerli dile çevirir (karşılığı yoksa aynen döner).
String tr(String s) {
  if (s.isEmpty || L.lang == 'tr') return s;
  if (!_hasLetter.hasMatch(s)) return s; // saatler, sayılar vb.
  final key = '${L.lang}|$s';
  final cached = L._cache[key];
  if (cached != null) return cached;
  final table = L.lang == 'ar' ? kAr : kEn;
  var res = table[s];
  if (res == null) {
    for (final p in _patterns(L.lang)) {
      final m = p.re.firstMatch(s);
      if (m != null) {
        res = _fill(p.out, m, p.n);
        break;
      }
    }
  }
  res ??= s;
  if (L._cache.length > 3000) L._cache.clear();
  L._cache[key] = res;
  return res;
}

/// Esmâü'l-Hüsnâ anlamı (i: 0 tabanlı sıra).
String esmaMeaning(int i, String turkish) {
  if (L.lang == 'en' && i < kEnEsma.length) return kEnEsma[i];
  if (L.lang == 'ar' && i < kArEsma.length) return kArEsma[i];
  return turkish;
}
