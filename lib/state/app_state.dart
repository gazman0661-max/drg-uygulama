import 'dart:async';
import 'dart:io';
import 'dart:ui' show Locale;

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart'
    show AppLifecycleState, WidgetsBinding, WidgetsBindingObserver;
import 'package:geolocator/geolocator.dart';
import 'package:hijri/hijri_calendar.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../services/analytics_service.dart';
import '../services/log_service.dart';
import '../l10n/l10n.dart';
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

/// Vakit şeridi ve geri sayım sırası: Güneş de dahildir (namaz vakti değildir ama
/// İmsak'tan sonra sayaç Güneş'e, ardından Öğle'ye iner). Ezan bildirimi ise
/// yalnızca prayerOrder (5 vakit) için çalışır.
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

/// Saniyelik sayaç için hafif bildirici (AppState'i yeniden çizdirmez).
class TickNotifier extends ChangeNotifier {
  void fire() => notifyListeners();
}

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

  /// Ezan ve hatırlatma bildirimleri açık mı? (ana sayfadaki zil / ayarlar)
  bool notificationsEnabled = true;

  /// Telefonun sistem ayarlarında bu uygulama için bildirim izni açık mı?
  /// (Kullanıcı sistem ayarlarından kapatırsa uygulama içi anahtar eski
  /// haliyle kalırdı; bu alan gerçek durumu izler.)
  bool osNotificationsGranted = true;

  /// Bildirimler GERÇEKTEN aktif mi? Uygulama içi anahtar açık VE sistem izni var.
  bool get notificationsActive => notificationsEnabled && osNotificationsGranted;

  /// true: ezan sesli bildirim, false: sessiz bildirim
  bool soundEnabled = true;

  /// Hangi vakitlerde ezan bildirimi gelsin (Güneş namaz vakti değildir)
  Map<String, bool> adhanEnabled = {for (final k in prayerOrder) k: true};

  /// Ezan sesi hangi ses kanalından çalsın: 'alarm' | 'notification' | 'media'
  String ezanStream = 'alarm';
  bool get alarmStream => ezanStream == 'alarm';

  /// Ezan ses yüksekliği (0.1 - 1.0; telefonun ses seviyesine oranla)
  double ezanVolume = 1.0;

  /// Hicri günü Akşam vaktinde değiştir
  bool hijriAtMaghrib = false;

  /// Ramazan'da ana sayfada iftara kalan süreyi göster
  bool iftarCounterEnabled = true;

  /// Ek hatırlatıcılar: sahur, teheccüt, Pzt/Per orucu, Cuma namazı
  Map<String, bool> extraOn = {
    'sahur': false, 'teheccud': false, 'oruc': false, 'cuma': false
  };
  Map<String, int> extraMin = {
    'sahur': 90, 'teheccud': 120, 'oruc': 60, 'cuma': 60
  };
  bool orucOneDayBefore = false;

  /// Vakit düzeltmesi (dakika, -30..+30): her vakit için ayrı
  Map<String, int> timeOffsets = {for (final k in stripOrder) k: 0};

  /// Hicri gün düzeltmesi (-2..+2)
  int hijriOffset = 0;

  /// Kerahat süresi (dakika)
  int kerahatMinutes = 45;

  Timer? _ticker;

  /// Saniyelik geri sayım için AYRI bildirici: yalnızca sayaç kartı dinler,
  /// böylece tüm uygulama (5 sekme + ayarlar) her saniye yeniden çizilmez.
  final TickNotifier ticks = TickNotifier();

  String? get nextPrayerKey => _nextPrayerKey;
  Duration? get remaining => _remaining;

  String get hijriDateText {
    try {
      var base = DateTime.now();
      if (hijriAtMaghrib && _afterMaghrib(base)) {
        base = base.add(const Duration(days: 1));
      }
      final h = HijriCalendar.fromDate(base.add(Duration(days: hijriOffset)));
      final ay = tr(_hicriAylar[(h.hMonth - 1).clamp(0, 11)]);
      return '${h.hDay} $ay ${h.hYear}';
    } catch (_) {
      return '-- -- ----';
    }
  }

  /// Belirli bir günün hicri tarihi (yıl olmadan; bildirim paneli için).
  String hijriShortFor(DateTime d) {
    try {
      final h = HijriCalendar.fromDate(d.add(Duration(days: hijriOffset)));
      final ay = tr(_hicriAylar[(h.hMonth - 1).clamp(0, 11)]);
      return '${h.hDay} $ay';
    } catch (_) {
      return '';
    }
  }

  DateTime? _todayAt(String? hhmm) {
    if (hhmm == null) return null;
    final p = hhmm.split(':');
    if (p.length != 2) return null;
    final h = int.tryParse(p[0]);
    final m = int.tryParse(p[1]);
    if (h == null || m == null) return null;
    final n = DateTime.now();
    return DateTime(n.year, n.month, n.day, h, m);
  }

  bool _afterMaghrib(DateTime now) {
    final t = _todayAt(times?.aksam);
    return t != null && !now.isBefore(t);
  }

  bool _isRamadanOn(DateTime d) {
    try {
      return HijriCalendar.fromDate(d.add(Duration(days: hijriOffset))).hMonth == 9;
    } catch (_) {
      return false;
    }
  }

  /// Şu an Ramazan ayı mı? (hicri gün düzeltmesi dikkate alınır)
  bool get isRamadan {
    try {
      return HijriCalendar.fromDate(
                  DateTime.now().add(Duration(days: hijriOffset)))
              .hMonth ==
          9;
    } catch (_) {
      return false;
    }
  }

  /// Ramazan'da bugünkü iftara (Akşam vakti) kalan süre; yoksa null.
  Duration? get iftarRemaining {
    if (!iftarCounterEnabled || !isRamadan) return null;
    final t = _todayAt(times?.aksam);
    final now = DateTime.now();
    if (t == null || !t.isAfter(now)) return null;
    return t.difference(now);
  }

  /// Miladi (Gregorian) takvim - Hicri tarihin yanında ana sayfada gösterilir.
  String get gregorianDateText {
    final now = DateTime.now();
    final ay = tr(_turkceAylar[now.month - 1]);
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

    final kerahatSuresi = Duration(minutes: kerahatMinutes);
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
    final kerahatSuresi = Duration(minutes: kerahatMinutes);

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

  final Completer<void> _selectionLoaded = Completer<void>();

  /// İlk açılış kurulumu (il/ilçe + bildirim izni) bitince tamamlanır.
  final Completer<void> _firstLaunchDone = Completer<void>();
  Future<void> waitForFirstLaunchSetup() => _firstLaunchDone.future;

  /// Kayıtlı il/ilçe okunduğunda tamamlanır (ilk açılış kontrolü için).
  Future<void> get selectionLoaded => _selectionLoaded.future;

  Future<void> init() async {
    AppLog.i('state', 'AppState.init basladi');
    WidgetsBinding.instance.addObserver(this);
    await _loadSavedSelection();
    if (!_selectionLoaded.isCompleted) _selectionLoaded.complete();
    if (!firstLaunchNeedsSelection && !_firstLaunchDone.isCompleted) {
      _firstLaunchDone.complete();
    }
    await _loadReminderSettings();
    await _loadPanelSettings();
    await _loadNotifySettings();
    try {
      await _notifier.init();
      await refreshOsNotificationPermission();
    } catch (e) {
      AppLog.e('bildirim', 'servis baslatilamadi: $e');
    }
    unawaited(_fetchLocationIfGranted()); // izin SORMAZ, sadece verilmişse okur
    renderQiblaText();
    await loadTimesAndRender();
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) => _tick());
    AppLog.i('state', 'AppState.init bitti');
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _ticker?.cancel();
    ticks.dispose();
    super.dispose();
  }

  /// Uygulama arka plandan dönünce (ör. telefon geceyi uykuda geçirdiyse)
  /// gün değişimini hemen yakala.
  /// Cihaz dili değişti: metinleri yenile, Android'e giden hatırlatıcı metinlerini yeniden gönder.
  @override
  void didChangeLocales(List<Locale>? locales) {
    L.initFromPlatform();
    notifyListeners();
    scheduleNotifications(force: true);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _updateCountdown();
      // Kullanıcı sistem ayarlarından bildirimi açıp/kapatmış olabilir.
      refreshOsNotificationPermission();
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
    AppLog.i('state', 'completeFirstLaunchSelection yeniIl=${yeniIl} yeniIlce=${yeniIlce}');
    firstLaunchNeedsSelection = false;
    await setIlIlce(yeniIl, yeniIlce);
    // Bildirimler ancak izin verilirse görünür; ilk kurulumda izni iste.
    unawaited(requestNotificationPermission()
        .catchError((_) => false)
        .whenComplete(() {
      if (!_firstLaunchDone.isCompleted) _firstLaunchDone.complete();
    }));
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

  Future<void> _loadNotifySettings() async {
    final prefs = await SharedPreferences.getInstance();
    notificationsEnabled = prefs.getBool('dergah_bildirim_acik') ?? true;
    soundEnabled = prefs.getBool('dergah_bildirim_sesli') ?? true;
    ezanStream = prefs.getString('dergah_ezan_kanal') ??
        ((prefs.getBool('dergah_ezan_alarm_kanali') ?? true) ? 'alarm' : 'notification');
    ezanVolume = prefs.getDouble('dergah_ezan_ses') ?? 1.0;
    hijriAtMaghrib = prefs.getBool('dergah_hicri_aksam') ?? false;
    iftarCounterEnabled = prefs.getBool('dergah_iftar_sayaci') ?? true;
    for (final k in extraOn.keys) {
      extraOn[k] = prefs.getBool('dergah_ek_${k}_on') ?? false;
      extraMin[k] = prefs.getInt('dergah_ek_${k}_dk') ?? extraMin[k]!;
    }
    orucOneDayBefore = prefs.getBool('dergah_ek_oruc_onceki') ?? false;
    for (final k in prayerOrder) {
      adhanEnabled[k] = prefs.getBool('dergah_ezan_$k') ?? true;
    }
    for (final k in stripOrder) {
      timeOffsets[k] = prefs.getInt('dergah_duzeltme_$k') ?? 0;
    }
    hijriOffset = prefs.getInt('dergah_hicri_duzeltme') ?? 0;
    kerahatMinutes = prefs.getInt('dergah_kerahat_dk') ?? 45;
  }

  // ---- Gelişmiş vakit / ezan ayarları ----
  Future<void> setAdhanEnabled(String key, bool v) async {
    AppLog.i('state', 'setAdhanEnabled key=${key} v=${v}');
    adhanEnabled[key] = v;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('dergah_ezan_$key', v);
    notifyListeners();
    await scheduleNotifications(force: true);
  }

  Future<void> setEzanStream(String v) async {
    AppLog.i('state', 'setEzanStream v=${v}');
    ezanStream = v;
    AnalyticsService.event('ezan_kanali', {'kanal': v});
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('dergah_ezan_kanal', v);
    notifyListeners();
    await scheduleNotifications(force: true);
  }

  Future<void> setEzanVolume(double v) async {
    AppLog.i('state', 'setEzanVolume v=${v}');
    ezanVolume = v.clamp(0.1, 1.0).toDouble();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble('dergah_ezan_ses', ezanVolume);
    notifyListeners();
    await scheduleNotifications(force: true);
  }

  Future<void> setHijriAtMaghrib(bool v) async {
    AppLog.i('state', 'setHijriAtMaghrib v=${v}');
    hijriAtMaghrib = v;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('dergah_hicri_aksam', v);
    notifyListeners();
  }

  Future<void> setIftarCounter(bool v) async {
    AppLog.i('state', 'setIftarCounter v=${v}');
    iftarCounterEnabled = v;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('dergah_iftar_sayaci', v);
    notifyListeners();
  }

  Future<void> setExtraReminder(String key, {bool? on, int? minutes}) async {
    AppLog.i('state', 'setExtraReminder key=${key} minutes=${minutes}');
    final prefs = await SharedPreferences.getInstance();
    if (on != null) {
      extraOn[key] = on;
      await prefs.setBool('dergah_ek_${key}_on', on);
      AnalyticsService.event('ek_hatirlatma', {'ad': key, 'acik': on ? 1 : 0});
    }
    if (minutes != null) {
      extraMin[key] = minutes;
      await prefs.setInt('dergah_ek_${key}_dk', minutes);
    }
    notifyListeners();
    await scheduleNotifications(force: true);
  }

  Future<void> setOrucOneDayBefore(bool v) async {
    AppLog.i('state', 'setOrucOneDayBefore v=${v}');
    orucOneDayBefore = v;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('dergah_ek_oruc_onceki', v);
    notifyListeners();
    await scheduleNotifications(force: true);
  }

  /// Yerel bildirim servisine gidecek ek hatırlatıcı listesi.
  List<Map<String, Object>> _extraRemindersJson() {
    final out = <Map<String, Object>>[];
    if (extraOn['sahur'] == true) {
      final m = extraMin['sahur']!;
      out.add({
        'base': 'Sabah', 'minutes': m, 'title': tr('Sahur Vakti'),
        'text': tr('İmsaka $m dakika kaldı.'),
      });
    }
    if (extraOn['teheccud'] == true) {
      final m = extraMin['teheccud']!;
      out.add({
        'base': 'Sabah', 'minutes': m, 'title': tr('Teheccüt Vakti'),
        'text': tr('İmsaka $m dakika kaldı; teheccüt için uyanma vakti.'),
      });
    }
    if (extraOn['oruc'] == true) {
      final m = extraMin['oruc']!;
      out.add({
        'base': 'Sabah', 'minutes': m, 'title': tr('Oruç Hatırlatması'),
        'text': tr('Bugün Pazartesi/Perşembe orucu günü. İmsaka $m dakika kaldı.'),
        'days': [1, 4],
      });
      if (orucOneDayBefore) {
        out.add({
          'base': 'Yatsi', 'minutes': 0, 'title': tr('Yarın Oruç Günü'),
          'text': tr('Yarın Pazartesi/Perşembe orucu günü. Niyet edebilirsiniz.'),
          'daysNext': [1, 4],
        });
      }
    }
    if (extraOn['cuma'] == true) {
      final m = extraMin['cuma']!;
      out.add({
        'base': 'Ogle', 'minutes': m, 'title': tr('Cuma Namazı'),
        'text': tr('Öğle vaktine $m dakika kaldı; Cuma namazına hazırlanın.'),
        'days': [5],
      });
    }
    return out;
  }

  Future<void> setTimeOffset(String key, int minutes) async {
    AppLog.i('state', 'setTimeOffset key=${key} minutes=${minutes}');
    timeOffsets[key] = minutes.clamp(-30, 30).toInt();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('dergah_duzeltme_$key', timeOffsets[key]!);
    notifyListeners();
    await loadTimesAndRender(silent: true);
  }

  Future<void> setHijriOffset(int days) async {
    AppLog.i('state', 'setHijriOffset days=${days}');
    hijriOffset = days.clamp(-2, 2).toInt();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('dergah_hicri_duzeltme', hijriOffset);
    notifyListeners();
  }

  Future<void> setKerahatMinutes(int minutes) async {
    AppLog.i('state', 'setKerahatMinutes minutes=${minutes}');
    kerahatMinutes = minutes;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('dergah_kerahat_dk', minutes);
    notifyListeners();
    await scheduleNotifications(force: true);
  }

  /// Kullanıcının dakika düzeltmelerini vakitlere uygular.
  GunlukVakitler? _adjust(GunlukVakitler? t) {
    if (t == null) return null;
    if (timeOffsets.values.every((v) => v == 0)) return t;
    final j = t.toJson();
    for (final k in stripOrder) {
      final off = timeOffsets[k] ?? 0;
      if (off != 0) j[k] = _shiftHHmm(j[k] as String, off);
    }
    return GunlukVakitler.fromJson(j);
  }

  String _shiftHHmm(String s, int minutes) {
    final p = s.split(':');
    if (p.length != 2) return s;
    final h = int.tryParse(p[0]);
    final m = int.tryParse(p[1]);
    if (h == null || m == null) return s;
    final total = (h * 60 + m + minutes) % 1440; // Dart: sonuç negatif olmaz
    return '${(total ~/ 60).toString().padLeft(2, '0')}:${(total % 60).toString().padLeft(2, '0')}';
  }

  /// Ezan/hatırlatma bildirimlerini açar/kapatır. Açarken izin gerekir;
  /// izin verilmezse açılmaz ve false döner.
  Future<bool> setNotificationsEnabled(bool value) async {
    AppLog.i('state', 'setNotificationsEnabled value=${value}');
    if (value) {
      final granted = await _notifier.requestPermission();
      osNotificationsGranted = granted;
      if (!granted) {
        notificationsEnabled = false;
        final prefs = await SharedPreferences.getInstance();
        await prefs.setBool('dergah_bildirim_acik', false);
        notifyListeners();
        await scheduleNotifications(force: true);
        return false;
      }
    }
    notificationsEnabled = value;
    AnalyticsService.event('bildirim_ayari', {'acik': value ? 1 : 0});
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('dergah_bildirim_acik', value);
    notifyListeners();
    await scheduleNotifications(force: true);
    return true;
  }

  /// Kullanıcının seçtiği uygulama dili (tr/en/ar); null = cihaz dili.
  String? get languageOverride => L.override;

  /// Dil seç. [code] null ise cihaz dilini izler.
  Future<void> setLanguage(String? code) async {
    AppLog.i('state', 'setLanguage code=${code}');
    if (code != null && !L.supported.contains(code)) return;
    L.override = code;
    L.initFromPlatform();
    AnalyticsService.event('dil_ayari', {'dil': code ?? 'sistem'});
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    if (code == null) {
      await prefs.remove('dergah_dil');
    } else {
      await prefs.setString('dergah_dil', code);
    }
    // Android'e giden hatırlatıcı metinlerini yeni dille yeniden gönder.
    await scheduleNotifications(force: true);
  }

  Future<void> setSoundEnabled(bool value) async {
    AppLog.i('state', 'setSoundEnabled value=${value}');
    soundEnabled = value;
    AnalyticsService.event('ses_ayari', {'sesli': value ? 1 : 0});
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('dergah_bildirim_sesli', value);
    notifyListeners();
    await scheduleNotifications(force: true);
  }

  /// Uygulama açılışında (splash'tan sonra) bildirim iznini ister.
  /// İzin zaten varsa sistem hiçbir şey göstermez. "Tam zamanlı alarm"
  /// ayar ekranı ise yalnızca bir kez açılır (her açılışta rahatsız etmesin).
  Future<void> askPermissionsOnLaunch() async {
    if (!notificationsEnabled || firstLaunchNeedsSelection) return;
    final prefs = await SharedPreferences.getInstance();
    final exactAsked = prefs.getBool('dergah_exact_soruldu') ?? false;
    final granted = await _notifier.requestPermission(askExact: !exactAsked);
    await prefs.setBool('dergah_exact_soruldu', true);
    if (granted) await scheduleNotifications(force: true);
  }

  Future<bool> notificationsGranted() => _notifier.areEnabled();

  /// Sistem bildirim iznini yeniden okur; değiştiyse arayüzü günceller.
  Future<void> refreshOsNotificationPermission() async {
    AppLog.i('state', 'refreshOsNotificationPermission ');
    final g = await _notifier.areEnabled();
    if (g != osNotificationsGranted) {
      osNotificationsGranted = g;
      notifyListeners();
    }
  }

  /// Pil/arka plan ipucu daha önce gösterildi mi?
  Future<bool> batteryTipShown() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool('dergah_pil_ipucu_goruldu') ?? false;
  }

  Future<void> markBatteryTipShown() async {
    AppLog.i('state', 'markBatteryTipShown ');
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('dergah_pil_ipucu_goruldu', true);
  }

  Future<bool> testAdhan() =>
      _widgetService.testAdhan(stream: ezanStream, volume: ezanVolume);

  Future<bool> openAppSettings() => _widgetService.openAppSettings();

  /// Tam zamanlı alarm ayarı açılamazsa (eski Android) uygulama ayarlarına düşer.
  Future<bool> openExactAlarmSettings() async {
    AppLog.i('state', 'openExactAlarmSettings ');
    final ok = await _widgetService.openExactAlarmSettings();
    return ok || await _widgetService.openAppSettings();
  }

  /// Bildirim çubuğu panelini açar/kapatır. Açarken bildirim izni gerekir;
  /// izin verilmezse panel açılmaz ve false döner.
  Future<bool> setPanelEnabled(bool value) async {
    AppLog.i('state', 'setPanelEnabled value=${value}');
    if (value) {
      final granted = await _notifier.requestPermission();
      if (!granted) {
        panelEnabled = false;
        notifyListeners();
        return false;
      }
    }
    panelEnabled = value;
    AnalyticsService.event('panel_ayari', {'acik': value ? 1 : 0});
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('dergah_panel_acik', value);
    notifyListeners();
    await scheduleNotifications(force: true);
    return true;
  }

  Future<void> setPanelKerahat(bool value) async {
    AppLog.i('state', 'setPanelKerahat value=${value}');
    panelKerahat = value;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('dergah_panel_kerahat', value);
    notifyListeners();
    await scheduleNotifications(force: true);
  }

  Future<void> setReminderMinutes(String prayerKey, int minutes) async {
    AppLog.i('state', 'setReminderMinutes prayerKey=${prayerKey} minutes=${minutes}');
    reminderMinutes[prayerKey] = minutes;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('dergah_hatirlatma_$prayerKey', minutes);
    notifyListeners();
    await scheduleNotifications();
  }

  Future<void> setIlIlce(String yeniIl, String yeniIlce) async {
    AppLog.i('state', 'setIlIlce yeniIl=${yeniIl} yeniIlce=${yeniIlce}');
    il = yeniIl;
    ilce = yeniIlce;
    AnalyticsService.event('il_secimi', {'il': yeniIl});
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('dergah_secili_il', il);
    await prefs.setString('dergah_secili_ilce', ilce);
    await loadTimesAndRender();
  }

  // ---------------- NAMAZ VAKİTLERİ (gerçek Diyanet) ----------------
  Future<void> loadTimesAndRender({bool silent = false}) async {
    final sw = Stopwatch()..start();
    AppLog.i('vakit', 'yukleme basladi il=$il ilce=$ilce silent=$silent');
    AppLog.i('state', 'loadTimesAndRender silent=${silent}');
    if (!silent) {
      loading = true;
      notifyListeners();
    }

    final online = await _connectivity.isOnline();
    final today = DateTime.now();
    final result =
        await _diyanetService.getTimesForDate(il, ilce, today, online: online);

    times = _adjust(result.vakitler);
    kaynak = result.kaynak;
    _timesDateTag = _dateTag(today);
    _tomorrowTimes = null;
    _tomorrowDateTag = null;
    _cityLat = result.lat;
    _cityLng = result.lng;
    loading = false;
    renderQiblaText();

    AppLog.i('vakit',
        'yukleme bitti kaynak=${kaynak.name} cevrimici=$online (${sw.elapsedMilliseconds}ms)');
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
        _tomorrowTimes = _adjust(r.vakitler);
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

    // Geri sayım Güneş'i de içerir: İmsak → Güneş → Öğle → İkindi → Akşam → Yatsı
    final tt = times!;
    final ordered = <String, String>{
      'Sabah': tt.sabah,
      'Gunes': tt.gunes,
      'Ogle': tt.ogle,
      'Ikindi': tt.ikindi,
      'Aksam': tt.aksam,
      'Yatsi': tt.yatsi,
    };
    for (final key in stripOrder) {
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
    final keyChanged = _nextPrayerKey != nextKey;
    final wasNull = _remaining == null;
    _nextPrayerKey = nextKey;

    if (next != null) {
      _remaining = next.difference(now);
    } else {
      _remaining = null;
    }

    // Tüm uygulamayı yalnızca yapısal değişimde (sıradaki vakit değişti /
    // sayaç doğdu ya da bitti) yeniden çiz; saniyelik sayaç ayrı bildirimle.
    if (keyChanged || wasNull != (_remaining == null)) {
      notifyListeners();
    }
    ticks.fire();
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
    AppLog.i('state', 'scheduleNotifications force=${force}');
    try {
      final rawDays =
          await _diyanetService.cachedDays(il, ilce, DateTime.now(), 90);
      final days = <DateTime, GunlukVakitler>{
        for (final e in rawDays.entries) e.key: _adjust(e.value)!,
      };
      // Sabah ezanı bildirim saati: normal aylarda Güneş'ten 45 dk önce,
      // Ramazan ayında İmsak vaktinde.
      final sabahEzan = <DateTime, String>{
        for (final e in days.entries)
          e.key: _isRamadanOn(e.key) ? e.value.sabah : _shiftHHmm(e.value.gunes, -45),
      };
      await _notifier.clearLegacyOnce();
      await _widgetService.push(
        place: '${_toTitle(ilce)}, ${_toTitle(il)}',
        days: days,
        reminders: reminderMinutes,
        panel: panelEnabled,
        panelKerahat: panelKerahat,
        notify: notificationsEnabled,
        sound: soundEnabled,
        adhan: adhanEnabled,
        alarmStream: alarmStream,
        kerahatMin: kerahatMinutes,
        stream: ezanStream,
        volume: ezanVolume,
        extras: _extraRemindersJson(),
        sabahEzan: sabahEzan,
        hijri: {for (final k in days.keys) k: hijriShortFor(k)},
      );
    } catch (e, st) {
      AnalyticsService.recordError(e, st, reason: 'scheduleNotifications');
      AppLog.e('bildirim', 'scheduleNotifications hatasi: $e', st);
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
    AppLog.i('state', 'requestNotificationPermission ');
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

  // ---------------- KONUM (ayrı, isteğe bağlı izin) ----------------
  bool get gpsActive => _gpsLat != null;

  /// Konum izni zaten verilmişse sessizce okur; ASLA izin penceresi açmaz.
  Future<void> _fetchLocationIfGranted() async {
    try {
      if (!await Geolocator.isLocationServiceEnabled()) return;
      final p = await Geolocator.checkPermission();
      if (p == LocationPermission.whileInUse ||
          p == LocationPermission.always) {
        await _readPosition();
      }
    } catch (lerr) { AppLog.w('state', 'yutulan hata: $lerr'); }
  }

  Future<void> _readPosition() async {
    try {
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

  /// Konum popup'ı daha önce gösterilmediyse ve izin henüz verilmediyse true.
  Future<bool> shouldAskLocationPermission() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      if (prefs.getBool('dergah_konum_soruldu') ?? false) return false;
      final p = await Geolocator.checkPermission();
      return p == LocationPermission.denied;
    } catch (_) {
      return false;
    }
  }

  Future<void> markLocationAsked() async {
    AppLog.i('state', 'markLocationAsked ');
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('dergah_konum_soruldu', true);
    } catch (lerr) { AppLog.w('state', 'yutulan hata: $lerr'); }
  }

  /// Kullanıcı konum vermek istemedi: kıble il/ilçe koordinatıyla hesaplanır.
  void declineLocation() {
    _gpsTried = true;
    renderQiblaText();
  }

  /// Konum izni ister ve konumu okur. Reddedilirse uygulama il/ilçeye göre
  /// çalışmaya devam eder. [openSettingsIfBlocked]: kalıcı reddedildiyse
  /// telefon ayarlarını açar (yalnızca kullanıcı butona bastığında).
  Future<bool> requestLocation({bool openSettingsIfBlocked = false}) async {
    AppLog.i('state', 'requestLocation openSettingsIfBlocked=${openSettingsIfBlocked}');
    try {
      if (!await Geolocator.isLocationServiceEnabled()) {
        declineLocation();
        return false;
      }
      var p = await Geolocator.checkPermission();
      if (p == LocationPermission.denied) {
        p = await Geolocator.requestPermission();
      }
      if (p == LocationPermission.deniedForever) {
        if (openSettingsIfBlocked) await Geolocator.openAppSettings();
        declineLocation();
        return false;
      }
      if (p == LocationPermission.denied) {
        declineLocation();
        return false;
      }
      await _readPosition();
      return _gpsLat != null;
    } catch (_) {
      declineLocation();
      return false;
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
