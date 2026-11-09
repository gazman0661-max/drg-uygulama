import 'dart:async';

import 'package:flutter/material.dart';
import 'package:unity_levelplay_mediation/unity_levelplay_mediation.dart';

import '../config/ads_config.dart';
import '../services/ads_service.dart';
import '../services/log_service.dart';

/// LevelPlay banner reklamı. Reklamlar kapalıysa (anahtarlar boş) ya da SDK
/// henüz hazır değilse hiçbir yer kaplamaz.
///
/// [safeArea]: true ise alt sistem çubuğu boşluğunu kendisi bırakır
/// (Scaffold.bottomNavigationBar için). Liste içinde kullanırken false verin.
class AdBanner extends StatefulWidget {
  const AdBanner({super.key, this.safeArea = true});

  final bool safeArea;

  @override
  State<AdBanner> createState() => _AdBannerState();
}

class _AdBannerState extends State<AdBanner> with LevelPlayBannerAdViewListener {
  final GlobalKey<LevelPlayBannerAdViewState> _key =
      GlobalKey<LevelPlayBannerAdViewState>();
  final LevelPlayAdSize _size = LevelPlayAdSize.BANNER;
  bool _requested = false;

  @override
  void initState() {
    super.initState();
    AdsService.instance.addListener(_onService);
  }

  void _onService() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    AdsService.instance.removeListener(_onService);
    try {
      _key.currentState?.destroy();
    } catch (_) {}
    super.dispose();
  }

  void _load() {
    try {
      _key.currentState?.loadAd();
    } catch (e, st) {
      AppLog.e('reklam', 'banner yukleme hatasi: $e', st);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!AdsConfig.bannerEnabled || !AdsService.instance.ready) {
      return const SizedBox.shrink();
    }
    if (!_requested) {
      _requested = true;
      WidgetsBinding.instance.addPostFrameCallback((_) => _load());
    }
    final banner = SizedBox(
      width: double.infinity,
      height: _size.height.toDouble(),
      child: Center(
        child: SizedBox(
          width: _size.width.toDouble(),
          height: _size.height.toDouble(),
          child: LevelPlayBannerAdView(
            key: _key,
            adUnitId: AdsConfig.bannerAdUnitId,
            adSize: _size,
            listener: this,
          ),
        ),
      ),
    );
    return widget.safeArea ? SafeArea(top: false, child: banner) : banner;
  }

  // ---- LevelPlayBannerAdViewListener ----
  @override
  void onAdLoaded(LevelPlayAdInfo adInfo) {}

  @override
  void onAdLoadFailed(LevelPlayAdError error) {
    AppLog.w('reklam', 'banner yuklenemedi: $error');
    Future.delayed(const Duration(seconds: 30), () {
      if (mounted) _load();
    });
  }

  @override
  void onAdDisplayed(LevelPlayAdInfo adInfo) {}

  @override
  void onAdDisplayFailed(LevelPlayAdInfo adInfo, LevelPlayAdError error) {
    AppLog.w('reklam', 'banner gosterilemedi: $error');
  }

  @override
  void onAdClicked(LevelPlayAdInfo adInfo) {}

  @override
  void onAdCollapsed(LevelPlayAdInfo adInfo) {}

  @override
  void onAdExpanded(LevelPlayAdInfo adInfo) {}

  @override
  void onAdLeftApplication(LevelPlayAdInfo adInfo) {}
}
