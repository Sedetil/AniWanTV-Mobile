import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:convert';
import 'dart:math';
import 'package:provider/provider.dart';
import '../services/api_service.dart';
import '../theme/app_theme.dart';
import '../providers/app_state_provider.dart';
import 'manga_reader_screen.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:fluttertoast/fluttertoast.dart';

class ComicDetailsScreen extends StatefulWidget {
  final String url;

  const ComicDetailsScreen({required this.url});

  @override
  State<ComicDetailsScreen> createState() => _ComicDetailsScreenState();
}

class _ComicDetailsScreenState extends State<ComicDetailsScreen> {
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
      final data = await ApiService.fetchComicDetails(widget.url);
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
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          _AnimatedLoadingIcon(),
          SizedBox(height: 24),
          _AnimatedLoadingText(),
        ],
      ),
    );
  }

  Widget _buildErrorView() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const _AnimatedErrorIcon(),
          const SizedBox(height: 24),
          _AnimatedErrorText(error: _error ?? 'Unknown error'),
          const SizedBox(height: 24),
          const _GoBackButton(),
        ],
      ),
    );
  }

  Widget _buildNoDataView() {
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          _AnimatedNoDataIcon(),
          SizedBox(height: 24),
          _AnimatedNoDataText(),
          SizedBox(height: 24),
          _GoBackButton(),
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
        _ComicSliverAppBar(comic: comic, url: widget.url),
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _AnimatedInfoCard(comic: comic),
                const SizedBox(height: 24),
                if (comic['alternative_titles'] != null &&
                    (comic['alternative_titles'] as List).isNotEmpty)
                  _AnimatedAlternativeTitlesSection(comic: comic),
                _AnimatedSynopsisSection(comic: comic),
                const SizedBox(height: 24),
                _AnimatedChaptersHeader(comic: comic),
                const SizedBox(height: 16),
                _AnimatedSearchField(
                  searchQuery: _searchQuery,
                  onChanged: (value) {
                    setState(() {
                      _searchQuery = value;
                    });
                  },
                ),
                const SizedBox(height: 16),
                _AnimatedChaptersList(
                  comic: comic,
                  searchQuery: _searchQuery,
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  @override
  void dispose() {
    _rewardedAd?.dispose();
    super.dispose();
  }
}

// --- Helper Widgets ---

class _AnimatedLoadingIcon extends StatelessWidget {
  const _AnimatedLoadingIcon();

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.8, end: 1.0),
      duration: const Duration(milliseconds: 800),
      builder: (context, value, _) {
        return Transform.scale(
          scale: value,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 300),
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: RadialGradient(
                colors: [
                  AppTheme.primaryColor.withOpacity(0.15),
                  AppTheme.primaryColor.withOpacity(0.05),
                  Colors.transparent,
                ],
                stops: const [0.0, 0.7, 1.0],
              ),
              shape: BoxShape.circle,
              border: Border.all(
                color: AppTheme.primaryColor.withOpacity(0.4),
                width: 1.5,
              ),
              boxShadow: [
                BoxShadow(
                  color: AppTheme.primaryColor.withOpacity(0.4),
                  blurRadius: 30,
                  spreadRadius: 2,
                ),
                BoxShadow(
                  color: AppTheme.primaryColor.withOpacity(0.2),
                  blurRadius: 60,
                  spreadRadius: 5,
                ),
              ],
            ),
            child: Icon(
              Icons.menu_book,
              size: 80,
              color: AppTheme.primaryColor,
              shadows: [
                Shadow(
                  color: AppTheme.primaryColor.withOpacity(0.5),
                  blurRadius: 10,
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _AnimatedLoadingText extends StatelessWidget {
  const _AnimatedLoadingText();

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.0, end: 1.0),
      duration: const Duration(milliseconds: 1000),
      curve: Curves.easeOut,
      builder: (context, value, _) {
        return Transform.translate(
          offset: Offset(0, 20 * (1 - value)),
          child: Opacity(
            opacity: value,
            child: Text(
              'Loading...',
              style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.w500,
                    letterSpacing: 0.5,
                  ),
            ),
          ),
        );
      },
    );
  }
}

class _AnimatedErrorIcon extends StatelessWidget {
  const _AnimatedErrorIcon();

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.8, end: 1.0),
      duration: const Duration(milliseconds: 800),
      builder: (context, value, _) {
        return Transform.scale(
          scale: value,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 300),
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: RadialGradient(
                colors: [
                  AppTheme.errorColor.withOpacity(0.15),
                  AppTheme.errorColor.withOpacity(0.05),
                  Colors.transparent,
                ],
                stops: const [0.0, 0.7, 1.0],
              ),
              shape: BoxShape.circle,
              border: Border.all(
                color: AppTheme.errorColor.withOpacity(0.4),
                width: 1.5,
              ),
              boxShadow: [
                BoxShadow(
                  color: AppTheme.errorColor.withOpacity(0.4),
                  blurRadius: 30,
                  spreadRadius: 2,
                ),
                BoxShadow(
                  color: AppTheme.errorColor.withOpacity(0.2),
                  blurRadius: 60,
                  spreadRadius: 5,
                ),
              ],
            ),
            child: Icon(
              Icons.error_outline,
              size: 80,
              color: AppTheme.errorColor,
              shadows: [
                Shadow(
                  color: AppTheme.errorColor.withOpacity(0.5),
                  blurRadius: 10,
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _AnimatedErrorText extends StatelessWidget {
  final String error;
  const _AnimatedErrorText({required this.error});

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.0, end: 1.0),
      duration: const Duration(milliseconds: 1000),
      curve: Curves.easeOut,
      builder: (context, value, _) {
        return Transform.translate(
          offset: Offset(0, 20 * (1 - value)),
          child: Opacity(
            opacity: value,
            child: Text(
              'Error: $error',
              style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.w500,
                    letterSpacing: 0.5,
                  ),
            ),
          ),
        );
      },
    );
  }
}

class _AnimatedNoDataIcon extends StatelessWidget {
  const _AnimatedNoDataIcon();

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.8, end: 1.0),
      duration: const Duration(milliseconds: 800),
      builder: (context, value, _) {
        return Transform.scale(
          scale: value,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 300),
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: RadialGradient(
                colors: [
                  Colors.amber.withOpacity(0.15),
                  Colors.amber.withOpacity(0.05),
                  Colors.transparent,
                ],
                stops: const [0.0, 0.7, 1.0],
              ),
              shape: BoxShape.circle,
              border: Border.all(
                color: Colors.amber.withOpacity(0.4),
                width: 1.5,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.amber.withOpacity(0.4),
                  blurRadius: 30,
                  spreadRadius: 2,
                ),
                BoxShadow(
                  color: Colors.amber.withOpacity(0.2),
                  blurRadius: 60,
                  spreadRadius: 5,
                ),
              ],
            ),
            child: const Icon(
              Icons.warning,
              size: 80,
              color: Colors.amber,
              shadows: [
                Shadow(
                  color: Colors.amber,
                  blurRadius: 10,
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _AnimatedNoDataText extends StatelessWidget {
  const _AnimatedNoDataText();

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.0, end: 1.0),
      duration: const Duration(milliseconds: 1000),
      curve: Curves.easeOut,
      builder: (context, value, _) {
        return Transform.translate(
          offset: Offset(0, 20 * (1 - value)),
          child: Opacity(
            opacity: value,
            child: Text(
              'No data found for this comic',
              style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.w500,
                    letterSpacing: 0.5,
                  ),
            ),
          ),
        );
      },
    );
  }
}

class _GoBackButton extends StatelessWidget {
  const _GoBackButton();

  @override
  Widget build(BuildContext context) {
    return StatefulBuilder(
      builder: (context, setState) {
        bool isHovered = false;
        return MouseRegion(
          cursor: SystemMouseCursors.click,
          onEnter: (_) => setState(() => isHovered = true),
          onExit: (_) => setState(() => isHovered = false),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            transform: Matrix4.identity()..scale(isHovered ? 1.05 : 1.0),
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: isHovered
                    ? AppTheme.primaryColor.withOpacity(0.9)
                    : AppTheme.primaryColor,
                foregroundColor: Colors.white,
                padding:
                    const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppTheme.radiusSmall),
                ),
                elevation: isHovered ? 8 : 4,
                shadowColor: AppTheme.primaryColor.withOpacity(0.3),
              ),
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Go Back'),
            ),
          ),
        );
      },
    );
  }
}

class _ComicSliverAppBar extends StatelessWidget {
  final Map<String, dynamic> comic;
  final String url;
  const _ComicSliverAppBar({required this.comic, required this.url});

  @override
  Widget build(BuildContext context) {
    return SliverAppBar(
      expandedHeight: 300.0,
      floating: false,
      pinned: true,
      backgroundColor: AppTheme.backgroundColor,
      actions: [_ShareButton(), _FavoriteButton(comic: comic, url: url)],
      flexibleSpace: FlexibleSpaceBar(
        titlePadding:
            const EdgeInsets.only(left: 60.0, bottom: 16.0, right: 120.0),
        title: _AnimatedAppBarTitle(title: comic['title']),
        background: Stack(
          fit: StackFit.expand,
          children: [
            Image.network(
              comic['image_url'] ?? '',
              fit: BoxFit.cover,
              errorBuilder: (context, _, __) => Container(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [AppTheme.surfaceColor, AppTheme.cardColor],
                  ),
                ),
                child: const Center(
                  child: Icon(
                    Icons.broken_image,
                    size: 50,
                    color: AppTheme.textSecondaryColor,
                  ),
                ),
              ),
            ),
            Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Colors.transparent, Colors.black.withOpacity(0.7)],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ShareButton extends StatelessWidget {
  const _ShareButton();

  @override
  Widget build(BuildContext context) {
    return StatefulBuilder(
      builder: (context, setState) {
        bool isHovered = false;
        return MouseRegion(
          cursor: SystemMouseCursors.click,
          onEnter: (_) => setState(() => isHovered = true),
          onExit: (_) => setState(() => isHovered = false),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            transform: Matrix4.identity()..scale(isHovered ? 1.1 : 1.0),
            child: IconButton(
              icon: const Icon(Icons.share),
              onPressed: () {
                Fluttertoast.showToast(
                  msg: 'Share functionality coming soon',
                  toastLength: Toast.LENGTH_SHORT,
                  gravity: ToastGravity.BOTTOM,
                  backgroundColor: AppTheme.primaryColor,
                  textColor: Colors.white,
                );
              },
              tooltip: 'Share',
            ),
          ),
        );
      },
    );
  }
}

class _FavoriteButton extends StatelessWidget {
  final Map<String, dynamic> comic;
  final String url;
  const _FavoriteButton({required this.comic, required this.url});

  @override
  Widget build(BuildContext context) {
    return StatefulBuilder(
      builder: (context, setState) {
        bool isHovered = false;
        final appStateProvider = Provider.of<AppStateProvider>(context);
        final isFavorited =
            appStateProvider.favoriteComics.any((item) => item['url'] == url);
        return MouseRegion(
          cursor: SystemMouseCursors.click,
          onEnter: (_) => setState(() => isHovered = true),
          onExit: (_) => setState(() => isHovered = false),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            transform: Matrix4.identity()..scale(isHovered ? 1.1 : 1.0),
            child: IconButton(
              icon: Icon(isFavorited ? Icons.bookmark : Icons.bookmark_border,
                  color: isFavorited ? AppTheme.accentColor : null),
              onPressed: () async {
                try {
                  final appStateProvider =
                      Provider.of<AppStateProvider>(context, listen: false);
                  await appStateProvider.initialize();
                  final existing = appStateProvider.favoriteComics
                      .where((item) => item['url'] == url)
                      .toList();
                  if (existing.isNotEmpty) {
                    final id = existing.first['id']?.toString() ?? '';
                    if (id.isNotEmpty) {
                      await appStateProvider.removeFromFavorites(id, false);
                      Fluttertoast.showToast(
                        msg: 'Removed from favorites',
                        toastLength: Toast.LENGTH_SHORT,
                        gravity: ToastGravity.BOTTOM,
                        backgroundColor: Colors.red,
                        textColor: Colors.white,
                      );
                      setState(() {});
                      return;
                    }
                  }

                  await appStateProvider.addToFavorites({
                    'title': comic['title'] ?? 'No Title',
                    'image_url': comic['image_url'] ?? '',
                    'url': url,
                    'description': comic['synopsis'] != null
                        ? '${comic['synopsis'].substring(0, min<int>(100, comic['synopsis'].length))}...'
                        : 'No description available',
                    'rating': comic['rating'],
                  }, false);

                  Fluttertoast.showToast(
                    msg: 'Added to favorites',
                    toastLength: Toast.LENGTH_SHORT,
                    gravity: ToastGravity.BOTTOM,
                    backgroundColor: Colors.green,
                    textColor: Colors.white,
                  );
                  setState(() {});
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
              tooltip: 'Add to Favorites',
            ),
          ),
        );
      },
    );
  }
}

class _AnimatedAppBarTitle extends StatelessWidget {
  final String title;
  const _AnimatedAppBarTitle({required this.title});

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.0, end: 1.0),
      duration: const Duration(milliseconds: 800),
      curve: Curves.easeOut,
      builder: (context, value, _) {
        return Transform.translate(
          offset: Offset(0, 20 * (1 - value)),
          child: Opacity(
            opacity: value,
            child: Text(
              title,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 20,
                shadows: [
                  Shadow(
                    blurRadius: 10.0,
                    color: Colors.black54,
                    offset: Offset(2.0, 2.0),
                  ),
                ],
              ),
              overflow: TextOverflow.ellipsis,
              maxLines: 2,
            ),
          ),
        );
      },
    );
  }
}

class _AnimatedInfoCard extends StatelessWidget {
  final Map<String, dynamic> comic;
  const _AnimatedInfoCard({required this.comic});

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.0, end: 1.0),
      duration: const Duration(milliseconds: 1000),
      curve: Curves.easeOut,
      builder: (context, value, _) {
        return Transform.translate(
          offset: Offset(0, 20 * (1 - value)),
          child: Opacity(
            opacity: value,
            child: Container(
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [AppTheme.surfaceColor, AppTheme.cardColor],
                ),
                borderRadius: BorderRadius.circular(AppTheme.radiusLarge),
                boxShadow: AppTheme.mediumShadow,
                border: Border.all(
                  color: Colors.white.withOpacity(0.05),
                  width: 1.2,
                ),
              ),
              child: Padding(
                padding: const EdgeInsets.all(20.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Builder(
                      builder: (context) {
                        final altTitles =
                            (comic['alternative_titles'] as List?) ?? [];
                        return Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            _InfoPill(
                              icon: Icons.star,
                              text: comic['rating']?.toString() ?? 'N/A',
                              iconColor: Colors.amber,
                            ),
                            if (comic['type'] != null)
                              _InfoPill(
                                icon: Icons.category,
                                text: comic['type'].toString(),
                              ),
                            if (comic['status'] != null)
                              _InfoPill(
                                icon: Icons.info_outline,
                                text: comic['status'].toString(),
                              ),
                            if (comic['demographic'] != null)
                              _InfoPill(
                                icon: Icons.group,
                                text: comic['demographic'].toString(),
                              ),
                            if (comic['author'] != null)
                              _InfoPill(
                                icon: Icons.person,
                                text: comic['author'].toString(),
                              ),
                            if (comic['illustrator'] != null)
                              _InfoPill(
                                icon: Icons.brush,
                                text: comic['illustrator'].toString(),
                              ),
                          ],
                        );
                      },
                    ),
                    const SizedBox(height: 20),
                    _GenresChips(genres: comic['genres'] ?? []),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

class _InfoRow extends StatelessWidget {
  final String label;
  final String infoValue;
  final IconData icon;
  final Color iconColor;
  const _InfoRow({
    required this.label,
    required this.infoValue,
    required this.icon,
    required this.iconColor,
  });

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.0, end: 1.0),
      duration: const Duration(milliseconds: 800),
      curve: Curves.easeOut,
      builder: (context, animationValue, _) {
        return Transform.translate(
          offset: Offset(0, 20 * (1 - animationValue)),
          child: Opacity(
            opacity: animationValue,
            child: Container(
              width: MediaQuery.of(context).size.width * 0.40,
              padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 16),
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
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          gradient: RadialGradient(
                            colors: [
                              iconColor.withOpacity(0.3),
                              iconColor.withOpacity(0.1),
                            ],
                          ),
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: iconColor.withOpacity(0.4),
                            width: 1.5,
                          ),
                        ),
                        child: Icon(icon, color: iconColor, size: 18),
                      ),
                      const SizedBox(width: 8),
                      Flexible(
                        child: Text(
                          label,
                          style:
                              Theme.of(context).textTheme.titleSmall?.copyWith(
                                    fontWeight: FontWeight.bold,
                                    color: Colors.white,
                                    letterSpacing: 0.5,
                                  ),
                          overflow: TextOverflow.ellipsis,
                          maxLines: 1,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    infoValue,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: Colors.white,
                          fontWeight: FontWeight.w500,
                        ),
                    overflow: TextOverflow.ellipsis,
                    maxLines: 1,
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

class _InfoPill extends StatelessWidget {
  final IconData icon;
  final String text;
  final Color? iconColor;
  const _InfoPill({required this.icon, required this.text, this.iconColor});

  @override
  Widget build(BuildContext context) {
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 180),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: AppTheme.primaryColor.withOpacity(0.1),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: AppTheme.primaryColor.withOpacity(0.3),
            width: 1.2,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 18, color: iconColor ?? AppTheme.primaryColor),
            const SizedBox(width: 6),
            Flexible(
              child: Text(
                text,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _GenresChips extends StatelessWidget {
  final List<dynamic> genres;
  const _GenresChips({required this.genres});

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.0, end: 1.0),
      duration: const Duration(milliseconds: 1000),
      curve: Curves.easeOut,
      builder: (context, value, _) {
        return Transform.translate(
          offset: Offset(0, 20 * (1 - value)),
          child: Opacity(
            opacity: value,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [
                            AppTheme.primaryColor.withOpacity(0.2),
                            AppTheme.primaryColor.withOpacity(0.1),
                          ],
                        ),
                        borderRadius:
                            BorderRadius.circular(AppTheme.radiusSmall),
                        border: Border.all(
                          color: AppTheme.primaryColor.withOpacity(0.3),
                          width: 1.5,
                        ),
                      ),
                      child: const Icon(
                        Icons.category,
                        color: AppTheme.primaryColor,
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 12),
                    const Text(
                      'Genres',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Wrap(
                  spacing: 10.0,
                  runSpacing: 10.0,
                  children: genres.asMap().entries.map((entry) {
                    int index = entry.key;
                    String genre = entry.value.toString();
                    Color genreColor =
                        Colors.primaries[index % Colors.primaries.length];
                    return _GenreChip(genre: genre, color: genreColor);
                  }).toList(),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _GenreChip extends StatelessWidget {
  final String genre;
  final Color color;
  const _GenreChip({required this.genre, required this.color});

  @override
  Widget build(BuildContext context) {
    return StatefulBuilder(
      builder: (context, setState) {
        bool isHovered = false;
        return MouseRegion(
          cursor: SystemMouseCursors.click,
          onEnter: (_) => setState(() => isHovered = true),
          onExit: (_) => setState(() => isHovered = false),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            transform: Matrix4.identity()..scale(isHovered ? 1.05 : 1.0),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    color.withOpacity(0.3),
                    color.withOpacity(0.1),
                  ],
                ),
                borderRadius: BorderRadius.circular(AppTheme.radiusLarge),
                border: Border.all(
                  color: isHovered
                      ? color.withOpacity(0.6)
                      : color.withOpacity(0.3),
                  width: isHovered ? 2 : 1.5,
                ),
                boxShadow: isHovered
                    ? [
                        BoxShadow(
                          color: color.withOpacity(0.4),
                          blurRadius: 8,
                          spreadRadius: 0,
                        ),
                      ]
                    : [
                        BoxShadow(
                          color: color.withOpacity(0.2),
                          blurRadius: 6,
                          spreadRadius: 0,
                        ),
                      ],
              ),
              child: Text(
                genre,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                  letterSpacing: 0.5,
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

class _AnimatedAlternativeTitlesSection extends StatelessWidget {
  final Map<String, dynamic> comic;
  const _AnimatedAlternativeTitlesSection({required this.comic});

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.0, end: 1.0),
      duration: const Duration(milliseconds: 1200),
      curve: Curves.easeOut,
      builder: (context, value, _) {
        return Transform.translate(
          offset: Offset(0, 20 * (1 - value)),
          child: Opacity(
            opacity: value,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Alternative Titles',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.primaryColor,
                  ),
                ),
                const SizedBox(height: 8),
                Container(
                  decoration: BoxDecoration(
                    gradient: AppTheme.glassGradient,
                    borderRadius: BorderRadius.circular(AppTheme.radiusLarge),
                    border: Border.all(
                      color: Colors.white.withOpacity(0.1),
                      width: 1.2,
                    ),
                    boxShadow: AppTheme.subtleShadow,
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
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 10, vertical: 6),
                                decoration: BoxDecoration(
                                  color: AppTheme.primaryColor.withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(20),
                                  border: Border.all(
                                    color:
                                        AppTheme.primaryColor.withOpacity(0.3),
                                  ),
                                ),
                                child: Text(
                                  title.toString(),
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 12,
                                  ),
                                ),
                              ))
                          .toList(),
                    ),
                  ),
                ),
                const SizedBox(height: 24),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _AnimatedSynopsisSection extends StatelessWidget {
  final Map<String, dynamic> comic;
  const _AnimatedSynopsisSection({required this.comic});

  @override
  Widget build(BuildContext context) {
    String? _cleanSynopsis(String? synopsis) {
      if (synopsis == null) return null;
      return synopsis.replaceAll(RegExp(r'\s+'), ' ').trim();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TweenAnimationBuilder<double>(
          tween: Tween(begin: 0.0, end: 1.0),
          duration: const Duration(milliseconds: 1400),
          curve: Curves.easeOut,
          builder: (context, value, _) {
            return Transform.translate(
              offset: Offset(0, 20 * (1 - value)),
              child: Opacity(
                opacity: value,
                child: const Text(
                  'Synopsis',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.primaryColor,
                  ),
                ),
              ),
            );
          },
        ),
        const SizedBox(height: 8),
        TweenAnimationBuilder<double>(
          tween: Tween(begin: 0.0, end: 1.0),
          duration: const Duration(milliseconds: 1600),
          curve: Curves.easeOut,
          builder: (context, value, _) {
            return Transform.translate(
              offset: Offset(0, 20 * (1 - value)),
              child: Opacity(
                opacity: value,
                child: Container(
                  decoration: BoxDecoration(
                    gradient: AppTheme.glassGradient,
                    borderRadius: BorderRadius.circular(AppTheme.radiusLarge),
                    border: Border.all(
                      color: Colors.white.withOpacity(0.1),
                      width: 1.2,
                    ),
                    boxShadow: AppTheme.subtleShadow,
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Text(
                      _cleanSynopsis(comic['synopsis']) ??
                          'No synopsis available',
                      style: const TextStyle(
                        fontSize: 16,
                        height: 1.5,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
              ),
            );
          },
        ),
      ],
    );
  }
}

class _AnimatedChaptersHeader extends StatelessWidget {
  final Map<String, dynamic> comic;
  const _AnimatedChaptersHeader({required this.comic});

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.0, end: 1.0),
      duration: const Duration(milliseconds: 1800),
      curve: Curves.easeOut,
      builder: (context, value, _) {
        return Transform.translate(
          offset: Offset(0, 20 * (1 - value)),
          child: Opacity(
            opacity: value,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Chapters',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.primaryColor,
                  ),
                ),
                StatefulBuilder(
                  builder: (context, setState) {
                    bool isHovered = false;
                    return MouseRegion(
                      cursor: SystemMouseCursors.click,
                      onEnter: (_) => setState(() => isHovered = true),
                      onExit: (_) => setState(() => isHovered = false),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        transform: Matrix4.identity()
                          ..scale(isHovered ? 1.05 : 1.0),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            color: isHovered
                                ? AppTheme.primaryColor.withOpacity(0.9)
                                : AppTheme.primaryColor,
                            borderRadius: BorderRadius.circular(20),
                            boxShadow: isHovered
                                ? [
                                    BoxShadow(
                                      color: AppTheme.primaryColor
                                          .withOpacity(0.5),
                                      blurRadius: 20,
                                      spreadRadius: 0,
                                      offset: const Offset(0, 8),
                                    ),
                                    BoxShadow(
                                      color: Colors.black.withOpacity(0.4),
                                      blurRadius: 12,
                                      spreadRadius: 0,
                                      offset: const Offset(0, 6),
                                    ),
                                  ]
                                : [
                                    BoxShadow(
                                      color: AppTheme.primaryColor
                                          .withOpacity(0.3),
                                      blurRadius: 16,
                                      spreadRadius: 0,
                                      offset: const Offset(0, 6),
                                    ),
                                    BoxShadow(
                                      color: Colors.black.withOpacity(0.3),
                                      blurRadius: 10,
                                      spreadRadius: 0,
                                      offset: const Offset(0, 4),
                                    ),
                                  ],
                          ),
                          child: Text(
                            '${comic['chapters']?.length ?? 0} chapters',
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _AnimatedSearchField extends StatelessWidget {
  final String searchQuery;
  final Function(String) onChanged;
  const _AnimatedSearchField(
      {required this.searchQuery, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.0, end: 1.0),
      duration: const Duration(milliseconds: 2000),
      curve: Curves.easeOut,
      builder: (context, value, _) {
        return Transform.translate(
          offset: Offset(0, 20 * (1 - value)),
          child: Opacity(
            opacity: value,
            child: Container(
              margin: const EdgeInsets.only(bottom: 16),
              padding: const EdgeInsets.symmetric(horizontal: 12),
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
                  color: AppTheme.primaryColor.withOpacity(0.3),
                  width: 1.2,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.1),
                    blurRadius: 8,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: TextField(
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  hintText: 'Search chapters...',
                  hintStyle: TextStyle(color: Colors.white.withOpacity(0.7)),
                  prefixIcon:
                      const Icon(Icons.search, color: AppTheme.primaryColor),
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(vertical: 12),
                ),
                onChanged: onChanged,
              ),
            ),
          ),
        );
      },
    );
  }
}

class _AnimatedChaptersList extends StatelessWidget {
  final Map<String, dynamic> comic;
  final String searchQuery;
  const _AnimatedChaptersList({required this.comic, required this.searchQuery});

  @override
  Widget build(BuildContext context) {
    final orderedChapters = List<dynamic>.from(comic['chapters'] ?? []);

    List<dynamic> filteredChapters = orderedChapters;
    if (searchQuery.isNotEmpty) {
      filteredChapters = orderedChapters.where((chapter) {
        final chapterTitle = chapter['title']?.toString().toLowerCase() ?? '';
        return chapterTitle.contains(searchQuery.toLowerCase());
      }).toList();
    }

    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.0, end: 1.0),
      duration: const Duration(milliseconds: 2200),
      curve: Curves.easeOut,
      builder: (context, value, _) {
        return Transform.translate(
          offset: Offset(0, 20 * (1 - value)),
          child: Opacity(
            opacity: value,
            child: Container(
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [AppTheme.surfaceColor, AppTheme.cardColor],
                ),
                borderRadius: BorderRadius.circular(AppTheme.radiusLarge),
                boxShadow: AppTheme.mediumShadow,
                border: Border.all(
                  color: Colors.white.withOpacity(0.05),
                  width: 1.2,
                ),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(AppTheme.radiusLarge),
                child: ListView.separated(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: filteredChapters.length,
                  separatorBuilder: (context, _) => Divider(
                    height: 1,
                    indent: 70,
                    color: Colors.white.withOpacity(0.1),
                  ),
                  itemBuilder: (context, index) {
                    final chapter = filteredChapters[index];
                    return _ChapterTile(
                      chapter: chapter,
                      index: index,
                      comicImageUrl: comic['image_url'],
                      totalChapters: orderedChapters.length,
                    );
                  },
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

class _ChapterTile extends StatelessWidget {
  final Map<String, dynamic> chapter;
  final int index;
  final String comicImageUrl;
  final int totalChapters;
  const _ChapterTile({
    required this.chapter,
    required this.index,
    required this.comicImageUrl,
    required this.totalChapters,
  });

  @override
  Widget build(BuildContext context) {
    String chapterNumber = '';
    String chapterNumberDisplay = '';

    if (chapter['title'] != null) {
      chapterNumber = chapter['title'];

      RegExp regExp = RegExp(r'Chapter\s+(\d+(?:\.\d+)?(?:[A-Za-z]+)?)');
      var match = regExp.firstMatch(chapter['title']);
      if (match != null && match.groupCount >= 1) {
        chapterNumberDisplay = match.group(1) ?? '';
      } else {
        chapterNumberDisplay = '${index + 1}';
      }
    } else {
      chapterNumber = 'Chapter ${totalChapters - index}';
      chapterNumberDisplay = '${totalChapters - index}';
    }

    return StatefulBuilder(
      builder: (context, setState) {
        bool isHovered = false;
        return MouseRegion(
          cursor: SystemMouseCursors.click,
          onEnter: (_) => setState(() => isHovered = true),
          onExit: (_) => setState(() => isHovered = false),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            transform: Matrix4.identity()..scale(isHovered ? 1.02 : 1.0),
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: () {
                  // Navigate to manga reader
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => MangaReaderScreen(
                        url: chapter['url'],
                        comicImageUrl: comicImageUrl,
                        title: chapterNumber,
                        chapterId: chapterNumberDisplay,
                      ),
                    ),
                  );
                },
                splashColor: AppTheme.primaryColor.withOpacity(0.1),
                highlightColor: AppTheme.primaryColor.withOpacity(0.05),
                child: Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: Row(
                    children: [
                      Container(
                        width: 56,
                        height: 56,
                        decoration: BoxDecoration(
                          gradient: isHovered
                              ? LinearGradient(
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                  colors: [
                                    AppTheme.primaryColor.withOpacity(0.95),
                                    AppTheme.primaryColor.withOpacity(0.75),
                                    AppTheme.accentColor.withOpacity(0.65),
                                  ],
                                )
                              : AppTheme.primaryGradient,
                          borderRadius:
                              BorderRadius.circular(AppTheme.radiusMedium),
                          boxShadow: isHovered
                              ? [
                                  BoxShadow(
                                    color:
                                        AppTheme.primaryColor.withOpacity(0.5),
                                    blurRadius: 20,
                                    spreadRadius: 0,
                                    offset: const Offset(0, 8),
                                  ),
                                  BoxShadow(
                                    color: Colors.black.withOpacity(0.4),
                                    blurRadius: 12,
                                    spreadRadius: 0,
                                    offset: const Offset(0, 6),
                                  ),
                                ]
                              : [
                                  BoxShadow(
                                    color:
                                        AppTheme.primaryColor.withOpacity(0.3),
                                    blurRadius: 16,
                                    spreadRadius: 0,
                                    offset: const Offset(0, 6),
                                  ),
                                  BoxShadow(
                                    color: Colors.black.withOpacity(0.3),
                                    blurRadius: 10,
                                    spreadRadius: 0,
                                    offset: const Offset(0, 4),
                                  ),
                                ],
                        ),
                        child: const Center(
                          child: Icon(
                            Icons.menu_book,
                            color: Colors.white,
                            size: 28,
                          ),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Row(
                              children: [
                                const Text(
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
                                    color: isHovered
                                        ? AppTheme.primaryColor.withOpacity(0.9)
                                        : AppTheme.textPrimaryColor,
                                  ),
                                ),
                                if (chapterNumber.contains('-') ||
                                    (chapterNumber
                                            .toLowerCase()
                                            .contains('chapter') &&
                                        chapterNumber.length >
                                            ('Chapter ' + chapterNumberDisplay)
                                                .length))
                                  Expanded(
                                    child: Text(
                                      ' ' +
                                          chapterNumber.replaceAll(
                                              RegExp(
                                                  r'Chapter\s+\d+(?:\.\d+)?(?:[A-Za-z]+)?\s*-?\s*'),
                                              ''),
                                      style: TextStyle(
                                        fontWeight: FontWeight.normal,
                                        color: isHovered
                                            ? AppTheme.primaryColor
                                                .withOpacity(0.9)
                                            : AppTheme.primaryColor,
                                        fontSize: 14,
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      Container(
                        width: 56,
                        height: 56,
                        decoration: BoxDecoration(
                          gradient: RadialGradient(
                            colors: [
                              AppTheme.primaryColor.withOpacity(0.2),
                              AppTheme.primaryColor.withOpacity(0.1),
                            ],
                          ),
                          borderRadius:
                              BorderRadius.circular(AppTheme.radiusSmall),
                          border: Border.all(
                            color: AppTheme.primaryColor.withOpacity(0.3),
                            width: 1.5,
                          ),
                        ),
                        child: const Center(
                          child: Icon(
                            Icons.arrow_forward_ios,
                            color: AppTheme.primaryColor,
                            size: 24,
                          ),
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
}
