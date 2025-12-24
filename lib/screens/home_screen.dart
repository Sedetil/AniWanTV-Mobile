import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../theme/app_theme.dart';
import '../widgets/custom_bottom_nav_bar.dart';
import '../widgets/update_dialog.dart';
import '../services/app_version_service.dart';
import '../services/ad_service.dart';
import 'home_content.dart';
import 'search_screen.dart';
import 'explore_screen.dart';
import 'favorites_screen.dart';
import 'profile_screen.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:window_manager/window_manager.dart';

class HomeScreen extends StatefulWidget {
  final List<dynamic>? preloadedAnime;
  final List<dynamic>? preloadedComics;
  final List<dynamic>? preloadedFeaturedContent;

  const HomeScreen({
    Key? key,
    this.preloadedAnime,
    this.preloadedComics,
    this.preloadedFeaturedContent,
  }) : super(key: key);

  @override
  _HomeScreenState createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with SingleTickerProviderStateMixin {
  int _currentNavIndex = 0;
  int _previousNavIndex = 0; // Track previous index for exit animation
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;
  
  late List<Widget> _pages;

  @override
  void initState() {
    super.initState();
    
    // Animation Controller
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );

    _fadeAnimation = CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeOut,
    );

    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.05), // Slight vertical slide (approx 10-20px depending on height)
      end: Offset.zero,
    ).animate(_fadeAnimation);

    _animationController.forward(); // Show initial page

    // Check for app updates logic moved here
    _checkForAppUpdate();
    
    // Load Ad
    AdService.loadBottomNavBanner(onLoaded: () {
      if (mounted) setState(() {});
    });

    // Initialize pages
    _pages = [
      HomeContent(
        preloadedAnime: widget.preloadedAnime,
        preloadedComics: widget.preloadedComics,
        preloadedFeaturedContent: widget.preloadedFeaturedContent,
      ),
      SearchScreen(),
      ExploreScreen(showBackButton: false),
      FavoritesScreen(showBackButton: false), // Hide back button for bottom nav
      ProfileScreen(),
    ];
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  // Check for app updates
  Future<void> _checkForAppUpdate() async {
    try {
      final isUpdateAvailable = await AppVersionService.isUpdateAvailable();
      if (isUpdateAvailable && mounted) {
        final versionData = await AppVersionService.getAppVersion();
        final changelog = await AppVersionService.getChangelog();
        
        // Show update dialog after a short delay to ensure UI is ready
        Future.delayed(const Duration(seconds: 2), () {
          if (mounted) {
            UpdateDialog.show(
              context: context,
              latestVersion: versionData?['version'],
              changelog: changelog,
            );
          }
        });
      }
    } catch (e) {
      print('Error checking for app update: $e');
    }
  }

  void _handleNavigation(int index) {
    if (index == _currentNavIndex) return;

    if (index == 5) {
       // Exit case if using Desktop
       windowManager.close();
       return;
    }

    setState(() {
      _previousNavIndex = _currentNavIndex;
      _currentNavIndex = index;
    });
    
    _animationController.forward(from: 0.0);
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    
    // For Desktop logic
    final isDesktop = screenWidth > 900;
    
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.light,
        systemNavigationBarColor: Colors.black, // Set to black
        systemNavigationBarIconBrightness: Brightness.light,
      ),
      child: Scaffold(
        backgroundColor: AppTheme.backgroundColor,
        extendBody: true, // Important for floating nav bar
        body: Stack(
          children: List.generate(_pages.length, (index) {
            final isCurrent = index == _currentNavIndex;
            final isPrevious = index == _previousNavIndex;
            final isAnimating = _animationController.isAnimating;
            
            // Logic:
            // 1. If Current: Visible, Interactive, Animated In.
            // 2. If Previous & Animating: Visible, IGNORED (no touch), Animated Out.
            // 3. Otherwise: Offstage (Hidden), IGNORED, Static.
            
            // Determine offstage status
            // Show if it is current OR (previous AND animating)
            final bool isVisible = isCurrent || (isPrevious && isAnimating);
            
            return Offstage(
              offstage: !isVisible,
              child: TickerMode(
                enabled: isCurrent, // only tick if current
                child: IgnorePointer(
                  ignoring: !isCurrent, // Ignore touches on fading out pages
                  child: Builder(
                    builder: (context) {
                      if (isCurrent) {
                        // Slide + Fade In
                        return FadeTransition(
                          opacity: _fadeAnimation,
                          child: SlideTransition(
                            position: _slideAnimation,
                            child: _pages[index],
                          ),
                        );
                      } else if (isPrevious && isAnimating) {
                         // Fade Out only
                        return FadeTransition(
                          opacity: Tween<double>(begin: 1.0, end: 0.0).animate(_fadeAnimation),
                          child: _pages[index],
                        );
                      } else {
                        // Just the page (hidden by Offstage)
                        return _pages[index];
                      }
                    },
                  ),
                ),
              ),
            );
          }),
        ),
        bottomNavigationBar: isDesktop ? null : Column(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
             CustomBottomNavBar(
              currentIndex: _currentNavIndex,
              onTap: _handleNavigation,
            ),
             if (AdService.bottomNavBanner != null)
              Container(
                width: double.infinity,
                color: Colors.black, // Ensures background is black behind system nav bar if transparent
                child: SafeArea(
                  top: false,
                  child: Align(
                    alignment: Alignment.center,
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.only(top: 4), // Separator above ad
                      child: SizedBox(
                        width: AdService.bottomNavBanner!.size.width.toDouble(),
                        height: AdService.bottomNavBanner!.size.height.toDouble(),
                        child: AdWidget(ad: AdService.bottomNavBanner!),
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
