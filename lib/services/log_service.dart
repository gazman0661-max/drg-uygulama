import 'dart:async';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/widgets.dart';

enum LogLevel { info, warn, error }

class _Entry {
  _Entry(this.text, this.level);
  final String text;
  final LogLevel level;
}

/// Log ekranını (gizli) canlı güncellemek için hafif bildirici.
class LogNotifier extends ChangeNotifier {
  bool get listening => hasListeners;
  void fire() => notifyListeners();
}

/// Uygulama geneli, kullanıcıya görünmeyen ayrıntılı kayıt sistemi.
///
/// - Bellekte son [_maxEntries] kaydı tutar; satırlar tamponlanıp [_flushDelay]
///   içinde (hata satırında hemen) `session.log` dosyasına eklenir.
/// - Bir sonraki açılışta o dosya `previous.log` sonuna eklenir ve "Önceki"
///   sekmesinde görünür (en fazla [_maxFileChars] karakter).
/// - Yakalanmamış Flutter/async hataları, yavaş kareler, rota geçişleri,
///   dokunuşlar, yaşam döngüsü, bellek nabzı ve servis çağrıları buraya akar.
/// - Log ekranı yalnızca Ayarlar > "Hakkında" başlığına 7 kez dokunarak açılır.
class AppLog {
  AppLog._();

  static const String appVersion = '1.0.0';

  static const _maxEntries = 6000;
  static const _maxFileChars = 500000;
  static const _maxMsgLen = 700;
  static const _flushDelay = Duration(milliseconds: 700);

  static final List<_Entry> _all = [];
  static String previousSession = '';
  static int infoCount = 0;
  static int warnCount = 0;
  static int errorCount = 0;

  static final LogNotifier changes = LogNotifier();
  static final LogNavObserver navObserver = LogNavObserver();

  /// Log ekranı açıkken true: ekranın kendi yeniden çizimi "yavaş kare" ve
  /// kaydırma dokunuşu satırı üretip ekranı tekrar tetiklemesin diye bu ikisi yazılmaz.
  static bool viewerOpen = false;

  static bool _inited = false;
  static final StringBuffer _pending = StringBuffer();
  static File? _file;
  static File? _prevFile;
  static Timer? _flushTimer;
  static Timer? _notifyTimer;
  static Timer? _pulseTimer;

  // ------------------------------------------------------------ erişim
  /// Bu oturum (veya yalnızca uyarı+hata) metni; başlık satırıyla birlikte.
  static String currentText({bool errorsOnly = false}) {
    final b = StringBuffer(header);
    for (final e in _all) {
      if (errorsOnly && e.level == LogLevel.info) continue;
      b.writeln(e.text);
    }
    return b.toString();
  }

  static String previousText() => previousSession.trim().isEmpty
      ? '(önceki oturum kaydı yok)'
      : previousSession;

  /// "Hatalar" sekmesindeki sayı (uyarı + hata).
  static int get problemCount => warnCount + errorCount;

  static String get header {
    final v = ui.PlatformDispatcher.instance.views;
    String screen = '?';
    if (v.isNotEmpty) {
      final s = v.first.physicalSize;
      screen =
          '${s.width.toInt()}x${s.height.toInt()} dpr=${v.first.devicePixelRatio.toStringAsFixed(2)}';
    }
    return 'Dergah-ı Kadirî v$appVersion | ${Platform.operatingSystem} '
        '${Platform.operatingSystemVersion} | ekran=$screen | '
        'dil=${ui.PlatformDispatcher.instance.locale.toLanguageTag()}\n';
  }

  // ------------------------------------------------------------ yazma
  static void i(String tag, String msg) => _add(LogLevel.info, tag, msg);
  static void w(String tag, String msg) => _add(LogLevel.warn, tag, msg);
  static void e(String tag, String msg, [StackTrace? st]) =>
      _add(LogLevel.error, tag, msg, st);

  /// Bir asenkron işi süresiyle birlikte kaydeder; hatayı loglar ve yeniden fırlatır.
  static Future<T> timed<T>(String tag, String label, Future<T> Function() fn) async {
    final sw = Stopwatch()..start();
    i(tag, '$label basladi');
    try {
      final r = await fn();
      i(tag, '$label bitti (${sw.elapsedMilliseconds}ms)');
      return r;
    } catch (err, st) {
      e(tag, '$label HATA (${sw.elapsedMilliseconds}ms): $err', st);
      rethrow;
    }
  }

  static String _two(int n) => n.toString().padLeft(2, '0');

  static String _ts(DateTime t) =>
      '${_two(t.hour)}:${_two(t.minute)}:${_two(t.second)}.${t.millisecond.toString().padLeft(3, '0')}';

  static void _add(LogLevel lv, String tag, String msg, [StackTrace? st]) {
    try {
      if (msg.length > _maxMsgLen) msg = '${msg.substring(0, _maxMsgLen)}…';
      final b = StringBuffer()
        ..write(_ts(DateTime.now()))
        ..write(' ')
        ..write(lv == LogLevel.info ? 'INFO' : (lv == LogLevel.warn ? 'WARN' : 'HATA'))
        ..write(' [')
        ..write(tag)
        ..write('] ')
        ..write(msg);
      if (st != null) {
        final lines = st
            .toString()
            .split('\n')
            .where((l) => l.trim().isNotEmpty)
            .take(8);
        for (final l in lines) {
          b.write('\n    ');
          b.write(l.trim());
        }
      }
      final text = b.toString();
      _all.add(_Entry(text, lv));
      if (_all.length > _maxEntries + 200) {
        _all.removeRange(0, _all.length - _maxEntries);
      }
      switch (lv) {
        case LogLevel.info:
          infoCount++;
        case LogLevel.warn:
          warnCount++;
        case LogLevel.error:
          errorCount++;
      }
      // Her satırda disk yazmak yavaşlatır: tamponla, toplu yaz (hatada hemen).
      _pending.writeln(text);
      if (lv == LogLevel.error) {
        flush();
      } else {
        _flushTimer ??= Timer(_flushDelay, flush);
      }
      if (kDebugMode) debugPrint(text);
      _scheduleNotify();
    } catch (_) {}
  }

  static void _scheduleNotify() {
    if (!changes.listening) return;
    if (_notifyTimer?.isActive ?? false) return;
    _notifyTimer = Timer(const Duration(milliseconds: 300), changes.fire);
  }

  // ------------------------------------------------------------ disk
  static Future<void> init() async {
    if (_inited) return;
    _inited = true;
    try {
      final dir = Directory('${Directory.systemTemp.path}/dergah_logs');
      if (!dir.existsSync()) dir.createSync(recursive: true);
      _file = File('${dir.path}/session.log');
      _prevFile = File('${dir.path}/previous.log');

      // Önceki oturumun kaydını "önceki" dosyasına ekle.
      var prev = _prevFile!.existsSync() ? _prevFile!.readAsStringSync() : '';
      if (_file!.existsSync()) {
        final last = _file!.readAsStringSync();
        if (last.trim().isNotEmpty) prev = prev.isEmpty ? last : '$prev\n$last';
      }
      if (prev.length > _maxFileChars) {
        prev = prev.substring(prev.length - _maxFileChars);
      }
      _prevFile!.writeAsStringSync(prev, flush: true);
      previousSession = prev;
      _file!.writeAsStringSync('', flush: true);
    } catch (_) {}

    _installHooks();
    _pulseTimer = Timer.periodic(const Duration(seconds: 10), (_) => _pulse());

    i('sistem', 'uygulama basladi v$appVersion '
        '${Platform.operatingSystem} ${Platform.operatingSystemVersion}');
    _logScreen();
  }

  /// Tamponu diske yazar. Arka plana alınırken de çağrılır.
  static void flush() {
    _flushTimer?.cancel();
    _flushTimer = null;
    if (_pending.isEmpty) return;
    final text = _pending.toString();
    _pending.clear();
    try {
      _file?.writeAsStringSync(text, mode: FileMode.append, flush: true);
    } catch (_) {}
  }

  static Future<void> clearAll() async {
    _pending.clear();
    _all.clear();
    previousSession = '';
    infoCount = warnCount = errorCount = 0;
    try {
      _prevFile?.writeAsStringSync('', flush: true);
      _file?.writeAsStringSync('', flush: true);
    } catch (_) {}
    i('sistem', 'kayitlar temizlendi');
    changes.fire();
  }

  // ------------------------------------------------------------ kancalar
  static void _installHooks() {
    final prevFlutter = FlutterError.onError;
    FlutterError.onError = (details) {
      e('flutter', details.exceptionAsString(), details.stack);
      prevFlutter?.call(details);
    };
    final prevPlatform = ui.PlatformDispatcher.instance.onError;
    ui.PlatformDispatcher.instance.onError = (error, stack) {
      e('async', '$error', stack);
      return prevPlatform?.call(error, stack) ?? true;
    };

    SchedulerBinding.instance.addTimingsCallback((timings) {
      for (final t in timings) {
        final total = t.totalSpan.inMilliseconds;
        final bd = t.buildDuration.inMilliseconds;
        final rd = t.rasterDuration.inMilliseconds;
        if (!viewerOpen && (total >= 120 || bd >= 60 || rd >= 60)) {
          w('jank',
              'yavas kare: toplam=${total}ms build=${bd}ms raster=${rd}ms');
        }
      }
    });

    WidgetsBinding.instance.addObserver(_LifecycleLogger());
  }

  static void _logScreen() {
    final v = ui.PlatformDispatcher.instance.views;
    if (v.isEmpty) return;
    final s = v.first.physicalSize;
    i('sistem',
        'ekran olcusu: ${s.width.toInt()}x${s.height.toInt()} dpr=${v.first.devicePixelRatio.toStringAsFixed(2)}');
  }

  static void _pulse() {
    try {
      final mb = (ProcessInfo.currentRss / 1048576).round();
      final peak = (ProcessInfo.maxRss / 1048576).round();
      i('nabiz',
          'bellek=${mb}MB (tepe ${peak}MB) log=${_all.length} hata=$errorCount uyari=$warnCount');
    } catch (_) {}
  }

  // ------------------------------------------------------------ dokunuş
  static int _lastMoveMs = 0;
  static int _downMs = 0;

  static void pointerDown(PointerDownEvent ev) {
    if (viewerOpen) return;
    _downMs = DateTime.now().millisecondsSinceEpoch;
    i('dokunus', 'x=${ev.position.dx.round()} y=${ev.position.dy.round()} (bas)');
  }

  static void pointerMove(PointerMoveEvent ev) {
    if (viewerOpen) return;
    final now = DateTime.now().millisecondsSinceEpoch;
    if (now - _lastMoveMs < 220) return;
    _lastMoveMs = now;
    i('dokunus', 'x=${ev.position.dx.round()} y=${ev.position.dy.round()}');
  }

  static void pointerUp(PointerUpEvent ev) {
    if (viewerOpen) return;
    final ms = DateTime.now().millisecondsSinceEpoch - _downMs;
    i('dokunus',
        'x=${ev.position.dx.round()} y=${ev.position.dy.round()} (birak, ${ms}ms)');
  }
}

class _LifecycleLogger with WidgetsBindingObserver {
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    AppLog.i('yasam', 'durum=${state.name}');
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.detached) {
      AppLog.flush();
    }
  }

  @override
  void didChangeMetrics() => AppLog._logScreen();

  @override
  void didHaveMemoryPressure() =>
      AppLog.w('bellek', 'sistem bellek uyarisi (didHaveMemoryPressure)');

  @override
  void didChangeLocales(List<Locale>? locales) =>
      AppLog.i('sistem', 'cihaz dili degisti: $locales');
}

/// Rota geçişlerini (sayfa/diyalog aç-kapat) kaydeder.
class LogNavObserver extends NavigatorObserver {
  String _n(Route<dynamic>? r) {
    if (r == null) return '-';
    final name = r.settings.name;
    return name != null ? '$name ${r.runtimeType}' : '${r.runtimeType}';
  }

  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) =>
      AppLog.i('rota', 'PUSH ${_n(route)} (onceki: ${_n(previousRoute)})');

  @override
  void didPop(Route<dynamic> route, Route<dynamic>? previousRoute) =>
      AppLog.i('rota', 'POP ${_n(route)} (donulen: ${_n(previousRoute)})');

  @override
  void didReplace({Route<dynamic>? newRoute, Route<dynamic>? oldRoute}) =>
      AppLog.i('rota', 'REPLACE ${_n(oldRoute)} -> ${_n(newRoute)}');

  @override
  void didRemove(Route<dynamic> route, Route<dynamic>? previousRoute) =>
      AppLog.i('rota', 'REMOVE ${_n(route)}');
}

/// Tüm uygulamanın üstüne oturur; dokunuşları loglar (olayı tüketmez).
class LogPointerListener extends StatelessWidget {
  const LogPointerListener({super.key, required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Listener(
      behavior: HitTestBehavior.translucent,
      onPointerDown: AppLog.pointerDown,
      onPointerMove: AppLog.pointerMove,
      onPointerUp: AppLog.pointerUp,
      child: child,
    );
  }
}
