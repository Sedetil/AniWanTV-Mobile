import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

import 'dart:io';
import 'package:flutter/foundation.dart';

class AdService {
  static RewardedAd? _rewardedAd;
  static bool _isAdLoading = false;
  static int _adLoadAttempts = 0;
  static const int _maxAdLoadAttempts = 3;
  static const String _rewardedAdUnitId = 'ca-app-pub-7591838535085655/4184612382';
  static const String _interstitialAdUnitId = 'ca-app-pub-7591838535085655/2876470342';
  static const String _bannerBottomNav = 'ca-app-pub-7591838535085655/8350682205';
  static BannerAd? _bottomNavBanner;

  static bool get isMobileAdsSupported {
    if (kIsWeb) return false;
    return Platform.isAndroid || Platform.isIOS;
  }

  static Future<void> loadRewardedAd({bool forceReload = false}) async {
    if (!isMobileAdsSupported) return;
    if (_isAdLoading && !forceReload) return;

    _isAdLoading = true;
    _adLoadAttempts++;

    await RewardedAd.load(
      adUnitId: _rewardedAdUnitId,
      request: AdRequest(),
      rewardedAdLoadCallback: RewardedAdLoadCallback(
        onAdLoaded: (RewardedAd ad) {
          _rewardedAd = ad;
          _isAdLoading = false;
          _adLoadAttempts = 0;
          print('RewardedAd loaded successfully');
        },
        onAdFailedToLoad: (LoadAdError error) async {
          _rewardedAd = null;
          _isAdLoading = false;
          print('RewardedAd failed to load: $error');

          if (_adLoadAttempts < _maxAdLoadAttempts) {
            print('Retrying to load ad... Attempt ${_adLoadAttempts + 1}');
            await Future.delayed(Duration(seconds: 2));
            await loadRewardedAd(forceReload: true);
          } else {
            _adLoadAttempts = 0;
          }
        },
      ),
    );
  }

  static Future<void> showRewardedAd(
    BuildContext context, {
    required VoidCallback onReward,
    bool setLandscapeOrientation = false,
  }) async {
    if (!isMobileAdsSupported) {
      onReward();
      return;
    }

    if (_rewardedAd == null || _isAdLoading) {
      try {
        await loadRewardedAd(forceReload: true);
      } catch (e) {
        print('Error loading rewarded ad: $e');
        onReward();
        return;
      }
    }

    if (_rewardedAd == null) {
      print('Rewarded ad is null, proceeding without ad');
      onReward();
      return;
    }

    // Set orientation before showing ad if requested
    if (setLandscapeOrientation) {
      await SystemChrome.setPreferredOrientations([
        DeviceOrientation.landscapeLeft,
        DeviceOrientation.landscapeRight,
      ]);
      await SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersive);
    } else {
      await SystemChrome.setPreferredOrientations([
        DeviceOrientation.portraitUp,
        DeviceOrientation.portraitDown,
      ]);
      await SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersive);
    }

    _rewardedAd!.fullScreenContentCallback = FullScreenContentCallback(
      onAdDismissedFullScreenContent: (RewardedAd ad) async {
        ad.dispose();
        _rewardedAd = null;
        
        // Restore system UI mode
        await SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
        
        // Reload ad for next use
        await loadRewardedAd(forceReload: true);
      },
      onAdFailedToShowFullScreenContent: (RewardedAd ad, AdError error) async {
        ad.dispose();
        _rewardedAd = null;
        print('RewardedAd failed to show: $error');
        
        // Restore system UI mode
        await SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
        
        onReward();
        await loadRewardedAd(forceReload: true);
      },
    );

    try {
      await _rewardedAd!.show(
        onUserEarnedReward: (AdWithoutView ad, RewardItem reward) {
          onReward();
        },
      );
    } catch (e) {
      print('Error showing rewarded ad: $e');
      await SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
      onReward();
    }
  }

  static InterstitialAd? _interstitialAd;
  static int _interstitialLoadAttempts = 0;
  static const int _maxInterstitialLoadAttempts = 3;

  static Future<void> loadInterstitialAd() async {
    if (!isMobileAdsSupported) return;

    await InterstitialAd.load(
      adUnitId: _interstitialAdUnitId,
      request: AdRequest(),
      adLoadCallback: InterstitialAdLoadCallback(
        onAdLoaded: (InterstitialAd ad) {
          _interstitialAd = ad;
          _interstitialLoadAttempts = 0;
          print('Interstitial ad loaded');
        },
        onAdFailedToLoad: (LoadAdError error) {
          _interstitialAd = null;
          _interstitialLoadAttempts++;
          print('Interstitial ad failed to load: $error');
          
          if (_interstitialLoadAttempts < _maxInterstitialLoadAttempts) {
            loadInterstitialAd();
          }
        },
      ),
    );
  }

  static Future<void> showInterstitialAd({
    required VoidCallback onAdDismissed,
  }) async {
    if (!isMobileAdsSupported) {
      onAdDismissed();
      return;
    }

    if (_interstitialAd == null) {
      print('Warning: attempt to show interstitial before loaded.');
      onAdDismissed();
      return;
    }
    
    _interstitialAd!.fullScreenContentCallback = FullScreenContentCallback(
      onAdShowedFullScreenContent: (InterstitialAd ad) {
        print('Interstitial ad showed full screen content.');
      },
      onAdDismissedFullScreenContent: (InterstitialAd ad) {
        print('Interstitial ad dismissed.');
        ad.dispose();
        _interstitialAd = null;
        onAdDismissed();
        loadInterstitialAd(); // Preload next ad
      },
      onAdFailedToShowFullScreenContent: (InterstitialAd ad, AdError error) {
        print('Interstitial ad failed to show full screen content: $error');
        ad.dispose();
        _interstitialAd = null;
        onAdDismissed();
        loadInterstitialAd(); // Preload next ad
      },
    );
    
    _interstitialAd!.show();
    _interstitialAd = null;
  }

  static void dispose() {
    _rewardedAd?.dispose();
    _rewardedAd = null;
    _interstitialAd?.dispose();
    _interstitialAd = null;
    _bottomNavBanner?.dispose();
    _bottomNavBanner = null;
  }

  static Future<void> loadBottomNavBanner({VoidCallback? onLoaded}) async {
    if (!isMobileAdsSupported) return;

    _bottomNavBanner?.dispose();
    _bottomNavBanner = BannerAd(
      adUnitId: _bannerBottomNav,
      request: AdRequest(),
      size: AdSize.banner,
      listener: BannerAdListener(
        onAdLoaded: (Ad ad) {
          onLoaded?.call();
        },
        onAdFailedToLoad: (Ad ad, LoadAdError error) {
          ad.dispose();
          _bottomNavBanner = null;
        },
      ),
    );
    await _bottomNavBanner!.load();
  }

  static BannerAd? get bottomNavBanner => _bottomNavBanner;
}