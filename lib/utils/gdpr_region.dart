import 'dart:ui' as ui;

/// AB / AEA / Birleşik Krallık / İsviçre bölgeleri (GDPR açık onayı gerekir).
const Set<String> _gdprRegions = {
  // AB üyeleri
  'AT', 'BE', 'BG', 'HR', 'CY', 'CZ', 'DK', 'EE', 'FI', 'FR', 'DE', 'GR', 'HU',
  'IE', 'IT', 'LV', 'LT', 'LU', 'MT', 'NL', 'PL', 'PT', 'RO', 'SK', 'SI', 'ES',
  'SE',
  // AEA + Birleşik Krallık + İsviçre
  'IS', 'LI', 'NO', 'GB', 'UK', 'CH',
};

/// Cihaz bölgesi AB/AEA/UK/İsviçre ise (ya da bölge bilinmiyorsa, temkinli
/// olarak) GDPR açık onay kutusu gösterilir ve LevelPlay'e GDPR bayrağı
/// gönderilir. Türkiye ve diğer bölgelerde bu kutu/bayrak kullanılmaz.
bool get gdprApplies {
  final cc = ui.PlatformDispatcher.instance.locale.countryCode;
  if (cc == null || cc.isEmpty) return true;
  return _gdprRegions.contains(cc.toUpperCase());
}
