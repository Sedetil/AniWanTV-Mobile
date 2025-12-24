import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:video_player/video_player.dart';
import 'package:chewie/chewie.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'dart:async';
import '../widgets/custom_controls.dart';
import '../widgets/custom_error_dialog.dart';
import '../theme/app_theme.dart';
import '../widgets/custom_loading_widget.dart';

class VideoPlayerScreen extends StatefulWidget {
  final String url;
  final String title;
  final String episodeId;
  final List<Map<String, String>> directStreamUrls;

  VideoPlayerScreen({
    required this.url,
    required this.title,
    required this.episodeId,
    this.directStreamUrls = const [],
  });

  @override
  _VideoPlayerScreenState createState() => _VideoPlayerScreenState();
}

class _VideoPlayerScreenState extends State<VideoPlayerScreen> {
  late VideoPlayerController? _videoPlayerController;
  ChewieController? _chewieController;
  bool _isInitialized = false;
  bool _isDirectVideo = true;
  WebViewController? _webViewController;
  bool _isLoading = true;
  List<Map<String, String>> _pixelDrainUrls = [];
  String _currentUrl = "";
  String _selectedQuality = "";
  bool _isOrientationLocked = false;
  Timer? _qualityChangeTimer;
  bool _isChangingResolution = false;

  @override
  void initState() {
    super.initState();
    // Set landscape orientation when video player opens
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);
    // Hide system UI for immersive experience
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
    // Additional settings to ensure system UI is hidden
    SystemChrome.setSystemUIOverlayStyle(SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      systemNavigationBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
      systemNavigationBarIconBrightness: Brightness.light,
    ));
    // Force hide system UI after a short delay to ensure it takes effect
    Future.delayed(Duration(milliseconds: 100), () {
      SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
    });
    _currentUrl = widget.url;
    _filterPixelDrainUrls();
    _initializePlayer();
  }

  void _filterPixelDrainUrls() {
    if (widget.directStreamUrls.isNotEmpty) {
      setState(() {
        print("Raw directStreamUrls: ${widget.directStreamUrls}");

        // Filter semua URL yang memiliki kualitas, tidak hanya pixeldrain
        _pixelDrainUrls = widget.directStreamUrls
            .where((item) =>
                item['quality'] != null &&
                item['quality']!.isNotEmpty &&
                item['url'] != null &&
                item['url']!.isNotEmpty)
            .toList();

        print("Filtered URLs with quality: $_pixelDrainUrls");

        _pixelDrainUrls.sort((a, b) {
          int qualityA = int.tryParse(
                  a['quality']?.replaceAll(RegExp(r'[^0-9]'), '') ?? '0') ??
              0;
          int qualityB = int.tryParse(
                  b['quality']?.replaceAll(RegExp(r'[^0-9]'), '') ?? '0') ??
              0;
          return qualityB.compareTo(qualityA);
        });

        final Map<String, Map<String, String>> uniqueQualityUrls = {};
        for (var item in _pixelDrainUrls) {
          final quality = item['quality'] ?? "";
          final url = item['url'] ?? "";
          if (!uniqueQualityUrls.containsKey(quality) &&
              quality.isNotEmpty &&
              url.isNotEmpty) {
            uniqueQualityUrls[quality] = item;
            print("Added quality $quality with URL: $url");
          }
        }

        _pixelDrainUrls = uniqueQualityUrls.values.toList();

        if (_pixelDrainUrls.isNotEmpty) {
          _selectedQuality = _pixelDrainUrls.first['quality'] ?? "";
          _currentUrl = _pixelDrainUrls.first['url'] ?? "";
        }

        print(
            "Available quality options: ${_pixelDrainUrls.map((e) => e['quality']).toList()}");
        print("Selected URL: $_currentUrl");
        print("Selected quality: $_selectedQuality");
      });
    } else {
      print("No directStreamUrls available");
    }
  }

  void _changeVideoQuality(String url, String quality) {
    if (_isChangingResolution) return;

    // Allow quality change even if URL is the same (for retry scenarios)
    print('Changing quality to: $quality, URL: $url');

    setState(() {
      _isChangingResolution = true;
      _isLoading = true;
    });

    _qualityChangeTimer?.cancel();

    _qualityChangeTimer = Timer(Duration(milliseconds: 300), () async {
      try {
        // Store the current position and full-screen state
        final currentPosition =
            _videoPlayerController?.value.position ?? Duration.zero;
        final wasFullScreen = _chewieController?.isFullScreen ?? false;

        print('Current position: ${currentPosition.inSeconds}s');
        print('Was fullscreen: $wasFullScreen');

        print('Was fullscreen: $wasFullScreen');
        
        // Unmount the player from UI first to prevent access to disposed controller
        if (mounted) {
           setState(() {
              _isInitialized = false; 
           });
        }

        // Wait a bit to ensure UI updates and player is unmounted
        await Future.delayed(Duration(milliseconds: 100));

        // Now safe to dispose
        _disposeControllers();

        if (!mounted) return;

        setState(() {
          _currentUrl = url;
          _selectedQuality = quality;
          _isInitialized = false;
        });

        // Initialize new player with validation
        await _initializePlayer();

        // Wait for initialization to complete
        await Future.delayed(Duration(milliseconds: 500));

        // Verify that the video controller is properly initialized
        if (_videoPlayerController == null ||
            !_videoPlayerController!.value.isInitialized) {
          throw Exception(
              'Failed to initialize video player for quality: $quality');
        }

        // Restore position and full-screen state
        if (mounted &&
            _videoPlayerController != null &&
            _videoPlayerController!.value.isInitialized) {
          try {
            await _videoPlayerController!.seekTo(currentPosition);
            print('Restored position to: ${currentPosition.inSeconds}s');

            if (wasFullScreen && _chewieController != null) {
              _chewieController!.enterFullScreen();
            }
          } catch (e) {
            print('Error restoring position: $e');
          }
        }

        if (mounted) {
          setState(() {
            _isChangingResolution = false;
            _isLoading = false;
          });
          print('Quality change completed successfully');
        }
      } catch (e) {
        print('Error during quality change: $e');
        if (mounted) {
          setState(() {
            _isChangingResolution = false;
            _isLoading = false;
          });

          // Try to fallback to a different quality if available
          final availableQualities = _pixelDrainUrls
              .where((item) =>
                  item['quality'] != quality &&
                  item['url'] != null &&
                  item['url']!.isNotEmpty)
              .toList();

          if (availableQualities.isNotEmpty) {
            print(
                'Trying fallback quality: ${availableQualities.first['quality']}');
            Future.delayed(Duration(milliseconds: 500), () {
              _changeVideoQuality(availableQualities.first['url']!,
                  availableQualities.first['quality']!);
            });
          } else {
            // Show error dialog if no fallback available
            CustomErrorDialog.show(
              context,
              title: 'Quality Change Error',
              message:
                  'Failed to change video quality: $e\n\nNo alternative quality available.',
              onRetry: () => _changeVideoQuality(url, quality),
            );
          }
        }
      }
    });
  }

  void _disposeControllers() {
    try {
      print('Disposing controllers...');
      
      // Cancel any pending timers first
      _qualityChangeTimer?.cancel();
      _qualityChangeTimer = null;

      // Handle Chewie controller disposal
      if (_chewieController != null) {
        try {
          // Exit fullscreen safely before disposal
          if (_chewieController!.isFullScreen) {
            try {
              _chewieController!.exitFullScreen();
              // Small delay to let fullscreen exit complete
              Future.delayed(Duration(milliseconds: 50));
            } catch (e) {
              print('Error exiting fullscreen: $e');
            }
          }

          _chewieController!.dispose();
          print('Chewie controller disposed');
        } catch (e) {
          print('Error disposing Chewie controller: $e');
        }
        _chewieController = null;
      }

      // Then dispose video player controller
      if (_videoPlayerController != null) {
        try {
          // Remove listener safely
          if (_videoPlayerController!.value.isInitialized) {
            _videoPlayerController!.removeListener(_saveCurrentPosition);
          }
          _videoPlayerController!.dispose();
          print('Video player controller disposed');
        } catch (e) {
          print('Error disposing video player controller: $e');
        }
        _videoPlayerController = null;
      }

      // Reset state flags
      _isInitialized = false;
      print('Controllers disposal completed');
    } catch (e) {
      print('Error in _disposeControllers: $e');
    }
  }

  Future<void> _initializePlayer() async {
    if (_isDirectVideoUrl(_currentUrl)) {
      _isDirectVideo = true;
      try {
        setState(() => _isLoading = true);

        // Validate URL before creating controller
        if (_currentUrl.isEmpty) {
          throw Exception('Video URL is empty');
        }

        print('Initializing video player with URL: $_currentUrl');
        _videoPlayerController =
            VideoPlayerController.networkUrl(Uri.parse(_currentUrl));

        // Add timeout for initialization
        await _videoPlayerController!.initialize().timeout(
          Duration(seconds: 30),
          onTimeout: () {
            throw Exception('Video initialization timeout');
          },
        );

        _chewieController = ChewieController(
          videoPlayerController: _videoPlayerController!,
          aspectRatio: 16 / 9,
          autoPlay: true,
          looping: false,
          allowPlaybackSpeedChanging: true,
          allowFullScreen: false,
          showControls: true,
          fullScreenByDefault: true,
          customControls: CustomControls(
            backgroundColor: Colors.black.withOpacity(0.5),
            iconColor: Colors.white,
            title: widget.title,
            onBackPressed: () async {
              // Safely dispose controllers before navigation
              try {
                print('Back button pressed, disposing controllers...');
                _disposeControllers();

                // Small delay to ensure disposal completes
                await Future.delayed(Duration(milliseconds: 100));

                // Navigate back after disposal
                if (mounted) {
                  Navigator.of(context).pop();
                }
              } catch (e) {
                print('Error during back navigation: $e');
                // Still navigate even if disposal fails
                if (mounted) {
                  Navigator.of(context).pop();
                }
              }
            },
            qualityOptions: _pixelDrainUrls,
            selectedQuality: _selectedQuality,
            onQualityChanged: _changeVideoQuality,
            onNextEpisode: () {
               // Placeholder for next episode logic
               // To implement this, we need to pass the full episode list to this screen
               // For now, show a toast or log
               print('Next Episode clicked');
               // ToastUtils.show('Next Episode not available in this demo');
            },
            onShowEpisodes: () {
               // Placeholder for episodes list
               print('Show Episodes clicked');
               // ToastUtils.show('Episodes list not available in this demo');
            },
          ),
          placeholder: Center(
            child: CircularProgressIndicator(
              valueColor: AlwaysStoppedAnimation<Color>(Colors.red),
              strokeWidth: 2,
            ),
          ),
          materialProgressColors: ChewieProgressColors(
            playedColor: Colors.red,
            handleColor: Colors.red,
            backgroundColor: Colors.grey.shade800,
            bufferedColor: Colors.grey.shade600,
          ),
          errorBuilder: (context, errorMessage) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.error_outline,
                    color: AppTheme.errorColor,
                    size: 48,
                  ),
                  SizedBox(height: 16),
                  Text(
                    'Error: $errorMessage',
                    style: TextStyle(color: AppTheme.textPrimaryColor),
                    textAlign: TextAlign.center,
                  ),
                  SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: () {
                      setState(() {
                        _initializePlayer();
                      });
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.primaryColor,
                      foregroundColor: Colors.white,
                    ),
                    child: Text('Retry'),
                  ),
                ],
              ),
            );
          },
          additionalOptions: (context) {
            return <OptionItem>[
              OptionItem(
                onTap: (BuildContext ctx) {
                  Navigator.of(ctx).pop();
                  setState(() {
                    _isOrientationLocked = !_isOrientationLocked;
                    if (_isOrientationLocked) {
                      SystemChrome.setPreferredOrientations([
                        DeviceOrientation.landscapeLeft,
                        DeviceOrientation.landscapeRight,
                      ]);
                    } else {
                      SystemChrome.setPreferredOrientations([
                        DeviceOrientation.portraitUp,
                        DeviceOrientation.portraitDown,
                        DeviceOrientation.landscapeLeft,
                        DeviceOrientation.landscapeRight,
                      ]);
                    }
                  });
                },
                iconData: _isOrientationLocked
                    ? Icons.screen_lock_rotation
                    : Icons.screen_rotation,
                title: _isOrientationLocked
                    ? 'Unlock Orientation'
                    : 'Lock Orientation',
              ),
            ];
          },
        );

        _videoPlayerController!.addListener(_saveCurrentPosition);
        await _loadLastPosition();
        setState(() {
          _isLoading = false;
          _isInitialized = true;
        });
      } catch (e) {
        print('Error initializing video player: $e');
        if (mounted) {
          setState(() {
            _isLoading = false;
            _isChangingResolution = false;
          });
          CustomErrorDialog.show(
            context,
            title: 'Video Player Error',
            message: 'Failed to initialize video player: $e',
            onRetry: () => _initializePlayer(),
            onDismiss: () {
              _isDirectVideo = false;
              _initializeWebView();
            },
          );
        }
      }
    } else {
      _isDirectVideo = false;
      _initializeWebView();
    }
  }

  bool _isDirectVideoUrl(String url) {
    if (url.isEmpty) {
      print('URL is empty, treating as non-direct video');
      return false;
    }

    print('Checking if URL is direct video: $url');

    final videoExtensions = ['.mp4', '.m3u8', '.mov', '.mkv', '.avi', '.webm'];
    if (videoExtensions.any((ext) => url.toLowerCase().contains(ext))) {
      print('URL contains video extension, treating as direct video');
      return true;
    }

    final embedDomains = [
      'krakenfiles.com',
      'embedsito.com',
      'filemoon.sx',
      'youtube.com',
      'youtu.be',
      'vimeo.com',
      'dailymotion.com'
    ];

    if (embedDomains.any((domain) => url.toLowerCase().contains(domain))) {
      print('URL contains embed domain, treating as non-direct video');
      return false;
    }

    // Check if URL looks like a direct stream (contains common streaming indicators)
    final streamingIndicators = ['pixeldrain.com', 'stream', 'video', 'play'];
    if (streamingIndicators
        .any((indicator) => url.toLowerCase().contains(indicator))) {
      print('URL contains streaming indicator, treating as direct video');
      return true;
    }

    print(
        'URL does not match any criteria, treating as direct video by default');
    return true;
  }

  void _initializeWebView() {
    setState(() => _isLoading = true);
    _webViewController = WebViewController()
      ..setBackgroundColor(Colors.black)
      ..enableZoom(false)
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageFinished: (String url) {
            setState(() {
              _isLoading = false;
              _isInitialized = true;
            });
          },
          onWebResourceError: (WebResourceError error) {
            print('WebView error: ${error.description}');
            setState(() {
              _isLoading = false;
              _isChangingResolution = false;
            });

            if (mounted) {
              CustomErrorDialog.show(
                context,
                title: 'WebView Error',
                message: 'Failed to load video: ${error.description}',
                onRetry: () => _initializeWebView(),
              );
            }
          },
        ),
      )
      ..loadRequest(Uri.parse(_currentUrl));
  }

  Future<void> _loadLastPosition() async {
    if (!_isDirectVideo) return;

    final prefs = await SharedPreferences.getInstance();
    final position = prefs.getInt('position_${widget.episodeId}') ?? 0;
    if (position > 0 &&
        _isInitialized &&
        _videoPlayerController != null &&
        _videoPlayerController!.value.isInitialized) {
      _videoPlayerController!.seekTo(Duration(seconds: position));
    }
  }

  int _lastSavedSeconds = -1;

  Future<void> _saveCurrentPosition() async {
    if (!_isDirectVideo ||
        !_isInitialized ||
        _videoPlayerController == null ||
        !_videoPlayerController!.value.isInitialized) return;

    final position = _videoPlayerController!.value.position;
    final currentSeconds = position.inSeconds;

    // Only save if 5 seconds have passed or if time jumped backwards (seek)
    if (_lastSavedSeconds == -1 || 
        (currentSeconds - _lastSavedSeconds).abs() >= 5) {
      _lastSavedSeconds = currentSeconds;
      try {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setInt('position_${widget.episodeId}', currentSeconds);
      } catch (e) {
        print('Error saving position: $e');
      }
    }
  }

  @override
  void dispose() {
    print('Disposing VideoPlayerScreen');

    // Cancel any pending quality change timer
    _qualityChangeTimer?.cancel();
    _qualityChangeTimer = null;

    // Only dispose controllers if they haven't been disposed already
    if (_videoPlayerController != null || _chewieController != null) {
      _disposeControllers();
    }

    // Delay orientation and system UI restoration to avoid visual glitch
    Future.delayed(Duration(milliseconds: 300), () {
      try {
        // Restore orientation to all orientations
        SystemChrome.setPreferredOrientations([
          DeviceOrientation.portraitUp,
          DeviceOrientation.portraitDown,
          DeviceOrientation.landscapeLeft,
          DeviceOrientation.landscapeRight,
        ]);
        // Restore system UI (show status bar, navigation bar, etc.)
        SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
        // Restore system UI overlay style to default
        SystemChrome.setSystemUIOverlayStyle(SystemUiOverlayStyle(
          statusBarColor: Colors.transparent,
          systemNavigationBarColor: Colors.transparent,
          statusBarIconBrightness: Brightness.dark,
          systemNavigationBarIconBrightness: Brightness.dark,
        ));
      } catch (e) {
        print('Error restoring system UI: $e');
      }
    });

    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Ensure system UI stays hidden when widget rebuilds


    return PopScope(
      onPopInvoked: (didPop) {
        if (didPop) {
          // Delay system UI restoration to avoid visual glitch
          Future.delayed(Duration(milliseconds: 200), () {
            SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
            SystemChrome.setSystemUIOverlayStyle(SystemUiOverlayStyle(
              statusBarColor: Colors.transparent,
              systemNavigationBarColor: Colors.transparent,
              statusBarIconBrightness: Brightness.dark,
              systemNavigationBarIconBrightness: Brightness.dark,
            ));
          });
        }
      },
      child: Scaffold(
        backgroundColor: Colors.black,
        extendBodyBehindAppBar: true,
        body: Container(
          width: double.infinity,
          height: double.infinity,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                Colors.black,
                Color(0xFF0A0A0A),
              ],
            ),
          ),
          child: Stack(
            children: [
              // Main video content - fullscreen
              Positioned.fill(
                child: _buildVideoContent(),
              ),

              // Loading overlay
              if (_isLoading)
                Container(
                  color: Colors.black.withOpacity(0.8),
                  child: Center(
                    child: CustomLoadingWidget(
                        message: _isChangingResolution ? "Switching Quality..." : "Loading...",
                        color: Colors.red,
                    ),
                  ),
                ),


            ],
          ),
        ),
      ),
    );
  }

  Widget _buildVideoContent() {
    if (!_isInitialized) {
      return Container(
        color: Colors.black,
        child: Center(
          child: CustomLoadingWidget(
            message: 'Initializing...',
            color: Colors.red,
          ),
        ),
      );
    }

    if (_isDirectVideo && _chewieController != null) {
      return Stack(
        fit: StackFit.expand,
        children: [
          // 1. Video Layer (Immersive, Under Notch)
          if (_videoPlayerController != null && _videoPlayerController!.value.isInitialized)
            SizedBox.expand(
              child: FittedBox(
                fit: BoxFit.contain, // Maintain aspect ratio, fully visible
                child: SizedBox(
                   width: _videoPlayerController!.value.size.width,
                   height: _videoPlayerController!.value.size.height,
                   child: VideoPlayer(_videoPlayerController!),
                ),
              ),
            ),
            
          // 2. Controls Layer
          CustomControls(
            controller: _chewieController,
            backgroundColor: Colors.transparent,
            iconColor: Colors.white,
            title: widget.title,
            onBackPressed: () {
               Navigator.of(context).pop();
            },
            qualityOptions: _pixelDrainUrls,
            selectedQuality: _selectedQuality,
            onQualityChanged: _changeVideoQuality,
            onNextEpisode: () {
               // Placeholder
               print('Next Episode');
            },
            onShowEpisodes: () {
               // Placeholder
               print('Episodes List');
            },
          ),
        ],
      );
    }

    if (_webViewController != null) {
      return WebViewWidget(controller: _webViewController!);
    }

    return Container(
      color: Colors.black,
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.red.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: Colors.red.withOpacity(0.3),
                  width: 1,
                ),
              ),
              child: Icon(
                Icons.error_outline,
                color: Colors.red,
                size: 48,
              ),
            ),
            SizedBox(height: 20),
            Text(
              'Unable to load video',
              style: TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            SizedBox(height: 8),
            Text(
              'Please check your connection and try again',
              style: TextStyle(
                color: Colors.white70,
                fontSize: 14,
              ),
              textAlign: TextAlign.center,
            ),
            SizedBox(height: 20),
            ElevatedButton(
              onPressed: () {
                _initializePlayer();
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                foregroundColor: Colors.white,
                padding: EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child: Text(
                'Retry',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
