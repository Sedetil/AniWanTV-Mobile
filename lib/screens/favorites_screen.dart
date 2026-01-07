import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter_svg/flutter_svg.dart';
import '../services/api_service.dart';
import '../theme/app_theme.dart';
import '../widgets/custom_error_dialog.dart';
import '../providers/app_state_provider.dart';
import 'anime_details_screen.dart';
import 'comic_details_screen.dart';
import 'comic_details_screen.dart';
import 'explore_screen.dart';
import 'search_screen.dart';
import '../utils/toast_utils.dart';

class FavoritesScreen extends StatefulWidget {
  final bool showBackButton;

  const FavoritesScreen({Key? key, this.showBackButton = true}) : super(key: key);

  @override
  _FavoritesScreenState createState() => _FavoritesScreenState();
}

class _FavoritesScreenState extends State<FavoritesScreen> {
  // Using a custom index state instead of TabController for custom toggle
  int _currentTabIndex = 0; // 0 for Anime, 1 for Komik
  
  List<dynamic> favoriteAnime = [];
  List<dynamic> favoriteComics = [];
  bool isLoading = true;

  // Search State
  bool _isSearching = false;
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Provider.of<AppStateProvider>(context, listen: false).initialize();
    });
    _loadFavorites();
  }

  Future<void> _loadFavorites() async {
    setState(() => isLoading = true);
    try {
      final appStateProvider = Provider.of<AppStateProvider>(context, listen: false);
      await appStateProvider.initialize();
      
      setState(() {
        favoriteAnime = appStateProvider.favoriteAnime;
        favoriteComics = appStateProvider.favoriteComics;
        isLoading = false;
      });
    } catch (e) {
      setState(() => isLoading = false);
      // We can fail silently here or show a toast, dialog might be intrusive if it's just a connection blip
    }
  }

  Future<void> _removeFavorite(String id, bool isAnime) async {
    try {
      final appStateProvider = Provider.of<AppStateProvider>(context, listen: false);
      await appStateProvider.removeFromFavorites(id, isAnime);
      
      setState(() {
        if (isAnime) {
          favoriteAnime = appStateProvider.favoriteAnime;
        } else {
          favoriteComics = appStateProvider.favoriteComics;
        }
      });

      ToastUtils.show(
        'Removed from favorites',
        backgroundColor: AppTheme.primaryColor,
      );
    } catch (e) {
      // Handle error
    }
  }

  @override
  Widget build(BuildContext context) {
    // Current items based on toggle
    List<dynamic> items = _currentTabIndex == 0 ? favoriteAnime : favoriteComics;
    final isAnime = _currentTabIndex == 0;

    // Filter items if searching
    if (_searchQuery.isNotEmpty) {
      items = items.where((item) {
        final title = (item['title'] ?? '').toString().toLowerCase();
        return title.contains(_searchQuery.toLowerCase());
      }).toList();
    }

    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 16.0),
              child: _isSearching 
              ? Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _searchController,
                        autofocus: true,
                        style: TextStyle(color: Colors.white),
                        decoration: InputDecoration(
                          hintText: 'Search favorites...',
                          hintStyle: TextStyle(color: Colors.white54),
                          border: InputBorder.none,
                          icon: Icon(Icons.search, color: Colors.white54),
                        ),
                        onChanged: (value) {
                          setState(() {
                            _searchQuery = value;
                          });
                        },
                      ),
                    ),
                    IconButton(
                      icon: Icon(Icons.close, color: Colors.white),
                      onPressed: () {
                        setState(() {
                          _isSearching = false;
                          _searchQuery = '';
                          _searchController.clear();
                        });
                      },
                    ),
                  ],
                )
              : Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      if (widget.showBackButton) ...[
                        GestureDetector(
                          onTap: () => Navigator.pop(context),
                          child: const Icon(Icons.arrow_back, color: Colors.white, size: 28),
                        ),
                        const SizedBox(width: 16),
                      ],
                      const Text(
                        'Favorites',
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                    ],
                  ),
                  GestureDetector(
                     onTap: () {
                       setState(() {
                         _isSearching = true;
                       });
                     },
                     child: Icon(Icons.search, color: Colors.white, size: 28),
                  ),
                ],
              ),
            ),

            // Toggle Tabs
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
              child: Row(
                children: [
                  Expanded(
                    child: _buildToggleItem(
                      label: 'ANIME', 
                      isActive: _currentTabIndex == 0, 
                      onTap: () => setState(() => _currentTabIndex = 0)
                    )
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: _buildToggleItem(
                      label: 'KOMIK', // Using "KOMIK" as requested in image, code uses "comic" internally
                      isActive: _currentTabIndex == 1, 
                      onTap: () => setState(() => _currentTabIndex = 1)
                    )
                  ),
                ],
              ),
            ),
            
            const SizedBox(height: 16),

            // Content
            Expanded(
              child: isLoading
                  ? Center(child: CircularProgressIndicator(color: AppTheme.primaryColor))
                  : _buildContent(items, isAnime),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildToggleItem({required String label, required bool isActive, required VoidCallback onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 40,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: isActive ? AppTheme.primaryColor : const Color(0xFF1E1E1E), // Red active, dark inactive
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(
          label,
          style: const TextStyle(
            color: Colors.white, 
            fontWeight: FontWeight.bold
          ),
        ),
      ),
    );
  }

  Widget _buildContent(List<dynamic> items, bool isAnime) {
    if (items.isEmpty) {
      return _buildEmptyState(isAnime);
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        // Responsive grid count based on available width
        int crossAxisCount;
        if (constraints.maxWidth > 1200) {
          crossAxisCount = 6;
        } else if (constraints.maxWidth > 900) {
          crossAxisCount = 5;
        } else if (constraints.maxWidth > 600) {
          crossAxisCount = 4;
        } else {
          crossAxisCount = 3; // Mobile default - 3 columns is better for posters, or 2 if they are wide
        }
        
        // Use 2 columns for very small mobile screens if 3 is too crowded, but user likely wants 3
        // Actually, previous code was fixed at 2. Let's stick closer to that for mobile.
        if (constraints.maxWidth < 400) {
           crossAxisCount = 2; 
        }

        return GridView.builder(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          physics: const BouncingScrollPhysics(),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: crossAxisCount,
            childAspectRatio: 0.7, // Poster ratio
            crossAxisSpacing: 16,
            mainAxisSpacing: 16,
          ),
          itemCount: items.length,
          itemBuilder: (context, index) {
            final item = items[index];
            return _buildFavoriteCard(item, isAnime);
          },
        );
      },
    );
  }

  Widget _buildEmptyState(bool isAnime) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // SVG Image
          SvgPicture.asset(
            'assets/images/anime_favorites.svg',
            width: 200, // Adjust size
          ),
          const SizedBox(height: 24),
          const Text(
            'Belum ada Favorit',
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            isAnime 
              ? 'Tambahkan anime ke favoritmu\nagar muncul di sini'
              : 'Tambahkan komik ke favoritmu\nagar muncul di sini',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.grey[400],
              fontSize: 16,
            ),
          ),
          const SizedBox(height: 32),
          // Explore Button
          SizedBox(
            width: 200,
            height: 48,
            child: ElevatedButton(
              onPressed: () {
                 // Navigate to ExploreScreen with the correct tab selected
                 Navigator.push(
                   context, 
                   MaterialPageRoute(
                     builder: (_) => ExploreScreen(initialIsAnime: isAnime)
                   )
                 );
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primaryColor,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
              ),
              child: const Text(
                'Explore Content',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
            ),
          ),
          // Add some padding at bottom if needed
          const SizedBox(height: 50),
        ],
      ),
    );
  }

  Widget _buildFavoriteCard(dynamic item, bool isAnime) {
    return GestureDetector(
      onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => isAnime
                  ? AnimeDetailsScreen(url: item['url'])
                  : ComicDetailsScreen(url: item['url'], type: item['type']),
            ),
          ).then((_) => _loadFavorites());
      },
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Stack(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: Image.network(
                    item['image_url'],
                    width: double.infinity,
                    height: double.infinity,
                    fit: BoxFit.cover,
                    errorBuilder: (_,__,___) => Container(color: const Color(0xFF1E1E1E)),
                  ),
                ),
                // Comic Type Badge
                if (!isAnime && item['type'] != null)
                  Positioned(
                    top: 8,
                    left: 8,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: AppTheme.primaryColor.withOpacity(0.9),
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

                // Remove Button overlay
                Positioned(
                  top: 8,
                  right: 8,
                  child: GestureDetector(
                    onTap: () => _removeFavorite(item['id'], isAnime),
                    child: Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: Colors.black.withOpacity(0.6),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.delete_outline, color: Colors.white, size: 20),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          Text(
            item['title'],
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }
}
