import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:photo_view/photo_view.dart';
import 'package:photo_view/photo_view_gallery.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../theme/app_theme.dart';
import '../widgets/custom_error_dialog.dart';
import 'dart:convert';
import '../services/api_service.dart';
import 'package:fluttertoast/fluttertoast.dart';

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

class _MangaReaderScreenState extends State<MangaReaderScreen> {
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

  final ApiService apiService = ApiService();

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
      final chapter = await apiService.fetchChapterImages(url);
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
      final prefs = await SharedPreferences.getInstance();
      final historyJson = prefs.getString('comic_history') ?? '[]';
      List<dynamic> history = jsonDecode(historyJson);
      final historyItem = {
        'id': DateTime.now().millisecondsSinceEpoch.toString(),
        'title': chapter['title'],
        'image_url': widget.comicImageUrl ??
            chapter['cover_image'] ??
            'https://via.placeholder.com/150',
        'url': url,
        'chapter': widget.chapterId ?? chapter['chapter_number'] ?? 'Unknown',
        'timestamp': DateTime.now().toString(),
        'type': 'comic',
      };
      history.removeWhere((item) => item['url'] == url);
      history.insert(0, historyItem);
      if (history.length > 50) {
        history = history.sublist(0, 50);
      }
      await prefs.setString('comic_history', jsonEncode(history));
    } catch (e) {
      _showErrorDialog('History Error', 'Failed to save to history: $e');
    }
  }

  Future<void> _saveToHistoryDirect() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final historyJson = prefs.getString('comic_history') ?? '[]';
      List<dynamic> history = jsonDecode(historyJson);
      final historyItem = {
        'id': DateTime.now().millisecondsSinceEpoch.toString(),
        'title': widget.title ?? 'Chapter',
        'image_url': widget.comicImageUrl ?? 'https://via.placeholder.com/150',
        'url': widget.url ?? '',
        'chapter': widget.chapterId ?? 'Unknown',
        'timestamp': DateTime.now().toString(),
        'type': 'comic',
      };
      history.removeWhere((item) => item['url'] == widget.url);
      history.insert(0, historyItem);
      if (history.length > 50) {
        history = history.sublist(0, 50);
      }
      await prefs.setString('comic_history', jsonEncode(history));
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

  void _toggleMenu() {
    setState(() => _isMenuVisible = !_isMenuVisible);
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
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircularProgressIndicator(
                valueColor:
                    AlwaysStoppedAnimation<Color>(AppTheme.primaryColor),
              ),
              SizedBox(height: 16),
              Text('Loading chapter...',
                  style: TextStyle(
                      color: _isDarkMode ? Colors.white : Colors.black)),
            ],
          ),
        ),
      );
    }

    if (_isPreloading) {
      return Scaffold(
        backgroundColor: _isDarkMode ? Colors.black : Colors.white,
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircularProgressIndicator(
                valueColor:
                    AlwaysStoppedAnimation<Color>(AppTheme.primaryColor),
                // Tampilkan progress preloading
                value: _pages.isEmpty ? 0 : _preloadedCount / _pages.length,
              ),
              SizedBox(height: 16),
              Text(
                'Preloading chapter... (${_preloadedCount}/${_pages.length})',
                style:
                    TextStyle(color: _isDarkMode ? Colors.white : Colors.black),
              ),
            ],
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
      body: GestureDetector(
        onTap: _toggleMenu,
        child: Stack(
          children: [
            _buildReader(),
            if (_isMenuVisible) _buildMenu(),
          ],
        ),
      ),
    );
  }

  Widget _buildReader() {
    // Kembali menggunakan ListView untuk scrolling vertikal
    return ListView.builder(
      itemCount: _pages.length,
      itemBuilder: (context, index) {
        // Simpan halaman saat ini saat scrolling
        if (index == 0) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            setState(() => _currentPage = index);
            _saveCurrentPage();
          });
        }
        return Container(
          width: _screenWidth,
          // Hapus batasan height agar gambar dapat ditampilkan penuh
          child: _buildImageView(_pages[index], index),
        );
      },
    );
  }

  // Horizontal reader telah dihapus, hanya menggunakan mode vertikal

  Widget _buildImageView(String imageUrl, int index) {
    // Gunakan Image widget biasa dengan CachedNetworkImage untuk tampilan yang lebih baik
    return CachedNetworkImage(
      imageUrl: imageUrl,
      cacheKey: 'manga_${_chapterId}_$index',
      fit: BoxFit.contain,
      width: _screenWidth,
      // Biarkan height menyesuaikan dengan rasio gambar asli
      placeholder: (context, url) => Center(
        child: CircularProgressIndicator(
          valueColor: AlwaysStoppedAnimation<Color>(AppTheme.primaryColor),
        ),
      ),
      errorWidget: (context, url, error) => Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error, color: Colors.red, size: 40),
            SizedBox(height: 16),
            Text(
              'Failed to load image',
              style:
                  TextStyle(color: _isDarkMode ? Colors.white : Colors.black),
            ),
            SizedBox(height: 8),
            ElevatedButton(
              onPressed: () {
                setState(() {
                  // Trigger reload
                  _hasImageError = false;
                });
              },
              child: Text('Retry'),
            ),
          ],
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
      Fluttertoast.showToast(
        msg: 'Tidak ada chapter selanjutnya',
        toastLength: Toast.LENGTH_SHORT,
        gravity: ToastGravity.BOTTOM,
        backgroundColor: AppTheme.primaryColor,
        textColor: Colors.white,
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
      Fluttertoast.showToast(
        msg: 'Ini adalah chapter pertama',
        toastLength: Toast.LENGTH_SHORT,
        gravity: ToastGravity.BOTTOM,
        backgroundColor: AppTheme.primaryColor,
        textColor: Colors.white,
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
      Navigator.pop(context); // Kembali ke halaman detail komik
    } else {
      Navigator.pop(context); // Fallback ke halaman sebelumnya
    }
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
