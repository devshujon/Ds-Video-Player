import 'dart:async';

import 'package:flutter/material.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

import '../../../../core/constants/app_constants.dart';

/// Opt-in rewarded ad. Strictly user-initiated; never auto-fired.
///
/// Loads the ad on tap, shows it, and invokes [onReward] exactly once when
/// the user earns the reward. Errors surface as a SnackBar; cancels do
/// nothing (no reward, no callback).
class RewardedUnlockButton extends StatefulWidget {
  const RewardedUnlockButton({
    super.key,
    required this.label,
    required this.onReward,
  });

  final String label;
  final VoidCallback onReward;

  @override
  State<RewardedUnlockButton> createState() => _RewardedUnlockButtonState();
}

class _RewardedUnlockButtonState extends State<RewardedUnlockButton> {
  bool _busy = false;

  Future<RewardedAd?> _loadAd() {
    final completer = Completer<RewardedAd?>();
    RewardedAd.load(
      adUnitId: AppConstants.adUnitRewarded,
      request: const AdRequest(),
      rewardedAdLoadCallback: RewardedAdLoadCallback(
        onAdLoaded: (ad) {
          if (!completer.isCompleted) completer.complete(ad);
        },
        onAdFailedToLoad: (_) {
          if (!completer.isCompleted) completer.complete(null);
        },
      ),
    );
    return completer.future;
  }

  Future<void> _watch() async {
    setState(() => _busy = true);
    final ad = await _loadAd();
    if (!mounted) {
      ad?.dispose();
      return;
    }
    if (ad == null) {
      setState(() => _busy = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Ad unavailable — try again later')),
      );
      return;
    }
    var rewarded = false;
    ad.fullScreenContentCallback = FullScreenContentCallback(
      onAdDismissedFullScreenContent: (ad) {
        ad.dispose();
        if (mounted) setState(() => _busy = false);
      },
      onAdFailedToShowFullScreenContent: (ad, _) {
        ad.dispose();
        if (mounted) setState(() => _busy = false);
      },
    );
    await ad.show(onUserEarnedReward: (_, __) {
      if (!rewarded) {
        rewarded = true;
        widget.onReward();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return OutlinedButton.icon(
      icon: _busy
          ? const SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : const Icon(Icons.play_circle_outline),
      label: Text(widget.label),
      onPressed: _busy ? null : _watch,
    );
  }
}
