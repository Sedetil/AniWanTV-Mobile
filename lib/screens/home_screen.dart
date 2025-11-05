import 'package:aniwantv/screens/explore_screen.dart';
import 'package:flutter/material.dart';
import 'package:carousel_slider/carousel_slider.dart';
import 'package:carousel_slider/carousel_controller.dart' as slider;
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../services/api_service.dart';
import '../services/app_version_service.dart';
import '../theme/app_theme.dart';
import '../widgets/custom_bottom_nav_bar.dart';
import '../widgets/custom_error_dialog.dart';
import '../widgets/custom_loading_widget.dart';
import '../widgets/update_dialog.dart';
import '../providers/app_state_provider.dart';
import 'anime_details_screen.dart';
import 'comic_details_screen.dart';
import 'search_screen.dart';
import 'favorites_screen.dart';
import 'history_screen.dart';
import 'profile_screen.dart';
import 'package:fluttertoast/fluttertoast.dart';

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

class _HomeScreenState extends State<HomeScreen>
    with SingleTickerProviderStateMixin {
  final slider.CarouselSliderController carouselController =
      slider.CarouselSliderController();

  List<dynamic> featuredContent = [];
  List<dynamic> latestAnime = [];
  List<dynamic> latestComics = [];
  bool isLoading = true;
  int _currentCarouselIndex = 0;
  int _currentNavIndex = 0;
  late TabController _tabController;
  bool _isFabHovered = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    
    // Initialize AppStateProvider
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Provider.of<AppStateProvider>(context, listen: false).initialize();
    });

    // Check for app updates
    _checkForAppUpdate();

    // Use preloaded content if available
    if (widget.preloadedAnime != null &&
        widget.preloadedComics != null &&
        widget.preloadedFeaturedContent != null) {
      setState(() {
        latestAnime = widget.preloadedAnime!;
        latestComics = widget.preloadedComics!;
        featuredContent = widget.preloadedFeaturedContent!;
        isLoading = false;
      });
    } else {
      _loadContent();
    }
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

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }



  Future<void> _loadContent() async {
    setState(() => isLoading = true);
    try {
      final anime = await ApiService.fetchLatestAnime();
      final comics = await ApiService.fetchLatestComics();
      final topAnime = await ApiService.fetchTopAnime();

      if (mounted) {
        setState(() {
          // Mix anime and comics, but limit to 8 total featured items
          // Ensure each item has the correct type property
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

          featuredContent = [...featuredAnime, ...featuredComics]
            ..shuffle(); // Shuffle for variety
          latestAnime = anime;
          latestComics = comics;
          isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => isLoading = false);
        _showErrorDialog('Error Loading Content', 'Failed to load content: $e');
      }
    }
  }

  void _showErrorDialog(String title, String message) {
    CustomErrorDialog.show(
      context,
      title: title,
      message: message,
      onRetry: _loadContent,
    );
  }

  void _handleNavigation(int index) {
    setState(() => _currentNavIndex = index);

    switch (index) {
      case 0:
        // Already on home screen
        break;
      case 1:
        // Explore
        Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => ExploreScreen()),
        ).then((_) => setState(() => _currentNavIndex = 0));
        break;
      case 2:
        // Favorites
        Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => FavoritesScreen()),
        ).then((_) => setState(() => _currentNavIndex = 0));
        break;
      case 3:
        // Profile
        Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => ProfileScreen()),
        ).then((_) => setState(() => _currentNavIndex = 0));
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final screenHeight = MediaQuery.of(context).size.height;
    final isTablet = screenWidth > 600;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.light,
      ),
      child: Scaffold(
        backgroundColor: AppTheme.backgroundColor,
        body: RefreshIndicator(
          onRefresh: _loadContent,
          color: AppTheme.primaryColor,
          strokeWidth: 3,
          child: CustomScrollView(
            physics: const BouncingScrollPhysics(),
            slivers: [
              _buildAppBar(isTablet),
              SliverToBoxAdapter(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SizedBox(height: 16),
                    _buildCarousel(screenWidth, screenHeight),
                    _buildQuickActions(),
                    _buildContentTabs(isTablet),
                  ],
                ),
              ),
            ],
          ),
        ),
        bottomNavigationBar: CustomBottomNavBar(
          currentIndex: _currentNavIndex,
          onTap: _handleNavigation,
        ),
        floatingActionButton: StatefulBuilder(
          builder: (context, setState) {
            return MouseRegion(
              cursor: SystemMouseCursors.click,
              onEnter: (_) => setState(() => _isFabHovered = true),
              onExit: (_) => setState(() => _isFabHovered = false),
              child: AnimatedContainer(
                duration: Duration(milliseconds: 200),
                width: 56,
                height: 56,
                transform: Matrix4.identity()
                  ..scale(_isFabHovered ? 1.1 : 1.0),
                decoration: BoxDecoration(
                  gradient: _isFabHovered
                    ? LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          AppTheme.primaryColor.withOpacity(0.95),
                          AppTheme.primaryColor.withOpacity(0.75),
                          AppTheme.accentColor.withOpacity(0.65),
                        ],
                      )
                    : AppTheme.primaryGradient,
                  borderRadius: BorderRadius.circular(28),
                  boxShadow: _isFabHovered
                    ? [
                        BoxShadow(
                          color: AppTheme.primaryColor.withOpacity(0.4),
                          blurRadius: 16,
                          spreadRadius: 0,
                          offset: Offset(0, 6),
                        ),
                        BoxShadow(
                          color: Colors.black.withOpacity(0.3),
                          blurRadius: 10,
                          spreadRadius: 0,
                          offset: Offset(0, 4),
                        ),
                      ]
                    : [
                        BoxShadow(
                          color: AppTheme.primaryColor.withOpacity(0.3),
                          blurRadius: 12,
                          spreadRadius: 0,
                          offset: Offset(0, 4),
                        ),
                        BoxShadow(
                          color: Colors.black.withOpacity(0.2),
                          blurRadius: 8,
                          spreadRadius: 0,
                          offset: Offset(0, 2),
                        ),
                      ],
                ),
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (context) => SearchScreen()),
                      );
                    },
                    borderRadius: BorderRadius.circular(28),
                    splashColor: Colors.white.withOpacity(0.2),
                    highlightColor: Colors.white.withOpacity(0.1),
                    child: Container(
                      width: 56,
                      height: 56,
                      child: Icon(
                        Icons.search,
                        color: Colors.white,
                        size: 24,
                      ),
                    ),
                  ),
                ),
              ),
            );
          },
        ),
        floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
      ),
    );
  }

  Widget _buildLoadingView() {
    return CustomLoadingWidget(
      message: 'Loading amazing content...',
      size: 100,
    );
  }

  Widget _buildAppBar(bool isTablet) {
    return SliverAppBar(
      expandedHeight: 60,
      floating: true,
      pinned: true,
      stretch: true,
      backgroundColor: AppTheme.backgroundColor,
      foregroundColor: Colors.white,
      elevation: 0,
      flexibleSpace: FlexibleSpaceBar(
        title: Text(
          'AniWanTV',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: isTablet ? 24 : 20,
            letterSpacing: 1.0,
            color: Colors.white,
          ),
        ),
        centerTitle: true,
      ),
      actions: [
        IconButton(
          icon: const Icon(Icons.history),
          onPressed: () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => HistoryScreen()),
            );
          },
          tooltip: 'History',
        ),
        IconButton(
          icon: const Icon(Icons.notifications_none),
          onPressed: () {
            Fluttertoast.showToast(
              msg: 'Notifications coming soon',
              toastLength: Toast.LENGTH_SHORT,
              gravity: ToastGravity.BOTTOM,
              backgroundColor: AppTheme.primaryColor,
              textColor: Colors.white,
            );
          },
          tooltip: 'Notifications',
        ),
        const SizedBox(width: 8),
      ],
    );
  }

  Widget _buildCarousel(double screenWidth, double screenHeight) {
    final carouselHeight = screenHeight * 0.28;

    return Column(
      children: [
        CarouselSlider(
          carouselController: carouselController,
          options: CarouselOptions(
            height: carouselHeight,
            viewportFraction: 0.85,
            initialPage: 0,
            enableInfiniteScroll: true,
            autoPlay: true,
            autoPlayInterval: const Duration(seconds: 5),
            autoPlayAnimationDuration: const Duration(milliseconds: 800),
            autoPlayCurve: Curves.fastOutSlowIn,
            enlargeCenterPage: true,
            enlargeFactor: 0.15,
            scrollDirection: Axis.horizontal,
            onPageChanged: (index, reason) {
              setState(() {
                _currentCarouselIndex = index;
              });
            },
          ),
          items: featuredContent.asMap().entries.map((entry) {
            final int index = entry.key;
            final item = entry.value;
            final isActive = index == _currentCarouselIndex;
            return Builder(
              builder: (BuildContext context) {
                return AnimatedContainer(
                  duration: Duration(milliseconds: 300),
                  curve: Curves.easeInOut,
                  child: GestureDetector(
                    onTap: () {
                      // Ensure correct navigation based on content type
                      if (item['type'] == 'anime') {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) =>
                                AnimeDetailsScreen(url: item['url']),
                          ),
                        );
                      } else if (item['type'] == 'comic') {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) =>
                                ComicDetailsScreen(url: item['url']),
                          ),
                        );
                      } else {
                        // Show error if type is undefined
                        Fluttertoast.showToast(
                          msg: 'Konten tidak dapat dibuka',
                          toastLength: Toast.LENGTH_SHORT,
                          gravity: ToastGravity.BOTTOM,
                          backgroundColor: Colors.red,
                          textColor: Colors.white,
                        );
                      }
                    },
                    child: AnimatedContainer(
                      duration: Duration(milliseconds: 300),
                      margin: const EdgeInsets.symmetric(horizontal: 5.0),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(AppTheme.radiusLarge),
                        boxShadow: isActive
                            ? AppTheme.heavyShadow
                            : AppTheme.subtleShadow,
                      ),
                      child: Stack(
                        children: [
                          // Image with enhanced gradient overlay
                          ClipRRect(
                            borderRadius: BorderRadius.circular(AppTheme.radiusLarge),
                            child: Hero(
                              tag: 'featured-${item['url']}',
                              child: ShaderMask(
                                shaderCallback: (rect) {
                                  return LinearGradient(
                                    begin: Alignment.topCenter,
                                    end: Alignment.bottomCenter,
                                    colors: [
                                      Colors.transparent,
                                      Colors.black.withOpacity(0.4),
                                      Colors.black.withOpacity(0.8),
                                    ],
                                    stops: [0.0, 0.6, 1.0],
                                  ).createShader(rect);
                                },
                                blendMode: BlendMode.darken,
                                child: Image.network(
                                  item['image_url'],
                                  fit: BoxFit.cover,
                                  width: double.infinity,
                                  height: double.infinity,
                                  errorBuilder: (ctx, error, stackTrace) =>
                                      Container(
                                    decoration: BoxDecoration(
                                      gradient: LinearGradient(
                                        begin: Alignment.topLeft,
                                        end: Alignment.bottomRight,
                                        colors: [
                                          AppTheme.surfaceColor,
                                          AppTheme.cardColor,
                                        ],
                                      ),
                                    ),
                                    child: const Center(
                                      child: Icon(Icons.broken_image,
                                          size: 40, color: AppTheme.textSecondaryColor),
                                    ),
                                  ),
                                  loadingBuilder: (ctx, child, loadingProgress) {
                                    if (loadingProgress == null) return child;
                                    return Container(
                                      decoration: BoxDecoration(
                                        gradient: LinearGradient(
                                          begin: Alignment.topLeft,
                                          end: Alignment.bottomRight,
                                          colors: [
                                            AppTheme.surfaceColor,
                                            AppTheme.cardColor,
                                          ],
                                        ),
                                      ),
                                      child: Center(
                                        child: CircularProgressIndicator(
                                          value: loadingProgress
                                                      .expectedTotalBytes !=
                                                  null
                                              ? loadingProgress
                                                      .cumulativeBytesLoaded /
                                                  loadingProgress
                                                      .expectedTotalBytes!
                                              : null,
                                          strokeWidth: 3,
                                          valueColor: AlwaysStoppedAnimation<Color>(
                                            AppTheme.primaryColor,
                                          ),
                                        ),
                                      ),
                                    );
                                  },
                                ),
                              ),
                            ),
                          ),

                          // Enhanced content info with glassmorphism
                          Positioned(
                            bottom: 0,
                            left: 0,
                            right: 0,
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 16.0, vertical: 16.0),
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  begin: Alignment.topCenter,
                                  end: Alignment.bottomCenter,
                                  colors: [
                                    Colors.transparent,
                                    Colors.black.withOpacity(0.3),
                                    Colors.black.withOpacity(0.8),
                                  ],
                                ),
                                borderRadius: BorderRadius.only(
                                  bottomLeft: Radius.circular(AppTheme.radiusLarge),
                                  bottomRight: Radius.circular(AppTheme.radiusLarge),
                                ),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  AnimatedContainer(
                                    duration: Duration(milliseconds: 300),
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 10, vertical: 6),
                                    decoration: BoxDecoration(
                                      gradient: isActive
                                          ? (item['type'] == 'anime'
                                              ? AppTheme.primaryGradient
                                              : item['type'] == 'comic'
                                                  ? LinearGradient(
                                                      colors: [
                                                        AppTheme.accentColor,
                                                        AppTheme.accentColor.withOpacity(0.8),
                                                      ],
                                                    )
                                                  : LinearGradient(
                                                      colors: [
                                                        Colors.grey,
                                                        Colors.grey.withOpacity(0.8),
                                                      ],
                                                    ))
                                          : AppTheme.glassGradient,
                                      borderRadius: BorderRadius.circular(AppTheme.radiusSmall),
                                      border: Border.all(
                                        color: isActive
                                            ? (item['type'] == 'anime'
                                                ? AppTheme.primaryColor
                                                : item['type'] == 'comic'
                                                    ? AppTheme.accentColor
                                                    : Colors.grey)
                                            : Colors.white.withOpacity(0.3),
                                        width: 1.5,
                                      ),
                                      boxShadow: isActive
                                          ? [
                                              BoxShadow(
                                                color: (item['type'] == 'anime'
                                                        ? AppTheme.primaryColor
                                                        : item['type'] == 'comic'
                                                            ? AppTheme.accentColor
                                                            : Colors.grey)
                                                    .withOpacity(0.3),
                                                blurRadius: 8,
                                                spreadRadius: 0,
                                              ),
                                            ]
                                          : null,
                                    ),
                                    child: Text(
                                      item['type'] == 'anime'
                                          ? 'ANIME'
                                          : item['type'] == 'comic'
                                              ? 'KOMIK'
                                              : 'UNKNOWN',
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontSize: 11,
                                        fontWeight: FontWeight.bold,
                                        letterSpacing: 1.0,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    item['title'],
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 16.0,
                                      fontWeight: FontWeight.bold,
                                      shadows: [
                                        Shadow(
                                          blurRadius: 8.0,
                                          color: Colors.black,
                                          offset: Offset(0, 2),
                                        ),
                                      ],
                                      height: 1.2,
                                    ),
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
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
              },
            );
          }).toList(),
        ),
        const SizedBox(height: 16),

        // Enhanced carousel indicators
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: featuredContent.asMap().entries.map((entry) {
            final isActive = _currentCarouselIndex == entry.key;
            return GestureDetector(
              onTap: () => carouselController.animateToPage(entry.key),
              child: AnimatedContainer(
                duration: Duration(milliseconds: 300),
                width: isActive ? 24.0 : 8.0,
                height: 8.0,
                margin: const EdgeInsets.symmetric(horizontal: 4.0),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(4.0),
                  gradient: isActive
                      ? AppTheme.primaryGradient
                      : LinearGradient(
                          colors: [
                            Colors.grey.withOpacity(0.5),
                            Colors.grey.withOpacity(0.3),
                          ],
                        ),
                  boxShadow: isActive
                      ? [
                          BoxShadow(
                            color: AppTheme.primaryColor.withOpacity(0.3),
                            blurRadius: 4,
                            spreadRadius: 0,
                          ),
                        ]
                      : null,
                ),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }

  Widget _buildQuickActions() {
    return Container(
      margin: const EdgeInsets.only(top: 24, bottom: 16),
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              AppTheme.surfaceColor,
              AppTheme.cardColor,
            ],
          ),
          borderRadius: BorderRadius.circular(AppTheme.radiusLarge),
          boxShadow: AppTheme.mediumShadow,
          border: Border.all(
            color: Colors.white.withOpacity(0.05),
            width: 1,
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 20.0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _buildQuickActionButton(
                icon: Icons.play_circle_outlined,
                label: 'Continue',
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => HistoryScreen()),
                  );
                },
              ),
              _buildQuickActionButton(
                icon: Icons.favorite_border,
                label: 'Favorites',
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => FavoritesScreen()),
                  );
                },
              ),
              _buildQuickActionButton(
                icon: Icons.category_outlined,
                label: 'Categories',
                onTap: () {
                  // Add categories screen navigation here
                  Fluttertoast.showToast(
                    msg: 'Categories coming soon',
                    toastLength: Toast.LENGTH_SHORT,
                    gravity: ToastGravity.BOTTOM,
                    backgroundColor: AppTheme.primaryColor,
                    textColor: Colors.white,
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildQuickActionButton({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return StatefulBuilder(
      builder: (context, setState) {
        bool _isHovered = false;
        return MouseRegion(
          cursor: SystemMouseCursors.click,
          onEnter: (_) => setState(() => _isHovered = true),
          onExit: (_) => setState(() => _isHovered = false),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: onTap,
              borderRadius: BorderRadius.circular(AppTheme.radiusSmall),
              splashColor: AppTheme.primaryColor.withOpacity(0.1),
              highlightColor: AppTheme.primaryColor.withOpacity(0.05),
              child: AnimatedContainer(
                duration: Duration(milliseconds: 200),
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                transform: Matrix4.identity()
                  ..scale(_isHovered ? 1.05 : 1.0),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    AnimatedContainer(
                      duration: Duration(milliseconds: 200),
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: _isHovered
                            ? [
                                AppTheme.primaryColor.withOpacity(0.25),
                                AppTheme.primaryColor.withOpacity(0.15),
                              ]
                            : [
                                AppTheme.primaryColor.withOpacity(0.15),
                                AppTheme.primaryColor.withOpacity(0.05),
                              ],
                        ),
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: _isHovered
                            ? AppTheme.primaryColor.withOpacity(0.3)
                            : AppTheme.primaryColor.withOpacity(0.2),
                          width: 1.5,
                        ),
                        boxShadow: _isHovered
                          ? [
                              BoxShadow(
                                color: AppTheme.primaryColor.withOpacity(0.2),
                                blurRadius: 12,
                                spreadRadius: 0,
                              ),
                            ]
                          : [
                              BoxShadow(
                                color: AppTheme.primaryColor.withOpacity(0.1),
                                blurRadius: 8,
                                spreadRadius: 0,
                              ),
                            ],
                      ),
                      child: Icon(
                        icon,
                        color: _isHovered
                          ? AppTheme.primaryColor.withOpacity(0.9)
                          : AppTheme.primaryColor,
                        size: 28,
                      ),
                    ),
                    const SizedBox(height: 8),
                    AnimatedDefaultTextStyle(
                      duration: Duration(milliseconds: 200),
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        color: _isHovered
                          ? AppTheme.primaryColor.withOpacity(0.9)
                          : Colors.white,
                        letterSpacing: 0.5,
                        fontSize: _isHovered ? 13 : 12,
                      ),
                      child: Text(label),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildContentTabs(bool isTablet) {
    return Column(
      children: [
        // Enhanced tab bar with glassmorphism
        Container(
          margin: const EdgeInsets.only(top: 24, bottom: 16),
          padding: const EdgeInsets.all(4),
          decoration: BoxDecoration(
            gradient: AppTheme.glassGradient,
            borderRadius: BorderRadius.circular(AppTheme.radiusXLarge),
            border: Border.all(
              color: Colors.white.withOpacity(0.1),
              width: 1,
            ),
            boxShadow: AppTheme.subtleShadow,
          ),
          width: 260,
          child: TabBar(
            controller: _tabController,
            indicator: BoxDecoration(
              borderRadius: BorderRadius.circular(AppTheme.radiusLarge),
              gradient: AppTheme.primaryGradient,
              boxShadow: [
                BoxShadow(
                  color: AppTheme.primaryColor.withOpacity(0.3),
                  blurRadius: 8,
                  spreadRadius: 0,
                ),
              ],
            ),
            labelColor: Colors.white,
            unselectedLabelColor: AppTheme.textSecondaryColor,
            labelStyle: const TextStyle(fontWeight: FontWeight.bold, letterSpacing: 0.5),
            unselectedLabelStyle: TextStyle(fontWeight: FontWeight.normal, letterSpacing: 0.25),
            indicatorSize: TabBarIndicatorSize.tab,
            dividerColor: Colors.transparent,
            tabs: const [
              Tab(text: 'ANIME'),
              Tab(text: 'KOMIK'),
            ],
          ),
        ),

        // Enhanced tab content with better spacing
        Container(
          height: 340,
          padding: const EdgeInsets.only(top: 8),
          child: TabBarView(
            controller: _tabController,
            children: [
              _buildContentGrid(latestAnime, isTablet, 'anime'),
              _buildContentGrid(latestComics, isTablet, 'comic'),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildContentGrid(List<dynamic> items, bool isTablet, String type) {
    final gridItemCount = isTablet ? 4 : 3;

    if (items.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.sentiment_dissatisfied,
              size: 48,
              color: Colors.grey,
            ),
            SizedBox(height: 16),
            Text(
              'No content available',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w500,
                color: Colors.grey,
              ),
            ),
          ],
        ),
      );
    }

    return GridView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: gridItemCount,
        childAspectRatio: 0.7,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
      ),
      itemCount: items.length > 6 ? 6 : items.length, // Limit to 6 items
      itemBuilder: (context, index) {
        final item = items[index];
        if (item == null ||
            !item.containsKey('title') ||
            !item.containsKey('image_url')) {
          // Handle cases where item data might be incomplete
          return Container(
            decoration: BoxDecoration(
              color: Colors.grey[800],
              borderRadius: BorderRadius.circular(12),
            ),
            child: Center(
              child: Icon(Icons.error_outline, color: Colors.grey),
            ),
          );
        }
        return _buildContentGridItem(item, type);
      },
    );
  }

  Widget _buildContentGridItem(dynamic item, String type) {
    return StatefulBuilder(
      builder: (context, setState) {
        bool _isHovered = false;
        return AnimatedContainer(
          duration: Duration(milliseconds: 200),
          transform: Matrix4.identity()
            ..scale(_isHovered ? 1.03 : 1.0),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => type == 'anime'
                        ? AnimeDetailsScreen(url: item['url'])
                        : ComicDetailsScreen(url: item['url']),
                  ),
                );
              },
              borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
              splashColor: AppTheme.primaryColor.withOpacity(0.1),
              highlightColor: AppTheme.primaryColor.withOpacity(0.05),
              child: MouseRegion(
                cursor: SystemMouseCursors.click,
                onEnter: (_) => setState(() => _isHovered = true),
                onExit: (_) => setState(() => _isHovered = false),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: AnimatedContainer(
                        duration: Duration(milliseconds: 200),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
                          boxShadow: _isHovered
                            ? AppTheme.mediumShadow
                            : AppTheme.subtleShadow,
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
                          child: Stack(
                            fit: StackFit.expand,
                            children: [
                              Image.network(
                                item['image_url'],
                                fit: BoxFit.cover,
                                errorBuilder: (ctx, error, stackTrace) => Container(
                                  decoration: BoxDecoration(
                                    gradient: LinearGradient(
                                      begin: Alignment.topLeft,
                                      end: Alignment.bottomRight,
                                      colors: [
                                        AppTheme.surfaceColor,
                                        AppTheme.cardColor,
                                      ],
                                    ),
                                  ),
                                  child: const Icon(Icons.broken_image, color: AppTheme.textSecondaryColor),
                                ),
                                loadingBuilder: (ctx, child, loadingProgress) {
                                  if (loadingProgress == null) return child;
                                  return Container(
                                    decoration: BoxDecoration(
                                      gradient: LinearGradient(
                                        begin: Alignment.topLeft,
                                        end: Alignment.bottomRight,
                                        colors: [
                                          AppTheme.surfaceColor,
                                          AppTheme.cardColor,
                                        ],
                                      ),
                                    ),
                                    child: Center(
                                      child: CircularProgressIndicator(
                                        value: loadingProgress.expectedTotalBytes != null
                                            ? loadingProgress.cumulativeBytesLoaded /
                                                loadingProgress.expectedTotalBytes!
                                            : null,
                                        strokeWidth: 2,
                                        valueColor: AlwaysStoppedAnimation<Color>(
                                          AppTheme.primaryColor,
                                        ),
                                      ),
                                    ),
                                  );
                                },
                              ),
                              // Gradient overlay for better text readability
                              Positioned.fill(
                                child: Container(
                                  decoration: BoxDecoration(
                                    gradient: LinearGradient(
                                      begin: Alignment.topCenter,
                                      end: Alignment.bottomCenter,
                                      colors: [
                                        Colors.transparent,
                                        Colors.transparent,
                                        Colors.black.withOpacity(_isHovered ? 0.7 : 0.6),
                                      ],
                                      stops: [0.0, 0.5, 1.0],
                                    ),
                                  ),
                                ),
                              ),
                              // Play button overlay on hover
                              if (_isHovered)
                                Positioned.fill(
                                  child: Container(
                                    decoration: BoxDecoration(
                                      gradient: RadialGradient(
                                        center: Alignment.center,
                                        radius: 0.8,
                                        colors: [
                                          Colors.black.withOpacity(0.3),
                                          Colors.transparent,
                                        ],
                                      ),
                                    ),
                                    child: Icon(
                                      Icons.play_circle_filled,
                                      color: Colors.white.withOpacity(0.9),
                                      size: 40,
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    // Enhanced text container with better typography
                    Container(
                      height: 40,
                      child: Text(
                        item['title'] ?? 'Unknown Title',
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          fontWeight: FontWeight.w600,
                          color: _isHovered
                            ? AppTheme.primaryColor.withOpacity(0.9)
                            : Colors.white,
                          height: 1.2,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

