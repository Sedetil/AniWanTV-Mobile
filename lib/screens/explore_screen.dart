import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/api_service.dart';
import '../theme/app_theme.dart';
import '../widgets/custom_error_dialog.dart';
import '../providers/app_state_provider.dart';
import 'anime_details_screen.dart';
import 'comic_details_screen.dart';
import 'search_screen.dart';
import '../widgets/custom_loading_widget.dart';


class ExploreScreen extends StatefulWidget {
  final bool initialIsAnime;
  final bool showBackButton;

  const ExploreScreen({
    Key? key,
    this.initialIsAnime = true,
    this.showBackButton = true,
  }) : super(key: key);

  @override
  _ExploreScreenState createState() => _ExploreScreenState();
}

class _ExploreScreenState extends State<ExploreScreen> {
  int _currentTabIndex = 0; // 0: Anime, 1: Komik
  List<dynamic> latestAnime = [];
  List<dynamic> latestComics = [];
  bool isLoadingContent = true;

  @override
  void initState() {
    super.initState();
    _currentTabIndex = widget.initialIsAnime ? 0 : 1;
    
    // Initialize AppStateProvider
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Provider.of<AppStateProvider>(context, listen: false).initialize();
    });
    
    _loadData();
  }

  Future<void> _loadData() async {
    try {
      // Load content
      final latestAnimeData = await _fetchAllLatestAnime();
      final latestComicsData = await _fetchAllLatestComics();

      if (mounted) {
        setState(() {
          latestAnime = latestAnimeData;
          latestComics = latestComicsData;
          isLoadingContent = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          isLoadingContent = false;
        });
        _showErrorDialog('Error Loading Content', 'Failed to load content: $e');
      }
    }
  }

  Future<List<dynamic>> _fetchAllLatestAnime() async {
    List<dynamic> all = [];
    Set<String> seen = {};
    for (int page = 1; page <= 5; page++) {
      final items = await ApiService.fetchLatestAnime(page: page);
      if (items.isEmpty) break;
      for (final item in items) {
        final key = item['url'] ?? item['title'] ?? 'unknown_${all.length}';
        if (!seen.contains(key)) {
          seen.add(key);
          all.add(item);
        }
      }
    }
    return all;
  }

  Future<List<dynamic>> _fetchAllLatestComics() async {
    List<dynamic> all = [];
    Set<String> seen = {};
    for (int page = 1; page <= 5; page++) {
      final items = await ApiService.fetchLatestComics(page: page);
      if (items.isEmpty) break;
      for (final item in items) {
        final key = item['url'] ?? item['title'] ?? 'unknown_${all.length}';
        if (!seen.contains(key)) {
          seen.add(key);
          all.add(item);
        }
      }
    }
    return all;
  }

  void _showErrorDialog(String title, String message) {
    CustomErrorDialog.show(
      context,
      title: title,
      message: message,
      onRetry: _loadData,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 16),
              // Header
              _buildHeader(),
              
              const SizedBox(height: 24),
              
              // Custom Toggle
              _buildToggleButtons(),
              
              const SizedBox(height: 24),

              // Section Title
              Text(
                _currentTabIndex == 0 ? 'Latest Anime' : 'Latest Komik',
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              
              const SizedBox(height: 16),

              // Content Grid
              Expanded(
                child: _buildContentGrid(),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Row(
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
              'Explore',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildToggleButtons() {
    return Row(
      children: [
        Expanded(
          child: _buildToggleItem(
            label: 'ANIME',
            isActive: _currentTabIndex == 0,
            onTap: () => setState(() => _currentTabIndex = 0),
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: _buildToggleItem(
            label: 'KOMIK',
            isActive: _currentTabIndex == 1,
            onTap: () => setState(() => _currentTabIndex = 1),
          ),
        ),
      ],
    );
  }

  Widget _buildToggleItem({required String label, required bool isActive, required VoidCallback onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 40,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: isActive ? AppTheme.primaryColor : const Color(0xFF1E1E1E),
          borderRadius: BorderRadius.circular(20),
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

  Widget _buildContentGrid() {
    if (isLoadingContent) {
      return Center(child: CustomLoadingWidget(message: "Exploring content...", size: 100));
    }

    final items = _currentTabIndex == 0 ? latestAnime : latestComics;
    
    if (items.isEmpty) {
      return Center(child: Text('Ga Ketemu Nih...', style: TextStyle(color: Colors.white)));
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        int crossAxisCount;
        if (constraints.maxWidth > 1200) {
          crossAxisCount = 6;
        } else if (constraints.maxWidth > 900) {
          crossAxisCount = 5;
        } else if (constraints.maxWidth > 600) {
          crossAxisCount = 4;
        } else {
          crossAxisCount = 2;
        }

        return GridView.builder(
          padding: const EdgeInsets.symmetric(horizontal: 0, vertical: 8), // Padding handled by parent
          physics: const BouncingScrollPhysics(),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: crossAxisCount,
            crossAxisSpacing: 16,
            mainAxisSpacing: 16,
            childAspectRatio: 0.7, 
          ),
          itemCount: items.length,
          itemBuilder: (context, index) {
            final item = items[index];
            return _buildCard(item);
          },
        );
      },
    );
  }

  Widget _buildCard(dynamic item) {
    return GestureDetector(
      onTap: () {
         if (_currentTabIndex == 0) {
            Navigator.push(context, MaterialPageRoute(builder: (_) => AnimeDetailsScreen(url: item['url'])));
         } else {
            Navigator.push(context, MaterialPageRoute(builder: (_) => ComicDetailsScreen(url: item['url'], type: item['type'])));
         }
      },
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Image
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                color: const Color(0xFF1E1E1E),
              ),
              clipBehavior: Clip.antiAlias,
              child: Stack(
                fit: StackFit.expand,
                children: [
                   Image.network(
                    item['image_url'] ?? '',
                    fit: BoxFit.cover,
                    width: double.infinity,
                    errorBuilder: (_,__,___) => Container(color: Colors.grey[800], child: Icon(Icons.broken_image, color: Colors.white)),
                  ),
                  if (_currentTabIndex == 1 && item['type'] != null)
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
                ],
              ),
            ),
          ),
          const SizedBox(height: 8),
          // Title
          Text(
            item['title'] ?? 'No Title',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 14,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }
}
