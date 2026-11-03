/// "Oyunlarımız ve Uygulamalarımız" listesi.
///
/// YENİ UYGULAMA EKLEMEK İÇİN:
///  1) İkonu `assets/images/` klasörüne koyun (alt klasör YOK; pubspec'te
///     `assets/images/` zaten tanımlı). Örn: assets/images/astrofelyx.png
///  2) Aşağıdaki listeye bir satır ekleyin:
///       OurApp(
///         name: 'Astrofelyx: Galaxy Puzzle',
///         icon: 'assets/images/astrofelyx.png',
///         url: 'https://play.google.com/store/apps/details?id=PAKET.ADI',
///       ),
class OurApp {
  const OurApp({required this.name, required this.icon, required this.url});
  final String name;
  final String icon; // assets/images/... yolu
  final String url; // Google Play uygulama sayfası adresi
}

const List<OurApp> ourApps = [
  OurApp(
    name: 'Astrofelyx: Galaxy Puzzle',
    icon: 'assets/images/astrofelyx.png',
    url: 'https://play.google.com/store/apps/details?id=com.astrofelyx.pro',
  ),
  OurApp(
    name: 'Worlds Merge',
    icon: 'assets/images/worlds_merge.png',
    url: 'https://play.google.com/store/apps/details?id=com.sitora.ai',
  ),
];
