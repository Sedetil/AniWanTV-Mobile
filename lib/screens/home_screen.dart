import 'package:flutter/material.dart';
import 'package:carousel_slider/carousel_slider.dart';
import 'package:carousel_slider/carousel_controller.dart' as slider;
import 'package:flutter/services.dart';
import '../services/api_service.dart';
import '../theme/app_theme.dart';
import '../widgets/custom_bottom_nav_bar.dart';
import '../widgets/custom_error_dialog.dart';
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
  final ApiService apiService = ApiService();
  final slider.CarouselSliderController carouselController =
      slider.CarouselSliderController();

  List<dynamic> featuredContent = [];
  List<dynamic> latestAnime = [];
  List<dynamic> latestComics = [];
  bool isLoading = true;
  int _currentCarouselIndex = 0;
  int _currentNavIndex = 0;
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);

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



  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }



  Future<void> _loadContent() async {
    setState(() => isLoading = true);
    try {
      final anime = await apiService.fetchLatestAnime();
      final comics = await apiService.fetchLatestComics();
      final topAnime = await apiService.fetchTopAnime();

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
        Fluttertoast.showToast(
          msg: 'Explore coming soon',
          toastLength: Toast.LENGTH_SHORT,
          gravity: ToastGravity.BOTTOM,
          backgroundColor: AppTheme.primaryColor,
          textColor: Colors.white,
        );
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
        floatingActionButton: FloatingActionButton(
          onPressed: () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => SearchScreen()),
            );
          },
          backgroundColor: AppTheme.primaryColor,
          child: const Icon(Icons.search, color: Colors.white),
          elevation: 4,
        ),
        floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
      ),
    );
  }

  Widget _buildLoadingView() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 100,
            height: 100,
            decoration: BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.play_circle_fill,
              size: 70,
              color: AppTheme.primaryColor,
            ),
          ),
          const SizedBox(height: 20),
          CircularProgressIndicator(
            valueColor: AlwaysStoppedAnimation<Color>(AppTheme.primaryColor),
          ),
          const SizedBox(height: 20),
          Text(
            'Loading amazing content...',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w500,
              color: Colors.grey.shade400,
            ),
          ),
        ],
      ),
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
    final carouselHeight = screenHeight * 0.25;

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
            enlargeFactor: 0.2,
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
                return GestureDetector(
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
                  child: Container(
                    margin: const EdgeInsets.symmetric(horizontal: 5.0),
                    child: Stack(
                      children: [
                        // Image with gradient overlay
                        ClipRRect(
                          borderRadius: BorderRadius.circular(16.0),
                          child: Hero(
                            tag: 'featured-${item['url']}',
                            child: ShaderMask(
                              shaderCallback: (rect) {
                                return LinearGradient(
                                  begin: Alignment.topCenter,
                                  end: Alignment.bottomCenter,
                                  colors: [
                                    Colors.transparent,
                                    Colors.black.withOpacity(0.8),
                                  ],
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
                                  color: Colors.grey[800],
                                  child: const Center(
                                    child: Icon(Icons.broken_image,
                                        size: 40, color: Colors.grey),
                                  ),
                                ),
                                loadingBuilder: (ctx, child, loadingProgress) {
                                  if (loadingProgress == null) return child;
                                  return Container(
                                    color: Colors.grey[800],
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
                                        strokeWidth: 2,
                                        color: AppTheme.primaryColor,
                                      ),
                                    ),
                                  );
                                },
                              ),
                            ),
                          ),
                        ),

                        // Content info
                        Positioned(
                          bottom: 0,
                          left: 0,
                          right: 0,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 16.0, vertical: 12.0),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 8, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: isActive
                                        ? (item['type'] == 'anime'
                                            ? AppTheme.primaryColor
                                            : item['type'] == 'comic'
                                                ? AppTheme.accentColor
                                                : Colors.grey)
                                        : Colors.white.withOpacity(0.3),
                                    border: Border.all(
                                      color: isActive
                                          ? (item['type'] == 'anime'
                                              ? AppTheme.primaryColor
                                              : item['type'] == 'comic'
                                                  ? AppTheme.accentColor
                                                  : Colors.grey)
                                          : Colors.white.withOpacity(0.5),
                                      width: 1,
                                    ),
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: Text(
                                    item['type'] == 'anime'
                                        ? 'ANIME'
                                        : item['type'] == 'comic'
                                            ? 'KOMIK'
                                            : 'UNKNOWN',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 10,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  item['title'],
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 16.0,
                                    fontWeight: FontWeight.bold,
                                    shadows: [
                                      Shadow(
                                        blurRadius: 5.0,
                                        color: Colors.black,
                                        offset: Offset(0, 1),
                                      ),
                                    ],
                                  ),
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                const SizedBox(height: 4),
                                // Rating removed as requested
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            );
          }).toList(),
        ),
        const SizedBox(height: 12),

        // Carousel indicators
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: featuredContent.asMap().entries.map((entry) {
            return GestureDetector(
              onTap: () => carouselController.animateToPage(entry.key),
              child: Container(
                width: 8.0,
                height: 8.0,
                margin: const EdgeInsets.symmetric(horizontal: 4.0),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: _currentCarouselIndex == entry.key
                      ? AppTheme.primaryColor
                      : Colors.grey.withOpacity(0.5),
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
      margin: const EdgeInsets.only(top: 24, bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Card(
        color: AppTheme.cardColor,
        elevation: 2,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 16.0),
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
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppTheme.primaryColor.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: AppTheme.primaryColor, size: 28),
            ),
            const SizedBox(height: 8),
            Text(
              label,
              style: TextStyle(
                fontWeight: FontWeight.w500,
                fontSize: 12,
                color: Colors.white,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildContentTabs(bool isTablet) {
    return Column(
      children: [
        // Tab bar
        Container(
          margin: const EdgeInsets.only(top: 16, bottom: 8),
          decoration: BoxDecoration(
            color: Colors.grey.withOpacity(0.1),
            borderRadius: BorderRadius.circular(25),
          ),
          width: 240,
          child: TabBar(
            controller: _tabController,
            indicator: BoxDecoration(
              borderRadius: BorderRadius.circular(25),
              color: AppTheme.primaryColor,
            ),
            labelColor: Colors.white,
            unselectedLabelColor: Colors.grey.shade400,
            labelStyle: const TextStyle(fontWeight: FontWeight.bold),
            tabs: const [
              Tab(text: 'ANIME'),
              Tab(text: 'KOMIK'),
            ],
          ),
        ),

        // Tab content
        Container(
          height: 320,
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
    return GestureDetector(
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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Stack(
                fit: StackFit.expand,
                children: [
                  Image.network(
                    item['image_url'],
                    fit: BoxFit.cover,
                    errorBuilder: (ctx, error, stackTrace) => Container(
                      color: Colors.grey[800],
                      child: const Icon(Icons.broken_image, color: Colors.grey),
                    ),
                  ),
                  // Rating removed as requested
                ],
              ),
            ),
          ),
          const SizedBox(height: 6),
          // Added container with fixed height to ensure text is visible
          Container(
            height: 36,
            child: Text(
              item['title'] ?? 'Unknown Title',
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: Colors.white,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
