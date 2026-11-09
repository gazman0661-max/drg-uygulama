/// 81 il merkezinin yaklaşık koordinatları (enlem, boylam).
/// Kıble hesabında GPS yoksa kullanılan YEDEK konumdur; internet gerekmez.
/// Aladhan'ın verdiği il/ilçe koordinatı Türkiye dışına ya da ilin çok
/// uzağına düşerse (yanlış geocode) bu değerler kullanılır.
const Map<String, List<double>> ilKoordinat = {
  'ADANA': [37.00, 35.32],
  'ADIYAMAN': [37.76, 38.28],
  'AFYONKARAHİSAR': [38.76, 30.54],
  'AKSARAY': [38.37, 34.03],
  'AMASYA': [40.65, 35.83],
  'ANKARA': [39.93, 32.86],
  'ANTALYA': [36.90, 30.69],
  'ARDAHAN': [41.11, 42.70],
  'ARTVİN': [41.18, 41.82],
  'AYDIN': [37.85, 27.84],
  'AĞRI': [39.72, 43.05],
  'BALIKESİR': [39.65, 27.89],
  'BARTIN': [41.64, 32.34],
  'BATMAN': [37.88, 41.13],
  'BAYBURT': [40.26, 40.23],
  'BOLU': [40.73, 31.61],
  'BURDUR': [37.72, 30.29],
  'BURSA': [40.18, 29.06],
  'BİLECİK': [40.14, 29.98],
  'BİNGÖL': [38.88, 40.50],
  'BİTLİS': [38.40, 42.11],
  'DENİZLİ': [37.78, 29.09],
  'DÜZCE': [40.84, 31.16],
  'DİYARBAKIR': [37.91, 40.24],
  'EDİRNE': [41.68, 26.56],
  'ELAZIĞ': [38.67, 39.22],
  'ERZURUM': [39.90, 41.27],
  'ERZİNCAN': [39.75, 39.49],
  'ESKİŞEHİR': [39.78, 30.52],
  'GAZİANTEP': [37.07, 37.38],
  'GÜMÜŞHANE': [40.46, 39.48],
  'GİRESUN': [40.91, 38.39],
  'HAKKARİ': [37.58, 43.74],
  'HATAY': [36.20, 36.16],
  'ISPARTA': [37.76, 30.55],
  'IĞDIR': [39.92, 44.05],
  'KAHRAMANMARAŞ': [37.58, 36.94],
  'KARABÜK': [41.20, 32.63],
  'KARAMAN': [37.18, 33.22],
  'KARS': [40.60, 43.10],
  'KASTAMONU': [41.38, 33.78],
  'KAYSERİ': [38.72, 35.49],
  'KIRIKKALE': [39.85, 33.52],
  'KIRKLARELİ': [41.73, 27.22],
  'KIRŞEHİR': [39.15, 34.17],
  'KOCAELİ': [40.77, 29.92],
  'KONYA': [37.87, 32.48],
  'KÜTAHYA': [39.42, 29.98],
  'KİLİS': [36.72, 37.12],
  'MALATYA': [38.35, 38.31],
  'MANİSA': [38.61, 27.43],
  'MARDİN': [37.31, 40.74],
  'MERSİN': [36.80, 34.64],
  'MUĞLA': [37.22, 28.36],
  'MUŞ': [38.74, 41.49],
  'NEVŞEHİR': [38.62, 34.71],
  'NİĞDE': [37.97, 34.68],
  'ORDU': [40.98, 37.88],
  'OSMANİYE': [37.07, 36.25],
  'RİZE': [41.02, 40.52],
  'SAKARYA': [40.69, 30.44],
  'SAMSUN': [41.29, 36.33],
  'SİNOP': [42.03, 35.15],
  'SİVAS': [39.75, 37.02],
  'SİİRT': [37.93, 41.94],
  'TEKİRDAĞ': [40.98, 27.51],
  'TOKAT': [40.31, 36.55],
  'TRABZON': [41.00, 39.72],
  'TUNCELİ': [39.11, 39.55],
  'UŞAK': [38.68, 29.41],
  'VAN': [38.49, 43.38],
  'YALOVA': [40.65, 29.27],
  'YOZGAT': [39.82, 34.81],
  'ZONGULDAK': [41.46, 31.80],
  'ÇANAKKALE': [40.15, 26.41],
  'ÇANKIRI': [40.60, 33.62],
  'ÇORUM': [40.55, 34.95],
  'İSTANBUL': [41.01, 28.98],
  'İZMİR': [38.42, 27.14],
  'ŞANLIURFA': [37.16, 38.79],
  'ŞIRNAK': [37.52, 42.46],
};

/// Kıble için kullanılacak koordinatı seçer.
/// [lat]/[lng]: Aladhan'dan gelen (boş olabilir) il/ilçe koordinatı.
/// Gelen değer makul değilse (boş, Türkiye dışı, ilin çok uzağı) ilin
/// merkez koordinatı döndürülür. Hiçbiri yoksa null.
({double lat, double lng})? kibleYedekKonum(
    String il, double? lat, double? lng) {
  final merkez = ilKoordinat[il];
  if (lat != null && lng != null) {
    final turkiyedeMi = lat >= 35.5 && lat <= 42.5 && lng >= 25.5 && lng <= 45.0;
    final ilYakinMi = merkez == null ||
        ((lat - merkez[0]).abs() <= 3.0 && (lng - merkez[1]).abs() <= 4.0);
    if (turkiyedeMi && ilYakinMi) return (lat: lat, lng: lng);
  }
  if (merkez != null) return (lat: merkez[0], lng: merkez[1]);
  return null;
}
