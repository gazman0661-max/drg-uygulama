import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// Açılış ekranı: koyu zümrüt zemin, ekranın ortasında taç görseli, üstünde
/// "Dergah-ı Kadirî" yazısı. Taç, Android'in yerel açılış ekranındaki
/// (launch_background.xml) 220 dp'lik tacla aynı boyut/konumdadır; böylece
/// yerel ekrandan Flutter ekranına geçerken taç yerinden oynamaz.
/// Dokunmayla / geri tuşuyla geçilemez; süre dolunca uygulama kendiliğinden
/// açılır (bkz. main.dart -> _SplashGate).
class SplashPage extends StatefulWidget {
  const SplashPage({super.key});

  @override
  State<SplashPage> createState() => _SplashPageState();
}

class _SplashPageState extends State<SplashPage>
    with SingleTickerProviderStateMixin {
  static const double _hat = 220;

  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1200),
  )..forward();

  late final Animation<double> _fade =
      CurvedAnimation(parent: _c, curve: Curves.easeOut);

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final w = MediaQuery.of(context).size.width;
    return PopScope(
      canPop: false, // geri tuşu ile geçilemez
      child: AbsorbPointer(
        // dokunmayla geçilemez
        child: Scaffold(
          backgroundColor: AppColors.deep,
          body: Stack(
            children: [
              // Taç: hemen görünür (yerel açılış ekranıyla aynı yerde)
              Center(
                child: Image.asset(
                  'assets/images/hat.png',
                  width: _hat,
                  height: _hat,
                  filterQuality: FilterQuality.high,
                ),
              ),
              // Başlık: tacın üstünde, yavaşça belirir
              Align(
                alignment: const Alignment(0, -0.42),
                child: FadeTransition(
                  opacity: _fade,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'Dergah-ı Kadirî',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontFamily: 'Amiri',
                          fontWeight: FontWeight.w700,
                          fontSize: w * 0.095,
                          color: AppColors.gold,
                          letterSpacing: 1.2,
                          shadows: const [
                            Shadow(
                              color: Color(0x66000000),
                              blurRadius: 12,
                              offset: Offset(0, 2),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 10),
                      Container(
                        width: w * 0.22,
                        height: 1.5,
                        color: AppColors.goldSoft.withValues(alpha: 0.7),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
