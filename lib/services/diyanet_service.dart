import 'log_service.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

/// ==========================================================
/// GERÇEK DİYANET VAKİTLERİ (Aladhan API + offline önbellek)
/// -------------------------------------------------------------
/// ÇALIŞMA MANTIĞI (HTML'deki DiyanetVakit modülüyle birebir aynı,
/// kendi astronomik yaklaşık hesabımız YOK - sadece Diyanet verisi):
///
/// 1) İnternet varsa: seçilen il/ilçe için Aladhan API'den
///    (method=13, "Diyanet İşleri Başkanlığı, Turkey") o ayın TÜM
///    günlerini tek seferde çekip SharedPreferences'a kaydeder.
/// 2) İnternet yoksa: daha önce kaydedilmiş önbellekteki veriyi kullanır.
///    Böylece günlük kullanımda internet gerekmez.
/// 3) Hiç önbellek yoksa VE internet de yoksa: vakitler gösterilemez,
///    kullanıcıya en az bir kez internete bağlanması gerektiği bildirilir.
///
/// Not: Aladhan API key gerektirmez, ücretsizdir (aladhan.com).
/// ==========================================================

enum VakitKaynak { diyanetOnline, diyanetCache, yok }

class GunlukVakitler {
  final String sabah;
  final String gunes;
  final String ogle;
  final String ikindi;
  final String aksam;
  final String yatsi;

  const GunlukVakitler({
    required this.sabah,
    required this.gunes,
    required this.ogle,
    required this.ikindi,
    required this.aksam,
    required this.yatsi,
  });

  factory GunlukVakitler.fromJson(Map<String, dynamic> j) => GunlukVakitler(
        sabah: j['Sabah'] ?? '--:--',
        gunes: j['Gunes'] ?? '--:--',
        ogle: j['Ogle'] ?? '--:--',
        ikindi: j['Ikindi'] ?? '--:--',
        aksam: j['Aksam'] ?? '--:--',
        yatsi: j['Yatsi'] ?? '--:--',
      );

  Map<String, dynamic> toJson() => {
        'Sabah': sabah,
        'Gunes': gunes,
        'Ogle': ogle,
        'Ikindi': ikindi,
        'Aksam': aksam,
        'Yatsi': yatsi,
      };

  /// Sıradaki vakit hesabı için sıralı liste (Güneş bir namaz vakti değildir)
  Map<String, String> get siraliVakitler => {
        'Sabah': sabah,
        'Ogle': ogle,
        'Ikindi': ikindi,
        'Aksam': aksam,
        'Yatsi': yatsi,
      };
}

class VakitSonucu {
  final VakitKaynak kaynak;
  final GunlukVakitler? vakitler;

  /// Aladhan'ın il/ilçe için geocode ettiği merkez koordinat (varsa).
  /// GPS izni yokken kıble hesabı için yedek olarak kullanılır.
  final double? lat;
  final double? lng;
  const VakitSonucu(this.kaynak, this.vakitler, {this.lat, this.lng});
}

class DiyanetService {
  static const _prefix = 'dergah_vakit_';

  String _cacheKey(String il, String ilce, int year, int month) =>
      '$_prefix${il}_${ilce}_${year}_${month.toString().padLeft(2, '0')}';

  String _buildAddress(String il, String ilce) {
    // "Merkez" ilçesi coğrafi olarak anlamlı bir arama terimi değildir,
    // bu yüzden bu durumda doğrudan il merkezini kullanıyoruz.
    if (ilce.trim().isEmpty || ilce.toUpperCase() == 'MERKEZ') {
      return '$il, Türkiye';
    }
    return '$ilce, $il, Türkiye';
  }

  /// Bir ay boyunca tüm günlerin vakitlerini Aladhan'dan çekip
  /// SharedPreferences'a yazar. days anahtarları "DD-MM-YYYY" formatındadır.
  Future<Map<String, dynamic>> _fetchAndCacheMonth(
      String il, String ilce, int year, int month) async {
    final address = Uri.encodeComponent(_buildAddress(il, ilce));
    final url = Uri.parse(
        'https://api.aladhan.com/v1/calendarByAddress/$year/$month?address=$address&method=13');

    final sw = Stopwatch()..start();
    AppLog.i('diyanet', 'GET aladhan $year/$month $ilce, $il');
    final res = await http.get(url).timeout(const Duration(seconds: 15));
    AppLog.i('diyanet',
        'yanit ${res.statusCode} ${res.bodyBytes.length}B (${sw.elapsedMilliseconds}ms)');
    if (res.statusCode != 200) {
      throw Exception('Aladhan API yanıt vermedi: ${res.statusCode}');
    }
    final json = jsonDecode(res.body);
    if (json['code'] != 200 || json['data'] is! List) {
      throw Exception('Beklenmeyen API yanıtı');
    }

    String clean(String v) => v.split(' ').first; // "05:37 (+03)" -> "05:37"

    final days = <String, dynamic>{};
    for (final day in (json['data'] as List)) {
      final dateStr = day['date']['gregorian']['date']; // "DD-MM-YYYY"
      final t = day['timings'];
      days[dateStr] = GunlukVakitler(
        sabah: clean(t['Fajr']),
        gunes: clean(t['Sunrise']),
        ogle: clean(t['Dhuhr']),
        ikindi: clean(t['Asr']),
        aksam: clean(t['Maghrib']),
        yatsi: clean(t['Isha']),
      ).toJson();
    }

    double? lat;
    double? lng;
    try {
      final meta = (json['data'] as List).first['meta'];
      lat = double.tryParse('${meta['latitude']}');
      lng = double.tryParse('${meta['longitude']}');
    } catch (lerr) { AppLog.w('diyanet', 'yutulan hata: $lerr'); }

    final payload = {
      'lat': lat,
      'lng': lng,
      'il': il,
      'ilce': ilce,
      'year': year,
      'month': month,
      'days': days,
      'savedAt': DateTime.now().toIso8601String(),
    };

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_cacheKey(il, ilce, year, month), jsonEncode(payload));
    return payload;
  }

  Future<Map<String, dynamic>?> _getCachedMonth(
      String il, String ilce, int year, int month) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_cacheKey(il, ilce, year, month));
    if (raw == null) return null;
    try {
      return jsonDecode(raw) as Map<String, dynamic>;
    } catch (lerr) {
      AppLog.w('diyanet', 'yutulan hata: $lerr');
      return null;
    }
  }

  double? _num(dynamic v) => v is num ? v.toDouble() : null;

  /// [start] gününden itibaren [count] günün vakitlerini SADECE önbellekten
  /// okur (ağ isteği yapmaz). Önbellekte olmayan günler listeye girmez.
  /// Anahtarlar gün başlangıcı (00:00) olan DateTime'dır.
  Future<Map<DateTime, GunlukVakitler>> cachedDays(
      String il, String ilce, DateTime start, int count) async {
    final out = <DateTime, GunlukVakitler>{};
    final months = <String, Map<String, dynamic>?>{};
    for (var i = 0; i < count; i++) {
      final d = DateTime(start.year, start.month, start.day + i);
      final mk = '${d.year}-${d.month}';
      if (!months.containsKey(mk)) {
        months[mk] = await _getCachedMonth(il, ilce, d.year, d.month);
      }
      final days = months[mk]?['days'];
      if (days is! Map) continue;
      final key =
          '${d.day.toString().padLeft(2, '0')}-${d.month.toString().padLeft(2, '0')}-${d.year}';
      final v = days[key];
      if (v is Map) {
        out[d] = GunlukVakitler.fromJson(Map<String, dynamic>.from(v));
      }
    }
    return out;
  }

  /// Belirli bir gün için 5 vakti döndürür.
  Future<VakitSonucu> getTimesForDate(String il, String ilce, DateTime date,
      {required bool online}) async {
    final year = date.year;
    final month = date.month;
    final dateStr =
        '${date.day.toString().padLeft(2, '0')}-${month.toString().padLeft(2, '0')}-$year';

    // 1) Önce bu ayın önbelleğine bak
    var cached = await _getCachedMonth(il, ilce, year, month);

    // 2) İnternet varsa (veya önbellek yoksa) API'den güncellemeyi dene
    if (online || cached == null) {
      try {
        cached = await _fetchAndCacheMonth(il, ilce, year, month);
        final days = cached['days'] as Map<String, dynamic>;
        if (days.containsKey(dateStr)) {
          return VakitSonucu(VakitKaynak.diyanetOnline,
              GunlukVakitler.fromJson(days[dateStr]),
              lat: _num(cached['lat']), lng: _num(cached['lng']));
        }
      } catch (lerr) {
      AppLog.w('diyanet', 'yutulan hata: $lerr');
        // Aladhan API'ye ulaşılamadı, önbelleğe düşülüyor
      }
    }

    // 3) Bu ayın önbelleği varsa oradan oku (offline senaryo)
    if (cached != null) {
      final days = cached['days'] as Map<String, dynamic>;
      if (days.containsKey(dateStr)) {
        return VakitSonucu(
            VakitKaynak.diyanetCache, GunlukVakitler.fromJson(days[dateStr]),
            lat: _num(cached['lat']), lng: _num(cached['lng']));
      }
    }

    // 4) Bu il/ilçe için hiç önbellek yoksa ve internet de yoksa:
    //    Diyanet dışında bir kaynağa (yaklaşık hesap) DÜŞMÜYORUZ.
    return const VakitSonucu(VakitKaynak.yok, null);
  }

  /// Sonraki 3 ayı da arka planda sessizce önbelleğe alır (ay sonu geçişinde
  /// ve uygulama uzun süre açılmasa bile bildirimlerin devam etmesi için).
  /// Önbellekte zaten olan aylar tekrar indirilmez.
  Future<void> prefetchNextMonthInBackground(
      String il, String ilce, DateTime date, {required bool online}) async {
    if (!online) return;
    for (var i = 1; i <= 3; i++) {
      final m = DateTime(date.year, date.month + i, 1);
      try {
        final cached = await _getCachedMonth(il, ilce, m.year, m.month);
        if (cached != null) continue;
        await _fetchAndCacheMonth(il, ilce, m.year, m.month);
      } catch (lerr) {
      AppLog.w('diyanet', 'yutulan hata: $lerr');
        // sessizce yut, kritik değil
      }
    }
  }
}
