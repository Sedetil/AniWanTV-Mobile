import 'package:flutter/material.dart';
import '../services/api_service.dart';
import '../theme/app_theme.dart';
import '../widgets/custom_error_dialog.dart';
import 'anime_details_screen.dart';
import 'comic_details_screen.dart';

class SearchScreen extends StatefulWidget {
  @override
  _SearchScreenState createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  final _searchController = TextEditingController();
  final ApiService _apiService = ApiService();
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
    _loadGenres();
  }

  void _loadGenres() async {
    setState(() {
      _isLoadingGenres = true;
    });

    try {
      final genres = await _apiService.fetchGenres();
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
        final genreContent = await _apiService.fetchGenreContent(genre['url']);
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
      final animeResults = await _apiService.searchAnime(query);
      final comicResults = await _apiService.searchComics(query);
      
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
    return Container(
      height: 40,
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.1),
        borderRadius: BorderRadius.circular(20),
      ),
      child: TextField(
        controller: _searchController,
        style: TextStyle(color: Colors.white),
        decoration: InputDecoration(
          hintText: 'Search anime or manga...',
          hintStyle: TextStyle(color: Colors.white70),
          prefixIcon: Icon(Icons.search, color: Colors.white70),
          suffixIcon: _searchController.text.isNotEmpty
              ? IconButton(
                  icon: Icon(Icons.clear, color: Colors.white70),
                  onPressed: _clearSearch,
                )
              : null,
          border: InputBorder.none,
          contentPadding: EdgeInsets.symmetric(vertical: 10, horizontal: 16),
        ),
        onSubmitted: (query) {
          setState(() {
            _selectedChip = '';
          });
          _performSearch(query);
        },
        textInputAction: TextInputAction.search,
      ),
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
    // Menentukan warna berdasarkan label
    Color chipColor;
    Color textColor;
    Color backgroundColor;

    if (label == 'Anime') {
      chipColor =
          isSelected ? AppTheme.primaryColor : Colors.white.withOpacity(0.1);
      backgroundColor = isSelected
          ? AppTheme.primaryColor
          : AppTheme.primaryColor.withOpacity(0.2);
      textColor = Colors.white;
    } else if (label == 'Manga') {
      chipColor =
          isSelected ? AppTheme.accentColor : Colors.white.withOpacity(0.1);
      backgroundColor = isSelected
          ? AppTheme.accentColor
          : AppTheme.accentColor.withOpacity(0.2);
      textColor = isSelected ? Colors.black : Colors.black87;
    } else {
      // All
      chipColor =
          isSelected ? AppTheme.primaryColor : Colors.white.withOpacity(0.1);
      backgroundColor =
          isSelected ? AppTheme.primaryColor : Colors.grey.withOpacity(0.3);
      textColor = isSelected ? Colors.white : Colors.white.withOpacity(0.9);
    }

    return FilterChip(
      label: Text(label),
      selected: isSelected,
      selectedColor: chipColor,
      backgroundColor: backgroundColor,
      checkmarkColor:
          label == 'Manga' && isSelected ? Colors.black : Colors.white,
      labelStyle: TextStyle(
        color: textColor,
        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
      ),
      onSelected: (selected) {
        setState(() {
          _selectedFilter = label;
          if (_searchController.text.isNotEmpty) {
            _performSearch(_searchController.text);
          }
        });
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
          ElevatedButton(
            onPressed: _clearSearch,
            child: Text('Clear Search'),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.primaryColor,
              foregroundColor: Colors.white,
              padding: EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
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
                         return ActionChip(
                           label: Text(
                             genre['name'],
                             style: TextStyle(
                               color: isSelected ? AppTheme.backgroundColor : Colors.white,
                               fontSize: 12,
                               fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                             ),
                           ),
                           backgroundColor: isSelected 
                               ? AppTheme.primaryColor 
                               : AppTheme.primaryColor.withOpacity(0.2),
                           side: BorderSide(
                             color: AppTheme.primaryColor, 
                             width: isSelected ? 2 : 1
                           ),
                           onPressed: () {
                              setState(() {
                                _selectedChip = genre['name'];
                              });
                              _performGenreSearch(genre);
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
      return Card(
        color: AppTheme.cardColor,
        child: Center(
          child: Text(
            'Unknown content type',
            style: TextStyle(color: Colors.white),
          ),
        ),
      );
    }

    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      color: AppTheme.cardColor,
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => targetScreen!),
          );
        },
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Stack(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.only(
                      topLeft: Radius.circular(12),
                      topRight: Radius.circular(12),
                    ),
                    child: Image.network(
                      item['image_url'] ?? '',
                      width: double.infinity,
                      height: double.infinity,
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) {
                        return Container(
                          color: Colors.grey[800],
                          child: Center(
                            child: Icon(Icons.broken_image, color: Colors.grey),
                          ),
                        );
                      },
                    ),
                  ),
                  Positioned(
                    top: 8,
                    left: 8,
                    child: Container(
                      padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: itemType == 'anime'
                            ? AppTheme.primaryColor
                            : AppTheme.accentColor,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        itemType == 'anime' ? 'Anime' : 'Komik',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 10,
                        ),
                      ),
                    ),
                  ),
                  if (item['rating'] != null)
                    Positioned(
                      top: 8,
                      right: 8,
                      child: Container(
                        padding:
                            EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: Colors.black.withOpacity(0.7),
                          borderRadius: BorderRadius.circular(4),
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
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(12.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item['title'] ?? 'No Title',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                      color: Colors.white,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (item['genres'] != null && item['genres'].isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 4.0),
                      child: Text(
                        item['genres'][0],
                        style: TextStyle(
                          color: AppTheme.textSecondaryColor,
                          fontSize: 12,
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
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
