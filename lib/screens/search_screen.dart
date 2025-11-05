import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/api_service.dart';
import '../theme/app_theme.dart';
import '../widgets/custom_error_dialog.dart';
import '../providers/app_state_provider.dart';
import 'anime_details_screen.dart';
import 'comic_details_screen.dart';

class SearchScreen extends StatefulWidget {
  @override
  _SearchScreenState createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  final _searchController = TextEditingController();
  List<dynamic> _searchResults = [];
  List<dynamic> _genres = [];
  bool _isLoading = false;
  bool _hasSearched = false;
  bool _isLoadingGenres = false;
  String _selectedFilter = 'All';
  int _selectedYear = DateTime.now().year;
  String _selectedGenre = 'All';
  String _selectedChip = '';

  @override
  void initState() {
    super.initState();
    
    // Initialize AppStateProvider
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Provider.of<AppStateProvider>(context, listen: false).initialize();
    });
    
    _loadGenres();
  }

  void _loadGenres() async {
    setState(() {
      _isLoadingGenres = true;
    });

    try {
      final genres = await ApiService.fetchGenres();
      if (mounted) {
        setState(() {
          _genres = genres;
          _isLoadingGenres = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoadingGenres = false);
        print('Error loading genres: $e');
      }
    }
  }

  void _performGenreSearch(Map<String, dynamic> genre) async {
    setState(() {
      _isLoading = true;
      _hasSearched = true;
    });

    try {
      List<dynamic> allResults = [];
      
      if (genre['url'] != null) {
        final genreContent = await ApiService.fetchGenreContent(genre['url']);
        if (genreContent['content'] != null) {
          // Tambahkan properti 'type' ke setiap item dan tangani tipe yang tidak dikenali
          allResults = genreContent['content'].map((item) {
            String itemType = 'unknown';
            if (item['type'] != null) {
              final originalType = item['type'].toString().toLowerCase();
              if (originalType == 'anime') {
                itemType = 'anime';
              } else if (originalType == 'comic' || originalType == 'manga') {
                itemType = 'comic';
              } else if (originalType == 'movie' || originalType == 'series') {
                // Konversi movie/series ke anime untuk konsistensi
                itemType = 'anime';
              } else {
                print('Unknown item type: ${originalType} for item: ${item['title']}');
                itemType = 'anime'; // Default ke anime
              }
            } else {
              itemType = 'anime'; // Default jika tidak ada type
            }
            return {...item, 'type': itemType};
          }).toList();
        }
      }

      if (mounted) {
        setState(() {
          // Gunakan hasil yang sudah disiapkan
          List<dynamic> filteredResults = allResults;

          // Terapkan filter tipe
          if (_selectedFilter == 'Anime') {
            filteredResults = filteredResults
                .where((item) => item['type'] == 'anime')
                .toList();
          } else if (_selectedFilter == 'Manga') {
            filteredResults = filteredResults
                .where((item) => item['type'] == 'comic')
                .toList();
          }

          _searchResults = filteredResults;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        _showErrorDialog('Search Error', 'Failed to perform search: $e');
      }
    }
  }

  void _performSearch(String query) async {
    if (query.isEmpty) return;

    setState(() {
      _isLoading = true;
      _hasSearched = true;
    });

    try {
      // Pencarian biasa dengan query text
      final animeResults = await ApiService.searchAnime(query);
      final comicResults = await ApiService.searchComics(query);
      
      // Tambahkan properti 'type' ke setiap item dan tangani tipe yang tidak dikenali
      final typedAnimeResults = animeResults.map((item) {
        String itemType = 'anime';
        if (item['type'] != null) {
          final originalType = item['type'].toString().toLowerCase();
          if (originalType == 'movie' || originalType == 'series') {
            itemType = 'anime'; // Konversi movie/series ke anime
          } else if (originalType != 'anime') {
            print('Unknown anime item type: ${originalType} for item: ${item['title']}');
            itemType = 'anime'; // Default ke anime
          }
        }
        return {...item, 'type': itemType};
      }).toList();
      final typedComicResults = comicResults.map((item) {
        String itemType = 'comic';
        if (item['type'] != null) {
          final originalType = item['type'].toString().toLowerCase();
          if (originalType != 'comic' && originalType != 'manga') {
            print('Unknown comic item type: ${originalType} for item: ${item['title']}');
            itemType = 'comic'; // Default ke comic
          }
        }
        return {...item, 'type': itemType};
      }).toList();
      
      final allResults = [...typedAnimeResults, ...typedComicResults];

      if (mounted) {
        setState(() {
          // Gunakan hasil yang sudah disiapkan
          List<dynamic> filteredResults = allResults;

          // Terapkan filter tipe
          if (_selectedFilter == 'Anime') {
            filteredResults = filteredResults
                .where((item) => item['type'] == 'anime')
                .toList();
          } else if (_selectedFilter == 'Manga') {
            filteredResults = filteredResults
                .where((item) => item['type'] == 'comic')
                .toList();
          }

          // Terapkan filter genre jika bukan 'All'
          if (_selectedGenre != 'All') {
            filteredResults = filteredResults.where((item) {
              if (item['genres'] != null) {
                return item['genres'].contains(_selectedGenre);
              }
              return false;
            }).toList();
          }

          // Terapkan filter tahun (jika diperlukan)
          if (_selectedYear != DateTime.now().year) {
            filteredResults = filteredResults.where((item) {
              final releaseYear = item['release_date'] != null
                  ? DateTime.tryParse(item['release_date'])?.year ?? 0
                  : 0;
              return releaseYear == _selectedYear;
            }).toList();
          }

          _searchResults = filteredResults;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        _showErrorDialog('Search Error', 'Failed to perform search: $e');
      }
    }
  }

  void _showErrorDialog(String title, String message) {
    CustomErrorDialog.show(
      context,
      title: title,
      message: message,
      onRetry: () {
        if (_searchController.text.isNotEmpty) {
          _performSearch(_searchController.text);
        }
      },
    );
  }

  void _clearSearch() {
    setState(() {
      _searchController.clear();
      _searchResults = [];
      _hasSearched = false;
      _selectedChip = '';
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      appBar: AppBar(
        backgroundColor: AppTheme.backgroundColor,
        elevation: 0,
        title: _buildSearchField(),
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
          _buildFilterChips(),
          Expanded(
            child: _isLoading
                ? _buildLoadingView()
                : _hasSearched && _searchResults.isEmpty
                    ? _buildNoResultsView()
                    : _hasSearched
                        ? _buildSearchResultsGrid()
                        : _buildInitialSearchView(),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchField() {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.0, end: 1.0),
      duration: Duration(milliseconds: 600),
      curve: Curves.easeOut,
      builder: (context, value, child) {
        return Transform.translate(
          offset: Offset(0, 20 * (1 - value)),
          child: Opacity(
            opacity: value,
            child: Container(
              height: 50,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    Colors.white.withOpacity(0.08),
                    Colors.white.withOpacity(0.03),
                  ],
                ),
                borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
                border: Border.all(
                  color: Colors.white.withOpacity(0.15),
                  width: 1.2,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.2),
                    blurRadius: 8,
                    offset: Offset(0, 4),
                  ),
                ],
              ),
              child: TextField(
                controller: _searchController,
                style: TextStyle(color: Colors.white, fontSize: 16),
                decoration: InputDecoration(
                  hintText: 'Search anime or manga...',
                  hintStyle: TextStyle(color: AppTheme.textSecondaryColor.withOpacity(0.7)),
                  prefixIcon: Icon(Icons.search, color: AppTheme.textSecondaryColor),
                  suffixIcon: _searchController.text.isNotEmpty
                      ? IconButton(
                          icon: Icon(Icons.clear, color: AppTheme.textSecondaryColor),
                          onPressed: _clearSearch,
                        )
                      : null,
                  border: InputBorder.none,
                  enabledBorder: InputBorder.none,
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
                    borderSide: BorderSide(color: AppTheme.accentColor, width: 2),
                  ),
                  contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                ),
                onSubmitted: (query) {
                  setState(() {
                    _selectedChip = '';
                  });
                  _performSearch(query);
                },
                textInputAction: TextInputAction.search,
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildFilterChips() {
    return Container(
      height: 50,
      padding: EdgeInsets.symmetric(horizontal: 16),
      child: ListView(
        scrollDirection: Axis.horizontal,
        children: [
          _buildFilterChip('All', _selectedFilter == 'All'),
          SizedBox(width: 8),
          _buildFilterChip('Anime', _selectedFilter == 'Anime'),
          SizedBox(width: 8),
          _buildFilterChip('Manga', _selectedFilter == 'Manga'),
          SizedBox(width: 16),
          if (_selectedChip.isNotEmpty) ...[
            Chip(
              label: Text(_selectedChip),
              backgroundColor: AppTheme.primaryColor.withOpacity(0.8),
              labelStyle: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
              deleteIcon: Icon(Icons.close, size: 16, color: Colors.white),
              onDeleted: () {
                setState(() {
                  _selectedChip = '';
                  _searchResults = [];
                  _hasSearched = false;
                });
              },
            ),
          ],
          if (_selectedGenre != 'All') ...[
          ],
        ],
      ),
    );
  }

  Widget _buildFilterChip(String label, bool isSelected) {
    return StatefulBuilder(
      builder: (context, setState) {
        bool _isHovered = false;
        return MouseRegion(
          cursor: SystemMouseCursors.click,
          onEnter: (_) => setState(() => _isHovered = true),
          onExit: (_) => setState(() => _isHovered = false),
          child: AnimatedContainer(
            duration: Duration(milliseconds: 200),
            transform: Matrix4.identity()
              ..scale(_isHovered ? 1.05 : 1.0),
            child: FilterChip(
              label: Text(label),
              selected: isSelected,
              selectedColor: label == 'Anime'
                ? AppTheme.primaryColor
                : label == 'Manga'
                  ? AppTheme.accentColor
                  : AppTheme.primaryColor,
              backgroundColor: _isHovered
                ? (label == 'Anime'
                    ? AppTheme.primaryColor.withOpacity(0.25)
                    : label == 'Manga'
                      ? AppTheme.accentColor.withOpacity(0.25)
                      : Colors.white.withOpacity(0.15))
                : (label == 'Anime'
                    ? AppTheme.primaryColor.withOpacity(0.2)
                    : label == 'Manga'
                      ? AppTheme.accentColor.withOpacity(0.2)
                      : Colors.white.withOpacity(0.1)),
              checkmarkColor: Colors.white,
              labelStyle: TextStyle(
                color: isSelected || _isHovered
                  ? Colors.white
                  : AppTheme.textSecondaryColor,
                fontWeight: isSelected || _isHovered ? FontWeight.bold : FontWeight.normal,
                fontSize: _isHovered ? 13 : 12,
              ),
              side: BorderSide(
                color: isSelected || _isHovered
                  ? (label == 'Anime'
                      ? AppTheme.primaryColor
                      : label == 'Manga'
                        ? AppTheme.accentColor
                        : AppTheme.primaryColor)
                  : Colors.white.withOpacity(0.3),
                width: isSelected || _isHovered ? 1.5 : 1.0,
              ),
              onSelected: (selected) {
                setState(() {
                  _selectedFilter = label;
                  if (_searchController.text.isNotEmpty) {
                    _performSearch(_searchController.text);
                  }
                });
              },
            ),
          ),
        );
      },
    );
  }

  Widget _buildLoadingView() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircularProgressIndicator(
            valueColor: AlwaysStoppedAnimation<Color>(AppTheme.primaryColor),
          ),
          SizedBox(height: 16),
          Text(
            'Searching...',
            style: TextStyle(color: Colors.white, fontSize: 16),
          ),
        ],
      ),
    );
  }

  Widget _buildNoResultsView() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.search_off,
            size: 64,
            color: Colors.grey,
          ),
          SizedBox(height: 16),
          Text(
            'No results found',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          SizedBox(height: 8),
          Text(
            'Try different keywords or filters',
            style: TextStyle(
              color: AppTheme.textSecondaryColor,
              fontSize: 14,
            ),
          ),
          SizedBox(height: 24),
          StatefulBuilder(
            builder: (context, setState) {
              bool _isHovered = false;
              return MouseRegion(
                cursor: SystemMouseCursors.click,
                onEnter: (_) => setState(() => _isHovered = true),
                onExit: (_) => setState(() => _isHovered = false),
                child: AnimatedContainer(
                  duration: Duration(milliseconds: 200),
                  transform: Matrix4.identity()
                    ..scale(_isHovered ? 1.05 : 1.0),
                  child: ElevatedButton(
                    onPressed: _clearSearch,
                    child: Text('Clear Search'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _isHovered
                        ? AppTheme.primaryColor.withOpacity(0.9)
                        : AppTheme.primaryColor,
                      foregroundColor: Colors.white,
                      padding: EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(AppTheme.radiusSmall),
                      ),
                      elevation: _isHovered ? 8 : 4,
                      shadowColor: AppTheme.primaryColor.withOpacity(0.3),
                    ),
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildInitialSearchView() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: AppTheme.cardColor,
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.search,
              size: 64,
              color: AppTheme.primaryColor,
            ),
          ),
          SizedBox(height: 24),
          Text(
            'Search for Anime or Komik',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          SizedBox(height: 12),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32.0),
            child: Text(
              'Enter a title, character, or genre to find your next favorite show',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: AppTheme.textSecondaryColor,
                fontSize: 16,
              ),
            ),
          ),
          SizedBox(height: 32),
          _buildPopularSearches(),
        ],
      ),
    );
  }

  Widget _buildPopularSearches() {
    // Ambil 8 genre pertama dari API, atau gunakan fallback jika belum dimuat
    final popularSearches = _genres.isNotEmpty
        ? _genres.take(8).map((genre) => genre['name'] as String).toList()
        : [
            'Action',
            'Romance',
            'Fantasy',
            'Sci-Fi',
            'Comedy',
            'Drama',
            'Adventure',
            'Slice of Life'
          ];

    return Column(
      children: [
        Text(
          'Popular Categories',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: AppTheme.textSecondaryColor,
          ),
        ),
        SizedBox(height: 16),
        _isLoadingGenres
            ? CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(AppTheme.primaryColor),
              )
            : Wrap(
                alignment: WrapAlignment.center,
                spacing: 8,
                runSpacing: 8,
                children: _genres.isNotEmpty
                     ? _genres.take(8).map((genre) {
                         final isSelected = _selectedChip == genre['name'];
                         return StatefulBuilder(
                           builder: (context, setState) {
                             bool _isHovered = false;
                             return MouseRegion(
                               cursor: SystemMouseCursors.click,
                               onEnter: (_) => setState(() => _isHovered = true),
                               onExit: (_) => setState(() => _isHovered = false),
                               child: AnimatedContainer(
                                 duration: Duration(milliseconds: 200),
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
                                        _selectedChip = genre['name'];
                                      });
                                      _performGenreSearch(genre);
                                   },
                                 ),
                               ),
                             );
                           },
                         );
                       }).toList()
                     : popularSearches.map((search) {
                         final isSelected = _selectedChip == search;
                         return ActionChip(
                           label: Text(
                             search,
                             style: TextStyle(
                               color: isSelected ? AppTheme.backgroundColor : Colors.white,
                               fontSize: 12,
                               fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                             ),
                           ),
                           backgroundColor: isSelected 
                               ? AppTheme.primaryColor 
                               : AppTheme.cardColor,
                           side: BorderSide(
                             color: AppTheme.primaryColor, 
                             width: isSelected ? 2 : 1
                           ),
                           onPressed: () {
                              setState(() {
                                _selectedChip = search;
                              });
                              _performSearch(search);
                            },
                         );
                       }).toList(),
              ),
      ],
    );
  }

  Widget _buildSearchResultsGrid() {
    return GridView.builder(
      padding: EdgeInsets.all(12),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        childAspectRatio: 0.7,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
      ),
      itemCount: _searchResults.length,
      itemBuilder: (context, index) {
        final item = _searchResults[index];
        return _buildResultCard(item);
      },
    );
  }

  Widget _buildResultCard(dynamic item) {
    // Ambil tipe item dan ubah ke lowercase untuk konsistensi
    final String itemType =
        (item['type']?.toString().toLowerCase() ?? '').trim();

    // Tentukan layar tujuan berdasarkan tipe
    Widget? targetScreen;
    if (itemType == 'anime') {
      targetScreen = AnimeDetailsScreen(url: item['url']);
    } else if (itemType == 'comic' || itemType == 'manga') {
      targetScreen = ComicDetailsScreen(url: item['url']);
    } else {
      // Log untuk debugging jika tipe tidak dikenali
      print('Unknown item type: $itemType for item: ${item['title']}');
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
          borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
          boxShadow: AppTheme.subtleShadow,
        ),
        child: Center(
          child: Text(
            'Unknown content type',
            style: TextStyle(color: AppTheme.textSecondaryColor),
          ),
        ),
      );
    }

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
              borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => targetScreen!),
                );
              },
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
                                item['image_url'] ?? '',
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
                                loadingBuilder: (context, child, loadingProgress) {
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
                            ),
                            Positioned(
                              top: 8,
                              left: 8,
                              child: AnimatedContainer(
                                duration: Duration(milliseconds: 200),
                                padding: EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                decoration: BoxDecoration(
                                  gradient: itemType == 'anime'
                                      ? AppTheme.primaryGradient
                                      : LinearGradient(
                                          colors: [
                                            AppTheme.accentColor,
                                            AppTheme.accentColor.withOpacity(0.8),
                                          ],
                                        ),
                                  borderRadius: BorderRadius.circular(AppTheme.radiusSmall),
                                  border: Border.all(
                                    color: itemType == 'anime'
                                        ? AppTheme.primaryColor.withOpacity(0.3)
                                        : AppTheme.accentColor.withOpacity(0.3),
                                    width: 1.5,
                                  ),
                                  boxShadow: [
                                    BoxShadow(
                                      color: itemType == 'anime'
                                          ? AppTheme.primaryColor.withOpacity(0.2)
                                          : AppTheme.accentColor.withOpacity(0.2),
                                      blurRadius: 6,
                                      spreadRadius: 0,
                                    ),
                                  ],
                                ),
                                child: Text(
                                  itemType == 'anime' ? 'Anime' : 'Komik',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 11,
                                    letterSpacing: 0.5,
                                  ),
                                ),
                              ),
                            ),
                            if (item['rating'] != null)
                              Positioned(
                                top: 8,
                                right: 8,
                                child: AnimatedContainer(
                                  duration: Duration(milliseconds: 200),
                                  padding:
                                      EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                  decoration: BoxDecoration(
                                    gradient: LinearGradient(
                                      begin: Alignment.topLeft,
                                      end: Alignment.bottomRight,
                                      colors: [
                                        Colors.black.withOpacity(0.8),
                                        Colors.black.withOpacity(0.6),
                                      ],
                                    ),
                                    borderRadius: BorderRadius.circular(AppTheme.radiusSmall),
                                    border: Border.all(
                                      color: Colors.amber.withOpacity(0.3),
                                      width: 1,
                                    ),
                                  ),
                                  child: Row(
                                    children: [
                                      Icon(Icons.star, color: Colors.amber, size: 12),
                                      SizedBox(width: 2),
                                      Text(
                                        '${item['rating']}',
                                        style: TextStyle(
                                          color: Colors.white,
                                          fontWeight: FontWeight.bold,
                                          fontSize: 10,
                                        ),
                                      ),
                                    ],
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
                                    stops: [0.0, 0.6, 1.0],
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
                        padding: const EdgeInsets.all(16.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              item['title'] ?? 'No Title',
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
                            if (item['genres'] != null && item['genres'].isNotEmpty)
                              Padding(
                                padding: const EdgeInsets.only(top: 6.0),
                                child: Text(
                                  item['genres'][0],
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
    // Buat list genres dengan 'All' di awal, diikuti genres dari API
    final List<String> genres = [
      'All',
      ..._genres.map((genre) => genre['name'] as String).toList()
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
                    value: _selectedYear,
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
                      setState(() => _selectedYear = value!);
                      Navigator.pop(context);
                      if (_searchController.text.isNotEmpty) {
                        _performSearch(_searchController.text);
                      }
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
                    value: _selectedGenre,
                    isExpanded: true,
                    dropdownColor: AppTheme.cardColor,
                    style: TextStyle(color: Colors.white),
                    icon: Icon(Icons.arrow_drop_down, color: Colors.white),
                    items: genres
                        .map((genre) => DropdownMenuItem(
                              value: genre,
                              child: Text(genre),
                            ))
                        .toList(),
                    onChanged: (value) {
                      setState(() => _selectedGenre = value!);
                      Navigator.pop(context);
                      if (_searchController.text.isNotEmpty) {
                        _performSearch(_searchController.text);
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
                _selectedYear = DateTime.now().year;
                _selectedGenre = 'All';
              });
              Navigator.pop(context);
              if (_searchController.text.isNotEmpty) {
                _performSearch(_searchController.text);
              }
            },
            child: Text(
              'Reset Filters',
              style: TextStyle(color: AppTheme.accentColor),
            ),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              if (_searchController.text.isNotEmpty) {
                _performSearch(_searchController.text);
              }
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
