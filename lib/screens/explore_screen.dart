import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/api_service.dart';
import '../theme/app_theme.dart';
import '../widgets/custom_error_dialog.dart';
import '../providers/app_state_provider.dart';
import 'anime_details_screen.dart';
import 'comic_details_screen.dart';
import 'package:fluttertoast/fluttertoast.dart';

class ExploreScreen extends StatefulWidget {
  @override
  _ExploreScreenState createState() => _ExploreScreenState();
}

class _ExploreScreenState extends State<ExploreScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  List<dynamic> genres = [];
  List<dynamic> topAnime = [];
  List<dynamic> latestAnime = [];
  List<dynamic> latestComics = [];
  bool isLoadingGenres = true;
  bool isLoadingContent = true;
  String selectedGenre = 'All';
  String selectedFilter = 'All';
  int selectedYear = DateTime.now().year;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    
    // Initialize AppStateProvider
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Provider.of<AppStateProvider>(context, listen: false).initialize();
    });
    
    _loadData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    try {
      // Load genres
      final genresData = await ApiService.fetchGenres();
      
      // Load content
      final topAnimeData = await ApiService.fetchTopAnime();
      final latestAnimeData = await ApiService.fetchLatestAnime();
      final latestComicsData = await ApiService.fetchLatestComics();

      if (mounted) {
        setState(() {
          genres = genresData;
          topAnime = topAnimeData;
          latestAnime = latestAnimeData;
          latestComics = latestComicsData;
          isLoadingGenres = false;
          isLoadingContent = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          isLoadingGenres = false;
          isLoadingContent = false;
        });
        _showErrorDialog('Error Loading Content', 'Failed to load content: $e');
      }
    }
  }

  void _showErrorDialog(String title, String message) {
    CustomErrorDialog.show(
      context,
      title: title,
      message: message,
      onRetry: _loadData,
    );
  }

  Future<void> _performGenreSearch(Map<String, dynamic> genre) async {
    setState(() {
      isLoadingContent = true;
    });

    try {
      List<dynamic> allResults = [];
      
      if (genre['url'] != null) {
        final genreContent = await ApiService.fetchGenreContent(genre['url']);
        if (genreContent['content'] != null) {
          allResults = genreContent['content'].map((item) {
            String itemType = 'unknown';
            if (item['type'] != null) {
              final originalType = item['type'].toString().toLowerCase();
              if (originalType == 'anime') {
                itemType = 'anime';
              } else if (originalType == 'comic' || originalType == 'manga') {
                itemType = 'comic';
              } else if (originalType == 'movie' || originalType == 'series') {
                itemType = 'anime';
              } else {
                itemType = 'anime';
              }
            } else {
              itemType = 'anime';
            }
            return {...item, 'type': itemType};
          }).toList();
        }
      }

      if (mounted) {
        setState(() {
          // Update content based on current tab
          if (_tabController.index == 0) {
            latestAnime = allResults.where((item) => item['type'] == 'anime').toList();
          } else {
            latestComics = allResults.where((item) => item['type'] == 'comic').toList();
          }
          isLoadingContent = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => isLoadingContent = false);
        _showErrorDialog('Search Error', 'Failed to perform search: $e');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      appBar: AppBar(
        title: Text(
          'Explore',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        backgroundColor: AppTheme.backgroundColor,
        elevation: 0,
        actions: [
          IconButton(
            icon: Icon(Icons.filter_list, color: Colors.white),
            onPressed: _showFilterDialog,
            tooltip: 'Filter results',
          ),
        ],
      ),
      body: Column(
        children: [
          _buildGenreSelector(),
          _buildContentTabs(),
        ],
      ),
    );
  }

  Widget _buildGenreSelector() {
    return Container(
      height: 60,
      padding: EdgeInsets.symmetric(vertical: 8),
      child: isLoadingGenres
          ? Center(
              child: CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(AppTheme.primaryColor),
              ),
            )
          : ListView.builder(
              scrollDirection: Axis.horizontal,
              padding: EdgeInsets.symmetric(horizontal: 16),
              itemCount: genres.length + 1, // +1 for "All" option
              itemBuilder: (context, index) {
                if (index == 0) {
                  return _buildGenreChip({'name': 'All', 'url': null}, true);
                }
                final genre = genres[index - 1];
                return _buildGenreChip(genre, false);
              },
            ),
    );
  }

  Widget _buildGenreChip(Map<String, dynamic> genre, bool isAll) {
    final isSelected = selectedGenre == genre['name'];
    
    return StatefulBuilder(
      builder: (context, setState) {
        bool _isHovered = false;
        return MouseRegion(
          cursor: SystemMouseCursors.click,
          onEnter: (_) => setState(() => _isHovered = true),
          onExit: (_) => setState(() => _isHovered = false),
          child: AnimatedContainer(
            duration: Duration(milliseconds: 200),
            margin: EdgeInsets.only(right: 8),
            transform: Matrix4.identity()
              ..scale(_isHovered ? 1.05 : 1.0),
            child: ActionChip(
              label: Text(
                genre['name'],
                style: TextStyle(
                  color: isSelected || _isHovered
                    ? AppTheme.backgroundColor
                    : Colors.white,
                  fontSize: _isHovered ? 13 : 12,
                  fontWeight: isSelected || _isHovered ? FontWeight.bold : FontWeight.normal,
                ),
              ),
              backgroundColor: isSelected || _isHovered
                ? AppTheme.primaryColor
                : AppTheme.primaryColor.withOpacity(0.2),
              side: BorderSide(
                color: isSelected || _isHovered
                  ? AppTheme.primaryColor
                  : AppTheme.primaryColor.withOpacity(0.5),
                width: isSelected || _isHovered ? 2 : 1
              ),
              onPressed: () {
                setState(() {
                  selectedGenre = genre['name'];
                });
                if (!isAll) {
                  _performGenreSearch(genre);
                } else {
                  _loadData(); // Reload all data when "All" is selected
                }
              },
            ),
          ),
        );
      },
    );
  }

  Widget _buildContentTabs() {
    return Expanded(
      child: Container(
        decoration: BoxDecoration(
          color: AppTheme.backgroundColor,
        ),
        child: Column(
          children: [
            // Tab bar
            Container(
              margin: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                gradient: AppTheme.glassGradient,
                borderRadius: BorderRadius.circular(AppTheme.radiusXLarge),
                border: Border.all(
                  color: Colors.white.withOpacity(0.1),
                  width: 1,
                ),
                boxShadow: AppTheme.subtleShadow,
              ),
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
                labelStyle: TextStyle(fontWeight: FontWeight.bold, letterSpacing: 0.5),
                unselectedLabelStyle: TextStyle(fontWeight: FontWeight.normal, letterSpacing: 0.25),
                indicatorSize: TabBarIndicatorSize.tab,
                dividerColor: Colors.transparent,
                tabs: const [
                  Tab(text: 'ANIME'),
                  Tab(text: 'MANGA'),
                ],
              ),
            ),
            
            // Tab content
            Expanded(
              child: TabBarView(
                controller: _tabController,
                children: [
                  _buildAnimeContent(),
                  _buildMangaContent(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAnimeContent() {
    if (isLoadingContent) {
      return Center(
        child: CircularProgressIndicator(
          valueColor: AlwaysStoppedAnimation<Color>(AppTheme.primaryColor),
        ),
      );
    }

    return Column(
      children: [
        // Top Anime Section
        if (topAnime.isNotEmpty && selectedGenre == 'All') ...[
          _buildSectionHeader('Top Anime'),
          Container(
            height: 200,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              padding: EdgeInsets.symmetric(horizontal: 16),
              itemCount: topAnime.take(10).length,
              itemBuilder: (context, index) {
                final anime = topAnime[index];
                return _buildHorizontalAnimeCard(anime);
              },
            ),
          ),
          SizedBox(height: 16),
        ],
        
        // Latest Anime Section
        _buildSectionHeader('Latest Anime'),
        Expanded(
          child: GridView.builder(
            padding: EdgeInsets.all(16),
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              childAspectRatio: 0.7,
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
            ),
            itemCount: latestAnime.length,
            itemBuilder: (context, index) {
              final anime = latestAnime[index];
              return _buildAnimeGridCard(anime);
            },
          ),
        ),
      ],
    );
  }

  Widget _buildMangaContent() {
    if (isLoadingContent) {
      return Center(
        child: CircularProgressIndicator(
          valueColor: AlwaysStoppedAnimation<Color>(AppTheme.accentColor),
        ),
      );
    }

    return Column(
      children: [
        // Latest Manga Section
        _buildSectionHeader('Latest Manga'),
        Expanded(
          child: GridView.builder(
            padding: EdgeInsets.all(16),
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              childAspectRatio: 0.7,
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
            ),
            itemCount: latestComics.length,
            itemBuilder: (context, index) {
              final comic = latestComics[index];
              return _buildMangaGridCard(comic);
            },
          ),
        ),
      ],
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
      child: Row(
        children: [
          Container(
            padding: EdgeInsets.all(8),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  AppTheme.primaryColor.withOpacity(0.2),
                  AppTheme.primaryColor.withOpacity(0.1),
                ],
              ),
              borderRadius: BorderRadius.circular(AppTheme.radiusSmall),
              border: Border.all(
                color: AppTheme.primaryColor.withOpacity(0.3),
                width: 1.5,
              ),
            ),
            child: Icon(
              Icons.category,
              color: AppTheme.primaryColor,
              size: 20,
            ),
          ),
          SizedBox(width: 12),
          Text(
            title,
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: Colors.white,
              letterSpacing: 0.5,
              fontSize: 18,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHorizontalAnimeCard(dynamic anime) {
    return StatefulBuilder(
      builder: (context, setState) {
        bool _isHovered = false;
        return MouseRegion(
          cursor: SystemMouseCursors.click,
          onEnter: (_) => setState(() => _isHovered = true),
          onExit: (_) => setState(() => _isHovered = false),
          child: AnimatedContainer(
            duration: Duration(milliseconds: 200),
            width: 120,
            margin: EdgeInsets.only(right: 12),
            transform: Matrix4.identity()
              ..scale(_isHovered ? 1.05 : 1.0),
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => AnimeDetailsScreen(url: anime['url']),
                    ),
                  );
                },
                borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
                splashColor: AppTheme.primaryColor.withOpacity(0.1),
                highlightColor: AppTheme.primaryColor.withOpacity(0.05),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Container(
                        width: double.infinity,
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
                                anime['image_url'] ?? '',
                                fit: BoxFit.cover,
                                errorBuilder: (context, error, stackTrace) {
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
                                      child: Icon(Icons.broken_image, color: AppTheme.textSecondaryColor),
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
                                      size: 30,
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    SizedBox(height: 8),
                    Container(
                      height: 40,
                      child: Text(
                        anime['title'] ?? 'Unknown Title',
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

  Widget _buildAnimeGridCard(dynamic anime) {
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
                    builder: (context) => AnimeDetailsScreen(url: anime['url']),
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
                    borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
                    boxShadow: _isHovered
                      ? AppTheme.mediumShadow
                      : AppTheme.subtleShadow,
                    border: Border.all(
                      color: Colors.white.withOpacity(_isHovered ? 0.1 : 0.05),
                      width: 1.2,
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Stack(
                          children: [
                            ClipRRect(
                              borderRadius: BorderRadius.only(
                                topLeft: Radius.circular(AppTheme.radiusMedium),
                                topRight: Radius.circular(AppTheme.radiusMedium),
                              ),
                              child: Image.network(
                                anime['image_url'] ?? '',
                                width: double.infinity,
                                height: double.infinity,
                                fit: BoxFit.cover,
                                errorBuilder: (context, error, stackTrace) {
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
                                      child: Icon(Icons.broken_image, color: AppTheme.textSecondaryColor),
                                    ),
                                  );
                                },
                              ),
                            ),
                            // Type badge
                            Positioned(
                              top: 8,
                              left: 8,
                              child: Container(
                                padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(
                                  gradient: AppTheme.primaryGradient,
                                  borderRadius: BorderRadius.circular(AppTheme.radiusSmall),
                                  border: Border.all(
                                    color: AppTheme.primaryColor.withOpacity(0.3),
                                    width: 1.5,
                                  ),
                                  boxShadow: [
                                    BoxShadow(
                                      color: AppTheme.primaryColor.withOpacity(0.2),
                                      blurRadius: 6,
                                      spreadRadius: 0,
                                    ),
                                  ],
                                ),
                                child: Text(
                                  'ANIME',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 10,
                                    letterSpacing: 0.5,
                                  ),
                                ),
                              ),
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
                                      Colors.black.withOpacity(_isHovered ? 0.4 : 0.3),
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
                      Padding(
                        padding: const EdgeInsets.all(12.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              anime['title'] ?? 'No Title',
                              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                                fontWeight: FontWeight.bold,
                                color: _isHovered
                                  ? AppTheme.primaryColor.withOpacity(0.9)
                                  : Colors.white,
                                height: 1.2,
                              ),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                            if (anime['genres'] != null && anime['genres'].isNotEmpty)
                              Padding(
                                padding: const EdgeInsets.only(top: 6.0),
                                child: Text(
                                  anime['genres'][0],
                                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                    color: AppTheme.textSecondaryColor,
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildMangaGridCard(dynamic manga) {
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
                    builder: (context) => ComicDetailsScreen(url: manga['url']),
                  ),
                );
              },
              borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
              splashColor: AppTheme.accentColor.withOpacity(0.1),
              highlightColor: AppTheme.accentColor.withOpacity(0.05),
              child: MouseRegion(
                cursor: SystemMouseCursors.click,
                onEnter: (_) => setState(() => _isHovered = true),
                onExit: (_) => setState(() => _isHovered = false),
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
                    borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
                    boxShadow: _isHovered
                      ? AppTheme.mediumShadow
                      : AppTheme.subtleShadow,
                    border: Border.all(
                      color: Colors.white.withOpacity(_isHovered ? 0.1 : 0.05),
                      width: 1.2,
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Stack(
                          children: [
                            ClipRRect(
                              borderRadius: BorderRadius.only(
                                topLeft: Radius.circular(AppTheme.radiusMedium),
                                topRight: Radius.circular(AppTheme.radiusMedium),
                              ),
                              child: Image.network(
                                manga['image_url'] ?? '',
                                width: double.infinity,
                                height: double.infinity,
                                fit: BoxFit.cover,
                                errorBuilder: (context, error, stackTrace) {
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
                                      child: Icon(Icons.broken_image, color: AppTheme.textSecondaryColor),
                                    ),
                                  );
                                },
                              ),
                            ),
                            // Type badge
                            Positioned(
                              top: 8,
                              left: 8,
                              child: Container(
                                padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(
                                    colors: [
                                      AppTheme.accentColor,
                                      AppTheme.accentColor.withOpacity(0.8),
                                    ],
                                  ),
                                  borderRadius: BorderRadius.circular(AppTheme.radiusSmall),
                                  border: Border.all(
                                    color: AppTheme.accentColor.withOpacity(0.3),
                                    width: 1.5,
                                  ),
                                  boxShadow: [
                                    BoxShadow(
                                      color: AppTheme.accentColor.withOpacity(0.2),
                                      blurRadius: 6,
                                      spreadRadius: 0,
                                    ),
                                  ],
                                ),
                                child: Text(
                                  'MANGA',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 10,
                                    letterSpacing: 0.5,
                                  ),
                                ),
                              ),
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
                                      Colors.black.withOpacity(_isHovered ? 0.4 : 0.3),
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
                                    Icons.menu_book,
                                    color: Colors.white.withOpacity(0.9),
                                    size: 40,
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.all(12.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              manga['title'] ?? 'No Title',
                              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                                fontWeight: FontWeight.bold,
                                color: _isHovered
                                  ? AppTheme.accentColor.withOpacity(0.9)
                                  : Colors.white,
                                height: 1.2,
                              ),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                            if (manga['genres'] != null && manga['genres'].isNotEmpty)
                              Padding(
                                padding: const EdgeInsets.only(top: 6.0),
                                child: Text(
                                  manga['genres'][0],
                                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                    color: AppTheme.textSecondaryColor,
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  void _showFilterDialog() {
    final List<String> genreOptions = [
      'All',
      ...genres.map((genre) => genre['name'] as String).toList()
    ];

    final List<int> years =
        List.generate(10, (index) => DateTime.now().year - index);

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppTheme.cardColor,
        title: Text(
          'Filter Results',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
        content: Container(
          width: double.maxFinite,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Year',
                style: TextStyle(
                  color: AppTheme.textSecondaryColor,
                  fontWeight: FontWeight.bold,
                ),
              ),
              SizedBox(height: 8),
              Container(
                padding: EdgeInsets.symmetric(horizontal: 12),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<int>(
                    value: selectedYear,
                    isExpanded: true,
                    dropdownColor: AppTheme.cardColor,
                    style: TextStyle(color: Colors.white),
                    icon: Icon(Icons.arrow_drop_down, color: Colors.white),
                    items: years
                        .map((year) => DropdownMenuItem(
                              value: year,
                              child: Text('$year'),
                            ))
                        .toList(),
                    onChanged: (value) {
                      setState(() => selectedYear = value!);
                      Navigator.pop(context);
                      _loadData();
                    },
                  ),
                ),
              ),
              SizedBox(height: 16),
              Text(
                'Genre',
                style: TextStyle(
                  color: AppTheme.textSecondaryColor,
                  fontWeight: FontWeight.bold,
                ),
              ),
              SizedBox(height: 8),
              Container(
                padding: EdgeInsets.symmetric(horizontal: 12),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<String>(
                    value: selectedGenre,
                    isExpanded: true,
                    dropdownColor: AppTheme.cardColor,
                    style: TextStyle(color: Colors.white),
                    icon: Icon(Icons.arrow_drop_down, color: Colors.white),
                    items: genreOptions
                        .map((genre) => DropdownMenuItem(
                              value: genre,
                              child: Text(genre),
                            ))
                        .toList(),
                    onChanged: (value) {
                      setState(() => selectedGenre = value!);
                      Navigator.pop(context);
                      if (value != 'All') {
                        final genre = genres.firstWhere((g) => g['name'] == value);
                        _performGenreSearch({'name': value, 'url': null});
                      } else {
                        _loadData();
                      }
                    },
                  ),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () {
              setState(() {
                selectedYear = DateTime.now().year;
                selectedGenre = 'All';
              });
              Navigator.pop(context);
              _loadData();
            },
            child: Text(
              'Reset Filters',
              style: TextStyle(color: AppTheme.accentColor),
            ),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _loadData();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.primaryColor,
              foregroundColor: Colors.white,
            ),
            child: Text('Apply'),
          ),
        ],
      ),
    );
  }
}