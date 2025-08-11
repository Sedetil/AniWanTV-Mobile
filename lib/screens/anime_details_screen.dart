import 'package:flutter/material.dart';
import 'dart:convert';
import 'dart:math';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/api_service.dart';
import '../theme/app_theme.dart';
import 'episode_streams_screen.dart';
import 'package:fluttertoast/fluttertoast.dart';

class AnimeDetailsScreen extends StatelessWidget {
  final String url;

  AnimeDetailsScreen({required this.url});

  final ApiService apiService = ApiService();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      body: FutureBuilder(
        future: apiService.fetchAnimeDetails(url),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(
                    valueColor:
                        AlwaysStoppedAnimation<Color>(AppTheme.primaryColor),
                  ),
                  SizedBox(height: 16),
                  Text(
                    'Loading...',
                    style: TextStyle(color: Colors.white),
                  ),
                ],
              ),
            );
          } else if (snapshot.hasError) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.error_outline,
                      size: 60, color: AppTheme.primaryColor),
                  SizedBox(height: 16),
                  Text(
                    'Error: ${snapshot.error}',
                    style: TextStyle(color: Colors.white),
                  ),
                  SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: () {
                      Navigator.of(context).pop();
                    },
                    child: Text('Go Back'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.primaryColor,
                    ),
                  ),
                ],
              ),
            );
          } else if (!snapshot.hasData) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.warning, size: 60, color: Colors.amber),
                  SizedBox(height: 16),
                  Text(
                    'No data found for this anime',
                    style: TextStyle(color: Colors.white),
                  ),
                  SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: () {
                      Navigator.of(context).pop();
                    },
                    child: Text('Go Back'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.primaryColor,
                    ),
                  ),
                ],
              ),
            );
          }

          final anime = snapshot.data;
          return CustomScrollView(
            slivers: [
              SliverAppBar(
                expandedHeight: 300.0,
                floating: false,
                pinned: true,
                backgroundColor: AppTheme.backgroundColor,
                flexibleSpace: FlexibleSpaceBar(
                  titlePadding: EdgeInsets.only(
                    left: 60.0, // Space for back button
                    bottom: 16.0,
                    right: 120.0, // Space for action buttons
                  ),
                  title: Text(
                    anime['title'],
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      shadows: [
                        Shadow(
                          blurRadius: 10.0,
                          color: Colors.black.withOpacity(0.5),
                          offset: Offset(2.0, 2.0),
                        ),
                      ],
                    ),
                    overflow: TextOverflow.ellipsis,
                    maxLines: 2,
                  ),
                  background: Stack(
                    fit: StackFit.expand,
                    children: [
                      Image.network(
                        anime['image_url'] ?? '',
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) {
                          return Container(
                            color: Colors.grey[800],
                            child: Center(
                                child: Icon(Icons.broken_image,
                                    size: 50, color: Colors.grey)),
                          );
                        },
                      ),
                      Container(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [
                              Colors.transparent,
                              Colors.black.withOpacity(0.7),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                actions: [
                  IconButton(
                    icon: Icon(Icons.share),
                    onPressed: () {
                      Fluttertoast.showToast(
                        msg: 'Share functionality coming soon',
                        toastLength: Toast.LENGTH_SHORT,
                        gravity: ToastGravity.BOTTOM,
                        backgroundColor: AppTheme.primaryColor,
                        textColor: Colors.white,
                      );
                    },
                  ),
                  IconButton(
                    icon: Icon(Icons.favorite_border),
                    onPressed: () async {
                      try {
                        final prefs = await SharedPreferences.getInstance();
                        final favoritesJson =
                            prefs.getString('favorite_anime') ?? '[]';
                        List<dynamic> favorites = jsonDecode(favoritesJson);

                        // Check if anime already exists in favorites
                        final animeExists =
                            favorites.any((item) => item['url'] == url);

                        if (animeExists) {
                          Fluttertoast.showToast(
                            msg: 'Anime already in favorites',
                            toastLength: Toast.LENGTH_SHORT,
                            gravity: ToastGravity.BOTTOM,
                            backgroundColor: Colors.orange,
                            textColor: Colors.white,
                          );
                          return;
                        }

                        // Add anime to favorites
                        favorites.add({
                          'id':
                              DateTime.now().millisecondsSinceEpoch.toString(),
                          'title': anime['title'] ?? 'No Title',
                          'image_url': anime['image_url'] ?? '',
                          'url': url,
                          'description': anime['synopsis'] != null
                              ? anime['synopsis'].substring(0,
                                      min<int>(100, anime['synopsis'].length)) +
                                  '...'
                              : 'No description available',
                          'type': 'anime',
                          'rating': anime['rating'],
                        });

                        await prefs.setString(
                            'favorite_anime', jsonEncode(favorites));

                        Fluttertoast.showToast(
                          msg: 'Added to favorites',
                          toastLength: Toast.LENGTH_SHORT,
                          gravity: ToastGravity.BOTTOM,
                          backgroundColor: Colors.green,
                          textColor: Colors.white,
                        );
                      } catch (e) {
                        Fluttertoast.showToast(
                          msg: 'Error adding to favorites: $e',
                          toastLength: Toast.LENGTH_LONG,
                          gravity: ToastGravity.BOTTOM,
                          backgroundColor: Colors.red,
                          textColor: Colors.white,
                        );
                      }
                    },
                  ),
                ],
              ),
              SliverToBoxAdapter(
                child: Container(
                  padding: EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Card(
                        elevation: 2,
                        color: AppTheme.cardColor,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(16.0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  _buildInfoRow(
                                    context,
                                    'Rating',
                                    '${anime['rating'] ?? 'N/A'}',
                                    Icons.star,
                                    Colors.amber,
                                  ),
                                ],
                              ),
                              SizedBox(height: 16),
                              _buildGenresChips(context, anime['genres'] ?? []),
                            ],
                          ),
                        ),
                      ),
                      SizedBox(height: 24),
                      Text(
                        'Synopsis',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: AppTheme.primaryColor,
                        ),
                      ),
                      SizedBox(height: 8),
                      Card(
                        elevation: 1,
                        color: AppTheme.cardColor,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(16.0),
                          child: Text(
                            anime['synopsis'] ?? 'No synopsis available',
                            style: TextStyle(
                              fontSize: 16,
                              height: 1.5,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ),
                      SizedBox(height: 24),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Episodes',
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                              color: AppTheme.primaryColor,
                            ),
                          ),
                          Container(
                            padding: EdgeInsets.symmetric(
                                horizontal: 12, vertical: 6),
                            decoration: BoxDecoration(
                              color: AppTheme.primaryColor,
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Text(
                              '${anime['episodes']?.length ?? 0} episodes',
                              style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      ),
                      SizedBox(height: 16),
                      _buildEpisodesList(
                          context, anime['episodes'] ?? [], anime),
                    ],
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildInfoRow(BuildContext context, String label, String value,
      IconData icon, Color iconColor) {
    return Container(
      width: MediaQuery.of(context).size.width * 0.40,
      padding: EdgeInsets.symmetric(vertical: 12, horizontal: 12),
      decoration: BoxDecoration(
        color: AppTheme.cardColor.withOpacity(0.5),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: iconColor.withOpacity(0.3), width: 1.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: iconColor.withOpacity(0.2),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, color: iconColor, size: 16),
              ),
              SizedBox(width: 6),
              Flexible(
                child: Text(
                  label,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                  overflow: TextOverflow.ellipsis,
                  maxLines: 1,
                ),
              ),
            ],
          ),
          SizedBox(height: 6),
          Text(
            value,
            style: TextStyle(
              fontSize: 15,
              color: Colors.white,
            ),
            overflow: TextOverflow.ellipsis,
            maxLines: 1,
          ),
        ],
      ),
    );
  }

  Widget _buildGenresChips(BuildContext context, List<dynamic> genres) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(Icons.category, color: AppTheme.primaryColor, size: 20),
            SizedBox(width: 8),
            Text(
              'Genres',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
          ],
        ),
        SizedBox(height: 12),
        Wrap(
          spacing: 8.0,
          runSpacing: 8.0,
          children: genres.asMap().entries.map((entry) {
            int index = entry.key;
            String genre = entry.value.toString();
            Color genreColor =
                Colors.primaries[index % Colors.primaries.length];

            return Container(
              margin: EdgeInsets.only(bottom: 4),
              child: Container(
                padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: genreColor.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                      color: genreColor.withOpacity(0.5), width: 1.5),
                ),
                child: Text(
                  genre,
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }

  Widget _buildEpisodesList(BuildContext context, List<dynamic> episodes,
      Map<String, dynamic> anime) {
    return Card(
      elevation: 3,
      color: AppTheme.cardColor,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: ListView.separated(
          shrinkWrap: true,
          physics: NeverScrollableScrollPhysics(),
          itemCount: episodes.length,
          separatorBuilder: (context, index) => Divider(
              height: 1, indent: 70, color: Colors.grey.withOpacity(0.2)),
          itemBuilder: (context, index) {
            final episode = episodes[index];
            return ListTile(
              leading: Container(
                width: 50,
                height: 50,
                decoration: BoxDecoration(
                  color: AppTheme.primaryColor,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Center(
                  child: Icon(
                    Icons.play_arrow,
                    color: Colors.white,
                    size: 30,
                  ),
                ),
              ),
              title: Text(
                episode['title'] ?? 'Episode ${index + 1}',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              trailing:
                  Icon(Icons.play_circle_fill, color: AppTheme.primaryColor),
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => EpisodeStreamsScreen(
                      url: episode['url'],
                      animeImageUrl: anime['image_url'],
                    ),
                  ),
                );
              },
            );
          },
        ),
      ),
    );
  }
}
