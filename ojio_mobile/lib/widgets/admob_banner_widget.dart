import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import '../core/admob_config.dart';
import '../services/admob_service.dart';

class AdMobBannerWidget extends StatefulWidget {
  final AdSize adSize;
  final bool showLabel;

  const AdMobBannerWidget({
    super.key,
    this.adSize = AdSize.banner,
    this.showLabel = true,
  });

  @override
  State<AdMobBannerWidget> createState() => _AdMobBannerWidgetState();
}

class _AdMobBannerWidgetState extends State<AdMobBannerWidget> {
  BannerAd? _bannerAd;
  AdSize? _displaySize;
  int? _requestedWidth;
  Orientation? _requestedOrientation;
  int _loadGeneration = 0;
  bool _failed = false;

  @override
  void initState() {
    super.initState();
    AdMobService.instance.adsReady.addListener(_onAdsReadinessChanged);
  }

  void _onAdsReadinessChanged() {
    if (!mounted) return;
    final previousAd = _bannerAd;
    setState(() {
      _loadGeneration++;
      _bannerAd = null;
      _displaySize = null;
      _requestedWidth = null;
      _requestedOrientation = null;
      _failed = false;
    });
    unawaited(_disposeAd(previousAd));
  }

  bool _isCurrent(int generation, [Ad? ad]) =>
      mounted &&
      AdMobService.instance.adsReady.value &&
      generation == _loadGeneration &&
      (ad == null || ad == _bannerAd);

  Future<void> _disposeAd(Ad? ad) async {
    try {
      await ad?.dispose();
    } catch (error) {
      debugPrint('AdMob dispose failed: $error');
    }
  }

  void _failAd(Ad ad, int generation) {
    if (!_isCurrent(generation, ad)) return;
    setState(() {
      _bannerAd = null;
      _displaySize = null;
      _failed = true;
    });
    unawaited(_disposeAd(ad));
  }

  Future<void> _loadBannerAd(int width, int generation) async {
    if (!_isCurrent(generation)) return;
    final previousAd = _bannerAd;
    setState(() {
      _bannerAd = null;
      _displaySize = null;
    });
    await _disposeAd(previousAd);
    if (!_isCurrent(generation)) return;
    final ad = BannerAd(
      adUnitId: AdMobConfig.bannerId,
      size: AdSize.getInlineAdaptiveBannerAdSize(width, widget.adSize.height),
      request: const AdRequest(),
      listener: BannerAdListener(
        onAdLoaded: (loadedAd) async {
          if (!_isCurrent(generation, loadedAd)) return;
          try {
            final size = await (loadedAd as BannerAd).getPlatformAdSize();
            if (!_isCurrent(generation, loadedAd)) return;
            if (size == null ||
                size.width > width ||
                size.height <= 0 ||
                size.height > widget.adSize.height) {
              _failAd(loadedAd, generation);
              return;
            }
            setState(() {
              _displaySize = size;
            });
          } catch (error) {
            debugPrint('AdMob size unavailable: $error');
            _failAd(loadedAd, generation);
          }
        },
        onAdFailedToLoad: (failedAd, error) {
          debugPrint('AdMob Banner failed to load: ${error.message}');
          _failAd(failedAd, generation);
        },
      ),
    );
    _bannerAd = ad;
    try {
      await ad.load();
    } catch (error) {
      debugPrint('AdMob unavailable: $error');
      _failAd(ad, generation);
    }
  }

  @override
  void dispose() {
    AdMobService.instance.adsReady.removeListener(_onAdsReadinessChanged);
    _loadGeneration++;
    unawaited(_disposeAd(_bannerAd));
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!AdMobConfig.isSupported || !AdMobService.instance.adsReady.value) {
      return const SizedBox.shrink();
    }
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth.isFinite
            ? constraints.maxWidth.floor()
            : MediaQuery.sizeOf(context).width.floor();
        if (width <= 0) return const SizedBox.shrink();
        final orientation = MediaQuery.orientationOf(context);
        if (_requestedWidth != width || _requestedOrientation != orientation) {
          _requestedWidth = width;
          _requestedOrientation = orientation;
          _displaySize = null;
          _failed = false;
          final generation = ++_loadGeneration;
          WidgetsBinding.instance.addPostFrameCallback((_) {
            unawaited(_loadBannerAd(width, generation));
          });
        }
        if (_failed) return const SizedBox.shrink();
        final size = _displaySize;
        final ad = _bannerAd;
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (widget.showLabel)
                Padding(
                  padding: const EdgeInsets.only(bottom: 2),
                  child: Text(
                    'ADVERTISEMENT',
                    style: GoogleFonts.outfit(
                      fontSize: 9,
                      color: const Color(0xFF94A3B8),
                      letterSpacing: 0.8,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              Container(
                width: size?.width.toDouble() ?? width.toDouble(),
                height: size?.height.toDouble() ?? 50,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(6),
                  border: size == null
                      ? Border.all(color: const Color(0xFFE2E8F0))
                      : null,
                ),
                child: size != null && ad != null
                    ? AdWidget(key: ObjectKey(ad), ad: ad)
                    : const Center(
                        child: Text(
                          'Loading ad…',
                          style: TextStyle(
                            fontSize: 11,
                            color: Color(0xFF94A3B8),
                          ),
                        ),
                      ),
              ),
            ],
          ),
        );
      },
    );
  }
}
