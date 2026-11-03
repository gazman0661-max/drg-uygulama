import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart' hide Text;
import '../l10n/app_text.dart';
import 'package:flutter_compass/flutter_compass.dart';
import 'package:provider/provider.dart';

import '../state/app_state.dart';
import '../theme/app_theme.dart';

class QiblaPage extends StatefulWidget {
  const QiblaPage({super.key, this.active = true});

  /// Sekme görünürken true. Pil tüketmemesi için pusula sensörü sadece
  /// bu sekme açıkken dinlenir.
  final bool active;

  @override
  State<QiblaPage> createState() => _QiblaPageState();
}

class _QiblaPageState extends State<QiblaPage> {
  StreamSubscription<CompassEvent>? _sub;
  double _heading = 0; // telefonun baktığı yön (kuzeyden, derece)
  bool _hasHeading = false;
  bool _sensorAvailable = true;

  @override
  void initState() {
    super.initState();
    if (widget.active) _startCompass();
  }

  @override
  void didUpdateWidget(QiblaPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.active && !oldWidget.active) _startCompass();
    if (!widget.active && oldWidget.active) _stopCompass();
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }

  void _startCompass() {
    if (_sub != null) return;
    final stream = FlutterCompass.events;
    if (stream == null) {
      _sensorAvailable = false;
      return;
    }
    _sub = stream.listen((event) {
      final h = event.heading;
      if (h == null) return;
      final target = (h % 360 + 360) % 360;
      if (!_hasHeading) {
        _heading = target;
        _hasHeading = true;
      } else {
        // Titremeyi azaltmak için yumuşatma; 359° → 0° geçişi en kısa yoldan.
        final delta = ((target - _heading + 540) % 360) - 180;
        _heading = (_heading + delta * 0.3 + 360) % 360;
      }
      if (mounted) setState(() {});
    });
  }

  void _stopCompass() {
    _sub?.cancel();
    _sub = null;
    _hasHeading = false;
  }

  double _rad(double deg) => deg * math.pi / 180;

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final heading = _hasHeading ? _heading : 0.0;
    final qibla = state.qiblaDeg;
    final diff = ((qibla - heading + 540) % 360) - 180;
    final aligned = _hasHeading && state.qiblaKnown && diff.abs() <= 5;
    final ringColor = aligned ? const Color(0xFF2E7D32) : AppColors.gold;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(18),
      child: Column(
        children: [
          const Text('Kıble Pusulası',
              style: TextStyle(
                  fontFamily: 'Amiri', fontSize: 22, color: AppColors.ink)),
          const SizedBox(height: 18),
          SizedBox(
            width: 260,
            height: 260,
            child: Stack(
              alignment: Alignment.center,
              children: [
                Container(
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(color: ringColor, width: 4),
                    gradient: RadialGradient(
                      center: const Alignment(0, -0.2),
                      colors: [AppColors.ivory, AppColors.paper],
                    ),
                    boxShadow: const [
                      BoxShadow(
                          color: Color.fromRGBO(13, 43, 39, 0.12),
                          blurRadius: 20,
                          offset: Offset(0, 6)),
                    ],
                  ),
                ),
                // Kuzey (K) işareti: sensör aktifken telefonla ters yönde döner.
                Transform.rotate(
                  angle: _rad(-heading),
                  child: const Align(
                    alignment: Alignment.topCenter,
                    child: Padding(
                      padding: EdgeInsets.only(top: 8),
                      child: Text('K',
                          style: TextStyle(
                              fontWeight: FontWeight.w700,
                              color: AppColors.danger)),
                    ),
                  ),
                ),
                // Kıble oku: Kabe simgesi dairenin kenarında, ok merkezden ona uzanır.
                if (state.qiblaKnown)
                  Transform.rotate(
                    angle: _rad(qibla - heading),
                    child: Align(
                      alignment: Alignment.topCenter,
                      child: Padding(
                        padding: const EdgeInsets.only(top: 24),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Text('🕋', style: TextStyle(fontSize: 30)),
                            const SizedBox(height: 4),
                            Container(
                              width: 5,
                              height: 80,
                              decoration: BoxDecoration(
                                color: ringColor,
                                borderRadius: BorderRadius.circular(3),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                Container(
                  width: 14,
                  height: 14,
                  decoration: const BoxDecoration(
                      color: AppColors.deep, shape: BoxShape.circle),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          if (state.qiblaKnown) ...[
            Text(
              'Kıble yönü: kuzeyden ${qibla.toStringAsFixed(1)}° (saat yönünde)',
              style: const TextStyle(
                  fontWeight: FontWeight.w600, color: AppColors.ink),
            ),
            if (aligned)
              const Padding(
                padding: EdgeInsets.only(top: 6),
                child: Text('✓ Kıble yönündesiniz',
                    style: TextStyle(
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF2E7D32))),
              ),
          ],
          if (state.locationNote.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(
                state.locationNote,
                textAlign: TextAlign.center,
                style: TextStyle(
                    fontSize: 12.5,
                    color: state.qiblaKnown ? AppColors.ink : AppColors.danger),
              ),
            ),
          if (!state.gpsActive)
            TextButton.icon(
              onPressed: () =>
                  state.requestLocation(openSettingsIfBlocked: true),
              icon: const Icon(Icons.my_location, size: 18),
              label: const Text('Konumumu kullan'),
              style: TextButton.styleFrom(foregroundColor: AppColors.ink),
            ),
          if (!_sensorAvailable)
            const Padding(
              padding: EdgeInsets.only(top: 8),
              child: Text(
                'Bu cihazda pusula sensörü bulunamadı; kıble açısı sadece sayısal ve kuzey yukarıda gösteriliyor.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 12, color: AppColors.danger),
              ),
            ),
          const SizedBox(height: 10),
          const Text(
            'Telefonu düz tutup yatay olarak çevirin; Kabe simgesi telefonun üst kenarına geldiğinde kıbleye dönmüşsünüz demektir. Pusula hatalı görünürse telefonu havada 8 çizer gibi hareket ettirerek kalibre edin.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 12, color: AppColors.ink),
          ),
        ],
      ),
    );
  }
}
