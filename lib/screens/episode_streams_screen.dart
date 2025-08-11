import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/api_service.dart';
import '../theme/app_theme.dart';
import '../widgets/custom_error_dialog.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'video_player_screen.dart';

class EpisodeStreamsScreen extends StatefulWidget {
  final String url;
  final String? animeImageUrl;

  EpisodeStreamsScreen({required this.url, this.animeImageUrl});

  @override
  _EpisodeStreamsScreenState createState() => _EpisodeStreamsScreenState();
}

class _EpisodeStreamsScreenState extends State<EpisodeStreamsScreen> {
  final ApiService apiService = ApiService();
  RewardedAd? _rewardedAd;
  bool _isAdLoading = false;
  int _adLoadAttempts = 0;
  static const int _maxAdLoadAttempts = 3;

  @override
  void initState() {
    super.initState();
    _loadRewardedAd();
  }

  Future<void> _loadRewardedAd({bool forceReload = false}) async {
    if (_isAdLoading && !forceReload) return;

    setState(() {
      _isAdLoading = true;
      _adLoadAttempts++;
    });

    await RewardedAd.load(
      adUnitId:
          'ca-app-pub-7591838535085655/4184612382', // Ganti dengan ID produksi
      request: AdRequest(),
      rewardedAdLoadCallback: RewardedAdLoadCallback(
        onAdLoaded: (RewardedAd ad) {
          setState(() {
            _rewardedAd = ad;
            _isAdLoading = false;
            _adLoadAttempts = 0;
          });
          print('RewardedAd loaded successfully');
        },
        onAdFailedToLoad: (LoadAdError error) async {
          setState(() {
            _rewardedAd = null;
            _isAdLoading = false;
          });
          print('RewardedAd failed to load: $error');

          if (_adLoadAttempts < _maxAdLoadAttempts) {
            print('Retrying to load ad... Attempt ${_adLoadAttempts + 1}');
            await Future.delayed(Duration(seconds: 2)); // Delay sebelum retry
            await _loadRewardedAd(forceReload: true);
          } else {
            setState(() {
              _adLoadAttempts = 0;
            });
          }
        },
      ),
    );
  }

  Future<void> _showRewardedAd(
      BuildContext context, VoidCallback onReward) async {
    // Pastikan iklan dimuat ulang setiap kali showRewardedAd dipanggil
    if (_rewardedAd == null || _isAdLoading) {
      try {
        await _loadRewardedAd(forceReload: true);
      } catch (e) {
        print('Error loading rewarded ad: $e');
        onReward();
        return;
      }
    }

    if (_rewardedAd == null) {
      print('Rewarded ad is null, proceeding without ad');
      onReward();
      return;
    }

    // Set landscape orientation before showing ad
    await SystemChrome.setPreferredOrientations([
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);
    await SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersive);

    _rewardedAd!.fullScreenContentCallback = FullScreenContentCallback(
      onAdDismissedFullScreenContent: (RewardedAd ad) async {
        ad.dispose();
        setState(() {
          _rewardedAd = null;
        });
        // Keep landscape orientation after ad for video player
        await SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
        _loadRewardedAd(
            forceReload: true); // Muat ulang untuk tindakan berikutnya
      },
      onAdFailedToShowFullScreenContent: (RewardedAd ad, AdError error) async {
        ad.dispose();
        setState(() {
          _rewardedAd = null;
        });
        print('RewardedAd failed to show: $error');
        // Keep landscape orientation after ad failure for video player
        await SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
        onReward(); // Lanjutkan ke konten meskipun iklan gagal
        _loadRewardedAd(
            forceReload: true); // Muat ulang untuk tindakan berikutnya
      },
    );

    try {
      await _rewardedAd!.show(
        onUserEarnedReward: (AdWithoutView ad, RewardItem reward) {
          onReward();
        },
      );
    } catch (e) {
      print('Error showing rewarded ad: $e');
      // Keep landscape orientation on error for video player
      await SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
      onReward();
    }
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

  Future<void> _saveToHistory(
      BuildContext context, Map<String, dynamic> episode) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final historyJson = prefs.getString('anime_history') ?? '[]';
      List<dynamic> history = jsonDecode(historyJson);

      final historyItem = {
        'id': DateTime.now().millisecondsSinceEpoch.toString(),
        'title': episode['title'],
        'image_url': widget.animeImageUrl ??
            episode['image_url'] ??
            episode['thumbnail'] ??
            'https://via.placeholder.com/150',
        'url': widget.url,
        'episode': episode['episode_number'] ?? 'Unknown',
        'timestamp': DateTime.now().toString(),
        'type': 'anime',
      };

      history.removeWhere((item) => item['url'] == widget.url);
      history.insert(0, historyItem);

      if (history.length > 50) {
        history = history.sublist(0, 50);
      }

      await prefs.setString('anime_history', jsonEncode(history));
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
        future: apiService.fetchEpisodeStreams(widget.url),
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

          return SingleChildScrollView(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Card(
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
                            episode['title'],
                            style: TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.bold,
                              color: AppTheme.textPrimaryColor,
                            ),
                          ),
                          SizedBox(height: 8),
                          if (episode['episode_number'] != null)
                            Container(
                              padding: EdgeInsets.symmetric(
                                  horizontal: 12, vertical: 4),
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
                  ),
                  SizedBox(height: 24),
                  Text(
                    'Stream Options',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.primaryColor,
                    ),
                  ),
                  SizedBox(height: 8),
                  Card(
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
                              style:
                                  TextStyle(color: AppTheme.textSecondaryColor),
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
                              style:
                                  TextStyle(color: AppTheme.textSecondaryColor),
                            ),
                            onTap: () =>
                                _launchUrl(context, episode['stream_url']),
                          ),
                        ],
                      ),
                    ),
                  ),
                  SizedBox(height: 24),
                  Text(
                    'Download Links',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.primaryColor,
                    ),
                  ),
                  SizedBox(height: 8),
                  Card(
                    color: AppTheme.cardColor,
                    elevation: 2,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: ListView.builder(
                      shrinkWrap: true,
                      physics: NeverScrollableScrollPhysics(),
                      itemCount: episode['download_links'].length,
                      itemBuilder: (context, index) {
                        final quality =
                            episode['download_links'].keys.elementAt(index);
                        final links = episode['download_links'][quality];
                        return ExpansionTile(
                          collapsedIconColor: AppTheme.textPrimaryColor,
                          iconColor: AppTheme.accentColor,
                          title: Text(
                            'Quality: $quality',
                            style: TextStyle(color: AppTheme.textPrimaryColor),
                          ),
                          children: links.map<Widget>((link) {
                            return ListTile(
                              leading: Icon(Icons.download,
                                  color: AppTheme.accentColor),
                              title: Text(
                                link['host'],
                                style:
                                    TextStyle(color: AppTheme.textPrimaryColor),
                              ),
                              onTap: () => _launchUrl(context, link['url']),
                            );
                          }).toList(),
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  @override
  void dispose() {
    _rewardedAd?.dispose();
    super.dispose();
  }
}
