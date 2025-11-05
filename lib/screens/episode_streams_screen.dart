import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:convert';
import 'package:provider/provider.dart';
import '../services/api_service.dart';
import '../theme/app_theme.dart';
import '../widgets/custom_error_dialog.dart';
import '../providers/app_state_provider.dart';
import 'package:url_launcher/url_launcher.dart';
import '../services/ad_service.dart';
import 'video_player_screen.dart';

class EpisodeStreamsScreen extends StatefulWidget {
  final String url;
  final String? animeImageUrl;

  EpisodeStreamsScreen({required this.url, this.animeImageUrl});

  @override
  _EpisodeStreamsScreenState createState() => _EpisodeStreamsScreenState();
}

class _EpisodeStreamsScreenState extends State<EpisodeStreamsScreen> {
  late Future<dynamic> _episodeStreamsFuture;

  @override
  void initState() {
    super.initState();
    AdService.loadRewardedAd();
    _episodeStreamsFuture = ApiService.fetchEpisodeStreams(widget.url);
  }


  Future<void> _showRewardedAd(
      BuildContext context, VoidCallback onReward) async {
    AdService.showRewardedAd(
      context,
      onReward: onReward,
      setLandscapeOrientation: true,
    );
  }

  Future<void> _launchUrl(BuildContext context, String url) async {
    try {
      if (await canLaunchUrl(Uri.parse(url))) {
        await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
      } else {
        throw 'Could not launch $url';
      }
    } catch (e) {
      CustomErrorDialog.show(
        context,
        title: 'Launch Error',
        message: 'Could not open the link: $e',
      );
    }
  }

  bool _isHistorySaved = false;
  
  Future<void> _saveToHistory(
      BuildContext context, Map<String, dynamic> episode) async {
    // Prevent multiple saves
    if (_isHistorySaved) return;
    _isHistorySaved = true;
    
    try {
      final appStateProvider = Provider.of<AppStateProvider>(context, listen: false);
      await appStateProvider.initialize();
      
      final historyItem = {
        'title': episode['title'],
        'image_url': widget.animeImageUrl ??
            episode['image_url'] ??
            episode['thumbnail'] ??
            'https://via.placeholder.com/150',
        'url': widget.url,
        'episode': episode['episode_number'] ?? 'Unknown',
        'type': 'anime',
      };
      
      await appStateProvider.addToHistory(historyItem, true);
    } catch (e) {
      CustomErrorDialog.show(
        context,
        title: 'History Error',
        message: 'Error saving to history: $e',
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      appBar: AppBar(
        title: Text('Episode Streams'),
        backgroundColor: AppTheme.backgroundColor,
        elevation: 0,
      ),
      body: FutureBuilder(
        future: _episodeStreamsFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return Center(
              child: CircularProgressIndicator(
                valueColor:
                    AlwaysStoppedAnimation<Color>(AppTheme.primaryColor),
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
                    'Error loading streams',
                    style: TextStyle(
                        color: AppTheme.textPrimaryColor, fontSize: 18),
                  ),
                  SizedBox(height: 8),
                  Text(
                    '${snapshot.error}',
                    style: TextStyle(color: AppTheme.textSecondaryColor),
                    textAlign: TextAlign.center,
                  ),
                  SizedBox(height: 24),
                  ElevatedButton(
                    onPressed: () => Navigator.pop(context),
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
                    'No stream data found',
                    style: TextStyle(
                        color: AppTheme.textPrimaryColor, fontSize: 18),
                  ),
                  SizedBox(height: 24),
                  ElevatedButton(
                    onPressed: () => Navigator.pop(context),
                    child: Text('Go Back'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.primaryColor,
                    ),
                  ),
                ],
              ),
            );
          }

          final episode = snapshot.data;

          if (episode != null) {
            if (episode['episode_number'] == null && episode['episode'] != null) {
              episode['episode_number'] = episode['episode'];
            }

            if (episode['episode_number'] == null && episode['title'] != null) {
              final episodeRegex =
                  RegExp(r'Episode\s+(\d+)', caseSensitive: false);
              final match = episodeRegex.firstMatch(episode['title']);
              if (match != null && match.groupCount >= 1) {
                episode['episode_number'] = match.group(1);
              }
            }

            _saveToHistory(context, episode);
          }

          if (episode == null) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.warning, size: 60, color: Colors.amber),
                  SizedBox(height: 16),
                  Text(
                    'No episode data available',
                    style: TextStyle(
                        color: AppTheme.textPrimaryColor, fontSize: 18),
                  ),
                  SizedBox(height: 24),
                  ElevatedButton(
                    onPressed: () => Navigator.pop(context),
                    child: Text('Go Back'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.primaryColor,
                    ),
                  ),
                ],
              ),
            );
          }

          return SingleChildScrollView(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Episode Info Card
                  _buildEpisodeInfoCard(episode),
                  SizedBox(height: 24),
                  
                  // Stream Options Section
                  _buildSectionHeader('Stream Options'),
                  SizedBox(height: 8),
                  _buildStreamOptionsCard(episode),
                  SizedBox(height: 24),
                  
                  // Download Links Section
                  _buildSectionHeader('Download Links'),
                  SizedBox(height: 8),
                  _buildDownloadLinksCard(episode),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  // Helper methods to build UI components
  Widget _buildEpisodeInfoCard(Map<String, dynamic> episode) {
    return Card(
      color: AppTheme.cardColor,
      elevation: 3,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              episode['title'] ?? 'Episode',
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: AppTheme.textPrimaryColor,
              ),
            ),
            SizedBox(height: 8),
            if (episode['episode_number'] != null)
              Container(
                padding: EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                decoration: BoxDecoration(
                  color: AppTheme.primaryColor,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Text(
                  'Episode ${episode['episode_number']}',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Text(
      title,
      style: TextStyle(
        fontSize: 18,
        fontWeight: FontWeight.bold,
        color: AppTheme.primaryColor,
      ),
    );
  }

  Widget _buildStreamOptionsCard(Map<String, dynamic> episode) {
    return Card(
      color: AppTheme.cardColor,
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ListTile(
              leading: Icon(Icons.play_circle_filled,
                  color: AppTheme.accentColor, size: 36),
              title: Text(
                'Watch in App',
                style: TextStyle(
                  color: AppTheme.textPrimaryColor,
                  fontWeight: FontWeight.bold,
                ),
              ),
              subtitle: Text(
                'Stream directly in the app',
                style: TextStyle(color: AppTheme.textSecondaryColor),
              ),
              onTap: () => _showRewardedAd(context, () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => VideoPlayerScreen(
                      url: episode['stream_url'] ?? '',
                      title: episode['title'] ?? 'Episode',
                      episodeId: episode['id'] ??
                          DateTime.now()
                              .millisecondsSinceEpoch
                              .toString(),
                      directStreamUrls:
                          episode['direct_stream_urls'] != null
                              ? List<Map<String, String>>.from(
                                  episode['direct_stream_urls']
                                      .map((item) => Map<String,
                                          String>.from(item)))
                              : [],
                    ),
                  ),
                );
              }),
            ),
            ListTile(
              leading: Icon(Icons.open_in_browser,
                  color: AppTheme.accentColor, size: 36),
              title: Text(
                'Open in Browser',
                style: TextStyle(
                  color: AppTheme.textPrimaryColor,
                  fontWeight: FontWeight.bold,
                ),
              ),
              subtitle: Text(
                'Stream in external browser',
                style: TextStyle(color: AppTheme.textSecondaryColor),
              ),
              onTap: () => _launchUrl(context, episode['stream_url'] ?? ''),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDownloadLinksCard(Map<String, dynamic> episode) {
    final downloadLinks = episode['download_links'] as Map<String, dynamic>?;
    if (downloadLinks == null || downloadLinks.isEmpty) {
      return Card(
        color: AppTheme.cardColor,
        elevation: 2,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Center(
            child: Text(
              'No download links available',
              style: TextStyle(color: AppTheme.textSecondaryColor),
            ),
          ),
        ),
      );
    }

    return Card(
      color: AppTheme.cardColor,
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: ListView.builder(
        shrinkWrap: true,
        physics: NeverScrollableScrollPhysics(),
        itemCount: downloadLinks.length,
        itemBuilder: (context, index) {
          final quality = downloadLinks.keys.elementAt(index);
          final links = downloadLinks[quality] as List<dynamic>? ?? [];
          return ExpansionTile(
            collapsedIconColor: AppTheme.textPrimaryColor,
            iconColor: AppTheme.accentColor,
            title: Text(
              'Quality: $quality',
              style: TextStyle(color: AppTheme.textPrimaryColor),
            ),
            children: links.map<Widget>((link) {
              return ListTile(
                leading: Icon(Icons.download, color: AppTheme.accentColor),
                title: Text(
                  link['host'] ?? 'Unknown Host',
                  style: TextStyle(color: AppTheme.textPrimaryColor),
                ),
                onTap: () => _launchUrl(context, link['url'] ?? ''),
              );
            }).toList(),
          );
        },
      ),
    );
  }

  @override
  void dispose() {
    AdService.dispose();
    super.dispose();
  }
}
