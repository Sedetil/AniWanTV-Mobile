import 'package:flutter_svg/flutter_svg.dart';
import 'package:url_launcher/url_launcher.dart';

import 'package:flutter/material.dart';
import 'dart:convert';
import 'dart:math';
import 'package:provider/provider.dart';
import '../services/api_service.dart';
import '../theme/app_theme.dart';
import '../providers/app_state_provider.dart';
import 'video_player_screen.dart';
import '../services/ad_service.dart';
import '../utils/toast_utils.dart';
import '../widgets/custom_loading_widget.dart';

class AnimeDetailsScreen extends StatefulWidget {
  final String url;
  const AnimeDetailsScreen({super.key, required this.url});

  @override
  State<AnimeDetailsScreen> createState() => _AnimeDetailsScreenState();
}

class _AnimeDetailsScreenState extends State<AnimeDetailsScreen> {
  late Future<dynamic> _animeDetailsFuture;
  bool _isEpisodeSearching = false;
  final TextEditingController _episodeSearchController = TextEditingController();
  String _episodeSearchQuery = '';

  @override
  void initState() {
    super.initState();
    _animeDetailsFuture = ApiService.fetchAnimeDetails(widget.url);
  }

  @override
  void dispose() {
    _episodeSearchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black, // Pure black background like reference
      body: FutureBuilder(
        future: _animeDetailsFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CustomLoadingWidget(message: "Loading anime details...", size: 100));
          } else if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}', style: TextStyle(color: Colors.white)));
          } else if (!snapshot.hasData) {
            return const Center(child: Text('No data found', style: TextStyle(color: Colors.white)));
          }

          final anime = snapshot.data!;
          return SafeArea(
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildHeader(context, anime),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildInfo(context, anime),
                        const SizedBox(height: 16),
                        _buildActionButtons(context, anime),
                        const SizedBox(height: 24),
                        _buildEpisodesList(context, anime),
                        const SizedBox(height: 32),
                      ],
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

  Widget _buildHeader(BuildContext context, Map<String, dynamic> anime) {
    return Stack(
      children: [
        AspectRatio(
          aspectRatio: 16 / 9,
          child: Image.network(
            anime['image_url'] ?? '',
            fit: BoxFit.cover,
            errorBuilder: (_, __, ___) => Container(color: Colors.grey[900]),
          ),
        ),
        // Gradient overlay
        Positioned.fill(
          child: Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Colors.black.withOpacity(0.4),
                  Colors.transparent,
                  Colors.black.withOpacity(0.6),
                  Colors.black, // Blend into body
                ],
                stops: const [0.0, 0.3, 0.8, 1.0],
              ),
            ),
          ),
        ),
        // Back Button
        Positioned(
          top: 16,
          left: 16,
          child: GestureDetector(
            onTap: () => Navigator.pop(context),
            child: Icon(Icons.arrow_back, color: Colors.white, size: 28),
          ),
        ),
        // Center Play Icon (Decoration)
        Positioned.fill(
          child: Center(
            child: SvgPicture.asset(
              'assets/icons/play.svg',
              width: 48,
              height: 48,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildInfo(BuildContext context, Map<String, dynamic> anime) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          anime['title'] ?? 'No Title',
          style: const TextStyle(
            color: Colors.white,
             fontSize: 24,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Text(
              anime['release_date']?.toString().split(',').last.trim() ?? '2022', // Rough year extraction
              style: TextStyle(color: Colors.grey[400], fontSize: 13),
            ),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
              decoration: BoxDecoration(
                color: Colors.grey[800],
                borderRadius: BorderRadius.circular(4),
              ),
              child: const Text(
                '16+', // Hardcoded rating
                style: TextStyle(color: Colors.white, fontSize: 11),
              ),
            ),
            const SizedBox(width: 8),
             Text(
              '${anime['total_episodes'] ?? '?'} Episodes',
              style: TextStyle(color: Colors.grey[400], fontSize: 13),
            ),
             const SizedBox(width: 8),
             Icon(Icons.star, size: 14, color: Colors.amber),
             const SizedBox(width: 4),
             Text(
               anime['rating']?.toString() ?? 'N/A',
               style: TextStyle(color: Colors.grey[400], fontSize: 13),
             ),
          ],
        ),
        const SizedBox(height: 12),
        // Genres as text or simple list? Reference image uses text description.
        // Let's use the synopsis as the main text block.
        _ExpandableDetails(anime: anime),
      ],
    );
  }

  Widget _buildActionButtons(BuildContext context, Map<String, dynamic> anime) {
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: ElevatedButton.icon(
                onPressed: () {
                   // Play first episode or resume
                   if (anime['episodes'] != null && (anime['episodes'] as List).isNotEmpty) {
                      _showStreamBottomSheet(context, anime['episodes'][0], anime);
                   }
                },
                label: Text('Play', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF393053),
                  foregroundColor: Colors.white,
                  side: const BorderSide(color: Color(0xFF6F4FA4)),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: ElevatedButton.icon(
                onPressed: () {
                   if (anime['episodes'] != null && (anime['episodes'] as List).isNotEmpty) {
                      _showDownloadBottomSheet(context, anime['episodes'][0]);
                   } else {
                      ToastUtils.show('No episodes available to download', backgroundColor: Colors.orange);
                   }
                },
                icon: Icon(Icons.download, color: Colors.white),
                label: Text('Download', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.grey[800],
                   padding: EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [

             _FavoriteIconAction(anime: anime, url: widget.url),
             _buildIconAction(Icons.thumb_up_alt_outlined, 'Like', () {
               ToastUtils.show('Like functionality coming soon', backgroundColor: AppTheme.primaryColor);
             }),
             _buildIconAction(Icons.share, 'Share', () {
               ToastUtils.show('Share functionality coming soon', backgroundColor: AppTheme.primaryColor);
             }),
             _buildIconAction(Icons.people, 'Watch Party', () {
               ToastUtils.show('Watch Party coming soon', backgroundColor: AppTheme.primaryColor);
             }),
          ],
        ),
      ],
    );
  }
  
  Widget _buildIconAction(IconData icon, String label, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        children: [
          Icon(icon, color: Colors.white, size: 24),
          const SizedBox(height: 4),
          Text(label, style: TextStyle(color: Colors.grey[400], fontSize: 10)),
        ],
      ),
    );
  }

  Widget _buildEpisodesList(BuildContext context, Map<String, dynamic> anime) {
    final episodes = anime['episodes'] as List<dynamic>? ?? [];
    
    // Filter episodes
    final filteredEpisodes = episodes.where((ep) {
      if (_episodeSearchQuery.isEmpty) return true;
      final title = ep['title']?.toString().toLowerCase() ?? '';
      final query = _episodeSearchQuery.toLowerCase();
      // Check title or episode number/index
      final index = episodes.indexOf(ep);
      final epNum = '${index + 1}'; 
      return title.contains(query) || epNum.contains(query);
    }).toList();

    return Column(
      children: [
        if (_isEpisodeSearching)
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _episodeSearchController,
                  autofocus: true,
                  style: TextStyle(color: Colors.white, fontSize: 13),
                  decoration: InputDecoration(
                    hintText: 'Search episode...',
                    hintStyle: TextStyle(color: Colors.grey[600]),
                    isDense: true,
                    contentPadding: EdgeInsets.symmetric(vertical: 8, horizontal: 8),
                    filled: true,
                    fillColor: Colors.grey[900],
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(4), borderSide: BorderSide.none),
                  ),
                  onChanged: (value) {
                    setState(() {
                      _episodeSearchQuery = value;
                    });
                  },
                ),
              ),
              const SizedBox(width: 8),
              GestureDetector(
                onTap: () {
                  setState(() {
                    _isEpisodeSearching = false;
                    _episodeSearchQuery = '';
                    _episodeSearchController.clear();
                  });
                },
                child: Text('Cancel', style: TextStyle(color: AppTheme.primaryColor)),
              ),
            ],
          )
        else
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
               Row(
                 children: [
                    Text(
                      'Episodes',
                      style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(width: 12),
                    GestureDetector(
                      onTap: () {
                        setState(() {
                          _isEpisodeSearching = true;
                        });
                      },
                      child: Icon(Icons.search, color: Colors.grey[400], size: 20),
                    ),
                 ],
               ),
              // Dummy dropdown for season
              InkWell(
                borderRadius: BorderRadius.circular(4),
                onTap: () {
                  // TODO: buka selector episode
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: const Color(0xFF393053), // fill
                    borderRadius: BorderRadius.circular(4),
                    border: Border.all(
                      color: const Color(0xFF6F4FA4), // stroke
                      width: 1,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: const [
                      Text(
                        '1–100',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      SizedBox(width: 2),
                      Icon(
                        Icons.keyboard_arrow_down,
                        color: Colors.white,
                        size: 16,
                      ),
                    ],
                  ),
                ),
              )
            ],
          ),
        const SizedBox(height: 16),
        if (filteredEpisodes.isEmpty)
           Padding(
             padding: const EdgeInsets.all(16.0),
             child: Text('No episodes found', style: TextStyle(color: Colors.grey[500])),
           )
        else
        ListView.separated(
          shrinkWrap: true,
          physics: NeverScrollableScrollPhysics(),
          itemCount: filteredEpisodes.length,
          separatorBuilder: (_, __) => const SizedBox(height: 16),
          itemBuilder: (context, index) {
            final episode = filteredEpisodes[index];
            // Must find original index for display
            final originalIndex = episodes.indexOf(episode);
            
            return GestureDetector(
              onTap: () => _showStreamBottomSheet(context, episode, anime),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Thumbnail (using anime image as fallback since ep image might not exist)
                  ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: Image.network(
                      anime['image_url'] ?? '', // Ideally episode['image'] if available
                      width: 120,
                      height: 68,
                      fit: BoxFit.cover,
                      errorBuilder: (_,__,___) => Container(width: 120, height: 68, color: Colors.grey[800]),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          episode['title'] ?? 'Episode',
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 13,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          episode['duration'] ?? anime['duration'] ?? '?',
                          style: TextStyle(color: Colors.grey[500], fontSize: 11),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          anime['synopsis'] ?? '', // Placeholder snippet
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(color: Colors.grey[500], fontSize: 10),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton(
                    icon: Icon(Icons.download_for_offline_outlined, color: Colors.grey[400], size: 24),
                    onPressed: () => _showDownloadBottomSheet(context, episode),
                  ),
                ],
              ),
            );
          },
        ),
      ],
    );
  }

  Future<void> _showStreamBottomSheet(BuildContext context, Map<String, dynamic> episode, Map<String, dynamic> anime) async {
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
      
      final streams = await ApiService.fetchEpisodeStreams(episode['url']);
      if (context.mounted) Navigator.pop(context); // Close loading

      if (streams == null) {
        ToastUtils.show('No streams found', backgroundColor: Colors.orange);
        return;
      }

      final List<dynamic> directStreams = streams['direct_stream_urls'] ?? [];
      final String streamUrl = streams['stream_url'] ?? '';

      if (context.mounted) {
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
                             onTap: () => _playVideo(context, streamUrl, 'Auto', streams, anime),
                           ),
                         
                         // Direct Streams
                         ...directStreams.map((stream) {
                            final quality = stream['quality'] ?? 'Unknown';
                            return ListTile(
                              leading: const Icon(Icons.hd, color: AppTheme.primaryColor),
                              title: Text(quality, style: const TextStyle(color: Colors.white)),
                              onTap: () => _playVideo(context, stream['url'], quality, streams, anime),
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
      if (context.mounted) Navigator.pop(context); // Close loading
      ToastUtils.show('Error loading streams: $e', backgroundColor: Colors.red);
    }
  }

  void _playVideo(BuildContext context, String url, String quality, Map<String, dynamic> episodeData, Map<String, dynamic> anime) {
     Navigator.pop(context); // Close bottom sheet
     
     // Add to History
     try {
       final historyItem = {
          'title': anime['title'] ?? 'No Title',
          'image_url': anime['image_url'] ?? '',
          'url': widget.url,
          'episode_url': episodeData['url'], // Specific episode URL for direct playback
          'episode': episodeData['title'] ?? 'Episode',
          'rating': anime['rating'],
          // For search screen compatibility
          'chapter': episodeData['title'] ?? 'Unknown', 
          'date': DateTime.now().toString(),
       };
       Provider.of<AppStateProvider>(context, listen: false).addToHistory(historyItem, true);
     } catch (e) {
       print('Error adding to history: $e');
     }
     
     AdService.showRewardedAd(context, onReward: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => VideoPlayerScreen(
              url: url,
              title: episodeData['title'] ?? 'Episode',
              episodeId: episodeData['id'] ?? DateTime.now().millisecondsSinceEpoch.toString(),
              directStreamUrls: (episodeData['direct_stream_urls'] as List?)
                  ?.map((e) => Map<String, String>.from(e))
                  .toList() ?? [],
            ),
          ),
        );
     }, setLandscapeOrientation: true); 
  }

  Future<void> _showDownloadBottomSheet(BuildContext context, Map<String, dynamic> episode) async {
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
          child: CustomLoadingWidget(message: "Loading links...", size: 80),
        ),
      ),
    );

    try {
      final streams = await ApiService.fetchEpisodeStreams(episode['url']);
      Navigator.pop(context); // Close loading

      if (streams == null || streams['download_links'] == null) {
        ToastUtils.show('No download links found', backgroundColor: Colors.orange);
        return;
      }

      final downloadLinks = streams['download_links'] as Map<String, dynamic>;

      if (downloadLinks.isEmpty) {
        ToastUtils.show('No download links found', backgroundColor: Colors.orange);
        return;
      }

      if (context.mounted) {
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
                     'Download Links',
                     style: TextStyle(
                       color: Colors.white,
                       fontSize: 18,
                       fontWeight: FontWeight.bold,
                     ),
                   ),
                   const SizedBox(height: 16),
                   Flexible(
                     child: ListView.builder(
                       shrinkWrap: true,
                       itemCount: downloadLinks.length,
                       itemBuilder: (context, index) {
                         final quality = downloadLinks.keys.elementAt(index);
                         final links = downloadLinks[quality] as List<dynamic>? ?? [];
                         
                         return Theme(
                           data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
                           child: ExpansionTile(
                             collapsedIconColor: Colors.white,
                             iconColor: AppTheme.primaryColor,
                             title: Text(
                               'Quality: $quality',
                               style: const TextStyle(color: Colors.white),
                             ),
                             children: links.map<Widget>((link) {
                               return ListTile(
                                 leading: const Icon(Icons.download, color: AppTheme.primaryColor),
                                 title: Text(
                                   link['host'] ?? 'Unknown Host',
                                   style: TextStyle(color: Colors.grey[300]),
                                 ),
                                 onTap: () => _launchUrl(link['url'] ?? ''),
                               );
                             }).toList(),
                           ),
                         );
                       },
                     ),
                   ),
                ],
              ),
            );
          },
        );
      }
    } catch (e) {
      if (context.mounted) Navigator.pop(context); // Close loading
      ToastUtils.show('Error loading links: $e', backgroundColor: Colors.red);
    }
  }

  Future<void> _launchUrl(String url) async {
    try {
      if (await canLaunchUrl(Uri.parse(url))) {
        await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
      } else {
        ToastUtils.show('Could not launch url', backgroundColor: Colors.red);
      }
    } catch (e) {
      ToastUtils.show('Error launching url: $e', backgroundColor: Colors.red);
    }
  }
}

class _FavoriteIconAction extends StatefulWidget {
  final Map<String, dynamic> anime;
  final String url;
  const _FavoriteIconAction({required this.anime, required this.url});

  @override
  State<_FavoriteIconAction> createState() => _FavoriteIconActionState();
}

class _FavoriteIconActionState extends State<_FavoriteIconAction> {
  @override
  Widget build(BuildContext context) {
    final appStateProvider = Provider.of<AppStateProvider>(context);
    final isFavorited = appStateProvider.favoriteAnime.any((item) => item['url'] == widget.url);
    
    return GestureDetector(
      onTap: () async {
         try {
            // Logic duplicated from original _FavoriteButton but simplified
            final provider = Provider.of<AppStateProvider>(context, listen: false);
            // ... (Simple toggle logic)
            if (isFavorited) {
               // Must find ID
               final item = provider.favoriteAnime.firstWhere((x) => x['url'] == widget.url);
               await provider.removeFromFavorites(item['id'], true);
               ToastUtils.show('Removed from My List', backgroundColor: Colors.red);
            } else {
               await provider.addToFavorites({
                  'title': widget.anime['title'] ?? 'No Title',
                  'image_url': widget.anime['image_url'] ?? '',
                  'url': widget.url,
                  'rating': widget.anime['rating'],
               }, true);
               ToastUtils.show('Added to My List', backgroundColor: Colors.green);
            }
            setState((){});
         } catch (e) {
            ToastUtils.show('Error: $e', backgroundColor: Colors.red);
         }
      },
      child: Column(
        children: [
          Icon(isFavorited ? Icons.check : Icons.add, color: Colors.white, size: 24), // "My List" icon usually acts like a check when added
          const SizedBox(height: 4),
          Text('My List', style: TextStyle(color: Colors.grey[400], fontSize: 10)),
        ],
      ),
    );
  }
}

class _ExpandableDetails extends StatefulWidget {
  final Map<String, dynamic> anime;
  const _ExpandableDetails({required this.anime});

  @override
  State<_ExpandableDetails> createState() => _ExpandableDetailsState();
}

class _ExpandableDetailsState extends State<_ExpandableDetails> {
  bool _isExpanded = false;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        AnimatedCrossFade(
          firstChild: Text(
            widget.anime['synopsis'] ?? '',
            maxLines: 4,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(color: Colors.grey[300], fontSize: 13, height: 1.4),
          ),
          secondChild: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                widget.anime['synopsis'] ?? '',
                style: TextStyle(color: Colors.grey[300], fontSize: 13, height: 1.4),
              ),
              const SizedBox(height: 16),
              _buildDetailGrid(),
            ],
          ),
          crossFadeState: _isExpanded ? CrossFadeState.showSecond : CrossFadeState.showFirst,
          duration: const Duration(milliseconds: 300),
        ),
        const SizedBox(height: 8),
        GestureDetector(
          onTap: () {
            setState(() {
              _isExpanded = !_isExpanded;
            });
          },
          child: Row(
            children: [
              Text(
                _isExpanded ? 'Show Less' : 'Show More',
                style: const TextStyle(
                  color: Colors.grey,
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                ),
              ),
              const SizedBox(width: 4),
              Icon(
                _isExpanded ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down,
                color: Colors.grey,
                size: 16,
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildDetailGrid() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (widget.anime['genres'] != null) ...[
          const Text('Genres:', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13)),
          const SizedBox(height: 4),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: (widget.anime['genres'] as List).map((genre) {
               return Container(
                 padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                 decoration: BoxDecoration(
                   color: Colors.grey[800],
                   borderRadius: BorderRadius.circular(12),
                 ),
                 child: Text(
                   genre.toString(),
                   style: const TextStyle(color: Colors.white, fontSize: 11),
                 ),
               );
            }).toList(),
          ),
          const SizedBox(height: 12),
        ],
        _buildInfoRow('Studio', widget.anime['studio']),
        _buildInfoRow('Producer', widget.anime['producer']),
        _buildInfoRow('Status', widget.anime['status']),
        _buildInfoRow('Type', widget.anime['type']),
        _buildInfoRow('Duration', widget.anime['duration']),
        _buildInfoRow('Japanese', widget.anime['japanese']),
      ],
    );
  }

  Widget _buildInfoRow(String label, dynamic value) {
    if (value == null || value.toString().isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(bottom: 4.0),
      child: RichText(
        text: TextSpan(
          style: const TextStyle(fontSize: 12, height: 1.4),
          children: [
            TextSpan(text: '$label: ', style: TextStyle(color: Colors.grey[400], fontWeight: FontWeight.bold)),
            TextSpan(text: value.toString(), style: const TextStyle(color: Colors.white)),
          ],
        ),
      ),
    );
  }
}
