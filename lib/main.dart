import 'dart:async';

import 'package:flutter/material.dart' hide Text;
import 'l10n/app_text.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'data/il_ilce_data.dart';
import 'l10n/l10n.dart';
import 'pages/book_page.dart';
import 'pages/home_page.dart';
import 'pages/qibla_page.dart';
import 'pages/settings_page.dart';
import 'pages/splash_page.dart';
import 'pages/sohbetler_page.dart';
import 'pages/times_page.dart';
import 'services/analytics_service.dart';
import 'services/update_service.dart';
import 'widgets/app_dialog.dart';
import 'widgets/consent_dialog.dart';
import 'widgets/location_dialog.dart';
import 'widgets/permission_dialogs.dart';
import 'state/app_state.dart';
import 'theme/app_theme.dart';
import 'utils/turkish.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Dil: kullanıcının seçtiği dil varsa o, yoksa cihaz dili (tr / en / ar)
  try {
    final prefs = await SharedPreferences.getInstance();
    L.override = prefs.getString('dergah_dil');
  } catch (_) {}
  L.initFromPlatform();
  // Analytics yalnızca gizlilik/şartlar kabul edildiyse başlar (ilk açılışta
  // kabul penceresinden sonra başlatılır). Başarısız olsa bile uygulama açılır.
  if (await isConsentAccepted()) {
    unawaited(AnalyticsService.init());
  }
  runApp(const DergahApp());
}

class DergahApp extends StatelessWidget {
  const DergahApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      lazy: false, // vakitler/konum açılış ekranı sürerken yüklenmeye başlasın
      // init() burada değil, _SplashGate'te (kabul onayından sonra) başlatılır.
      create: (_) => AppState(),
      child: Consumer<AppState>(
        builder: (context, app, _) => MaterialApp(
        locale: app.languageOverride == null ? null : Locale(L.lang),
        onGenerateTitle: (_) => tr('Dergah-ı Kadirî - Ezan Vakti'),
        debugShowCheckedModeBanner: false,
        supportedLocales: const [Locale('en'), Locale('tr'), Locale('ar')],
        localizationsDelegates: const [
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        // Cihaz dili tr/en/ar ise o dil, değilse İngilizce (arayüz Arapça'da sağdan sola)
        localeResolutionCallback: (device, supported) {
          final code =
              L.override ?? L.resolve(device?.languageCode ?? 'en');
          L.lang = code;
          return Locale(code);
        },
        theme: buildAppTheme(),
        // Cihaz yazı tipi boyutu: kullanıcının tercihine saygı duyulur ama
        // aşırı büyütmede arayüzün bozulmaması için 0.85x–1.3x aralığına sınırlanır.
        builder: (context, child) => MediaQuery.withClampedTextScaling(
          minScaleFactor: 0.85,
          maxScaleFactor: 1.3,
          child: child ?? const SizedBox.shrink(),
        ),
        home: const _SplashGate(),
        ),
      ),
    );
  }
}

/// Açılışta 3 saniye splash gösterir, sonra ana uygulamaya geçer.
class _SplashGate extends StatefulWidget {
  const _SplashGate();

  @override
  State<_SplashGate> createState() => _SplashGateState();
}

class _SplashGateState extends State<_SplashGate> {
  static const _duration = Duration(seconds: 3);
  bool _done = false;
  Timer? _timer;
  bool _initStarted = false;

  /// Vakit/konum yüklemesi yalnızca onay verildikten sonra başlar.
  void _startAppInit() {
    if (_initStarted) return;
    _initStarted = true;
    unawaited(context.read<AppState>().init());
  }

  @override
  void initState() {
    super.initState();
    // Daha önce kabul edildiyse yükleme splash sürerken başlasın.
    isConsentAccepted().then((ok) {
      if (ok && mounted) _startAppInit();
    });
    _timer = Timer(_duration, () async {
      if (!mounted) return;
      // İlk açılışta gizlilik politikası + kullanım şartları onayı (Vazgeç = çıkış)
      await showConsentIfNeeded(context);
      if (!mounted) return;
      _startAppInit();
      // İlk açılış il/ilçe kontrolü için kayıtlı seçimin okunmasını bekle.
      await context
          .read<AppState>()
          .selectionLoaded
          .timeout(const Duration(seconds: 3), onTimeout: () {});
      if (!mounted) return;
      setState(() => _done = true);
      // Ana ekran göründükten sonra bildirim iznini iste
      WidgetsBinding.instance.addPostFrameCallback((_) async {
        final app = context.read<AppState>();
        // Sıra: Play güncellemesi → bildirim izni → (ilk açılışta il/ilçe +
        // bildirim bitince) AYRI ve isteğe bağlı konum izni popup'ı.
        await UpdateService.checkAndUpdate();
        if (!mounted) return;
        await maybeExplainAndAskNotifications(context);
        if (!mounted) return;
        await app.waitForFirstLaunchSetup();
        if (!mounted) return;
        await maybeAskLocation(context);
        if (!mounted) return;
        await maybeShowBatteryTip(context);
      });
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 500),
      child: _done
          ? const RootShell(key: ValueKey('root'))
          : const SplashPage(key: ValueKey('splash')),
    );
  }
}

/// Orijinal HTML'deki tek sayfalık .page / .page.active + .bottom-nav
/// yapısının Flutter karşılığı: IndexedStack + BottomNavigationBar.
class RootShell extends StatefulWidget {
  const RootShell({super.key});

  @override
  State<RootShell> createState() => _RootShellState();
}

class _RootShellState extends State<RootShell> {
  int _index = 0;

  /// Kitap sekmesi (indeks 3) tam ekran okuma modundadır: üst/alt çubuklar ve
  /// sistem çubukları gizlenir.
  static const int _bookIndex = 3;

  static const _screenNames = ['ana_sayfa', 'vakitler', 'kible', 'kitap', 'sohbetler'];

  void _goto(int i) {
    if (i != _index && i >= 0 && i < _screenNames.length) {
      AnalyticsService.screen(_screenNames[i]);
    }
    setState(() => _index = i);
    _applySystemUi();
  }

  void _applySystemUi() {
    SystemChrome.setEnabledSystemUIMode(
      _index == _bookIndex ? SystemUiMode.immersiveSticky : SystemUiMode.edgeToEdge,
    );
  }

  @override
  void dispose() {
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _maybeShowIlIlceDialog());
  }

  void _maybeShowIlIlceDialog() {
    final state = context.read<AppState>();
    if (!state.firstLaunchNeedsSelection) return;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const _IlIlceSecimDialog(),
    );
  }

  @override
  Widget build(BuildContext context) {
    Localizations.localeOf(context); // dil değişince etiketler yenilensin
    final pages = <Widget>[
      HomePage(onNavigate: _goto),
      const TimesPage(),
      QiblaPage(active: _index == 2),
      BookReaderPage(active: _index == _bookIndex, onExit: () => _goto(0)),
      const SohbetlerPage(),
    ];

    final reading = _index == _bookIndex;

    // Geri tuşu: tam ekran okumadan/diğer sekmelerden önce ana sayfaya döner.
    return PopScope(
      canPop: _index == 0,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop) _goto(0);
      },
      child: Scaffold(
      appBar: reading
          ? null
          : AppBar(
        leading: Padding(
          padding: const EdgeInsets.all(8),
          child: _TopbarStar(),
        ),
        title: const Text('Dergah-ı Kadirî'),
        actions: [
          Consumer<AppState>(
            builder: (context, st, _) {
              // Uygulama içi anahtar AÇIK ve telefon ayarlarında izin VAR ise aktif
              final on = st.notificationsActive;
              return IconButton(
                tooltip: tr(on ? 'Bildirimleri kapat' : 'Bildirimleri aç'),
                style: IconButton.styleFrom(
                  backgroundColor: on ? AppColors.gold : Colors.transparent,
                  foregroundColor: on ? AppColors.deep : AppColors.ivory,
                ),
                icon: Icon(on
                    ? Icons.notifications_active
                    : Icons.notifications_off_outlined),
                onPressed: () async {
                  final messenger = ScaffoldMessenger.of(context);
                  final app = context.read<AppState>();
                  final ok = await app.setNotificationsEnabled(!on);
                  messenger.hideCurrentSnackBar();
                  messenger.showSnackBar(SnackBar(
                    action: (!on && !ok)
                        ? SnackBarAction(
                            label: tr('Ayarlar'),
                            onPressed: () {
                              app.openAppSettings();
                            },
                          )
                        : null,
                    content: Text(!on && !ok
                        ? 'Bildirim izni verilmedi. Telefon ayarlarından Dergah-ı Kadirî için bildirimleri açabilirsiniz.'
                        : (app.notificationsEnabled
                            ? 'Bildirimler açıldı. Namaz vakti girdiğinde haber verilecek.'
                            : 'Bildirimler kapatıldı.')),
                  ));
                },
              );
            },
          ),
          IconButton(
            tooltip: tr('Ayarlar'),
            icon: const Icon(Icons.settings_outlined),
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const SettingsPage()),
            ),
          ),
          const SizedBox(width: 4),
        ],
      ),
      body: IndexedStack(index: _index, children: pages),
      bottomNavigationBar: reading
          ? null
          : BottomNavigationBar(
        currentIndex: _index,
        onTap: _goto,
        items: [
          BottomNavigationBarItem(
              icon: const Icon(Icons.home), label: tr('Ana Sayfa')),
          BottomNavigationBarItem(
              icon: const Icon(Icons.mosque), label: tr('Vakitler')),
          BottomNavigationBarItem(
              icon: const Icon(Icons.explore), label: tr('Kıble')),
          BottomNavigationBarItem(
              icon: const Icon(Icons.menu_book), label: tr('Kitap')),
          BottomNavigationBarItem(
              icon: const Icon(Icons.video_collection), label: tr('Sohbetler')),
        ],
      ),
    ));
  }
}

/// Orijinal HTML'deki .topbar-star (sekiz kollu yıldız / hatem motifi)
/// basitleştirilmiş bir Flutter karşılığı.
class _TopbarStar extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Image.asset(
      'assets/images/hat.png',
      fit: BoxFit.contain,
      filterQuality: FilterQuality.high,
    );
  }
}

/// Uygulama ilk kez açıldığında (daha önce kaydedilmiş bir il/ilçe yoksa)
/// gösterilen, kapatılamayan il/ilçe seçim penceresi. Onaylanınca seçilen
/// il/ilçe için vakitler otomatik olarak çekilir.
class _IlIlceSecimDialog extends StatefulWidget {
  const _IlIlceSecimDialog();

  @override
  State<_IlIlceSecimDialog> createState() => _IlIlceSecimDialogState();
}

class _IlIlceSecimDialogState extends State<_IlIlceSecimDialog> {
  late String _il;
  late String _ilce;
  bool _kaydediliyor = false;

  @override
  void initState() {
    super.initState();
    final state = context.read<AppState>();
    _il = state.il;
    _ilce = state.ilce;
  }

  String _toTitle(String s) => trTitle(s);

  @override
  Widget build(BuildContext context) {
    final iller = ilIlceData.keys.toList()..sort(trCompare);
    final ilceler = (ilIlceData[_il] ?? []).toList()..sort(trCompare);
    if (!ilceler.contains(_ilce) && ilceler.isNotEmpty) {
      _ilce = ilceler.first;
    }

    return AppDialog(
      title: 'Hoş Geldiniz',
      primaryLabel: 'Onayla',
      primaryBusy: _kaydediliyor,
      onPrimary: _kaydediliyor
          ? null
          : () async {
              setState(() => _kaydediliyor = true);
              await context
                  .read<AppState>()
                  .completeFirstLaunchSelection(_il, _ilce);
              if (context.mounted) Navigator.of(context).pop();
            },
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Namaz vakitlerinin gösterileceği il ve ilçeyi seçin.'),
          const SizedBox(height: 14),
          DropdownButton<String>(
            isExpanded: true,
            value: _il,
            items: iller
                .map((il) =>
                    DropdownMenuItem(value: il, child: Text(_toTitle(il))))
                .toList(),
            onChanged: (v) {
              if (v == null) return;
              setState(() {
                _il = v;
                final newIlceler =
                    (ilIlceData[v] ?? []).toList()..sort(trCompare);
                _ilce = newIlceler.isNotEmpty ? newIlceler.first : '';
              });
            },
          ),
          const SizedBox(height: 8),
          DropdownButton<String>(
            isExpanded: true,
            value: ilceler.contains(_ilce) ? _ilce : null,
            items: ilceler
                .map((i) =>
                    DropdownMenuItem(value: i, child: Text(_toTitle(i))))
                .toList(),
            onChanged: (v) {
              if (v == null) return;
              setState(() => _ilce = v);
            },
          ),
        ],
      ),
    );
  }
}
