import 'package:flutter/material.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:provider/provider.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../premium/presentation/providers/premium_provider.dart';

/// A bounded banner that loads itself on mount and **reactively hides**
/// when the user becomes premium.
///
/// Per `docs/05_MONETIZATION.md`, banners only sit on library/list screens
/// — never over the player. The ad load is gated on
/// [PremiumProvider.showAds] so paying users never trigger a network ad
/// request at all.
class BannerAdView extends StatefulWidget {
  const BannerAdView({super.key, this.size = AdSize.banner});
  final AdSize size;

  @override
  State<BannerAdView> createState() => _BannerAdViewState();
}

class _BannerAdViewState extends State<BannerAdView> {
  BannerAd? _ad;
  bool _loaded = false;

  @override
  void initState() {
    super.initState();
    // Read once in initState — paying users never start an ad load.
    final showAds = context.read<PremiumProvider>().showAds;
    if (showAds) _load();
  }

  void _load() {
    _ad = BannerAd(
      size: widget.size,
      adUnitId: AppConstants.adUnitBanner,
      listener: BannerAdListener(
        onAdLoaded: (_) {
          if (mounted) setState(() => _loaded = true);
        },
        onAdFailedToLoad: (ad, _) {
          ad.dispose();
          if (mounted) {
            setState(() {
              _ad = null;
              _loaded = false;
            });
          }
        },
      ),
      request: const AdRequest(),
    )..load();
  }

  @override
  void dispose() {
    _ad?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Reactive: if entitlement flips mid-session, the banner hides on the
    // next rebuild.
    final showAds = context.select<PremiumProvider, bool>(
      (p) => p.showAds,
    );
    if (!showAds || !_loaded || _ad == null) {
      return const SizedBox.shrink();
    }
    return SizedBox(
      width: _ad!.size.width.toDouble(),
      height: _ad!.size.height.toDouble(),
      child: AdWidget(ad: _ad!),
    );
  }
}
