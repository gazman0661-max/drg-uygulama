import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// Açılış ekranı: koyu zümrüt zemin, üstte "Dergah-ı Kadirî" yazısı,
/// altta taç görseli. Dokunmayla / geri tuşuyla geçilemez; süre dolunca
/// uygulama kendiliğinden açılır (bkz. main.dart -> _SplashGate).
class SplashPage extends StatefulWidget {
  const SplashPage({super.key});

  @override
  State<SplashPage> createState() => _SplashPageState();
}

class _SplashPageState extends State<SplashPage>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1400),
  )..forward();

  late final Animation<double> _fade =
      CurvedAnimation(parent: _c, curve: Curves.easeOut);
  late final Animation<double> _scale =
      Tween<double>(begin: 0.92, end: 1.0).animate(_fade);

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
          body: SafeArea(
            child: Center(
              child: FadeTransition(
                opacity: _fade,
                child: ScaleTransition(
                  scale: _scale,
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
                      SizedBox(height: w * 0.08),
                      Image.asset(
                        'assets/images/hat.png',
                        width: w * 0.62,
                        height: w * 0.62,
                        filterQuality: FilterQuality.high,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
