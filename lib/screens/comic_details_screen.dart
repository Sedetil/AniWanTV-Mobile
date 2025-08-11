import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:convert';
import 'dart:math';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/api_service.dart';
import 'manga_reader_screen.dart';
import '../theme/app_theme.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:fluttertoast/fluttertoast.dart';

class ComicDetailsScreen extends StatefulWidget {
  final String url;

  ComicDetailsScreen({required this.url});

  @override
  _ComicDetailsScreenState createState() => _ComicDetailsScreenState();
}

class _ComicDetailsScreenState extends State<ComicDetailsScreen> {
  final ApiService apiService = ApiService();
  String _searchQuery = '';
  Map<String, dynamic>? _comicData;
  bool _isLoading = true;
  String? _error;
  RewardedAd? _rewardedAd;
  bool _isAdLoading = false;
  int _adLoadAttempts = 0;
  static const int _maxAdLoadAttempts = 3;

  @override
  void initState() {
    super.initState();
    _loadComicData();
    _loadRewardedAd();
  }

  Future<void> _loadComicData() async {
    try {
      final data = await apiService.fetchComicDetails(widget.url);
      setState(() {
        _comicData = data;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
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

    // Set portrait orientation before showing ad for manga
    await SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
    ]);
    await SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersive);

    _rewardedAd!.fullScreenContentCallback = FullScreenContentCallback(
      onAdDismissedFullScreenContent: (RewardedAd ad) async {
        ad.dispose();
        setState(() {
          _rewardedAd = null;
        });
        // Keep portrait orientation after ad for manga reader
        await SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
        _loadRewardedAd(forceReload: true);
      },
      onAdFailedToShowFullScreenContent: (RewardedAd ad, AdError error) async {
        ad.dispose();
        setState(() {
          _rewardedAd = null;
        });
        print('RewardedAd failed to show: $error');
        // Keep portrait orientation after ad failure for manga reader
        await SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
        onReward(); // Lanjutkan ke konten meskipun iklan gagal
        _loadRewardedAd(forceReload: true);
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
      // Keep portrait orientation on error for manga reader
      await SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
      onReward();
    }
  }

  String? _cleanSynopsis(String? synopsis) {
    if (synopsis == null) return null;
    return synopsis.replaceAll(RegExp(r'\s+'), ' ').trim();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      body: _isLoading
          ? _buildLoadingView()
          : _error != null
              ? _buildErrorView()
              : _comicData == null
                  ? _buildNoDataView()
                  : _buildComicDetailsView(),
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
          Text('Loading...', style: TextStyle(color: Colors.white)),
        ],
      ),
    );
  }

  Widget _buildErrorView() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.error_outline, size: 60, color: AppTheme.primaryColor),
          SizedBox(height: 16),
          Text('Error: $_error', style: TextStyle(color: Colors.white)),
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

  Widget _buildNoDataView() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.warning, size: 60, color: Colors.amber),
          SizedBox(height: 16),
          Text('No data found for this comic',
              style: TextStyle(color: Colors.white)),
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

  Widget _buildComicDetailsView() {
    final comic = _comicData;
    if (comic == null) {
      return _buildNoDataView();
    }

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
              comic['title'] ?? 'No Title',
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
                  comic['image_url'] ?? '',
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) {
                    return Container(
                      color: Colors.grey[800],
                      child: Center(
                        child: Icon(Icons.broken_image,
                            size: 50, color: Colors.grey),
                      ),
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
                // Share functionality placeholder
              },
            ),
            IconButton(
              icon: Icon(Icons.bookmark_border),
              onPressed: () async {
                try {
                  final prefs = await SharedPreferences.getInstance();
                  final favoritesJson =
                      prefs.getString('favorite_comics') ?? '[]';
                  List<dynamic> favorites = jsonDecode(favoritesJson);

                  final comicExists =
                      favorites.any((item) => item['url'] == widget.url);

                  if (comicExists) {
                    Fluttertoast.showToast(
                      msg: 'Comic already in favorites',
                      toastLength: Toast.LENGTH_SHORT,
                      gravity: ToastGravity.BOTTOM,
                      backgroundColor: Colors.orange,
                      textColor: Colors.white,
                    );
                    return;
                  }

                  favorites.add({
                    'id': DateTime.now().millisecondsSinceEpoch.toString(),
                    'title': comic['title'] ?? 'No Title',
                    'image_url': comic['image_url'] ?? '',
                    'url': widget.url,
                    'description': comic['synopsis'] != null
                        ? comic['synopsis'].substring(
                                0, min<int>(100, comic['synopsis'].length)) +
                            '...'
                        : 'No description available',
                    'type': 'comic',
                    'rating': comic['rating'],
                  });

                  await prefs.setString(
                      'favorite_comics', jsonEncode(favorites));

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
                        Column(
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                _buildInfoRow(
                                  context,
                                  'Rating',
                                  '${comic['rating'] ?? 'N/A'}',
                                  Icons.star,
                                  Colors.amber,
                                ),
                                _buildInfoRow(
                                  context,
                                  'Author',
                                  '${comic['author'] ?? 'Unknown'}',
                                  Icons.person,
                                  Colors.blue,
                                ),
                              ],
                            ),
                            SizedBox(height: 12),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                _buildInfoRow(
                                  context,
                                  'Illustrator',
                                  '${comic['illustrator'] ?? 'Wuer Manhua, Ye Xiao'}',
                                  Icons.brush,
                                  Colors.purple,
                                ),
                                _buildInfoRow(
                                  context,
                                  'Type',
                                  '${comic['type'] ?? 'Manhua'}',
                                  Icons.category,
                                  Colors.green,
                                ),
                              ],
                            ),
                            SizedBox(height: 12),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                _buildInfoRow(
                                  context,
                                  'Status',
                                  '${comic['status'] ?? 'Berjalan'}',
                                  Icons.info_outline,
                                  Colors.orange,
                                ),
                                Opacity(opacity: 0),
                              ],
                            ),
                          ],
                        ),
                        SizedBox(height: 16),
                        _buildGenresChips(context, comic['genres'] ?? []),
                      ],
                    ),
                  ),
                ),
                SizedBox(height: 24),
                if (comic['alternative_titles'] != null &&
                    (comic['alternative_titles'] as List).isNotEmpty)
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Alternative Titles',
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
                          child: Wrap(
                            spacing: 8.0,
                            runSpacing: 8.0,
                            children: (comic['alternative_titles'] as List? ??
                                    [
                                      "Best Devil Housekeeper",
                                      "Demon Emperor Butler",
                                      "Demon Emperor Great Butler",
                                      "Demon Emperor Housekeeper",
                                      "Housekeeper is the Magic Emperor",
                                      "Demonic Emperor",
                                      "Mo Huang Da Guan Jia",
                                      "The Steward demonic emperor",
                                      "Как демон-император стал дворецким",
                                      "魔皇大管家"
                                    ])
                                .map((title) => Container(
                                      padding: EdgeInsets.symmetric(
                                          horizontal: 10, vertical: 6),
                                      decoration: BoxDecoration(
                                        color: AppTheme.primaryColor
                                            .withOpacity(0.1),
                                        borderRadius: BorderRadius.circular(20),
                                        border: Border.all(
                                            color: AppTheme.primaryColor
                                                .withOpacity(0.3)),
                                      ),
                                      child: Text(
                                        title.toString(),
                                        style: TextStyle(
                                          color: Colors.white,
                                          fontSize: 12,
                                        ),
                                      ),
                                    ))
                                .toList(),
                          ),
                        ),
                      ),
                      SizedBox(height: 24),
                    ],
                  ),
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
                      _cleanSynopsis(comic['synopsis']) ??
                          'No synopsis available',
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
                      'Chapters',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: AppTheme.primaryColor,
                      ),
                    ),
                    Container(
                      padding:
                          EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: AppTheme.primaryColor,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        '${comic['chapters']?.length ?? 0} chapters',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 16),
                Container(
                  margin: EdgeInsets.only(bottom: 16),
                  padding: EdgeInsets.symmetric(horizontal: 12),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                        color: AppTheme.primaryColor.withOpacity(0.3)),
                  ),
                  child: TextField(
                    style: TextStyle(color: Colors.white),
                    decoration: InputDecoration(
                      hintText: 'Cari chapter...',
                      hintStyle: TextStyle(color: Colors.white70),
                      prefixIcon:
                          Icon(Icons.search, color: AppTheme.primaryColor),
                      border: InputBorder.none,
                      contentPadding: EdgeInsets.symmetric(vertical: 12),
                    ),
                    onChanged: (value) {
                      setState(() {
                        _searchQuery = value;
                      });
                    },
                  ),
                ),
                _buildChaptersList(
                    context, comic['chapters'] ?? [], _searchQuery),
              ],
            ),
          ),
        ),
      ],
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
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: AppTheme.textSecondaryColor,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          SizedBox(height: 6),
          Padding(
            padding: const EdgeInsets.only(left: 4.0),
            child: Text(
              value,
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

  Widget _buildChaptersList(BuildContext context, List<dynamic> chapters,
      [String searchQuery = '']) {
    final orderedChapters = List<dynamic>.from(chapters);

    List<dynamic> filteredChapters = orderedChapters;
    if (searchQuery.isNotEmpty) {
      filteredChapters = orderedChapters.where((chapter) {
        final chapterTitle = chapter['title']?.toString().toLowerCase() ?? '';
        return chapterTitle.contains(searchQuery.toLowerCase());
      }).toList();
    }

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
          itemCount: filteredChapters.length,
          separatorBuilder: (context, index) => Divider(
              height: 1, indent: 70, color: Colors.grey.withOpacity(0.2)),
          itemBuilder: (context, index) {
            final chapter = filteredChapters[index];
            String chapterNumber = '';
            String chapterNumberDisplay = '';

            if (chapter['title'] != null) {
              chapterNumber = chapter['title'];

              RegExp regExp =
                  RegExp(r'Chapter\s+(\d+(?:\.\d+)?(?:[A-Za-z]+)?)');
              var match = regExp.firstMatch(chapter['title']);
              if (match != null && match.groupCount >= 1) {
                chapterNumberDisplay = match.group(1) ?? '';
              } else {
                chapterNumberDisplay = '${index + 1}';
              }
            } else {
              chapterNumber = 'Chapter ${orderedChapters.length - index}';
              chapterNumberDisplay = '${orderedChapters.length - index}';
            }

            return ListTile(
              leading: Container(
                width: 50,
                height: 50,
                decoration: BoxDecoration(
                  color: AppTheme.primaryColor,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.menu_book,
                        color: Colors.white,
                        size: 24,
                      ),
                    ],
                  ),
                ),
              ),
              title: Row(
                children: [
                  Text(
                    'Chapter ',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  Text(
                    chapterNumberDisplay,
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: AppTheme.textPrimaryColor,
                    ),
                  ),
                  if (chapterNumber.contains('-') ||
                      (chapterNumber.toLowerCase().contains('chapter') &&
                          chapterNumber.length >
                              ('Chapter ' + chapterNumberDisplay).length))
                    Expanded(
                      child: Text(
                        ' ' +
                            chapterNumber.replaceAll(
                                RegExp(
                                    r'Chapter\s+\d+(?:\.\d+)?(?:[A-Za-z]+)?\s*-?\s*'),
                                ''),
                        style: TextStyle(
                          fontWeight: FontWeight.normal,
                          color: AppTheme.primaryColor,
                          fontSize: 14,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                ],
              ),
              trailing: Icon(Icons.arrow_forward_ios,
                  size: 16, color: AppTheme.primaryColor),
              onTap: () => _showRewardedAd(context, () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => MangaReaderScreen(
                      url: chapter['url'],
                      comicImageUrl: _comicData?['image_url'],
                      title: chapterNumber,
                      chapterId: chapterNumberDisplay,
                    ),
                  ),
                );
              }),
            );
          },
        ),
      ),
    );
  }

  @override
  void dispose() {
    _rewardedAd?.dispose();
    super.dispose();
  }
}
