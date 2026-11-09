/// Aladhan hesaplama yöntemleri (id -> Türkçe ad). Sıralama listedeki sıradır.
/// Türkiye il/ilçe modunda her zaman 13 (Diyanet) kullanılır; bu liste
/// yalnızca GPS / şehir araması modunda geçerlidir.
const Map<int, String> vakitYontemleri = {
  3: 'Müslüman Dünya Birliği (MWL)',
  13: 'Diyanet (Türkiye)',
  2: 'ISNA (Kuzey Amerika)',
  4: 'Ümmülkura (Suudi Arabistan)',
  5: 'Mısır Genel Otoritesi',
  1: 'Karaçi İslami İlimler Üniversitesi',
  8: 'Körfez Bölgesi',
  9: 'Kuveyt',
  10: 'Katar',
  11: 'Singapur (MUIS)',
  12: 'Fransa (UOIF)',
  14: 'Rusya Müslümanları',
  15: 'Ay Gözlem Komitesi (Moonsighting)',
  16: 'Dubai',
  17: 'Malezya (JAKIM)',
  18: 'Tunus',
  19: 'Cezayir',
  20: 'Endonezya (KEMENAG)',
  21: 'Fas',
};

/// Yüksek enlem kuralı (0 = kapalı). Kuzey Avrupa gibi yerlerde yazın
/// sabah/yatsı vakti oluşmadığında kullanılır.
const Map<int, String> enlemKurallari = {
  0: 'Kapalı (otomatik)',
  1: 'Gecenin ortası',
  2: 'Gecenin yedide biri',
  3: 'Açı bazlı',
};
