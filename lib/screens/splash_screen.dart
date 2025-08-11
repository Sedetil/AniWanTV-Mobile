import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'home_screen.dart';
import 'login_screen.dart';
import '../theme/app_theme.dart';
import '../services/api_service.dart';

class SplashScreen extends StatefulWidget {
  @override
  _SplashScreenState createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  final ApiService apiService = ApiService();
  late AnimationController _controller;
  late Animation<double> _animation;
  
  // Interstitial Ad variables
  InterstitialAd? _interstitialAd;
  int _numInterstitialLoadAttempts = 0;
  static const int maxFailedLoadAttempts = 3;

  @override
  void initState() {
    super.initState();

    // Load interstitial ad first
    _createInterstitialAd();

    // Setup animation
    _controller = AnimationController(
      duration: Duration(milliseconds: 1500),
      vsync: this,
    );

    _animation = CurvedAnimation(
      parent: _controller,
      curve: Curves.easeInOut,
    );

    _controller.forward();

    // Check auth status after animation
    _controller.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        _checkAuthStatus();
      }
    });
  }

  @override
  void dispose() {
    _interstitialAd?.dispose();
    _controller.dispose();
    super.dispose();
  }

  Future<void> _checkAuthStatus() async {
    // Bypass login check - always treat as logged in
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('isLoggedIn', true); // Set logged in to true

    // Add a small delay to ensure animation is complete
    await Future.delayed(Duration(milliseconds: 500));

    try {
      // Preload content for HomeScreen
      final anime = await apiService.fetchLatestAnime();
      final comics = await apiService.fetchLatestComics();
      final topAnime = await apiService.fetchTopAnime();

      // Process data for HomeScreen
      final featuredAnime = topAnime
          .take(4)
          .map((item) => {
                ...item,
                'type': 'anime',
              })
          .toList();

      final featuredComics = comics
          .take(4)
          .map((item) => {
                ...item,
                'type': 'comic',
              })
          .toList();

      final featuredContent = [...featuredAnime, ...featuredComics]..shuffle();

      // Store preloaded data for navigation
      _navigateWithPreloadedData(anime, comics, featuredContent);
    } catch (e) {
      // If loading fails, navigate without preloaded data
      _navigateWithPreloadedData(null, null, null);
    }
  }

  void _createInterstitialAd() {
    InterstitialAd.load(
      adUnitId: 'ca-app-pub-7591838535085655/2876470342', // Test ID
      request: AdRequest(),
      adLoadCallback: InterstitialAdLoadCallback(
        onAdLoaded: (InterstitialAd ad) {
          print('Interstitial ad loaded.');
          _interstitialAd = ad;
          _numInterstitialLoadAttempts = 0;
        },
        onAdFailedToLoad: (LoadAdError error) {
          print('Interstitial ad failed to load: $error');
          _numInterstitialLoadAttempts += 1;
          _interstitialAd = null;
          if (_numInterstitialLoadAttempts < maxFailedLoadAttempts) {
            _createInterstitialAd();
          }
        },
      ),
    );
  }

  void _showInterstitialAd(List<dynamic>? anime, List<dynamic>? comics,
      List<dynamic>? featuredContent) {
    if (_interstitialAd == null) {
      print('Warning: attempt to show interstitial before loaded.');
      _navigateToHome(anime, comics, featuredContent);
      return;
    }
    
    _interstitialAd!.fullScreenContentCallback = FullScreenContentCallback(
      onAdShowedFullScreenContent: (InterstitialAd ad) {
        print('Interstitial ad showed full screen content.');
      },
      onAdDismissedFullScreenContent: (InterstitialAd ad) {
        print('Interstitial ad dismissed.');
        ad.dispose();
        _navigateToHome(anime, comics, featuredContent);
      },
      onAdFailedToShowFullScreenContent: (InterstitialAd ad, AdError error) {
        print('Interstitial ad failed to show full screen content: $error');
        ad.dispose();
        _navigateToHome(anime, comics, featuredContent);
      },
    );
    
    _interstitialAd!.show();
    _interstitialAd = null;
  }

  void _navigateWithPreloadedData(List<dynamic>? anime, List<dynamic>? comics,
      List<dynamic>? featuredContent) {
    // Show interstitial ad before navigation
    _showInterstitialAd(anime, comics, featuredContent);
  }

  void _navigateToHome(List<dynamic>? anime, List<dynamic>? comics,
      List<dynamic>? featuredContent) {
    if (mounted) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (context) => HomeScreen(
            preloadedAnime: anime,
            preloadedComics: comics,
            preloadedFeaturedContent: featuredContent,
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      body: Center(
        child: FadeTransition(
          opacity: _animation,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Logo
              Container(
                width: 150,
                height: 150,
                decoration: BoxDecoration(
                  color: Colors.white,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: AppTheme.primaryColor.withOpacity(0.5),
                      blurRadius: 20,
                      spreadRadius: 5,
                    ),
                  ],
                ),
                child: Icon(
                  Icons.play_circle_fill,
                  size: 100,
                  color: AppTheme.primaryColor,
                ),
              ),
              SizedBox(height: 32),
              // App Name
              Text(
                'AniWanTV',
                style: TextStyle(
                  fontSize: 42,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                  letterSpacing: 1.5,
                ),
              ),
              SizedBox(height: 8),
              Text(
                'Watch Anime & Read Komik',
                style: TextStyle(
                  fontSize: 16,
                  color: AppTheme.textSecondaryColor,
                  letterSpacing: 0.5,
                ),
              ),
              SizedBox(height: 48),
              // Loading indicator
              SizedBox(
                width: 40,
                height: 40,
                child: CircularProgressIndicator(
                  valueColor:
                      AlwaysStoppedAnimation<Color>(AppTheme.primaryColor),
                  strokeWidth: 3,
                ),
              ),
              // Removed loading text for cleaner UI
            ],
          ),
        ),
      ),
    );
  }
}
