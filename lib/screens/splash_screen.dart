import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:provider/provider.dart';
import 'package:lottie/lottie.dart';
import 'home_screen.dart';
import 'login_screen.dart';
import 'landing_screen.dart';
import '../theme/app_theme.dart';
import '../services/api_service.dart';
import '../services/ad_service.dart';
import '../providers/app_state_provider.dart';

class SplashScreen extends StatefulWidget {
  @override
  _SplashScreenState createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;
  
  // AdService will handle ads

  @override
  void initState() {
    super.initState();

    // Load interstitial ad first
    AdService.loadInterstitialAd();

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

    // Initialize AppStateProvider
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Provider.of<AppStateProvider>(context, listen: false).initialize();
    });

    // Check auth status after animation
    _controller.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        _checkAuthStatus();
      }
    });
  }

  @override
  void dispose() {
    AdService.dispose();
    _controller.dispose();
    super.dispose();
  }

  Future<void> _checkAuthStatus() async {
    // Initialize AppStateProvider and check login status
    final appStateProvider = Provider.of<AppStateProvider>(context, listen: false);
    await appStateProvider.initialize();
    final isLoggedIn = appStateProvider.isLoggedIn;

    // Add a small delay to ensure animation is complete
    await Future.delayed(Duration(milliseconds: 500));

    if (!isLoggedIn) {
      // If not logged in, navigate to login screen
      if (mounted) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => const LandingScreen()),
        );
      }
      return;
    }

    try {
      // Preload content for HomeScreen
      final anime = await ApiService.fetchLatestAnime();
      final comics = await ApiService.fetchLatestComics();
      final topAnime = await ApiService.fetchTopAnime();

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


  void _showInterstitialAd(List<dynamic>? anime, List<dynamic>? comics,
      List<dynamic>? featuredContent) {
    AdService.showInterstitialAd(
      onAdDismissed: () => _navigateToHome(anime, comics, featuredContent),
    );
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
              // Loading Animation
              Lottie.asset(
                'assets/animations/loading_animation.json',
                width: 100,
                height: 100,
                fit: BoxFit.contain,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
