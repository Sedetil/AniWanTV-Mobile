import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:carousel_slider/carousel_slider.dart';
import 'package:carousel_slider/carousel_controller.dart' as slider;
import 'package:provider/provider.dart';
import '../services/api_service.dart';
import '../services/app_version_service.dart';
import '../theme/app_theme.dart';
import '../widgets/custom_error_dialog.dart';
import '../widgets/custom_loading_widget.dart';
import '../widgets/update_bottom_sheet.dart';
import '../providers/app_state_provider.dart';
import '../services/ad_service.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'anime_details_screen.dart';
import 'comic_details_screen.dart';
import 'categories_screen.dart';
import 'favorites_screen.dart';
import 'search_screen.dart';

class HomeContent extends StatefulWidget {
  final List<dynamic>? preloadedAnime;
  final List<dynamic>? preloadedComics;
  final List<dynamic>? preloadedFeaturedContent;

  const HomeContent({
    Key? key,
    this.preloadedAnime,
    this.preloadedComics,
    this.preloadedFeaturedContent,
  }) : super(key: key);

  @override
  _HomeContentState createState() => _HomeContentState();
}

class _HomeContentState extends State<HomeContent> with AutomaticKeepAliveClientMixin {
  final slider.CarouselSliderController carouselController =
      slider.CarouselSliderController();

  List<dynamic> featuredContent = [];
  List<dynamic> latestAnime = [];
  List<dynamic> latestComics = [];
  bool isLoading = true;
  int _currentCarouselIndex = 0;
  bool _showAnime = true; // Toggle state

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();

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

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final screenHeight = MediaQuery.of(context).size.height;

    if (isLoading) {
      return Center(child: _buildLoadingView());
    }

    return RefreshIndicator(
      onRefresh: _loadContent,
      color: AppTheme.primaryColor,
      strokeWidth: 3,
      child: CustomScrollView(
        physics: const BouncingScrollPhysics(),
        slivers: [
          SliverToBoxAdapter(
            child: Column(
              children: [
                _buildHeroSection(MediaQuery.of(context).size.width, screenHeight),
                _buildCategoryToggle(),
                _buildContentGrid(MediaQuery.of(context).size.width),
                // Add extra padding at bottom to avoid content being hidden behind floating nav bar + ads
                // Base 80 (Nav) + 50 (Ad) + Safe Area
                SizedBox(height: 130 + MediaQuery.of(context).padding.bottom), 
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLoadingView() {
    return const SizedBox.shrink();
  }

  Widget _buildHeroSection(double screenWidth, double screenHeight) {
    if (featuredContent.isEmpty) return SizedBox.shrink();

    final item = featuredContent[_currentCarouselIndex]; // Use current index
    // Adjusted height to 0.45 to allow grid content (2 rows) to be visible
    final heroHeight = screenHeight * 0.45; 

    return SizedBox(
      height: heroHeight,
      child: Stack(
        fit: StackFit.expand,
        children: [
          // Background Slider
          CarouselSlider(
            options: CarouselOptions(
              height: heroHeight,
              viewportFraction: 1.0,
              autoPlay: true,
              autoPlayInterval: Duration(seconds: 5),
              onPageChanged: (index, reason) {
                setState(() {
                  _currentCarouselIndex = index;
                });
              },
            ),
            items: featuredContent.map((contentItem) {
              return Builder(
                builder: (BuildContext context) {
                  return Image.network(
                    contentItem['image_url'],
                    fit: BoxFit.cover,
                    width: double.infinity,
                    errorBuilder: (_,__,___) => Container(color: AppTheme.surfaceColor),
                  );
                },
              );
            }).toList(),
          ),
          
          // Gradient Overlay
          IgnorePointer(
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.black.withOpacity(0.3), // Darker top for white text
                    Colors.transparent,
                    AppTheme.backgroundColor.withOpacity(0.8),
                    AppTheme.backgroundColor,
                  ],
                  stops: [0.0, 0.4, 0.8, 1.0],
                ),
              ),
            ),
          ),
          
          // Top Gradient overlay for status bar and header
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            height: 120, // Covers status bar and header area
            child: IgnorePointer(
              child: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.black.withOpacity(0.8),
                      Colors.transparent,
                    ],
                  ),
                ),
              ),
            ),
          ),

          // Content
          SafeArea(
            bottom: false, // Ignore bottom padding (nav bar/ads) for hero section
            child: Column(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                // Header (AniWanTV + Icons)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'AniWanTV',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 24, // Reduced from 24
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Row(
                        children: [
                          GestureDetector(
                            onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => SearchScreen(autoFocus: true))),
                            child: Icon(Icons.search, color: Colors.white, size: 24),
                          ),
                          SizedBox(width: 16),
                          Icon(Icons.notifications_outlined, color: Colors.white, size: 24),
                        ],
                      ),
                    ],
                  ),
                ),

                // Hero Details & Actions
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 0), // Bottom padding removed for tight spacing
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Title
                      Text(
                        item['title'],
                        textAlign: TextAlign.center,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 26, // Reduced slightly more
                          fontWeight: FontWeight.bold,
                          fontFamily: 'Roboto',
                          color: Colors.white,
                          shadows: [
                            Shadow(blurRadius: 10, color: Colors.black, offset: Offset(0, 2)) 
                          ],
                        ),
                      ),
                      
                      const SizedBox(height: 8), // Reduced from 16

                      // Actions Row
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          // Favorites
                          _buildHeroActionItem(
                            'assets/icons/favorite.svg', 
                            'Favorites',
                            () => Navigator.push(context, MaterialPageRoute(builder: (_) => FavoritesScreen())),
                          ),

                          // Play/Read Button
                          SizedBox(
                            width: 140, // Slightly smaller button
                            height: 45, 
                            child: ElevatedButton(
                              onPressed: () {
                                if (item['type'] == 'anime') {
                                    Navigator.push(context, MaterialPageRoute(builder: (_) => AnimeDetailsScreen(url: item['url'])));
                                } else if (item['type'] == 'comic') {
                                    Navigator.push(context, MaterialPageRoute(builder: (_) => ComicDetailsScreen(url: item['url'])));
                                }
                              },
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFFE50914), // Red
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                                padding: EdgeInsets.symmetric(horizontal: 16),
                              ),
                              child: Text(
                                item['type'] == 'comic' ? 'Read' : 'Play', 
                                style: const TextStyle(
                                  fontSize: 16, 
                                  fontWeight: FontWeight.bold, 
                                  color: Colors.white,
                                  height: 1.2, 
                                )
                              ),
                            ),
                          ),

                          // Categories
                           _buildHeroActionItem(
                             'assets/icons/categories.svg', 
                             'Categories',
                             () => Navigator.push(context, MaterialPageRoute(builder: (_) => CategoriesScreen())),
                           ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeroActionItem(String iconPath, String label, VoidCallback onTap) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.all(8.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SvgPicture.asset(
                iconPath,
                color: Colors.white,
                width: 24,
                height: 24,
              ),
              const SizedBox(height: 4),
              Text(
                label,
                style: const TextStyle(color: Colors.white, fontSize: 12),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCategoryToggle() {
    return Padding(
      // Increased spacing to 20.0 for more separation
      padding: const EdgeInsets.fromLTRB(16.0, 20.0, 16.0, 12.0), 
      child: Container(
        height: 45,
        decoration: BoxDecoration(
           color: const Color(0xFF333333), // Dark grey background for container
           borderRadius: BorderRadius.circular(8),
        ),
        padding: const EdgeInsets.all(4),
        child: Stack(
          children: [
            // Sliding Indicator
            AnimatedAlign(
              duration: const Duration(milliseconds: 250),
              curve: Curves.easeInOut,
              alignment: _showAnime ? Alignment.centerLeft : Alignment.centerRight,
              child: FractionallySizedBox(
                widthFactor: 0.5,
                child: Container(
                  decoration: BoxDecoration(
                    color: const Color(0xFFE50914), // Red
                    borderRadius: BorderRadius.circular(6),
                  ),
                ),
              ),
            ),
            // Text Labels (Transparent overlay)
            Row(
              children: [
                Expanded(
                  child: GestureDetector(
                    onTap: () => setState(() => _showAnime = true),
                    behavior: HitTestBehavior.translucent, // Ensure taps are caught
                    child: Container(
                      alignment: Alignment.center,
                      child: Text(
                        'ANIME',
                        style: TextStyle(
                          color: Colors.white, 
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                ),
                Expanded(
                  child: GestureDetector(
                    onTap: () => setState(() => _showAnime = false),
                    behavior: HitTestBehavior.translucent, // Ensure taps are caught
                    child: Container(
                      alignment: Alignment.center,
                      child: Text(
                        'KOMIK',
                        style: TextStyle(
                          color: Colors.white, 
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildContentGrid(double maxWidth) {
    final items = _showAnime ? latestAnime : latestComics;
    
    // Calculate aspect ratio for posters
    final cardWidth = (maxWidth - 48) / 3; // 3 columns, some padding
    
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0),
      child: GridView.builder(
        physics: const NeverScrollableScrollPhysics(),
        shrinkWrap: true,
        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 3,
          childAspectRatio: 0.70, // Increased aspect ratio makes items shorter
          crossAxisSpacing: 12,
          mainAxisSpacing: 16,
        ),
        itemCount: items.length,
        itemBuilder: (context, index) {
          final item = items[index];
          return GestureDetector(
            onTap: () {
               if (_showAnime) {
                  Navigator.push(context, MaterialPageRoute(builder: (_) => AnimeDetailsScreen(url: item['url'])));
               } else {
                  Navigator.push(context, MaterialPageRoute(builder: (_) => ComicDetailsScreen(url: item['url'], type: item['type'])));
               }
            },
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: Image.network(
                          item['image_url'],
                          fit: BoxFit.cover,
                          width: double.infinity,
                          errorBuilder: (_,__,___) => Container(color: Colors.grey[800]),
                        ),
                      ),
                      // Type Badge
                      if (!_showAnime && item['type'] != null)
                        Positioned(
                          top: 4,
                          left: 4,
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: AppTheme.primaryColor.withOpacity(0.9), // Brand color
                              borderRadius: BorderRadius.circular(4),
                              boxShadow: [
                                BoxShadow(color: Colors.black26, blurRadius: 2, offset: Offset(0, 1))
                              ],
                            ),
                            child: Text(
                              (item['type'] as String).toUpperCase(),
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 9,
                                fontWeight: FontWeight.bold,
                                letterSpacing: 0.5,
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  item['title'],
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
