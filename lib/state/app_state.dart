import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart'
    show AppLifecycleState, WidgetsBinding, WidgetsBindingObserver;
import 'package:geolocator/geolocator.dart';
import 'package:hijri/hijri_calendar.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../services/diyanet_service.dart';
import '../services/notification_service.dart';
import '../services/qibla_service.dart';
import '../services/widget_service.dart';
import '../utils/turkish.dart';

/// Sıralı 5 vakit (Güneş bir namaz vakti değildir - orijinal HTML'deki
/// PRAYER_ORDER ile birebir aynı)
/// Hicri ay isimleri (Türkçe, Diyanet yazımı). hijri paketinin longMonthName
/// değeri İngilizce transliterasyon döndürdüğü için kullanılmıyor.
const List<String> _hicriAylar = [
  'Muharrem',
  'Safer',
  'Rebiülevvel',
  'Rebiülahir',
  'Cemaziyelevvel',
  'Cemaziyelahir',
  'Recep',
  'Şaban',
  'Ramazan',
  'Şevval',
  'Zilkade',
  'Zilhicce',
];

const List<String> prayerOrder = ['Sabah', 'Ogle', 'Ikindi', 'Aksam', 'Yatsi'];
const Map<String, String> prayerLabels = {
  'Sabah': 'İmsak',
  'Gunes': 'Güneş',
  'Ogle': 'Öğle',
  'Ikindi': 'İkindi',
  'Aksam': 'Akşam',
  'Yatsi': 'Yatsı',
};

/// Ana sayfadaki vakit şeridinde Güneş de gösterilir (namaz vakti değildir,
/// bu yüzden geri sayım/ezan bildirimi hesaplarında prayerOrder kullanılmaya
/// devam eder, sadece görünüm için Güneş eklenmiştir).
const List<String> stripOrder = ['Sabah', 'Gunes', 'Ogle', 'Ikindi', 'Aksam', 'Yatsi'];

/// Vakit öncesi hatırlatma bildirimi için seçilebilir dakika seçenekleri.
const List<int> reminderOptions = [0, 15, 30, 45];

/// intl paketinin 'tr_TR' locale verisini yüklemesini beklemeden
/// (initializeDateFormatting gerektirmeden) Miladi tarihi Türkçe
/// göstermek için sabit ay isimleri.
const List<String> _turkceAylar = [
  'Ocak', 'Şubat', 'Mart', 'Nisan', 'Mayıs', 'Haziran',
  'Temmuz', 'Ağustos', 'Eylül', 'Ekim', 'Kasım', 'Aralık',
];

class AppState extends ChangeNotifier with WidgetsBindingObserver {
  final DiyanetService _diyanetService = DiyanetService();
  final NotificationService _notifier = NotificationService();
  final WidgetService _widgetService = WidgetService();
  final _Connectivity _connectivity = _Connectivity();

  String il = 'İSTANBUL';
  String ilce = 'MERKEZ';

  // Kıble konumu: önce GPS, yoksa seçili il/ilçenin merkez koordinatı.
  // (Eskiden sessizce İstanbul koordinatına düşülüyordu.)
  double? _gpsLat;
  double? _gpsLng;
  double? _cityLat;
  double? _cityLng;
  bool _gpsTried = false;
  bool qiblaKnown = false;

  // Gün değişimi / Yatsı sonrası geri sayım için
  String? _timesDateTag; // `times` hangi güne ait
  GunlukVakitler? _tomorrowTimes;
  String? _tomorrowDateTag;
  bool _loadingTomorrow = false;
  bool _refreshingDay = false;
  DateTime _tomorrowRetryAt = DateTime.fromMillisecondsSinceEpoch(0);
  DateTime _reloadRetryAt = DateTime.fromMillisecondsSinceEpoch(0);

  GunlukVakitler? times;
  VakitKaynak kaynak = VakitKaynak.yok;
  bool loading = false;
  String locationNote = 'Konum alınıyor…';

  double qiblaDeg = 0;

  String? _nextPrayerKey;
  Duration? _remaining;

  /// Uygulama ilk kez açıldığında (daha önce kaydedilmiş bir il/ilçe yoksa)
  /// true olur; il/ilçe seçim ekranı gösterilip seçim tamamlanınca false olur.
  bool firstLaunchNeedsSelection = false;

  /// Her vakit için (Güneş dahil) kaç dakika önce hatırlatma bildirimi
  /// gönderilsin. 0 = hatırlatma kapalı.
  Map<String, int> reminderMinutes = {
    for (final k in stripOrder) k: 0,
  };

  /// Bildirim çubuğunda kalıcı vakit paneli gösterilsin mi? (kullanıcı seçer)
  bool panelEnabled = false;

  /// Panelde kerahat vakitleri / uyarısı da gösterilsin mi?
  bool panelKerahat = true;

  Timer? _ticker;

  String? get nextPrayerKey => _nextPrayerKey;
  Duration? get remaining => _remaining;

  String get hijriDateText {
    try {
      final h = HijriCalendar.now();
      final ay = _hicriAylar[(h.hMonth - 1).clamp(0, 11)];
      return '${h.hDay} $ay ${h.hYear}';
    } catch (_) {
      return '-- -- ----';
    }
  }

  /// Miladi (Gregorian) takvim - Hicri tarihin yanında ana sayfada gösterilir.
  String get gregorianDateText {
    final now = DateTime.now();
    final ay = _turkceAylar[now.month - 1];
    return '${now.day} $ay ${now.year}';
  }

  String _fmtHHmm(DateTime d) =>
      '${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';

  /// Diyanet İşleri Başkanlığı'na göre namaz kılınması mekruh (kerahat)
  /// olan üç vakit. Diyanet bu aralıkları dakika olarak yayımlamadığından
  /// yaygın kabul gören yaklaşık 45 dakikalık süre kullanılır:
  ///  1) Güneşin doğuşundan itibaren ~45 dk
  ///  2) İstiva (tam gün ortası) - öğle vaktinden ~45 dk öncesi
  ///  3) Güneşin batışından ~45 dk öncesi (ikindi sonrası - akşam vakti girene kadar)
  Map<String, String>? get kerahatVakitleri {
    final t = times;
    if (t == null) return null;
    final now = DateTime.now();
    final gunes = _timeStrToDate(t.gunes, now);
    final ogle = _timeStrToDate(t.ogle, now);
    final aksam = _timeStrToDate(t.aksam, now);
    if (gunes == null || ogle == null || aksam == null) return null;

    const kerahatSuresi = Duration(minutes: 45);
    final gunesDogusu =
        '${_fmtHHmm(gunes)} - ${_fmtHHmm(gunes.add(kerahatSuresi))}';
    final istiva =
        '${_fmtHHmm(ogle.subtract(kerahatSuresi))} - ${_fmtHHmm(ogle)}';
    final gunesBatisi =
        '${_fmtHHmm(aksam.subtract(kerahatSuresi))} - ${_fmtHHmm(aksam)}';

    return {
      'Güneşin Doğuşu': gunesDogusu,
      'İstiva (Tam Öğle)': istiva,
      'Güneşin Batışı': gunesBatisi,
    };
  }

  /// Şu an bir kerahat vakti içindeysek kısa bir uyarı metni döndürür
  /// (ör. "Kerahat Vakti: İstiva"), değilse null. Ana sayfadaki sayacın
  /// yanında gösterilir.
  String? get kerahatUyarisi {
    final t = times;
    if (t == null) return null;
    final now = DateTime.now();
    final gunes = _timeStrToDate(t.gunes, now);
    final ogle = _timeStrToDate(t.ogle, now);
    final aksam = _timeStrToDate(t.aksam, now);
    const kerahatSuresi = Duration(minutes: 45);

    bool icinde(DateTime? baslangic, DateTime? bitis) {
      if (baslangic == null || bitis == null) return false;
      return !now.isBefore(baslangic) && now.isBefore(bitis);
    }

    if (icinde(gunes, gunes?.add(kerahatSuresi))) {
      return 'Kerahat Vakti: Güneşin Doğuşu';
    }
    if (icinde(ogle?.subtract(kerahatSuresi), ogle)) {
      return 'Kerahat Vakti: İstiva (Tam Öğle)';
    }
    if (icinde(aksam?.subtract(kerahatSuresi), aksam)) {
      return 'Kerahat Vakti: Güneşin Batışı';
    }
    return null;
  }

  String get vakitKaynakNote {
    switch (kaynak) {
      case VakitKaynak.diyanetOnline:
        return '✓ ${_toTitle(ilce)}, ${_toTitle(il)} için vakitler güncellendi (Aladhan, Türkiye Diyanet yöntemi).';
      case VakitKaynak.diyanetCache:
        return 'Offline: ${_toTitle(ilce)}, ${_toTitle(il)} için önceden indirilmiş vakitler gösteriliyor (Aladhan, Türkiye Diyanet yöntemi).';
      case VakitKaynak.yok:
        return '⚠️ Bu il/ilçe için hiç internet bağlantısı sağlanamadı. Lütfen bir kez internete bağlanıp "Bu il/ilçe için vakitleri getir" butonuna basın.';
    }
  }

  String _toTitle(String s) => trTitle(s);

  String _dateTag(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  Future<void> init() async {
    WidgetsBinding.instance.addObserver(this);
    await _loadSavedSelection();
    await _loadReminderSettings();
    await _loadPanelSettings();
    try {
      await _notifier.init();
    } catch (e) {
      debugPrint('Bildirim servisi başlatılamadı: $e');
    }
    _requestLocationForQibla();
    renderQiblaText();
    await loadTimesAndRender();
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) => _tick());
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _ticker?.cancel();
    super.dispose();
  }

  /// Uygulama arka plandan dönünce (ör. telefon geceyi uykuda geçirdiyse)
  /// gün değişimini hemen yakala.
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _updateCountdown();
      // Zamanlama ufku (14 gün) her açılışta/gün değişiminde ileri kayar.
      scheduleNotifications();
    }
  }

  Future<void> _loadSavedSelection() async {
    final prefs = await SharedPreferences.getInstance();
    final savedIl = prefs.getString('dergah_secili_il');
    final savedIlce = prefs.getString('dergah_secili_ilce');
    if (savedIl != null) il = savedIl;
    if (savedIlce != null) ilce = savedIlce;
    // Daha önce hiç il/ilçe seçilip kaydedilmemişse, bu ilk açılıştır:
    // kullanıcıya seçim ekranı gösterilecek.
    firstLaunchNeedsSelection = savedIl == null || savedIlce == null;
  }

  /// İlk açılışta gösterilen il/ilçe seçim ekranı onaylandığında çağrılır.
  Future<void> completeFirstLaunchSelection(
      String yeniIl, String yeniIlce) async {
    firstLaunchNeedsSelection = false;
    await setIlIlce(yeniIl, yeniIlce);
    // Bildirimler ancak izin verilirse görünür; ilk kurulumda izni iste.
    unawaited(requestNotificationPermission());
  }

  Future<void> _loadReminderSettings() async {
    final prefs = await SharedPreferences.getInstance();
    for (final k in stripOrder) {
      reminderMinutes[k] = prefs.getInt('dergah_hatirlatma_$k') ?? 0;
    }
  }

  Future<void> _loadPanelSettings() async {
    final prefs = await SharedPreferences.getInstance();
    panelEnabled = prefs.getBool('dergah_panel_acik') ?? false;
    panelKerahat = prefs.getBool('dergah_panel_kerahat') ?? true;
  }

  /// Bildirim çubuğu panelini açar/kapatır. Açarken bildirim izni gerekir;
  /// izin verilmezse panel açılmaz ve false döner.
  Future<bool> setPanelEnabled(bool value) async {
    if (value) {
      final granted = await _notifier.requestPermission();
      if (!granted) {
        panelEnabled = false;
        notifyListeners();
        return false;
      }
    }
    panelEnabled = value;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('dergah_panel_acik', value);
    notifyListeners();
    await scheduleNotifications(force: true);
    return true;
  }

  Future<void> setPanelKerahat(bool value) async {
    panelKerahat = value;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('dergah_panel_kerahat', value);
    notifyListeners();
    await scheduleNotifications(force: true);
  }

  Future<void> setReminderMinutes(String prayerKey, int minutes) async {
    reminderMinutes[prayerKey] = minutes;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('dergah_hatirlatma_$prayerKey', minutes);
    notifyListeners();
    await scheduleNotifications();
  }

  Future<void> setIlIlce(String yeniIl, String yeniIlce) async {
    il = yeniIl;
    ilce = yeniIlce;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('dergah_secili_il', il);
    await prefs.setString('dergah_secili_ilce', ilce);
    await loadTimesAndRender();
  }

  // ---------------- NAMAZ VAKİTLERİ (gerçek Diyanet) ----------------
  Future<void> loadTimesAndRender({bool silent = false}) async {
    if (!silent) {
      loading = true;
      notifyListeners();
    }

    final online = await _connectivity.isOnline();
    final today = DateTime.now();
    final result =
        await _diyanetService.getTimesForDate(il, ilce, today, online: online);

    times = result.vakitler;
    kaynak = result.kaynak;
    _timesDateTag = _dateTag(today);
    _tomorrowTimes = null;
    _tomorrowDateTag = null;
    _cityLat = result.lat;
    _cityLng = result.lng;
    loading = false;
    renderQiblaText();

    unawaited(_scheduleAfterLoad(online, today));

    _updateCountdown();
    notifyListeners();
  }

  // ---------------- GERİ SAYIM ----------------
  void _tick() => _updateCountdown();

  DateTime? _timeStrToDate(String hhmm, DateTime base) {
    if (hhmm == '--:--') return null;
    final parts = hhmm.split(':');
    if (parts.length != 2) return null;
    final h = int.tryParse(parts[0]);
    final m = int.tryParse(parts[1]);
    if (h == null || m == null) return null;
    return DateTime(base.year, base.month, base.day, h, m);
  }

  /// Gün değişiminde (veya ilk yükleme başarısız olduysa) vakitleri sessizce
  /// yeniden yükler.
  Future<void> _refreshNewDay() async {
    if (_refreshingDay) return;
    _refreshingDay = true;
    try {
      await loadTimesAndRender(silent: true);
    } finally {
      _refreshingDay = false;
    }
  }

  /// Yatsı'dan sonra yarının İmsak vaktine geri sayabilmek için yarının
  /// vakitlerini (önce önbellekten) yükler.
  Future<void> _loadTomorrow(DateTime tm) async {
    if (_loadingTomorrow || DateTime.now().isBefore(_tomorrowRetryAt)) return;
    _loadingTomorrow = true;
    final reqIl = il;
    final reqIlce = ilce;
    try {
      final r = await _diyanetService.getTimesForDate(reqIl, reqIlce, tm,
          online: false);
      if (reqIl != il || reqIlce != ilce) return; // arada il/ilçe değişti
      if (r.vakitler != null) {
        _tomorrowTimes = r.vakitler;
        _tomorrowDateTag = _dateTag(tm);
      } else {
        _tomorrowRetryAt = DateTime.now().add(const Duration(minutes: 1));
      }
    } catch (_) {
      _tomorrowRetryAt = DateTime.now().add(const Duration(minutes: 1));
    } finally {
      _loadingTomorrow = false;
    }
  }

  void _updateCountdown() {
    final now = DateTime.now();

    if (times == null) {
      _remaining = null;
      // Vakitler yüklenemediyse (ör. internetsiz ilk açılış) dakikada bir
      // sessizce tekrar dene.
      if (!loading && !_refreshingDay && !now.isBefore(_reloadRetryAt)) {
        _reloadRetryAt = now.add(const Duration(minutes: 1));
        _refreshNewDay();
      }
      return;
    }

    // Gün değiştiyse: hazır yarın vakitlerini kullan, yoksa yeniden yükle.
    final todayTag = _dateTag(now);
    if (_timesDateTag != todayTag) {
      if (_tomorrowTimes != null && _tomorrowDateTag == todayTag) {
        times = _tomorrowTimes;
        _timesDateTag = todayTag;
        _tomorrowTimes = null;
        _tomorrowDateTag = null;
      } else if (!_refreshingDay) {
        _refreshNewDay();
      }
    }
    final stale = _timesDateTag != todayTag; // yeni gün vakitleri henüz yok

    DateTime? next;
    String? nextKey;

    final ordered = times!.siraliVakitler;
    for (final key in prayerOrder) {
      final t = _timeStrToDate(ordered[key]!, now);
      if (t != null && t.isAfter(now)) {
        next = t;
        nextKey = key;
        break;
      }
    }

    // Yatsı geçti: yarının İmsak vaktine geri say.
    if (next == null && !stale) {
      final tm = DateTime(now.year, now.month, now.day + 1);
      if (_tomorrowTimes != null && _tomorrowDateTag == _dateTag(tm)) {
        final sabah = _timeStrToDate(_tomorrowTimes!.sabah, tm);
        if (sabah != null && sabah.isAfter(now)) {
          next = sabah;
          nextKey = 'Sabah';
        }
      } else {
        _loadTomorrow(tm);
      }
    }

    nextKey ??= 'Sabah';
    _nextPrayerKey = nextKey;

    if (next != null) {
      _remaining = next.difference(now);
    } else {
      _remaining = null;
    }

    notifyListeners();
  }

  // ---------------- BİLDİRİMLER ----------------
  // Ezan ve hatırlatmalar işletim sistemine ÖNCEDEN zamanlanır (uygulama
  // kapalıyken de çalışır). Eski "uygulama açıkken saniyede bir kontrol"
  // yöntemi kaldırıldı; aksi halde bildirimler iki kez gelirdi.

  /// Önbellekteki (en çok ~90 gün) vakitleri ve bildirim ayarlarını Android
  /// tarafına iletir. Ezan, hatırlatma, panel ve widget orada zincirleme
  /// alarmla çalışır: yalnızca sıradaki alarm kurulur, çalınca bir sonrakini
  /// kurar. [force] eski çağrılarla uyum için durur.
  Future<void> scheduleNotifications({bool force = false}) async {
    try {
      final days =
          await _diyanetService.cachedDays(il, ilce, DateTime.now(), 90);
      await _notifier.clearLegacyOnce();
      await _widgetService.push(
        place: '${_toTitle(ilce)}, ${_toTitle(il)}',
        days: days,
        reminders: reminderMinutes,
        panel: panelEnabled,
        panelKerahat: panelKerahat,
      );
    } catch (e) {
      debugPrint('scheduleNotifications hatası: $e');
    }
  }

  /// Vakitler yüklenince: önce eldeki önbellekle kur, internet varsa gelecek
  /// ayı da indirip (ay sonu geçişi için) yeniden kur.
  Future<void> _scheduleAfterLoad(bool online, DateTime today) async {
    await scheduleNotifications();
    if (online) {
      await _diyanetService.prefetchNextMonthInBackground(il, ilce, today,
          online: true);
      await scheduleNotifications();
    }
  }

  /// İzin verildiyse true döner (Android 13+ / iOS'ta kullanıcı reddederse false).
  Future<bool> requestNotificationPermission() async {
    final granted = await _notifier.requestPermission();
    if (granted) await scheduleNotifications(force: true);
    return granted;
  }

  // ---------------- KIBLE SAYFASI ----------------
  void renderQiblaText() {
    final la = _gpsLat ?? _cityLat;
    final ln = _gpsLng ?? _cityLng;
    if (la == null || ln == null) {
      qiblaKnown = false;
      qiblaDeg = 0;
      locationNote = _gpsTried
          ? 'Konum alınamadı, kıble hesaplanamıyor. Konum iznini açın veya bir kez internete bağlanıp vakitleri getirin.'
          : 'Konum alınıyor…';
    } else {
      qiblaKnown = true;
      qiblaDeg = QiblaService.qiblaBearing(la, ln);
      locationNote = (_gpsLat == null && _gpsTried)
          ? 'Konum alınamadığı için kıble seçili il/ilçeye (${_toTitle(ilce)}, ${_toTitle(il)}) göre hesaplandı.'
          : '';
    }
    notifyListeners();
  }

  Future<void> _requestLocationForQibla() async {
    try {
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) return;
      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        return;
      }
      final pos = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.low,
        ),
      ).timeout(const Duration(seconds: 8));
      _gpsLat = pos.latitude;
      _gpsLng = pos.longitude;
    } catch (_) {
      // GPS alınamadı: kıble il/ilçe koordinatına düşer (renderQiblaText).
    } finally {
      _gpsTried = true;
      renderQiblaText();
    }
  }
}

/// Basit internet erişilebilirlik kontrolü (connectivity_plus paketi
/// eklemek istemezseniz DNS sorgusu ile de kontrol edilebilir; burada
/// http isteğinin kendisi zaten online/offline ayrımını da yönetiyor,
/// bu sınıf sadece "önce dene" kararını hızlandırmak için kullanılır).
class _Connectivity {
  Future<bool> isOnline() async {
    try {
      final result = await InternetAddress.lookup('api.aladhan.com')
          .timeout(const Duration(seconds: 3));
      return result.isNotEmpty && result[0].rawAddress.isNotEmpty;
    } catch (_) {
      return false;
    }
  }
}
