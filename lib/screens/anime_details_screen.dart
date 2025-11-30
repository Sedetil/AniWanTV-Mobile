import 'package:flutter/material.dart';
import 'dart:convert';
import 'dart:math';
import 'package:provider/provider.dart';
import '../services/api_service.dart';
import '../theme/app_theme.dart';
import '../providers/app_state_provider.dart';
import 'episode_streams_screen.dart';
import 'package:fluttertoast/fluttertoast.dart';

class AnimeDetailsScreen extends StatefulWidget {
  final String url;
  const AnimeDetailsScreen({super.key, required this.url});

  @override
  State<AnimeDetailsScreen> createState() => _AnimeDetailsScreenState();
}

class _AnimeDetailsScreenState extends State<AnimeDetailsScreen> {
  late Future<dynamic> _animeDetailsFuture;

  @override
  void initState() {
    super.initState();
    _animeDetailsFuture = ApiService.fetchAnimeDetails(widget.url);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      body: FutureBuilder(
        future: _animeDetailsFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
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
          } else if (snapshot.hasError) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const _AnimatedErrorIcon(),
                  const SizedBox(height: 24),
                  _AnimatedErrorText(error: snapshot.error.toString()),
                  const SizedBox(height: 24),
                  _GoBackButton(),
                ],
              ),
            );
          } else if (!snapshot.hasData) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const _AnimatedNoDataIcon(),
                  const SizedBox(height: 24),
                  const _AnimatedNoDataText(),
                  const SizedBox(height: 24),
                  _GoBackButton(),
                ],
              ),
            );
          }

          final anime = snapshot.data!;
          return CustomScrollView(
            slivers: [
              _AnimeSliverAppBar(anime: anime, url: widget.url),
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _AnimatedInfoCard(anime: anime),
                      const SizedBox(height: 24),
                      _AnimatedSynopsisSection(anime: anime),
                      const SizedBox(height: 24),
                      _AnimatedEpisodesHeader(anime: anime),
                      const SizedBox(height: 16),
                      _AnimatedEpisodesList(anime: anime),
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
              Icons.play_circle_fill,
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
              'No data found for this anime',
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

class _AnimeSliverAppBar extends StatelessWidget {
  final Map<String, dynamic> anime;
  final String url;
  const _AnimeSliverAppBar({required this.anime, required this.url});

  @override
  Widget build(BuildContext context) {
    return SliverAppBar(
      expandedHeight: 300.0,
      floating: false,
      pinned: true,
      backgroundColor: AppTheme.backgroundColor,
      actions: [_ShareButton(), _FavoriteButton(anime: anime, url: url)],
      flexibleSpace: FlexibleSpaceBar(
        titlePadding:
            const EdgeInsets.only(left: 60.0, bottom: 16.0, right: 120.0),
        title: _AnimatedAppBarTitle(title: anime['title']),
        background: Stack(
          fit: StackFit.expand,
          children: [
            Image.network(
              anime['image_url'] ?? '',
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
  final Map<String, dynamic> anime;
  final String url;
  const _FavoriteButton({required this.anime, required this.url});

  @override
  Widget build(BuildContext context) {
    return StatefulBuilder(
      builder: (context, setState) {
        bool isHovered = false;
        final appStateProvider = Provider.of<AppStateProvider>(context);
        final isFavorited =
            appStateProvider.favoriteAnime.any((item) => item['url'] == url);
        return MouseRegion(
          cursor: SystemMouseCursors.click,
          onEnter: (_) => setState(() => isHovered = true),
          onExit: (_) => setState(() => isHovered = false),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            transform: Matrix4.identity()..scale(isHovered ? 1.1 : 1.0),
            child: IconButton(
              icon: Icon(isFavorited ? Icons.favorite : Icons.favorite_border,
                  color: isFavorited ? Colors.red : null),
              onPressed: () async {
                try {
                  final appStateProvider =
                      Provider.of<AppStateProvider>(context, listen: false);
                  await appStateProvider.initialize();
                  final existing = appStateProvider.favoriteAnime
                      .where((item) => item['url'] == url)
                      .toList();
                  if (existing.isNotEmpty) {
                    final id = existing.first['id']?.toString() ?? '';
                    if (id.isNotEmpty) {
                      await appStateProvider.removeFromFavorites(id, true);
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
                    'title': anime['title'] ?? 'No Title',
                    'image_url': anime['image_url'] ?? '',
                    'url': url,
                    'description': anime['synopsis'] != null
                        ? '${anime['synopsis'].substring(0, min<int>(100, anime['synopsis'].length))}...'
                        : 'No description available',
                    'rating': anime['rating'],
                  }, true);

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
  final Map<String, dynamic> anime;
  const _AnimatedInfoCard({required this.anime});

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
                        final releaseDate =
                            anime['release_date']?.toString() ?? '';
                        final ratingRaw = anime['rating']?.toString() ?? '';
                        final ratingTrim = ratingRaw.trim();
                        final ratingText = (ratingTrim.isNotEmpty &&
                                RegExp(r'^\d+(\.\d+)?(\/\d+)?$')
                                    .hasMatch(ratingTrim))
                            ? ratingTrim
                            : 'Belum Ada';
                        final releaseDateText =
                            releaseDate.trim().isNotEmpty ? releaseDate : 'N/A';
                        return Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            _InfoPill(
                              icon: Icons.star,
                              text: ratingText,
                              iconColor: Colors.amber,
                            ),
                            _InfoPill(
                              icon: Icons.calendar_today,
                              text: releaseDateText,
                            ),
                            if (anime['type'] != null)
                              _InfoPill(
                                icon: Icons.tv,
                                text: anime['type'].toString(),
                              ),
                            if (anime['japanese'] != null &&
                                anime['japanese'].toString().isNotEmpty)
                              _InfoPill(
                                icon: Icons.translate,
                                text: 'Japan',
                              ),
                            if (anime['status'] != null)
                              _InfoPill(
                                icon: Icons.info_outline,
                                text: anime['status'].toString(),
                              ),
                            if (anime['total_episodes'] != null)
                              _InfoPill(
                                icon: Icons.format_list_numbered,
                                text: anime['total_episodes'].toString(),
                              ),
                            if (anime['duration'] != null)
                              _InfoPill(
                                icon: Icons.timer,
                                text: anime['duration'].toString(),
                              ),
                            if (anime['studio'] != null)
                              _InfoPill(
                                icon: Icons.apartment,
                                text: anime['studio'].toString(),
                              ),
                            if (anime['producer'] != null &&
                                anime['producer'].toString().isNotEmpty)
                              _InfoPill(
                                icon: Icons.group,
                                text: anime['producer'].toString(),
                              ),
                          ],
                        );
                      },
                    ),
                    const SizedBox(height: 20),
                    _GenresChips(genres: anime['genres'] ?? []),
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

class _AnimatedSynopsisSection extends StatelessWidget {
  final Map<String, dynamic> anime;
  const _AnimatedSynopsisSection({required this.anime});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TweenAnimationBuilder<double>(
          tween: Tween(begin: 0.0, end: 1.0),
          duration: const Duration(milliseconds: 1200),
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
          duration: const Duration(milliseconds: 1400),
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
                      anime['synopsis'] ?? 'No synopsis available',
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

class _AnimatedEpisodesHeader extends StatelessWidget {
  final Map<String, dynamic> anime;
  const _AnimatedEpisodesHeader({required this.anime});

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.0, end: 1.0),
      duration: const Duration(milliseconds: 1600),
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
                  'Episodes',
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
                            '${anime['episodes']?.length ?? 0} episodes',
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

class _AnimatedEpisodesList extends StatelessWidget {
  final Map<String, dynamic> anime;
  const _AnimatedEpisodesList({required this.anime});

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
                  itemCount: anime['episodes']?.length ?? 0,
                  separatorBuilder: (context, _) => Divider(
                    height: 1,
                    indent: 70,
                    color: Colors.white.withOpacity(0.1),
                  ),
                  itemBuilder: (context, index) {
                    final episode = anime['episodes'][index];
                    return _EpisodeTile(
                      episode: episode,
                      index: index,
                      animeImageUrl: anime['image_url'],
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

class _EpisodeTile extends StatelessWidget {
  final Map<String, dynamic> episode;
  final int index;
  final String animeImageUrl;
  const _EpisodeTile({
    required this.episode,
    required this.index,
    required this.animeImageUrl,
  });

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
            transform: Matrix4.identity()..scale(isHovered ? 1.02 : 1.0),
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => EpisodeStreamsScreen(
                        url: episode['url'],
                        animeImageUrl: animeImageUrl,
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
                            Icons.play_arrow,
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
                            Text(
                              episode['title'] ?? 'Episode ${index + 1}',
                              style: Theme.of(context)
                                  .textTheme
                                  .titleMedium
                                  ?.copyWith(
                                    fontWeight: FontWeight.bold,
                                    color: isHovered
                                        ? AppTheme.primaryColor.withOpacity(0.9)
                                        : Colors.white,
                                    letterSpacing: 0.25,
                                  ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
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
                            Icons.play_circle_fill,
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

class _InfoPill extends StatelessWidget {
  final IconData icon;
  final String text;
  final Color? iconColor;
  const _InfoPill({required this.icon, required this.text, this.iconColor});

  @override
  Widget build(BuildContext context) {
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 160),
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
