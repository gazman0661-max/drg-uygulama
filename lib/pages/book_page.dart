import 'dart:async';

import 'package:flutter/material.dart' hide Text;
import '../l10n/app_text.dart';
import '../l10n/l10n.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../data/book_data.dart';
import '../theme/app_theme.dart';

/// Yazıyı büyütme düzeyleri (sayfa genişliğine göre). Büyük düzeylerde sayfa
/// yukarıdan aşağı kaydırılarak okunur.
const List<double> _zoomLevels = [1.0, 1.25, 1.5];
const List<String> _zoomLabels = ['Normal', 'Büyük', 'Çok büyük'];

/// Tam ekran kitap okuyucu.
///  - Sayfa tüm ekranı kaplar (üst/alt çubuklar gizlenir, ekran kenarına
///    dokunarak sayfa çevrilir, ortaya dokununca kontroller açılıp kapanır).
///  - "Aa" düğmesi yazıyı büyütür; seçim hatırlanır.
///  - İki parmakla/çift dokunarak da yakınlaştırılabilir.
///  - Son okunan sayfa hatırlanır.
class BookReaderPage extends StatefulWidget {
  const BookReaderPage({super.key, this.active = true, this.onExit});

  /// Kitap sekmesi görünürken true.
  final bool active;

  /// Geri okuna basılınca (tam ekrandan çıkış) çağrılır.
  final VoidCallback? onExit;

  @override
  State<BookReaderPage> createState() => _BookPageState();
}

class _BookPageState extends State<BookReaderPage> {
  static const _pageKey = 'dergah_kitap_son_sayfa';
  static const _zoomKey = 'dergah_kitap_buyutme';

  PageController? _controller;
  int _current = 0;
  int _zoomIdx = 0;
  bool _pinchZoomed = false; // parmakla ek yakınlaştırma yapıldı mı
  bool _overlay = true;
  Timer? _hideTimer;
  double? _dragValue;

  @override
  void initState() {
    super.initState();
    _restore();
    _bumpOverlay();
  }

  @override
  void didUpdateWidget(BookReaderPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.active && !oldWidget.active) _bumpOverlay();
  }

  @override
  void dispose() {
    _hideTimer?.cancel();
    _controller?.dispose();
    super.dispose();
  }

  Future<void> _restore() async {
    var page = 0;
    var zoom = 0;
    try {
      final prefs = await SharedPreferences.getInstance();
      page = (prefs.getInt(_pageKey) ?? 0).clamp(0, bookPageCount - 1).toInt();
      zoom = (prefs.getInt(_zoomKey) ?? 0).clamp(0, _zoomLevels.length - 1).toInt();
    } catch (_) {}
    if (!mounted) return;
    setState(() {
      _current = page;
      _zoomIdx = zoom;
      _controller = PageController(initialPage: page);
    });
  }

  Future<void> _save(String key, int value) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt(key, value);
    } catch (_) {}
  }

  // ---- kontrol çubuklarını göster/gizle ----
  void _bumpOverlay() {
    _hideTimer?.cancel();
    if (!_overlay && mounted) setState(() => _overlay = true);
    _hideTimer = Timer(const Duration(seconds: 4), () {
      if (mounted) setState(() => _overlay = false);
    });
  }

  void _toggleOverlay() {
    if (_overlay) {
      _hideTimer?.cancel();
      setState(() => _overlay = false);
    } else {
      _bumpOverlay();
    }
  }

  // ---- gezinme ----
  void _goTo(int page, {bool jump = false}) {
    final c = _controller;
    if (c == null || !c.hasClients) return;
    final p = page.clamp(0, bookPageCount - 1).toInt();
    if (p == _current) return;
    if (jump) {
      c.jumpToPage(p);
    } else {
      c.animateToPage(p,
          duration: const Duration(milliseconds: 250), curve: Curves.easeOut);
    }
  }

  void _cycleZoom() {
    setState(() {
      _zoomIdx = (_zoomIdx + 1) % _zoomLevels.length;
      _pinchZoomed = false;
    });
    _save(_zoomKey, _zoomIdx);
    _bumpOverlay();
  }

  Future<void> _askPage() async {
    _bumpOverlay();
    final ctrl = TextEditingController();
    final result = await showDialog<int>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Sayfaya git'),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          keyboardType: TextInputType.number,
          decoration: InputDecoration(hintText: '1 - $bookPageCount'),
          onSubmitted: (v) => Navigator.pop(ctx, int.tryParse(v)),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Vazgeç')),
          TextButton(
              onPressed: () => Navigator.pop(ctx, int.tryParse(ctrl.text)),
              child: const Text('Git')),
        ],
      ),
    );
    if (result != null && result >= 1 && result <= bookPageCount) {
      _goTo(result - 1, jump: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = _controller;
    if (c == null) return const ColoredBox(color: Colors.white);

    final pad = MediaQuery.of(context).padding;
    final locked = _zoomIdx > 0 || _pinchZoomed;

    return ColoredBox(
      color: Colors.white,
      child: Stack(
        children: [
          Positioned.fill(
            child: PageView.builder(
              controller: c,
              itemCount: bookPageCount,
              physics: locked
                  ? const NeverScrollableScrollPhysics()
                  : const PageScrollPhysics(),
              onPageChanged: (i) {
                setState(() {
                  _current = i;
                  _pinchZoomed = false;
                });
                _save(_pageKey, i);
                // Komşu sayfaları önceden yükle.
                for (final n in [i - 1, i + 1]) {
                  if (n >= 0 && n < bookPageCount) {
                    precacheImage(AssetImage(bookPageAsset(n)), context);
                  }
                }
              },
              itemBuilder: (context, i) => _ZoomablePage(
                asset: bookPageAsset(i),
                zoom: _zoomLevels[_zoomIdx],
                onTapCenter: _toggleOverlay,
                onPrev: () => _goTo(_current - 1),
                onNext: () => _goTo(_current + 1),
                onPinchZoom: (z) {
                  if (z != _pinchZoomed && i == _current) {
                    setState(() => _pinchZoomed = z);
                  }
                },
              ),
            ),
          ),
          // Üst çubuk
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: _OverlayFade(
              visible: _overlay,
              onTouch: _bumpOverlay,
              child: Container(
                padding: EdgeInsets.fromLTRB(4, pad.top + 4, 8, 6),
                decoration: const BoxDecoration(
                  color: Color.fromRGBO(255, 255, 255, 0.94),
                  boxShadow: [
                    BoxShadow(color: Color(0x33000000), blurRadius: 6)
                  ],
                ),
                child: Row(
                  children: [
                    IconButton(
                      tooltip: tr('Ana sayfaya dön'),
                      onPressed: widget.onExit,
                      icon: const Icon(Icons.arrow_back),
                    ),
                    Expanded(
                      child: Center(
                        child: InkWell(
                          onTap: _askPage,
                          borderRadius: BorderRadius.circular(20),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 14, vertical: 6),
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(color: AppColors.goldSoft),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  'Sayfa ${_current + 1} / $bookPageCount',
                                  style: const TextStyle(
                                      fontFamily: 'Amiri',
                                      fontSize: 19,
                                      color: AppColors.ink),
                                ),
                                const SizedBox(width: 8),
                                const Icon(Icons.search,
                                    size: 22, color: AppColors.ink),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                    TextButton.icon(
                      onPressed: _cycleZoom,
                      icon: const Icon(Icons.text_increase),
                      label: Text(_zoomLabels[_zoomIdx]),
                    ),
                  ],
                ),
              ),
            ),
          ),
          // Alt çubuk
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: _OverlayFade(
              visible: _overlay,
              onTouch: _bumpOverlay,
              child: Container(
                padding: EdgeInsets.fromLTRB(4, 4, 4, pad.bottom + 8),
                decoration: const BoxDecoration(
                  color: Color.fromRGBO(255, 255, 255, 0.94),
                  boxShadow: [
                    BoxShadow(color: Color(0x33000000), blurRadius: 6)
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      children: [
                        IconButton(
                          tooltip: tr('Önceki sayfa'),
                          iconSize: 30,
                          onPressed:
                              _current > 0 ? () => _goTo(_current - 1) : null,
                          icon: const Icon(Icons.chevron_left),
                        ),
                        Expanded(
                          child: Slider(
                            min: 1,
                            max: bookPageCount.toDouble(),
                            divisions: bookPageCount - 1,
                            activeColor: AppColors.gold,
                            value: (_dragValue ?? (_current + 1).toDouble())
                                .clamp(1.0, bookPageCount.toDouble())
                                .toDouble(),
                            onChanged: (v) => setState(() => _dragValue = v),
                            onChangeEnd: (v) {
                              setState(() => _dragValue = null);
                              _goTo(v.round() - 1, jump: true);
                            },
                          ),
                        ),
                        IconButton(
                          tooltip: tr('Sonraki sayfa'),
                          iconSize: 30,
                          onPressed: _current < bookPageCount - 1
                              ? () => _goTo(_current + 1)
                              : null,
                          icon: const Icon(Icons.chevron_right),
                        ),
                      ],
                    ),
                    const Text(
                      'Sayfa çevirmek için ekranın sağ/sol kenarına dokunun veya kaydırın. Ortaya dokunarak bu çubukları kapatın.',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 11, color: AppColors.ink),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _OverlayFade extends StatelessWidget {
  const _OverlayFade({
    required this.visible,
    required this.onTouch,
    required this.child,
  });

  final bool visible;
  final VoidCallback onTouch;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      ignoring: !visible,
      child: AnimatedOpacity(
        opacity: visible ? 1 : 0,
        duration: const Duration(milliseconds: 200),
        child: Listener(
          onPointerDown: (_) => onTouch(),
          child: child,
        ),
      ),
    );
  }
}

/// Tek sayfa: tam genişlikte gösterilir; seçilen büyütme düzeyine göre
/// yakınlaşır, parmakla kaydırılıp yakınlaştırılabilir.
class _ZoomablePage extends StatefulWidget {
  const _ZoomablePage({
    required this.asset,
    required this.zoom,
    required this.onTapCenter,
    required this.onPrev,
    required this.onNext,
    required this.onPinchZoom,
  });

  final String asset;
  final double zoom;
  final VoidCallback onTapCenter;
  final VoidCallback onPrev;
  final VoidCallback onNext;
  final ValueChanged<bool> onPinchZoom;

  @override
  State<_ZoomablePage> createState() => _ZoomablePageState();
}

class _ZoomablePageState extends State<_ZoomablePage> {
  final TransformationController _tc = TransformationController();
  Size _viewport = Size.zero;
  double _appliedZoom = -1;
  Offset _doubleTapPos = Offset.zero;

  @override
  void dispose() {
    _tc.dispose();
    super.dispose();
  }

  Matrix4 _matrix(double s, double tx, double ty) =>
      Matrix4(s, 0, 0, 0, 0, s, 0, 0, 0, 0, 1, 0, tx, ty, 0, 1);

  /// Seçilen büyütme düzeyini uygula: yatayda ortalı, dikeyde sayfanın üstü.
  void _applyLevel(Size vp) {
    final s = widget.zoom;
    _tc.value =
        s <= 1.0 ? Matrix4.identity() : _matrix(s, -vp.width * (s - 1) / 2, 0);
    _appliedZoom = s;
    _viewport = vp;
  }

  void _doubleTap() {
    final s = _tc.value.getMaxScaleOnAxis();
    if (s > 1.02) {
      _tc.value = Matrix4.identity();
      widget.onPinchZoom(false);
    } else {
      const sc = 2.2;
      final p = _doubleTapPos;
      _tc.value = _matrix(sc, -p.dx * (sc - 1), -p.dy * (sc - 1));
      widget.onPinchZoom(true);
    }
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, box) {
        final vp = Size(box.maxWidth, box.maxHeight);
        if (_appliedZoom != widget.zoom || _viewport != vp) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) _applyLevel(vp);
          });
        }
        return GestureDetector(
          behavior: HitTestBehavior.opaque,
          onDoubleTapDown: (d) => _doubleTapPos = d.localPosition,
          onDoubleTap: _doubleTap,
          onTapUp: (d) {
            final x = d.localPosition.dx / vp.width;
            if (x < 0.22) {
              widget.onPrev();
            } else if (x > 0.78) {
              widget.onNext();
            } else {
              widget.onTapCenter();
            }
          },
          child: InteractiveViewer(
            transformationController: _tc,
            minScale: 1,
            maxScale: 5,
            onInteractionEnd: (_) => widget.onPinchZoom(
                _tc.value.getMaxScaleOnAxis() > widget.zoom + 0.05),
            child: SizedBox(
              width: vp.width,
              height: vp.height,
              child: Align(
                alignment:
                    widget.zoom > 1 ? Alignment.topCenter : Alignment.center,
                child: Image.asset(
                  widget.asset,
                  fit: BoxFit.contain,
                  filterQuality: FilterQuality.medium,
                  errorBuilder: (_, __, ___) => const Padding(
                    padding: EdgeInsets.all(24),
                    child: Text('Sayfa görüntüsü bulunamadı.'),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
