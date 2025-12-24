import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:photo_view/photo_view.dart';
import 'package:photo_view/photo_view_gallery.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../theme/app_theme.dart';
import '../widgets/custom_error_dialog.dart';
import '../providers/app_state_provider.dart';
import 'dart:convert';
import '../services/api_service.dart';

import '../utils/toast_utils.dart';
import '../widgets/custom_loading_widget.dart';


class MangaReaderScreen extends StatefulWidget {
  final String? url;
  final List<String>? pages;
  final String? title;
  final String? chapterId;
  final String? nextChapterUrl;
  final String? prevChapterUrl;
  final String? chapterListUrl;
  final String? comicImageUrl;

  MangaReaderScreen({
    this.url,
    this.pages,
    this.title,
    this.chapterId,
    this.nextChapterUrl,
    this.prevChapterUrl,
    this.chapterListUrl,
    this.comicImageUrl,
  });

  @override
  _MangaReaderScreenState createState() => _MangaReaderScreenState();
}

class _MangaReaderScreenState extends State<MangaReaderScreen> with SingleTickerProviderStateMixin {
  late PageController _pageController;
  bool _isDarkMode = true;
  bool _isMenuVisible = true;
  int _currentPage = 0;
  bool _isImageLoading = false;
  bool _hasImageError = false;
  double _screenWidth = 0;
  double _screenHeight = 0;
  List<String> _pages = [];
  String _chapterTitle = '';
  String _chapterId = '';
  bool _loading = false;
  String? _error;
  bool _isPreloading = false;
  int _preloadedCount = 0;

  // Navigasi chapter
  String? _nextChapterUrl;
  String? _prevChapterUrl;
  String? _chapterListUrl;

  // Scroll Controller for tap navigation
  late ScrollController _scrollController;

  // Global Zoom State
  late TransformationController _transformationController;
  late AnimationController _animationController;
  Animation<Matrix4>? _animation;
  TapDownDetails? _doubleTapDetails;
  bool _canPan = false;


  @override
  void initState() {
    super.initState();
    // Set portrait orientation for manga reading
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
    ]);
    // Hide status bar for immersive reading experience
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersive);
    
    _scrollController = ScrollController(); // Init scroll controller
    
    _transformationController = TransformationController();
    _animationController = AnimationController(
       vsync: this,
       duration: const Duration(milliseconds: 200),
    )..addListener(() {
       _transformationController.value = _animation!.value;
       _updatePanState();
    });
    _loadPreferences();
    // Inisialisasi URL navigasi
    _nextChapterUrl = widget.nextChapterUrl;
    _prevChapterUrl = widget.prevChapterUrl;
    _chapterListUrl = widget.chapterListUrl;

    if (widget.url != null) {
      _fetchChapterImages(widget.url!);
    } else {
      _pages = widget.pages ?? [];
      _chapterTitle = widget.title ?? '';
      _chapterId = widget.chapterId ?? '';
      _loadLastPage();
      // Preload semua gambar setelah halaman diinisialisasi
      _preloadImages();
      // Save to history for direct navigation
      if (widget.title != null && widget.chapterId != null) {
        _saveToHistoryDirect();
      }
    }
  }

  Future<void> _fetchChapterImages(String url) async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final chapter = await ApiService.fetchChapterImages(url);
      final List<String> pages = List<String>.from(
        (chapter['images'] as List).map((img) => (img['url'] as String).trim()),
      );
      final String title = chapter['title'] ?? 'Chapter';
      final String chapterId = widget.chapterId ?? chapter['chapter_number']?.toString() ?? url;

      // Ambil data navigasi jika tersedia
      if (chapter.containsKey('navigation')) {
        _nextChapterUrl =
            chapter['navigation']['next_chapter']?.toString()?.trim();
        _prevChapterUrl =
            chapter['navigation']['prev_chapter']?.toString()?.trim();
        _chapterListUrl =
            chapter['navigation']['chapter_list']?.toString()?.trim();
      }

      setState(() {
        _pages = pages;
        _chapterTitle = title;
        _chapterId = chapterId;
        _loading = false;
      });
      _saveToHistory(chapter, url);
      _loadLastPage();
      // Preload semua gambar setelah data diambil
      _preloadImages();
    } catch (e) {
      setState(() {
        _loading = false;
        _error = e.toString();
      });
    }
  }

  Future<void> _saveToHistory(Map<String, dynamic> chapter, String url) async {
    try {
      final appStateProvider = Provider.of<AppStateProvider>(context, listen: false);
      await appStateProvider.initialize();
      
      final historyItem = {
        'title': widget.title ?? chapter['title'], // Use Series title if available
        'image_url': widget.comicImageUrl ??
            chapter['cover_image'] ??
            'https://via.placeholder.com/150',
        'url': url,
        // Use chapter title (e.g. "Chapter 1") instead of number (e.g. "0") if possible
        'chapter': chapter['title'] ?? widget.chapterId ?? chapter['chapter_number'] ?? 'Unknown',
        'type': 'comic',
      };
      
      await appStateProvider.addToHistory(historyItem, false);
    } catch (e) {
      _showErrorDialog('History Error', 'Failed to save to history: $e');
    }
  }

  Future<void> _saveToHistoryDirect() async {
    try {
      final appStateProvider = Provider.of<AppStateProvider>(context, listen: false);
      await appStateProvider.initialize();
      
      final historyItem = {
        'title': widget.title ?? 'Chapter',
        'image_url': widget.comicImageUrl ?? 'https://via.placeholder.com/150',
        'url': widget.url ?? '',
        'chapter': widget.chapterId ?? 'Unknown',
        'type': 'comic',
      };
      
      await appStateProvider.addToHistory(historyItem, false);
    } catch (e) {
      _showErrorDialog('History Error', 'Failed to save to history: $e');
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Get screen dimensions
    _screenWidth = MediaQuery.of(context).size.width;
    _screenHeight = MediaQuery.of(context).size.height;
  }

  Future<void> _loadPreferences() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      setState(() {
        _isDarkMode = prefs.getBool('manga_dark_mode') ?? true;
      });
    } catch (e) {
      _showErrorDialog('Failed to load preferences', e.toString());
    }
  }

  Future<void> _savePreferences() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('manga_dark_mode', _isDarkMode);
    } catch (e) {
      _showErrorDialog('Failed to save preferences', e.toString());
    }
  }

  Future<void> _loadLastPage() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final lastPage = prefs.getInt('page_${widget.chapterId}') ?? 0;
      _pageController = PageController(initialPage: lastPage);
      setState(() => _currentPage = lastPage);
    } catch (e) {
      _showErrorDialog('Failed to load last page', e.toString());
      _pageController = PageController(initialPage: 0);
    }
  }

  Future<void> _saveCurrentPage() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt('page_${widget.chapterId}', _currentPage);
    } catch (e) {
      _showErrorDialog('Failed to save current page', e.toString());
    }
  }

  void _handleTap(TapUpDetails details, BoxConstraints constraints) {
    // If zoomed, simple toggle menu (or do nothing to avoid confusion)
    if (_transformationController.value.getMaxScaleOnAxis() > 1.0) {
       _toggleMenu();
       return;
    }

    final double height = constraints.maxHeight;
    final double tapY = details.localPosition.dy;
    final double relativeY = tapY / height;

    // Top 25%: Scroll Up
    if (relativeY < 0.25) {
      _scrollController.animateTo(
        (_scrollController.offset - 300).clamp(0.0, _scrollController.position.maxScrollExtent),
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOut,
      );
    } 
    // Bottom 25%: Scroll Down
    else if (relativeY > 0.75) {
       _scrollController.animateTo(
        (_scrollController.offset + 300).clamp(0.0, _scrollController.position.maxScrollExtent),
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOut,
      );
    }
    // Middle 50%: Toggle Menu
    else {
      _toggleMenu();
    }
  }

  void _toggleMenu() {
     setState(() => _isMenuVisible = !_isMenuVisible);
  }

  void _updatePanState() {
    final isZoomed = _transformationController.value.getMaxScaleOnAxis() > 1.0;
    if (_canPan != isZoomed) {
      setState(() {
        _canPan = isZoomed;
      });
    }
  }

  void _handleDoubleTap() {
    if (_animationController.isAnimating) return;

    Matrix4 endMatrix;
    Offset position = _doubleTapDetails != null
        ? _doubleTapDetails!.localPosition
        : Offset.zero;

    if (_transformationController.value.getMaxScaleOnAxis() > 1.0) {
      endMatrix = Matrix4.identity();
    } else {
      endMatrix = Matrix4.identity()
        ..translate(-position.dx * 1.5, -position.dy * 1.5)
        ..scale(2.5);
    }

    _animation = Matrix4Tween(
      begin: _transformationController.value,
      end: endMatrix,
    ).animate(CurveTween(curve: Curves.easeOut).animate(_animationController));

    _animationController.forward(from: 0);
  }

  void _showErrorDialog(String title, String message) {
    if (mounted) {
      CustomErrorDialog.show(
        context,
        title: title,
        message: message,
        onRetry: () {
          // Retry logic if needed
        },
      );
    }
  }

  // Metode untuk melakukan preload semua gambar
  void _preloadImages() {
    if (_pages.isEmpty) return;

    setState(() {
      _isPreloading = true;
      _preloadedCount = 0;
    });

    for (int i = 0; i < _pages.length; i++) {
      // Pastikan URL gambar sudah dibersihkan dari spasi
      final cleanImageUrl = _pages[i].trim();
      // Preload gambar menggunakan CachedNetworkImageProvider
      precacheImage(
        CachedNetworkImageProvider(
          cleanImageUrl,
          cacheKey: 'manga_${_chapterId}_$i',
        ),
        context,
        onError: (exception, stackTrace) {
          // Tangani error saat preload
          setState(() {
            _preloadedCount++;
            if (_preloadedCount >= _pages.length) {
              _isPreloading = false;
            }
          });
        },
      ).then((_) {
        // Update counter saat gambar berhasil di-preload
        setState(() {
          _preloadedCount++;
          if (_preloadedCount >= _pages.length) {
            _isPreloading = false;
          }
        });
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return Scaffold(
        backgroundColor: _isDarkMode ? Colors.black : Colors.white,
        body: Center(
          child: CustomLoadingWidget(
            message: 'Loading chapter...',
            color: AppTheme.primaryColor,
          ),
        ),
      );
    }

    if (_isPreloading) {
      return Scaffold(
        backgroundColor: _isDarkMode ? Colors.black : Colors.white,
        body: Center(
          child: CustomLoadingWidget(
            message: 'Preloading chapter... (${_preloadedCount}/${_pages.length})',
            color: AppTheme.primaryColor,
          ),
        ),
      );
    }
    if (_error != null) {
      return Scaffold(
        backgroundColor: _isDarkMode ? Colors.black : Colors.white,
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.error_outline, size: 60, color: AppTheme.primaryColor),
              SizedBox(height: 16),
              Text('Error loading chapter images',
                  style: TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold)),
              SizedBox(height: 8),
              Text(_error!,
                  style: TextStyle(color: AppTheme.textSecondaryColor),
                  textAlign: TextAlign.center),
              SizedBox(height: 24),
              ElevatedButton(
                onPressed: () => Navigator.of(context).pop(),
                child: Text('Go Back'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primaryColor,
                  foregroundColor: Colors.white,
                  padding: EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    }
    return Scaffold(
      backgroundColor: _isDarkMode ? Colors.black : Colors.white,
      body: LayoutBuilder(
        builder: (context, constraints) {
          return Stack(
            children: [
              _buildReader(constraints),
              IgnorePointer(
                ignoring: !_isMenuVisible,
                child: AnimatedOpacity(
                  opacity: _isMenuVisible ? 1.0 : 0.0,
                  duration: const Duration(milliseconds: 300),
                  curve: Curves.easeInOut,
                  child: _buildMenu(),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildReader(BoxConstraints screenConstraints) {
    // Wrap entire reader in InteractiveViewer for global zoom
    return GestureDetector(
      onTapUp: (details) => _handleTap(details, screenConstraints), // Logic Tap Zone
      onDoubleTapDown: (details) => _doubleTapDetails = details,
      onDoubleTap: _handleDoubleTap,
      child: InteractiveViewer(
        transformationController: _transformationController,
        minScale: 1.0,
        maxScale: 3.0,
        panEnabled: _canPan,
        onInteractionEnd: (details) {
           _updatePanState();
        },
        child: Container(
          color: _isDarkMode ? Colors.black : Colors.white,
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 800),
              child: ListView.builder(
                controller: _scrollController, // Attach controller
                // Disable list scrolling when panning/zoomed
                physics: _canPan ? NeverScrollableScrollPhysics() : const AlwaysScrollableScrollPhysics(),
                itemCount: _pages.length,
                itemBuilder: (context, index) {
                  // Simpan halaman saat ini saat scrolling
                  if (index == 0) {
                    WidgetsBinding.instance.addPostFrameCallback((_) {
                      // Avoid setState during build if possible, but basic scroll tracking logic kept
                      // _currentPage = index; 
                    });
                  }
                  return _buildImageView(_pages[index], index);
                },
              ),
            ),
          ),
        ),
      ),
    );
  }

  // Horizontal reader telah dihapus, hanya menggunakan mode vertikal

  Widget _buildImageView(String imageUrl, int index) {
    // Gunakan Image widget biasa dengan CachedNetworkImage untuk tampilan yang lebih baik
    // Gunakan Custom ZoomableImage untuk interaksi zoom yang lebih baik
    // Gunakan Custom ZoomableImage untuk interaksi zoom yang lebih baik
    // Use standard CachedNetworkImage, as global zoom is handled by parent InteractiveViewer
    return CachedNetworkImage(
      imageUrl: imageUrl,
      cacheKey: 'manga_${_chapterId}_$index',
      fit: BoxFit.fitWidth,
      width: double.infinity,
      alignment: Alignment.topCenter,
      placeholder: (context, url) => Container(
        height: 300,
        child: Center(
          child: CustomLoadingWidget(
            message: '', // Hide text for individual images
            size: 100, // Adjusted size
          ),
        ),
      ),
      errorWidget: (context, url, error) => Container(
        height: 300,
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.error, color: Colors.red, size: 40),
              SizedBox(height: 16),
              Text('Failed to load'),
            ],
          ),
        ),
      ),
    );
  }

  // Navigasi ke chapter berikutnya
  void _navigateToNextChapter() {
    if (_nextChapterUrl != null && _nextChapterUrl!.isNotEmpty) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (context) => MangaReaderScreen(
            url: _nextChapterUrl,
            comicImageUrl: widget.comicImageUrl,
          ),
        ),
      );
    } else {
      ToastUtils.show(
        'Tidak ada chapter selanjutnya',
        backgroundColor: AppTheme.primaryColor,
      );
    }
  }

  // Navigasi ke chapter sebelumnya
  void _navigateToPrevChapter() {
    if (_prevChapterUrl != null && _prevChapterUrl!.isNotEmpty) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (context) => MangaReaderScreen(
            url: _prevChapterUrl,
            comicImageUrl: widget.comicImageUrl,
          ),
        ),
      );
    } else {
      ToastUtils.show(
        'Ini adalah chapter pertama',
        backgroundColor: AppTheme.primaryColor,
      );
    }
  }

  // Cek apakah ada chapter selanjutnya
  bool get _hasNextChapter =>
      _nextChapterUrl != null && _nextChapterUrl!.isNotEmpty;

  // Cek apakah ada chapter sebelumnya
  bool get _hasPrevChapter =>
      _prevChapterUrl != null && _prevChapterUrl!.isNotEmpty;

  // Navigasi ke daftar chapter
  void _navigateToChapterList() {
    if (_chapterListUrl != null && _chapterListUrl!.isNotEmpty) {
       _showChapterListBottomSheet();
    } else {
      Navigator.pop(context); // Fallback ke halaman sebelumnya
    }
  }

  void _showChapterListBottomSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1E1E1E),
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return DraggableScrollableSheet(
          initialChildSize: 0.5,
          minChildSize: 0.3,
          maxChildSize: 0.9,
          expand: false,
          builder: (context, scrollController) {
            return Column(
              children: [
                // Handle bar
                Container(
                  margin: const EdgeInsets.only(top: 12, bottom: 12),
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey[600],
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.only(bottom: 12.0),
                  child: Text(
                    "Select Chapter",
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                Expanded(
                  child: FutureBuilder<dynamic>(
                    future: ApiService.fetchComicDetails(_chapterListUrl!),
                    builder: (context, snapshot) {
                      if (snapshot.connectionState == ConnectionState.waiting) {
                        return const Center(
                          child: CircularProgressIndicator(
                            valueColor: AlwaysStoppedAnimation<Color>(AppTheme.primaryColor),
                          ),
                        );
                      } else if (snapshot.hasError) {
                        return Center(
                          child: Text(
                            'Failed to load chapters',
                            style: TextStyle(color: Colors.white54),
                          ),
                        );
                      } else if (snapshot.hasData) {
                         final chapters = snapshot.data['chapters'] as List?;
                         if (chapters == null || chapters.isEmpty) {
                            return Center(
                              child: Text(
                                'No chapters found',
                                style: TextStyle(color: Colors.white54),
                              ),
                            );
                         }

                         return ListView.builder(
                           controller: scrollController,
                           itemCount: chapters.length,
                           itemBuilder: (context, index) {
                             final chapter = chapters[index];
                             final isCurrent = chapter['url'] == widget.url; // Basic check
                             
                             return ListTile(
                               title: Text(
                                 chapter['title'] ?? 'Chapter',
                                 style: TextStyle(
                                   color: isCurrent ? AppTheme.primaryColor : Colors.white,
                                   fontWeight: isCurrent ? FontWeight.bold : FontWeight.normal,
                                 ),
                               ),
                               trailing: isCurrent ? Icon(Icons.check, color: AppTheme.primaryColor, size: 16) : null,
                               onTap: () {
                                 Navigator.pop(context); // Close sheet
                                 if (!isCurrent) {
                                   Navigator.pushReplacement(
                                     context,
                                     MaterialPageRoute(
                                       builder: (context) => MangaReaderScreen(
                                         url: chapter['url'],
                                         // Pass current comic info to keep context
                                         title: widget.title, 
                                         comicImageUrl: widget.comicImageUrl,
                                         // Chapter ID might need update if available in list
                                         chapterId: chapter['chapter_number']?.toString(), // Assuming API provides this
                                         chapterListUrl: _chapterListUrl,
                                       ),
                                     ),
                                   );
                                 }
                               },
                             );
                           },
                         );
                      }
                      return const SizedBox();
                    },
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Widget _buildMenu() {
    return SafeArea(
      child: Column(
        children: [
          Container(
            color: Colors.black.withOpacity(0.7),
            padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              children: [
                IconButton(
                  icon: Icon(Icons.arrow_back, color: Colors.white),
                  onPressed: () => Navigator.pop(context),
                ),
                Expanded(
                  child: Text(
                    widget.title ?? _chapterTitle ?? '',
                    style: TextStyle(color: Colors.white),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                IconButton(
                  icon: Icon(
                    _isDarkMode ? Icons.brightness_4 : Icons.brightness_7,
                    color: Colors.white,
                  ),
                  onPressed: () {
                    setState(() => _isDarkMode = !_isDarkMode);
                    _savePreferences();
                  },
                  tooltip: _isDarkMode ? 'Light Mode' : 'Dark Mode',
                ),
              ],
            ),
          ),
          Spacer(),
          // Navigasi chapter di bagian bawah
          Container(
            color: Colors.black.withOpacity(0.7),
            padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                // Tombol previous hanya ditampilkan jika ada chapter sebelumnya
                if (_hasPrevChapter)
                  IconButton(
                    icon: Icon(Icons.skip_previous, color: Colors.white),
                    onPressed: _navigateToPrevChapter,
                    tooltip: 'Chapter Sebelumnya',
                  )
                else
                  // Widget kosong untuk menjaga layout tetap seimbang
                  SizedBox(width: 48),
                IconButton(
                  icon: Icon(Icons.list, color: Colors.white),
                  onPressed: _navigateToChapterList,
                  tooltip: 'Daftar Chapter',
                ),
                // Tombol next hanya ditampilkan jika ada chapter selanjutnya
                if (_hasNextChapter)
                  IconButton(
                    icon: Icon(Icons.skip_next, color: Colors.white),
                    onPressed: _navigateToNextChapter,
                    tooltip: 'Chapter Selanjutnya',
                  )
                else
                  // Widget kosong untuk menjaga layout tetap seimbang
                  SizedBox(width: 48),
              ],
            ),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _transformationController.dispose();
    _animationController.dispose();
    // Restore orientation to all orientations when leaving manga reader
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);
    // Restore status bar when leaving manga reader
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.manual, overlays: SystemUiOverlay.values);
    super.dispose();
  }
}


