import 'dart:math' as math;

/// Türkçe'ye duyarlı küçük harfe çevirme (I → ı, İ → i).
/// Dart'ın toLowerCase() fonksiyonu locale bilmez: "DIYARBAKIR" → "diyarbakir"
/// ve "İ" → "i̇" (birleşik nokta) üretir.
String trLower(String s) =>
    s.replaceAll('I', 'ı').replaceAll('İ', 'i').toLowerCase();

String _trUpperChar(String c) {
  if (c == 'i') return 'İ';
  if (c == 'ı') return 'I';
  return c.toUpperCase();
}

/// "AFYONKARAHİSAR" → "Afyonkarahisar", "DİYARBAKIR" → "Diyarbakır",
/// "ŞIRNAK" → "Şırnak". Boşlukla ayrılmış her kelimenin ilk harfi büyük olur.
String trTitle(String s) {
  if (s.isEmpty) return s;
  return s.split(' ').map((w) {
    if (w.isEmpty) return w;
    final lower = trLower(w);
    return _trUpperChar(lower[0]) + lower.substring(1);
  }).join(' ');
}

const String _alfabe = 'abcçdefgğhıijklmnoöpqrsştuüvwxyz';

/// Türkçe alfabe sırasına göre karşılaştırma (… C, Ç, D … G, Ğ, H, I, İ …
/// O, Ö, P … S, Ş, T, U, Ü …). list.sort(trCompare) şeklinde kullanılır.
int trCompare(String a, String b) {
  final x = trLower(a);
  final y = trLower(b);
  final n = math.min(x.length, y.length);
  for (var i = 0; i < n; i++) {
    final ia = _alfabe.indexOf(x[i]);
    final ib = _alfabe.indexOf(y[i]);
    final ca = ia < 0 ? 1000 + x.codeUnitAt(i) : ia;
    final cb = ib < 0 ? 1000 + y.codeUnitAt(i) : ib;
    if (ca != cb) return ca.compareTo(cb);
  }
  return x.length.compareTo(y.length);
}
