import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import '../services/api_service.dart';
import '../theme/app_theme.dart';
import '../widgets/custom_error_dialog.dart';
import 'anime_details_screen.dart';
import 'comic_details_screen.dart';
import 'package:fluttertoast/fluttertoast.dart';

class FavoritesScreen extends StatefulWidget {
  @override
  _FavoritesScreenState createState() => _FavoritesScreenState();
}

class _FavoritesScreenState extends State<FavoritesScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final ApiService apiService = ApiService();
  List<dynamic> favoriteAnime = [];
  List<dynamic> favoriteComics = [];
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadFavorites();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadFavorites() async {
    setState(() => isLoading = true);
    try {
      final prefs = await SharedPreferences.getInstance();
      final animeJson = prefs.getString('favorite_anime') ?? '[]';
      final comicsJson = prefs.getString('favorite_comics') ?? '[]';

      setState(() {
        favoriteAnime = jsonDecode(animeJson);
        favoriteComics = jsonDecode(comicsJson);
        isLoading = false;
      });
    } catch (e) {
      setState(() => isLoading = false);
      _showErrorDialog(
          'Error Loading Favorites', 'Failed to load favorites: $e');
    }
  }

  void _showErrorDialog(String title, String message) {
    CustomErrorDialog.show(
      context,
      title: title,
      message: message,
      onRetry: _loadFavorites,
    );
  }

  Future<void> _removeFavorite(String id, bool isAnime) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final key = isAnime ? 'favorite_anime' : 'favorite_comics';
      final list = isAnime ? favoriteAnime : favoriteComics;

      final updatedList = list.where((item) => item['id'] != id).toList();
      await prefs.setString(key, jsonEncode(updatedList));

      setState(() {
        if (isAnime) {
          favoriteAnime = updatedList;
        } else {
          favoriteComics = updatedList;
        }
      });

      Fluttertoast.showToast(
        msg: 'Removed from favorites',
        toastLength: Toast.LENGTH_SHORT,
        gravity: ToastGravity.BOTTOM,
        backgroundColor: AppTheme.primaryColor,
        textColor: Colors.white,
      );
    } catch (e) {
      _showErrorDialog(
          'Error Removing Favorite', 'Failed to remove from favorites: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      appBar: AppBar(
        title: Text(
          'My Favorites',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        backgroundColor: AppTheme.backgroundColor,
        elevation: 0,
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: AppTheme.primaryColor,
          indicatorWeight: 3,
          labelColor: Colors.white,
          unselectedLabelColor: AppTheme.textSecondaryColor,
          labelStyle: TextStyle(fontWeight: FontWeight.bold),
          tabs: [
            Tab(text: 'ANIME'),
            Tab(text: 'MANGA'),
          ],
        ),
      ),
      body: isLoading
          ? Center(
              child: CircularProgressIndicator(
                valueColor:
                    AlwaysStoppedAnimation<Color>(AppTheme.primaryColor),
              ),
            )
          : TabBarView(
              controller: _tabController,
              children: [
                _buildFavoritesList(favoriteAnime, true),
                _buildFavoritesList(favoriteComics, false),
              ],
            ),
    );
  }

  Widget _buildFavoritesList(List<dynamic> items, bool isAnime) {
    if (items.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: AppTheme.cardColor,
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.favorite,
                size: 64,
                color: isAnime ? AppTheme.primaryColor : AppTheme.primaryColor,
              ),
            ),
            SizedBox(height: 24),
            Text(
              'No favorites yet',
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
                isAnime
                    ? 'Add anime to your favorites to see them here'
                    : 'Add manga to your favorites to see them here',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: AppTheme.textSecondaryColor,
                  fontSize: 16,
                ),
              ),
            ),
            SizedBox(height: 32),
            ElevatedButton.icon(
              icon: Icon(Icons.explore),
              label: Text('Explore Content'),
              style: ElevatedButton.styleFrom(
                backgroundColor:
                    isAnime ? AppTheme.primaryColor : AppTheme.primaryColor,
                foregroundColor: Colors.white,
                padding: EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              onPressed: () {
                Navigator.pop(context);
              },
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadFavorites,
      color: isAnime ? AppTheme.primaryColor : AppTheme.primaryColor,
      child: GridView.builder(
        padding: EdgeInsets.all(12),
        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          childAspectRatio: 0.7,
          crossAxisSpacing: 12,
          mainAxisSpacing: 12,
        ),
        itemCount: items.length,
        itemBuilder: (context, index) {
          final item = items[index];
          return _buildFavoriteCard(item, isAnime);
        },
      ),
    );
  }

  Widget _buildFavoriteCard(dynamic item, bool isAnime) {
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
            MaterialPageRoute(
              builder: (context) => isAnime
                  ? AnimeDetailsScreen(url: item['url'])
                  : ComicDetailsScreen(url: item['url']),
            ),
          ).then((_) => _loadFavorites());
        },
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Image with overlay
            Expanded(
              child: Stack(
                children: [
                  // Image
                  ClipRRect(
                    borderRadius: BorderRadius.only(
                      topLeft: Radius.circular(12),
                      topRight: Radius.circular(12),
                    ),
                    child: Image.network(
                      item['image_url'],
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

                  // Type badge
                  Positioned(
                    top: 8,
                    left: 8,
                    child: Container(
                      padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: isAnime
                            ? AppTheme.primaryColor
                            : AppTheme.primaryColor,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        isAnime ? 'ANIME' : 'MANGA',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 10,
                        ),
                      ),
                    ),
                  ),

                  // Rating badge
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

                  // Remove button
                  Positioned(
                    bottom: 8,
                    right: 8,
                    child: Container(
                      decoration: BoxDecoration(
                        color: Colors.black.withOpacity(0.7),
                        shape: BoxShape.circle,
                      ),
                      child: IconButton(
                        icon: Icon(Icons.delete_outline, size: 20),
                        color: Colors.white,
                        onPressed: () => _removeFavorite(item['id'], isAnime),
                        tooltip: 'Remove from favorites',
                        padding: EdgeInsets.all(4),
                        constraints: BoxConstraints(),
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // Title and description
            Padding(
              padding: const EdgeInsets.all(12.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item['title'],
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                      color: Colors.white,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  SizedBox(height: 4),
                  if (item['description'] != null)
                    Text(
                      item['description'],
                      style: TextStyle(
                        color: AppTheme.textSecondaryColor,
                        fontSize: 12,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
