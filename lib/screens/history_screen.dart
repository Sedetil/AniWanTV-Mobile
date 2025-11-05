import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/api_service.dart';
import '../theme/app_theme.dart';
import '../widgets/custom_error_dialog.dart';
import '../providers/app_state_provider.dart';
import 'anime_details_screen.dart';
import 'comic_details_screen.dart';
import 'video_player_screen.dart';
import 'manga_reader_screen.dart';
import 'package:fluttertoast/fluttertoast.dart';

class HistoryScreen extends StatefulWidget {
  @override
  _HistoryScreenState createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  List<dynamic> animeHistory = [];
  List<dynamic> comicHistory = [];
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    
    // Initialize AppStateProvider
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Provider.of<AppStateProvider>(context, listen: false).initialize();
    });
    
    _loadHistory();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadHistory() async {
    setState(() => isLoading = true);
    try {
      final appStateProvider = Provider.of<AppStateProvider>(context, listen: false);
      await appStateProvider.initialize();
      
      setState(() {
        animeHistory = appStateProvider.animeHistory;
        comicHistory = appStateProvider.comicHistory;
        isLoading = false;
      });
    } catch (e) {
      setState(() => isLoading = false);
      _showErrorDialog('Error Loading History', 'Failed to load history: $e');
    }
  }

  void _showErrorDialog(String title, String message) {
    CustomErrorDialog.show(
      context,
      title: title,
      message: message,
      onRetry: _loadHistory,
    );
  }

  Future<void> _clearHistory(bool isAnime) async {
    try {
      final appStateProvider = Provider.of<AppStateProvider>(context, listen: false);
      await appStateProvider.clearHistory(isAnime);
      
      setState(() {
        if (isAnime) {
          animeHistory = appStateProvider.animeHistory;
        } else {
          comicHistory = appStateProvider.comicHistory;
        }
      });

      Fluttertoast.showToast(
        msg: 'History cleared',
        toastLength: Toast.LENGTH_SHORT,
        gravity: ToastGravity.BOTTOM,
        backgroundColor: AppTheme.primaryColor,
        textColor: Colors.white,
      );
    } catch (e) {
      _showErrorDialog('Error Clearing History', 'Failed to clear history: $e');
    }
  }

  Future<void> _removeHistoryItem(String id, bool isAnime) async {
    try {
      final appStateProvider = Provider.of<AppStateProvider>(context, listen: false);
      await appStateProvider.removeFromHistory(id, isAnime);
      
      setState(() {
        if (isAnime) {
          animeHistory = appStateProvider.animeHistory;
        } else {
          comicHistory = appStateProvider.comicHistory;
        }
      });

      Fluttertoast.showToast(
        msg: 'Removed from history',
        toastLength: Toast.LENGTH_SHORT,
        gravity: ToastGravity.BOTTOM,
        backgroundColor: AppTheme.primaryColor,
        textColor: Colors.white,
      );
    } catch (e) {
      _showErrorDialog(
          'Error Removing Item', 'Failed to remove from history: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      appBar: AppBar(
        title: Text(
          'Watch History',
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
            Tab(text: 'COMIC'),
          ],
        ),
        actions: [
          PopupMenuButton<String>(
            icon: Icon(Icons.more_vert, color: Colors.white),
            onSelected: (value) {
              if (value == 'clear_anime') {
                _clearHistory(true);
              } else if (value == 'clear_comics') {
                _clearHistory(false);
              } else if (value == 'clear_all') {
                _clearHistory(true);
                _clearHistory(false);
              }
            },
            itemBuilder: (BuildContext context) => [
              PopupMenuItem<String>(
                value: 'clear_anime',
                child: Row(
                  children: [
                    Icon(Icons.delete_sweep, color: AppTheme.primaryColor),
                    SizedBox(width: 8),
                    Text('Clear Anime History'),
                  ],
                ),
              ),
              PopupMenuItem<String>(
                value: 'clear_comics',
                child: Row(
                  children: [
                    Icon(Icons.delete_sweep, color: AppTheme.primaryColor),
                    SizedBox(width: 8),
                    Text('Clear Manga History'),
                  ],
                ),
              ),
              PopupMenuItem<String>(
                value: 'clear_all',
                child: Row(
                  children: [
                    Icon(Icons.delete_forever, color: Colors.red),
                    SizedBox(width: 8),
                    Text('Clear All History'),
                  ],
                ),
              ),
            ],
          ),
        ],
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
                _buildHistoryList(animeHistory, true),
                _buildHistoryList(comicHistory, false),
              ],
            ),
    );
  }

  Widget _buildHistoryList(List<dynamic> items, bool isAnime) {
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
                Icons.history,
                size: 64,
                color: isAnime ? AppTheme.primaryColor : AppTheme.primaryColor,
              ),
            ),
            SizedBox(height: 24),
            Text(
              'No history yet',
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
                    ? 'Watch anime to see your history here'
                    : 'Read manga to see your history here',
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
      onRefresh: _loadHistory,
      color: isAnime ? AppTheme.primaryColor : AppTheme.primaryColor,
      child: ListView.builder(
        padding: EdgeInsets.all(12),
        itemCount: items.length,
        itemBuilder: (context, index) {
          final item = items[index];
          // Format timestamp
          String formattedTime = 'Unknown time';
          try {
            final DateTime timestamp = DateTime.parse(item['timestamp']);
            final DateTime now = DateTime.now();
            final Duration difference = now.difference(timestamp);

            if (difference.inDays > 0) {
              formattedTime =
                  '${difference.inDays} ${difference.inDays == 1 ? 'day' : 'days'} ago';
            } else if (difference.inHours > 0) {
              formattedTime =
                  '${difference.inHours} ${difference.inHours == 1 ? 'hour' : 'hours'} ago';
            } else if (difference.inMinutes > 0) {
              formattedTime =
                  '${difference.inMinutes} ${difference.inMinutes == 1 ? 'minute' : 'minutes'} ago';
            } else {
              formattedTime = 'Just now';
            }
          } catch (e) {
            // Use default value if parsing fails
          }

          return Card(
            elevation: 3,
            margin: EdgeInsets.symmetric(vertical: 8, horizontal: 4),
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
                ).then((_) => _loadHistory());
              },
              child: Padding(
                padding: const EdgeInsets.all(12.0),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Thumbnail
                    ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: Image.network(
                        item['image_url'] ?? 'https://via.placeholder.com/150',
                        width: 80,
                        height: 120,
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) {
                          return Container(
                            width: 80,
                            height: 120,
                            color: Colors.grey[800],
                            child: Icon(Icons.broken_image, color: Colors.grey),
                          );
                        },
                      ),
                    ),
                    SizedBox(width: 16),

                    // Content details
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            item['title'],
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                              color: Colors.white,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                          SizedBox(height: 8),
                          Container(
                            padding: EdgeInsets.symmetric(
                                horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: isAnime
                                  ? AppTheme.primaryColor.withOpacity(0.2)
                                  : AppTheme.primaryColor.withOpacity(0.2),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              isAnime
                                  ? 'Episode: ${item['episode'] ?? 'Unknown'}'
                                  : 'Chapter: ${item['chapter'] ?? 'Unknown'}',
                              style: TextStyle(
                                color: isAnime
                                    ? AppTheme.primaryColor
                                    : AppTheme.primaryColor,
                                fontWeight: FontWeight.bold,
                                fontSize: 12,
                              ),
                            ),
                          ),
                          SizedBox(height: 12),
                          Row(
                            children: [
                              Icon(
                                Icons.access_time,
                                size: 14,
                                color: AppTheme.textSecondaryColor,
                              ),
                              SizedBox(width: 4),
                              Text(
                                formattedTime,
                                style: TextStyle(
                                  color: AppTheme.textSecondaryColor,
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                          SizedBox(height: 8),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.end,
                            children: [
                              TextButton.icon(
                                icon: Icon(
                                  isAnime ? Icons.play_arrow : Icons.book,
                                  size: 16,
                                ),
                                label: Text(
                                  isAnime ? 'Continue' : 'Read',
                                  style: TextStyle(fontSize: 12),
                                ),
                                style: TextButton.styleFrom(
                                  foregroundColor: isAnime
                                      ? AppTheme.primaryColor
                                      : AppTheme.primaryColor,
                                  padding: EdgeInsets.symmetric(
                                      horizontal: 8, vertical: 4),
                                ),
                                onPressed: () {
                                  if (isAnime) {
                                    // Navigate directly to video player for anime
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (context) => VideoPlayerScreen(
                                          url: item['url'],
                                          title: item['title'] ?? 'Episode',
                                          episodeId: item['id'] ??
                                              DateTime.now()
                                                  .millisecondsSinceEpoch
                                                  .toString(),
                                        ),
                                      ),
                                    ).then((_) => _loadHistory());
                                  } else {
                                    // Navigate directly to manga reader for manga
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (context) => MangaReaderScreen(
                                          url: item['url'],
                                          title: item['title'] ?? 'Chapter',
                                          chapterId:
                                              item['chapter'] ?? 'Unknown',
                                          comicImageUrl: item['image_url'],
                                        ),
                                      ),
                                    ).then((_) => _loadHistory());
                                  }
                                },
                              ),
                              IconButton(
                                icon: Icon(Icons.delete_outline, size: 20),
                                color: Colors.red,
                                onPressed: () =>
                                    _removeHistoryItem(item['id'], isAnime),
                                tooltip: 'Remove from history',
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
