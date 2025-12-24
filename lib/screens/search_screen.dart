import 'package:flutter/material.dart';
import 'dart:async';
import 'package:provider/provider.dart';
import '../services/api_service.dart';
import '../theme/app_theme.dart';
import '../widgets/custom_error_dialog.dart';
import '../providers/app_state_provider.dart';
import 'anime_details_screen.dart';
import 'comic_details_screen.dart';
import 'manga_reader_screen.dart';
import 'manga_reader_screen.dart';
import '../services/ad_service.dart';
import 'video_player_screen.dart';
import '../utils/toast_utils.dart';
import '../widgets/custom_loading_widget.dart';
import 'package:url_launcher/url_launcher.dart';

class SearchScreen extends StatefulWidget {
  final bool autoFocus;
  const SearchScreen({Key? key, this.autoFocus = false}) : super(key: key);

  @override
  _SearchScreenState createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> with SingleTickerProviderStateMixin {
  final _searchController = TextEditingController();
  List<dynamic> _searchResults = [];
  List<dynamic> _genres = [];
  bool _isLoading = false;
  bool _hasSearched = false;
  bool _isLoadingGenres = false;
  
  // Search Filters
  String _selectedFilter = 'All';
  int _selectedYear = DateTime.now().year;
  String _selectedGenre = 'All';
  String _selectedChip = ''; // For generic chips in search
  
  // Redesign States
  bool _isSearching = false;
  bool _showAnimeHistory = true; // Toggle between Anime and Komik history
  Timer? _debounce;
  final FocusNode _searchFocusNode = FocusNode();

  @override
  void dispose() {
    _debounce?.cancel();
    _searchController.dispose();
    _searchFocusNode.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    
    // Initialize search state
    _isSearching = widget.autoFocus;
    
    // Initialize AppStateProvider
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Provider.of<AppStateProvider>(context, listen: false).initialize();
      
      // Auto-focus if requested
      if (widget.autoFocus) {
        FocusScope.of(context).requestFocus(_searchFocusNode);
      }
    });
    
    _loadGenres();
  }

  void _onSearchChanged(String query) {
    if (_debounce?.isActive ?? false) _debounce!.cancel();
    _debounce = Timer(const Duration(milliseconds: 1000), () {
      if (query.isNotEmpty) {
        _performSearch(query);
      } else {
        setState(() {
          _searchResults = [];
          _hasSearched = false;
        });
      }
    });
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
      _isSearching = true; // Switch to search view
    });

    try {
      List<dynamic> allResults = [];
      
      if (genre['url'] != null) {
        final genreContent = await ApiService.fetchGenreContent(genre['url']);
        if (genreContent['content'] != null) {
          allResults = genreContent['content'].map((item) {
            String category = 'anime';
            if (item['type'] != null) {
              final originalType = item['type'].toString().toLowerCase();
              if (originalType == 'comic' || originalType == 'manga' || originalType == 'manhwa' || originalType == 'manhua') {
                category = 'comic';
              }
            }
            return {...item, 'category': category, 'type': item['type'] ?? category};
          }).toList();
        }
      }

      if (mounted) {
        setState(() {
          List<dynamic> filteredResults = allResults;

          if (_selectedFilter == 'Anime') {
            filteredResults = filteredResults
                .where((item) => item['category'] == 'anime' || item['type'] == 'anime')
                .toList();
          } else if (_selectedFilter == 'Manga') {
            filteredResults = filteredResults
                .where((item) => item['category'] == 'comic' || item['type'] == 'comic' || item['type'] == 'manga')
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
      final animeResults = await ApiService.searchAnime(query);
      final comicResults = await ApiService.searchComics(query);
      
      final allResults = [...animeResults, ...comicResults];

      if (mounted) {
        setState(() {
          List<dynamic> filteredResults = allResults;

          if (_selectedFilter == 'Anime') {
            filteredResults = filteredResults
                .where((item) => item['category'] == 'anime' || item['type'] == 'anime')
                .toList();
          } else if (_selectedFilter == 'Manga') {
            filteredResults = filteredResults
                .where((item) => item['category'] == 'comic' || item['type'] == 'comic')
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

  void _toggleSearchMode() {
    setState(() {
      _isSearching = !_isSearching;
      if (!_isSearching) {
        _searchController.clear();
        _searchResults = [];
        _hasSearched = false;
        _selectedChip = '';
        FocusScope.of(context).unfocus();
      } else {
        // Automatically focus search field when opened
        Future.delayed(Duration(milliseconds: 100), () {
            FocusScope.of(context).requestFocus(_searchFocusNode);
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      appBar: _buildAppBar(),
      body: _isSearching
          ? Column(
              children: [
                _buildFilterChips(),
                Expanded(
                  child: _isLoading
                      ? _buildLoadingView()
                      : _hasSearched && _searchResults.isEmpty
                          ? _buildNoResultsView()
                          : _hasSearched
                              ? _buildSearchResultsGrid()
                              : _buildInitialSearchView(), // Or simple "Type to search..."
                ),
              ],
            )
          : _buildHistoryView(),
    );
  }

  AppBar _buildAppBar() {
    if (_isSearching) {
      return AppBar(
        backgroundColor: AppTheme.backgroundColor,
        elevation: 0,
        title: _buildSearchField(),
        leading: IconButton(
            icon: Icon(Icons.arrow_back, color: Colors.white),
            onPressed: _toggleSearchMode,
        ),
        actions: [
          IconButton(
            icon: Icon(Icons.filter_list, color: Colors.white),
            onPressed: (){}, // TODO: Implement advanced filter dialog if needed
            tooltip: 'Filter results',
          ),
        ],
      );
    }
    
    return AppBar(
      backgroundColor: AppTheme.backgroundColor,
      elevation: 0,
      title: Text(
        'History', 
        style: TextStyle(
            fontSize: 24, 
            fontWeight: FontWeight.bold, 
            color: Colors.white
        ),
      ),
      actions: [
        IconButton(
          icon: Icon(Icons.search, size: 28, color: Colors.white),
          onPressed: _toggleSearchMode,
        ),
        SizedBox(width: 8),
      ],
    );
  }

  Widget _buildHistoryView() {
    final appState = Provider.of<AppStateProvider>(context);
    final historyList = _showAnimeHistory ? appState.animeHistory : appState.comicHistory;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(height: 16),
        _buildHistoryToggle(),
        SizedBox(height: 24),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0),
          child: Text(
            _showAnimeHistory ? 'Latest Watched' : 'Latest Read',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
        ),
        SizedBox(height: 16),
        Expanded(
          child: historyList.isEmpty
              ? _buildEmptyHistoryView()
              : ListView.builder(
                  padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  itemCount: historyList.length,
                  itemBuilder: (context, index) {
                    final item = historyList[index];
                    return _buildHistoryCard(item);
                  },
                ),
        ),
      ],
    );
  }

  Widget _buildHistoryToggle() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0),
      child: Row(
        children: [
          Expanded(
            child: _buildToggleItem(
              label: 'ANIME',
              isActive: _showAnimeHistory,
              onTap: () => setState(() => _showAnimeHistory = true),
            ),
          ),
          SizedBox(width: 16),
          Expanded(
            child: _buildToggleItem(
              label: 'KOMIK',
              isActive: !_showAnimeHistory,
              onTap: () => setState(() => _showAnimeHistory = false),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildToggleItem({required String label, required bool isActive, required VoidCallback onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: isActive ? AppTheme.primaryColor : const Color(0xFF1E1E1E),
          borderRadius: BorderRadius.circular(30),
        ),
        child: Text(
          label,
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 14,
          ),
        ),
      ),
    );
  }

  Widget _buildHistoryCard(dynamic item) {
    // Determine target screen and type label
    Widget? targetScreen;
    String typeLabel = 'Unknown';
    if (item['type'] == 'anime') {
      typeLabel = 'Anime';
      if (item['episode'] != null) {
        // For episodes, we redirect to AnimeDetailsScreen for now
        targetScreen = AnimeDetailsScreen(url: item['url']);
        final ep = item['episode'].toString();
        final match = RegExp(r'episode\s*(\d+)', caseSensitive: false).firstMatch(ep);
        if (match != null) {
           typeLabel = 'Episode ${match.group(1)}';
        } else {
           typeLabel = ep.toLowerCase().contains('episode') ? ep : 'Episode $ep';
        }
      } else {
        targetScreen = AnimeDetailsScreen(url: item['url']);
      }
    } else if (item['type'] == 'comic' || item['type'] == 'manga') {
      typeLabel = 'Manga';
      // Check if it's a specific chapter history (has 'chapter' key) or just a comic link
      if (item['chapter'] != null) {
        targetScreen = MangaReaderScreen(
          url: item['url'],
          title: item['title'],
          chapterId: item['chapter'].toString(),
          comicImageUrl: item['image_url'] ?? item['image'],
        );
        final ch = item['chapter'].toString();
        // Normalize: Remove existing 'chapter' text (case-insensitive) and force 'Chapter X' format
        final cleanCh = ch.replaceAll(RegExp(r'chapter\s*', caseSensitive: false), '').trim();
        typeLabel = 'Chapter $cleanCh';
      } else {
        targetScreen = ComicDetailsScreen(url: item['url'], type: item['type']);
      }
    }

    return Container(
      margin: EdgeInsets.only(bottom: 12),
      height: 80,
      decoration: BoxDecoration(
        color: Color(0xFF3F3B6C), // Purple-ish card background from design
        borderRadius: BorderRadius.circular(12),
      ),
      child: InkWell(
        onTap: () {
          if (item['type'] == 'anime') {
             if (item['episode_url'] != null) {
                // Feature: Direct play if URL exists (New history items)
                _showStreamBottomSheet(item);
             } else if (item['episode'] != null) {
                // Feature: Fallback for legacy items (Try to find episode by name)
                _fetchAndDirectPlay(item);
             } else if (targetScreen != null) {
                 Navigator.push(
                   context,
                   MaterialPageRoute(builder: (context) => targetScreen!),
                 );
             }
          } else if (targetScreen != null) {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => targetScreen!),
              );
          }
        },
        borderRadius: BorderRadius.circular(12),
        child: Row(
          children: [
            // Image
            ClipRRect(
              borderRadius: BorderRadius.only(
                topLeft: Radius.circular(12),
                bottomLeft: Radius.circular(12),
              ),
              child: (item['image_url'] ?? item['image']) != null
                  ? Image.network(
                      item['image_url'] ?? item['image'] ?? '',
                      width: 80,
                      height: 80,
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) => Container(
                        width: 80,
                        height: 80,
                        color: Colors.grey[800],
                        child: Icon(Icons.broken_image, color: Colors.white54),
                      ),
                    )
                  : Container(
                      width: 80,
                      height: 80,
                      color: Colors.grey[800],
                      child: Icon(Icons.image_not_supported, color: Colors.white54),
                    ),
            ),
            
            SizedBox(width: 16),
            
            // Title & Subtitle Logic
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 12.0),
                child: (() {
                  // Calculate Cleaned Title (Series Name)
                  final originalTitle = (item['title'] ?? 'Unknown Title').toString();
                  // Remove "Chapter X" or "Episode X" from start or end
                  // Example: "Chapter 1 Job Change Log" -> "Job Change Log"
                  // Example: "Job Change Log Chapter 1" -> "Job Change Log"
                  String cleanedTitle = originalTitle.replaceAll(RegExp(r'^(Episode|Chapter)\s*\d+\s*[-:]*\s*', caseSensitive: false), '');
                  cleanedTitle = cleanedTitle.replaceAll(RegExp(r'\s*[-:]*\s*(Episode|Chapter)\s*\d+.*$', caseSensitive: false), '').trim();
                  
                  final seriesTitle = cleanedTitle.isNotEmpty ? cleanedTitle : originalTitle;

                  // Determined Display Strings
                  String mainText = seriesTitle;
                  String subText = typeLabel;

                  // Swap for Comics: Chapter on Top, Series on Bottom
                  if (item['type'] == 'comic' || item['type'] == 'manga') {
                    mainText = typeLabel;
                    subText = seriesTitle;
                  }

                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        mainText,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 16,
                          color: Colors.white,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      SizedBox(height: 4),
                      Text(
                        subText,
                        style: TextStyle(
                          fontSize: 13,
                          color: Colors.grey[400],
                        ),
                      ),
                    ],
                  );
                })(),
              ),
            ),
            
            // Play Button Icon
            Container(
              margin: EdgeInsets.only(right: 16),
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white, width: 2),
              ),
              child: Icon(
                Icons.play_arrow_rounded,
                color: Colors.white,
                size: 20,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyHistoryView() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.history, size: 60, color: Colors.white24),
          SizedBox(height: 16),
          Text(
            'Belum ada riwayat',
            style: TextStyle(color: Colors.white54, fontSize: 16),
          ),
        ],
      ),
    );
  }

  // --- EXISTING SEARCH WIDGETS (Slightly modified) ---

  Widget _buildSearchField() {
    return TextField(
      controller: _searchController,
      focusNode: _searchFocusNode,
      style: TextStyle(color: Colors.white, fontSize: 16),
      decoration: InputDecoration(
        filled: true,
        fillColor: Colors.white.withOpacity(0.1),
        hintText: 'Search anime or manga...',
        hintStyle: TextStyle(color: AppTheme.textSecondaryColor.withOpacity(0.7)),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(30), // Pill shape for search bar
          borderSide: BorderSide.none,
        ),
        contentPadding: EdgeInsets.symmetric(horizontal: 20, vertical: 0),
        suffixIcon: _searchController.text.isNotEmpty
            ? IconButton(
                icon: Icon(Icons.clear, color: AppTheme.textSecondaryColor),
                onPressed: () {
                    _searchController.clear();
                    setState(() {
                         _searchResults = [];
                         _hasSearched = false;
                    });
                },
              )
            : null,
      ),
      onSubmitted: (query) {
        setState(() {
          _selectedChip = '';
        });
        _performSearch(query);
      },
      onChanged: _onSearchChanged,
      textInputAction: TextInputAction.search,
    );
  }

  Widget _buildFilterChips() {
    return Container(
      height: 50,
      padding: EdgeInsets.symmetric(horizontal: 16),
      margin: EdgeInsets.only(bottom: 8),
      child: ListView(
        scrollDirection: Axis.horizontal,
        children: [
          _buildFilterChip('All', _selectedFilter == 'All'),
          SizedBox(width: 8),
          _buildFilterChip('Anime', _selectedFilter == 'Anime'),
          SizedBox(width: 8),
          _buildFilterChip('Manga', _selectedFilter == 'Manga'),
           if (_selectedChip.isNotEmpty) ...[
            SizedBox(width: 8),
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
        ],
      ),
    );
  }

  Widget _buildFilterChip(String label, bool isSelected) {
    return FilterChip(
      label: Text(label),
      selected: isSelected,
      selectedColor: AppTheme.primaryColor,
      backgroundColor: Colors.white.withOpacity(0.1),
      checkmarkColor: Colors.white,
      labelStyle: TextStyle(
        color: isSelected ? Colors.white : AppTheme.textSecondaryColor,
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
      child: CustomLoadingWidget(
        message: 'Searching...',
        size: 150,
      ),
    );
  }

  Widget _buildNoResultsView() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.search_off, size: 64, color: Colors.grey),
          SizedBox(height: 16),
          Text(
            'No results found',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.white,
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
          Icon(Icons.search, size: 64, color: AppTheme.primaryColor.withOpacity(0.5)),
          SizedBox(height: 16),
          Text(
            'Type to search...',
            style: TextStyle(color: Colors.white54, fontSize: 16),
          ),
          SizedBox(height: 32),
          _buildPopularSearches(),
        ],
      ),
    );
  }
  
  Widget _buildPopularSearches() {
      // Reuse logic from previous implementation but simplified
      if (_isLoadingGenres) return SizedBox();
      
      return Padding(
          padding: EdgeInsets.symmetric(horizontal: 20),
          child: Wrap(
            alignment: WrapAlignment.center,
            spacing: 8,
            children: _genres.take(6).map((genre) {
                 return ActionChip(
                   label: Text(genre['name']),
                   backgroundColor: Colors.white10,
                   labelStyle: TextStyle(color: Colors.white),
                   onPressed: () {
                        setState(() {
                            _selectedChip = genre['name'];
                        });
                        _performGenreSearch(genre);
                   },
                 );
            }).toList(),
          ),
      );
  }

  Widget _buildSearchResultsGrid() {
    return GridView.builder(
      padding: EdgeInsets.all(12),
      gridDelegate: SliverGridDelegateWithMaxCrossAxisExtent(
        maxCrossAxisExtent: 200,
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
    // Basic Grid Card for search results
     Widget? targetScreen;
    String category = item['category'] ?? 'anime'; // Default to anime if unknown
    
    // Fallback logic if category is missing but type exists
    if (item['category'] == null) {
       String t = (item['type'] ?? '').toString().toLowerCase();
       if (t == 'comic' || t == 'manga' || t == 'manhwa' || t == 'manhua') category = 'comic';
    }

    if (category == 'anime') {
      targetScreen = AnimeDetailsScreen(url: item['url']);
    } else if (category == 'comic') {
      targetScreen = ComicDetailsScreen(url: item['url'], type: item['type']);
    }

    return InkWell(
        onTap: () {
            if (targetScreen != null) {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => targetScreen!),
                );
            }
        },
        child: Stack(
          children: [
            // Background Image
            Positioned.fill(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: Image.network(
                  item['image_url'] ?? item['image'] ?? '',
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) => Container(
                    color: Colors.grey[900],
                    child: Icon(Icons.broken_image, color: Colors.white24),
                  ),
                ),
              ),
            ),
            // Type Badge
            if (item['type'] != null)
              Positioned(
                top: 4,
                left: 4,
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
            // Gradient and Text Overlay
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: Container(
                padding: EdgeInsets.all(8),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Colors.transparent, Colors.black87],
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                  ),
                  borderRadius: BorderRadius.vertical(bottom: Radius.circular(8)),
                ),
                child: Text(
                  item['title'] ?? '',
                  style: TextStyle(color: Colors.white, fontSize: 12),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ),
          ],
        ),
    );
  }
  /* Direct Play Logic copied/adapted from AnimeDetailsScreen */
  Future<void> _showStreamBottomSheet(Map<String, dynamic> historyItem) async {
     // Show loading
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1E1E1E),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => const Center(
        heightFactor: 1,
        child: Padding(
          padding: EdgeInsets.all(32.0),
          child: CustomLoadingWidget(message: "Loading streams...", size: 80),
        ),
      ),
    );

    try {
      // Load Ad
      await AdService.loadRewardedAd();
      
      final episodeUrl = historyItem['episode_url'];
      final streams = await ApiService.fetchEpisodeStreams(episodeUrl);
      if (mounted) Navigator.pop(context); // Close loading

      if (streams == null) {
        ToastUtils.show('No streams found', backgroundColor: Colors.orange);
        return;
      }

      final List<dynamic> directStreams = streams['direct_stream_urls'] ?? [];
      final String streamUrl = streams['stream_url'] ?? '';

      if (mounted) {
        showModalBottomSheet(
          context: context,
          backgroundColor: const Color(0xFF1E1E1E),
          shape: const RoundedRectangleBorder(
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          builder: (context) {
            return Container(
              padding: const EdgeInsets.symmetric(vertical: 24),
              constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.6),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [

                   const Text(
                     'Select Resolution',
                     style: TextStyle(
                       color: Colors.white,
                       fontSize: 18,
                       fontWeight: FontWeight.bold,
                     ),
                   ),
                   const SizedBox(height: 16),
                   Flexible(
                     child: ListView(
                       shrinkWrap: true,
                       children: [
                         // Auto Option
                         if (streamUrl.isNotEmpty) 
                           ListTile(
                             leading: const Icon(Icons.auto_awesome, color: AppTheme.primaryColor),
                             title: const Text('Auto (Recommended)', style: TextStyle(color: Colors.white)),
                             subtitle: const Text('Adaptive quality', style: TextStyle(color: Colors.grey)),
                             onTap: () => _playVideo(context, streamUrl, 'Auto', streams, historyItem),
                           ),
                         
                         // Direct Streams
                         ...directStreams.map((stream) {
                            final quality = stream['quality'] ?? 'Unknown';
                            return ListTile(
                              leading: const Icon(Icons.hd, color: AppTheme.primaryColor),
                              title: Text(quality, style: const TextStyle(color: Colors.white)),
                              onTap: () => _playVideo(context, stream['url'], quality, streams, historyItem),
                            );
                         }).toList(),

                         // Alternative Option
                         if (streamUrl.isNotEmpty) ...[
                            const Divider(color: Colors.grey),
                            ListTile(
                              leading: const Icon(Icons.open_in_browser, color: Colors.orange),
                              title: const Text('Alternative Server', style: TextStyle(color: Colors.white)),
                              subtitle: const Text('Jika video tidak dapat diputar, gunakan opsi ini', style: TextStyle(color: Colors.grey)),
                              onTap: () async {
                                Navigator.pop(context);
                                if (await canLaunchUrl(Uri.parse(streamUrl))) {
                                  await launchUrl(Uri.parse(streamUrl), mode: LaunchMode.externalApplication);
                                } else {
                                  ToastUtils.show('Could not launch url', backgroundColor: Colors.red);
                                }
                              },
                            ),
                         ],
                       ],
                     ),
                   ),
                ],
              ),
            );
          },
        );
      }
    } catch (e) {
      if (mounted) Navigator.pop(context); // Close loading
      ToastUtils.show('Error loading streams: $e', backgroundColor: Colors.red);
    }
  }

  void _playVideo(BuildContext context, String url, String quality, Map<String, dynamic> episodeData, Map<String, dynamic> historyItem) {
     Navigator.pop(context); // Close bottom sheet
      
     AdService.showRewardedAd(context, onReward: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => VideoPlayerScreen(
              url: url,
              title: historyItem['episode'] ?? 'Episode',
              episodeId: DateTime.now().millisecondsSinceEpoch.toString(), // Dummy ID for history
              directStreamUrls: (episodeData['direct_stream_urls'] as List?)
                  ?.map((e) => Map<String, String>.from(e))
                  .toList() ?? [],
            ),
          ),
        );
     }, setLandscapeOrientation: true); 
  }

  Future<void> _fetchAndDirectPlay(Map<String, dynamic> item) async {
    // Show loading
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(
        child: CustomLoadingWidget(message: "Finding episode...", size: 100),
      ),
    );

    try {
      final animeDetails = await ApiService.fetchAnimeDetails(item['url']);
      Navigator.pop(context); // Close loading

      if (animeDetails != null && animeDetails['episodes'] != null) {
         final episodes = animeDetails['episodes'] as List<dynamic>;
         final targetEpisode = item['episode'].toString(); // "Episode 1"
         
         // Try to find matching episode with flexible matching
         final episode = episodes.firstWhere(
            (e) => _isSameEpisode(e['title'], targetEpisode),
            orElse: () => null,
         );

         if (episode != null) {
            // Found it! Construct updated history item and show sheet
            final updatedItem = Map<String, dynamic>.from(item);
            updatedItem['episode_url'] = episode['url'];
            _showStreamBottomSheet(updatedItem);
         } else {
            // Not found, try matching by index as fallback if targetEpisode contains a number
            // ... (Simple navigation for now to avoid wrong episode)
            if (mounted) {
               Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => AnimeDetailsScreen(url: item['url'])),
               );
            }
         }
      }
    } catch (e) {
      Navigator.pop(context); // Ensure loading is closed
      ToastUtils.show('Failed to load episode details', backgroundColor: Colors.red);
      // Fallback
      if (mounted) {
         Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => AnimeDetailsScreen(url: item['url'])),
         );
      }
    }
  }

  bool _isSameEpisode(dynamic apiTitle, dynamic searchTitle) {
      if (apiTitle == null || searchTitle == null) return false;
      final t1 = apiTitle.toString().toLowerCase().trim();
      final t2 = searchTitle.toString().toLowerCase().trim();
      
      // Exact match
      if (t1 == t2) return true;
      
      // Check if one contains the other
      if (t1.contains(t2) || t2.contains(t1)) return true;
      
      // Check numeric match (e.g. "Episode 1" vs "1")
      final n1 = RegExp(r'(\d+)').firstMatch(t1)?.group(1);
      final n2 = RegExp(r'(\d+)').firstMatch(t2)?.group(1);
      
      if (n1 != null && n2 != null && n1 == n2) return true;
      
      return false;
  }
}
