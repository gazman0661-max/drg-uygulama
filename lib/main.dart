import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import 'data/il_ilce_data.dart';
import 'pages/book_page.dart';
import 'pages/home_page.dart';
import 'pages/qibla_page.dart';
import 'pages/splash_page.dart';
import 'pages/sohbetler_page.dart';
import 'pages/times_page.dart';
import 'state/app_state.dart';
import 'theme/app_theme.dart';
import 'utils/turkish.dart';

void main() {
  runApp(const DergahApp());
}

class DergahApp extends StatelessWidget {
  const DergahApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      lazy: false, // vakitler/konum açılış ekranı sürerken yüklenmeye başlasın
      create: (_) => AppState()..init(),
      child: MaterialApp(
        title: 'Dergah-ı Kadirî - Ezan Vakti',
        debugShowCheckedModeBanner: false,
        theme: buildAppTheme(),
        home: const _SplashGate(),
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

  @override
  void initState() {
    super.initState();
    _timer = Timer(_duration, () {
      if (mounted) setState(() => _done = true);
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

  void _goto(int i) {
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
          IconButton(
            tooltip: 'Bildirimleri ve ezan sesini etkinleştir',
            icon: const Icon(Icons.notifications_active_outlined),
            onPressed: () async {
              final granted = await context
                  .read<AppState>()
                  .requestNotificationPermission();
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                  content: Text(granted
                      ? 'Bildirimler etkinleştirildi. Namaz vakti girdiğinde haber verilecek.'
                      : 'Bildirim izni verilmedi. Telefon ayarlarından Dergah-ı Kadirî için bildirimleri açabilirsiniz.'),
                ));
              }
            },
          ),
        ],
      ),
      body: IndexedStack(index: _index, children: pages),
      bottomNavigationBar: reading
          ? null
          : BottomNavigationBar(
        currentIndex: _index,
        onTap: _goto,
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.home), label: 'Ana Sayfa'),
          BottomNavigationBarItem(
              icon: Icon(Icons.mosque), label: 'Vakitler'),
          BottomNavigationBarItem(icon: Icon(Icons.explore), label: 'Kıble'),
          BottomNavigationBarItem(icon: Icon(Icons.menu_book), label: 'Kitap'),
          BottomNavigationBarItem(
              icon: Icon(Icons.video_collection), label: 'Sohbetler'),
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

    return PopScope(
      canPop: false,
      child: AlertDialog(
        title: const Text('Hoş geldiniz'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
                'Namaz vakitlerinin gösterileceği il ve ilçeyi seçin.'),
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
        actions: [
          ElevatedButton(
            onPressed: _kaydediliyor
                ? null
                : () async {
                    setState(() => _kaydediliyor = true);
                    await context
                        .read<AppState>()
                        .completeFirstLaunchSelection(_il, _ilce);
                    if (context.mounted) Navigator.of(context).pop();
                  },
            child: _kaydediliyor
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2))
                : const Text('Onayla'),
          ),
        ],
      ),
    );
  }
}
