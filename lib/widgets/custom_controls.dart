import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:chewie/chewie.dart';
import 'package:video_player/video_player.dart';
import 'package:provider/provider.dart' as provider;
import 'package:flutter_svg/flutter_svg.dart';
import 'dart:async';

import 'package:flutter/foundation.dart';
import 'dart:io';
import 'package:screen_brightness/screen_brightness.dart';

class CustomControls extends StatefulWidget {
  final Color backgroundColor;
  final Color iconColor;
  final String title;
  final VoidCallback onBackPressed;
  final List<Map<String, String>> qualityOptions;
  final String selectedQuality;
  final Function(String, String)? onQualityChanged;
  final VoidCallback? onNextEpisode;
  final VoidCallback? onShowEpisodes;
  final ChewieController? controller;

  const CustomControls({
    Key? key,
    this.backgroundColor = Colors.black54,
    this.iconColor = Colors.white,
    required this.title,
    required this.onBackPressed,
    this.qualityOptions = const [],
    this.selectedQuality = '',
    this.onQualityChanged,
    this.onNextEpisode,
    this.onShowEpisodes,
    this.controller,
  }) : super(key: key);

  @override
  _CustomControlsState createState() => _CustomControlsState();
}

class _CustomControlsState extends State<CustomControls> {
  @override
  Widget build(BuildContext context) {
    return MaterialControls(
      showPlayButton: true,
      backgroundColor: widget.backgroundColor,
      iconColor: widget.iconColor,
      title: widget.title,
      onBackPressed: widget.onBackPressed,
      qualityOptions: widget.qualityOptions,
      selectedQuality: widget.selectedQuality,
      onQualityChanged: widget.onQualityChanged,
      onNextEpisode: widget.onNextEpisode,
      onShowEpisodes: widget.onShowEpisodes,
      controller: widget.controller,
    );
  }
}

class MaterialControls extends StatefulWidget {
  const MaterialControls({
    Key? key,
    this.showPlayButton = true,
    this.backgroundColor = Colors.black54,
    this.iconColor = Colors.white,
    required this.title,
    required this.onBackPressed,
    this.qualityOptions = const [],
    this.selectedQuality = '',
    this.onQualityChanged,
    this.onNextEpisode,
    this.onShowEpisodes,
    this.controller,
  }) : super(key: key);

  final bool showPlayButton;
  final Color backgroundColor;
  final Color iconColor;
  final String title;
  final VoidCallback onBackPressed;
  final List<Map<String, String>> qualityOptions;
  final String selectedQuality;
  final Function(String, String)? onQualityChanged;
  final VoidCallback? onNextEpisode;
  final VoidCallback? onShowEpisodes;
  final ChewieController? controller;

  @override
  State<MaterialControls> createState() => _MaterialControlsState();
}

class _MaterialControlsState extends State<MaterialControls>
    with TickerProviderStateMixin {
  late PlayerNotifier notifier;
  Timer? _hideTimer;
  Timer? _initTimer;
  bool _subtitleOn = false;
  Timer? _showAfterExpandCollapseTimer;
  bool _dragging = false;
  bool _displayTapped = false;

  final barHeight = 48.0;
  final marginSize = 5.0;

  VideoPlayerController? controller;
  ChewieController? _chewieController;
  AnimationController? _controlsAnimationController;

  // Double tap skip variables
  bool _isSkipping = false;
  bool _isForwardSkip = true;
  int _skipAmount = 0;
  Timer? _skipResetTimer;
  Offset? _lastTapDownPosition;

  @override
  void initState() {
    super.initState();
    notifier = PlayerNotifier();
    _initBrightness();
  }

  bool _isLocked = false;
  double _brightness = 0.5;

  Future<void> _initBrightness() async {
    try {
      final current = await ScreenBrightness().current;
      setState(() {
        _brightness = current;
      });
    } catch (e) {
      print('Failed to get current brightness: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    if (controller == null) {
      return Container();
    }

    Widget controls = GestureDetector(
        onTap: () {
          if (_isLocked) return; // Ignore taps if locked
          if (_isSkipping) {
            _incrementSkip();
          } else {
            _toggleControls();
          }
        },
        child: AnimatedBuilder(
          animation: controller!,
          builder: (context, child) {
            final latestValue = controller!.value;
            
            if (latestValue.hasError) {
               return chewieController?.errorBuilder?.call(
                    context,
                    latestValue.errorDescription ?? 'Error loading video',
                  ) ??
                  const Center(
                    child: Icon(
                      Icons.error,
                      color: Colors.white,
                      size: 42,
                    ),
                  );
            }
            
            return Container(
              color: Colors.transparent,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  // 1. Skip Overlay (BACKGROUND LAYER)
                  if (_isSkipping) _buildSkipOverlay(),

                  // 2. Main Interface (Hidden if locked)
                  if (!_isLocked)
                    IgnorePointer(
                      ignoring: notifier.hideStuff,
                      child: AnimatedOpacity(
                        opacity: notifier.hideStuff ? 0.0 : 1.0,
                        duration: const Duration(milliseconds: 300),
                        child: Stack(
                          children: [
                             // Top Bar (Title)
                             Positioned(
                               top: 0,
                               left: 0,
                               right: 0,
                               child: _buildTopBar(context),
                             ),
                             
                             // Center Controls (Play/Pause, Rewind, Forward)
                             Center(child: _buildCenterControls(latestValue)),
                             
                             // Bottom Bar
                             Positioned(
                               bottom: 0,
                               left: 0,
                               right: 0,
                               child: _buildBottomBar(context, latestValue),
                             ),
                          ],
                        ),
                      ),
                    ),

                  // 3. Lock Button (Always Visible or dependent on logic, usually visible to unlock)
                  if (notifier.hideStuff == false || _isLocked)
                     Positioned(
                        bottom: 44, // Adjusted to avoid overlapping bottom bar
                        left: 24,
                        child: _isLocked ? _buildLockOverlayButton() : SizedBox(),
                     ),
                ],
              ),
            );
          },
        ),
      );

    // Only wrap with MouseRegion on Web or Desktop
    if (kIsWeb || Platform.isWindows || Platform.isLinux || Platform.isMacOS) {
      return MouseRegion(
        onHover: (_) {
           _cancelAndRestartTimer();
        },
        child: controls,
      );
    }

    return controls;
  }

  Widget _buildTopBar(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 24),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Colors.black87, Colors.transparent],
        ),
      ),
      child: SafeArea(
        child: Stack(
          alignment: Alignment.center,
          children: [
            // Title digeser ke kiri sedikit
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 40.0),
              child: Transform.translate(
                // Offset adjustment: Mobile uses -12, Desktop uses 0 (Centered) or adjustable
                offset: (kIsWeb || Platform.isWindows || Platform.isLinux || Platform.isMacOS)
                    ? const Offset(-8, 0) // Desktop: Shift Left -40
                    : const Offset(-16, 0), // Mobile: Slightly left adjustments
                child: Text(
                  widget.title,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ),

            // Back button kiri
            Positioned(
              left: 0,
              child: InkWell(
                onTap: () {
                  // Restore system UI manually before popping
                  SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
                  SystemChrome.setSystemUIOverlayStyle(SystemUiOverlayStyle(
                    statusBarColor: Colors.transparent,
                    systemNavigationBarColor: Colors.transparent,
                  ));
                  widget.onBackPressed();
                },
                child: const Icon(
                  Icons.arrow_back_ios,
                  color: Colors.white,
                  size: 20,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBrightnessSlider() {
    // Custom vertical slider using RotatedBox
    return Container(
      width: 40,
      child: Column(
        mainAxisSize: MainAxisSize.max,
        children: [
          SvgPicture.asset(
             'assets/icons/brightness.svg',
             color: Colors.white,
             width: 24,
             height: 24,
          ),
          SizedBox(height: 10),
          Expanded(
            child: RotatedBox(
              quarterTurns: -1,
              child: SliderTheme(
                data: SliderTheme.of(context).copyWith(
                  activeTrackColor: Colors.white,
                  inactiveTrackColor: Colors.white24,
                  thumbColor: Colors.white,
                  trackHeight: 2.0,
                  thumbShape: RoundSliderThumbShape(enabledThumbRadius: 6.0),
                  overlayShape: RoundSliderOverlayShape(overlayRadius: 12.0),
                ),
                child: Slider(
                  value: _brightness,
                  onChanged: (value) {
                    setState(() {
                      _brightness = value;
                    });
                    try {
                      ScreenBrightness().setScreenBrightness(value);
                    } catch (e) {
                      print('Failed to set brightness: $e');
                    }
                  },
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCenterControls(VideoPlayerValue latestValue) {
    // 1. Desktop/Web Layout (Features Dead-Center Controls + Independent Slider)
    if (kIsWeb || Platform.isWindows || Platform.isLinux || Platform.isMacOS) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.only(bottom: 30),
        child: Stack(
          alignment: Alignment.center,
          children: [
            // Brightness Slider (Left Side)
            Align(
              alignment: Alignment.centerLeft,
              child: Padding(
                padding: const EdgeInsets.only(left: 50),
                child: SizedBox(
                  height: 180,
                  child: _buildBrightnessSlider(),
                ),
              ),
            ),

            // Center Playback Controls (Dead Center)
            // Center Playback Controls (Shifted Left)
            Transform.translate(
              offset: const Offset(-8, 0), // Desktop Shift
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  InkWell(
                    onTap: () {
                      controller?.seekTo(
                        latestValue.position - const Duration(seconds: 10),
                      );
                    },
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        SvgPicture.asset(
                          'assets/icons/rewind.svg',
                          color: Colors.white,
                          width: 48,
                          height: 48,
                        ),
                        const Text(
                          '10',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(width: 40),

                  InkWell(
                    onTap: _playPause,
                    child: Icon(
                      latestValue.isPlaying
                          ? Icons.pause_rounded
                          : Icons.play_arrow_rounded,
                      color: Colors.white,
                      size: 64,
                    ),
                  ),

                  const SizedBox(width: 40),

                  InkWell(
                    onTap: () {
                      controller?.seekTo(
                        latestValue.position + const Duration(seconds: 10),
                      );
                    },
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        SvgPicture.asset(
                          'assets/icons/forward.svg',
                          color: Colors.white,
                          width: 48,
                          height: 48,
                        ),
                        const Text(
                          '10',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    } 
    
    // 2. Mobile Layout (Android/iOS) - Preserves Original Design
    else {
      return Padding(
        padding: const EdgeInsets.only(bottom: 30),
        child: Row(
          children: [
            const Spacer(flex: 4),

            SizedBox(
              height: 180,
              child: _buildBrightnessSlider(),
            ),

            const SizedBox(width: 94),

            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                InkWell(
                  onTap: () {
                    controller?.seekTo(
                      latestValue.position - const Duration(seconds: 10),
                    );
                  },
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      SvgPicture.asset(
                        'assets/icons/rewind.svg',
                        color: Colors.white,
                        width: 48,
                        height: 48,
                      ),
                      const Text(
                        '10',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(width: 40),

                InkWell(
                  onTap: _playPause,
                  child: Icon(
                    latestValue.isPlaying
                        ? Icons.pause_rounded
                        : Icons.play_arrow_rounded,
                    color: Colors.white,
                    size: 64,
                  ),
                ),

                const SizedBox(width: 40),

                InkWell(
                  onTap: () {
                    controller?.seekTo(
                      latestValue.position + const Duration(seconds: 10),
                    );
                  },
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      SvgPicture.asset(
                        'assets/icons/forward.svg',
                        color: Colors.white,
                        width: 48,
                        height: 48,
                      ),
                      const Text(
                        '10',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),

            const Spacer(flex: 7),
          ],
        ),
      );
    }
  }

  Widget _buildLockOverlayButton() {
     return InkWell(
        onTap: () {
           setState(() {
              _isLocked = false;
              notifier.hideStuff = false;
              _startHideTimer();
           });
        },
        child: Container(
           padding: EdgeInsets.all(12),
           decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.2),
              shape: BoxShape.circle,
           ),
           child: Icon(Icons.lock_open, color: Colors.white, size: 28),
        ),
     );
  }

  @override
  void dispose() {
    _dispose();
    notifier.dispose();
    // Safety check: Restore system UI when widget is disposed
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    super.dispose();
  }

  void _dispose() {
    print('Disposing MaterialControlsState');

    // Remove listener safely - UpdateState listener no longer used
    // if (controller != null) {
    //   try {
    //     // Try to remove listener regardless of initialization state
    //      // controller!.removeListener(_updateState);
    //     print('Listener cleanup skipped');
    //   } catch (e) {
    //     print('Error removing listener: $e');
    //   }
    // }

    // Clear controller reference
    controller = null;

    // Cancel all timers
    // Cancel all timers
    _hideTimer?.cancel();
    _hideTimer = null;
    _initTimer?.cancel();
    _initTimer = null;
    _showAfterExpandCollapseTimer?.cancel();
    _showAfterExpandCollapseTimer = null;
    _skipResetTimer?.cancel();
    _skipResetTimer = null;

    // Dispose animation controller
    if (_controlsAnimationController != null) {
      print('Disposing AnimationController');
      _controlsAnimationController!.dispose();
      _controlsAnimationController = null;
    }

    // Clear state
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    print('didChangeDependencies called');
    final _oldController = _chewieController;
    _chewieController = widget.controller ?? ChewieController.of(context);
    
    if (_chewieController != null) {
      final newController = chewieController!.videoPlayerController;

      if (_oldController != _chewieController) {
        if (_oldController != null) {
          print('Disposing old controller');
          _dispose();
        }

        // Only initialize if the new controller is valid and initialized
        try {
          if (newController.value.isInitialized) {
            controller = newController;
            print('Initializing new controller');
            _initialize();
          } else {
            print('New controller not initialized yet, waiting...');
            // Wait for controller to be initialized
            late VoidCallback initListener;
            initListener = () {
              try {
                if (newController.value.isInitialized &&
                    mounted &&
                    controller == null) {
                  newController.removeListener(initListener);
                  controller = newController;
                  _initialize();
                }
              } catch (e) {
                print('Error in init listener: $e');
                // Try to remove listener even if there's an error
                try {
                  newController.removeListener(initListener);
                } catch (removeError) {
                  print('Error removing listener: $removeError');
                }
              }
            };

            try {
              newController.addListener(initListener);
            } catch (e) {
              print('Error adding init listener: $e');
            }
          }
        } catch (e) {
          print('Error accessing controller in didChangeDependencies: $e');
        }
      }
    }
  }

  ChewieController? get chewieController => _chewieController;

  void _initialize() {
    if (controller == null) {
      print('Controller is null, skipping _initialize');
      return;
    }

    try {
      // Check if controller is still valid before accessing
      if (!controller!.value.isInitialized) {
        print('Controller not initialized, skipping _initialize');
        return;
      }

      // Listener addition removed to avoid high frequency setState
      // controller!.addListener(_updateState);
      
      print('Controller initialized successfully');

      print('Controller initialized successfully');
    } catch (e) {
      print('Error in _initialize: $e');
      return;
    }

    if (_controlsAnimationController == null) {
      _controlsAnimationController = AnimationController(
        vsync: this,
        duration: const Duration(milliseconds: 300),
      );
    }

    _initTimer?.cancel();
    _initTimer = Timer(const Duration(milliseconds: 200), () {
      if (mounted) {
        setState(() {
          notifier.hideStuff = false;
          _updateSystemUI();
        });
      }
    });
  }

  void _updateSystemUI() {
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
  }

  void _updateState() {
     // No-op to satisfy listener requirement if needed, or remove listener entirely. 
     // We will remove the listener in _initialize and _dispose, but keeping an empty method if referenced.
     // However, we plan to remove the listener addition.
  }


  void _toggleControls() {
    _hideTimer?.cancel();

    setState(() {
      notifier.hideStuff = !notifier.hideStuff;
      _displayTapped = true;
      _updateSystemUI();
    });

    if (!notifier.hideStuff) {
      _startHideTimer();
    }
  }

  void _resetHideTimer() {
    _hideTimer?.cancel();
    if (mounted) {
      setState(() {
        notifier.hideStuff = false;
        _updateSystemUI();
      });
    }
    _startHideTimer();
  }

  void _startHideTimer() {
    _hideTimer?.cancel();
    _hideTimer = Timer(const Duration(seconds: 5), () {
      if (controller?.value.isPlaying == true) {
        if (mounted) {
          setState(() {
            notifier.hideStuff = true;
            _updateSystemUI();
          });
        }
      }
    });
  }

  void _cancelAndRestartTimer() {
    _hideTimer?.cancel();
    _startHideTimer();

    if (notifier.hideStuff) {
      if (mounted) {
        setState(() {
          notifier.hideStuff = false;
          _updateSystemUI();
        });
      }
    }
  }

  Widget _buildBottomBar(BuildContext context, VideoPlayerValue latestValue) {
    return Container(
      // Remove horizontal padding from main container to allow scrubber to be edge-to-edge
      padding: EdgeInsets.symmetric(vertical: 20), 
      color: Colors.transparent,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Duration Text (Aligned left, with proper padding)
          Align(
            alignment: Alignment.centerLeft,
            child: Padding(
              padding: const EdgeInsets.only(bottom: 8.0, left: 74.0), // Aligned with scrubber padding (74)
              child: _buildDurationText(latestValue),
            ),
          ),
          
          // Timeline
          Container(
            width: double.infinity,
            padding: EdgeInsets.symmetric(horizontal: 74), // Increased padding as requested
            child: _buildProgressBar(),
          ),
          SizedBox(height: 5), // Reduced from 10 to 5 to compensate for taller progress bar container
          
          // Actions Row (With restored original padding)
          Padding(
             padding: const EdgeInsets.symmetric(horizontal: 24.0),
             child: Row(
               mainAxisAlignment: MainAxisAlignment.spaceEvenly,
               children: [
              _buildActionIcon(
                'Speed (${latestValue.playbackSpeed.toString().replaceAll(RegExp(r"([.]*0)(?!.*\d)"), "")}x)', 
                'assets/icons/playback.svg', 
                () => _showSpeedDialog(),
              ),
              _buildActionIcon(
                'Lock', 
                'assets/icons/lock.svg', 
                () {
                  setState(() {
                    _isLocked = true;
                    notifier.hideStuff = true; // Immediately hide controls
                  });
                },
              ),
              _buildActionIcon(
                'Episodes', 
                'assets/icons/episode.svg', 
                widget.onShowEpisodes,
              ),
              _buildActionIcon(
                'Subtitles', 
                'assets/icons/subtitle.svg', 
                () {
                  // TODO: Implement new function here
                  // _showQualityDialog(); // Disabled as requested
                },
              ),
              _buildActionIcon(
                'Next Ep.', 
                'assets/icons/next.svg', 
                widget.onNextEpisode,
              ),
               ],
             ),
          ),
        ],
      ),
    );
  }

  Widget _buildProgressBar() {
    return Container(
      height: 30, // Increased from 20 to 30 to prevent overlay clipping (overlayRadius 12 = 24px + padding)
      child: controller != null
          ? MaterialVideoProgressBar(
              controller!,
              onDragStart: () {
                setState(() {
                  _dragging = true;
                });
                _hideTimer?.cancel();
              },
              onDragEnd: () {
                setState(() {
                  _dragging = false;
                });
                _startHideTimer();
              },
              colors: ChewieProgressColors(
                playedColor: Colors.red,
                handleColor: Colors.red,
                bufferedColor: Colors.white,
                backgroundColor: Colors.white24,
              ),
            )
          : Container(
              height: 4,
              color: Colors.white24,
            ),
    );
  }

  Widget _buildDurationText(VideoPlayerValue latestValue) {
    final duration = latestValue.duration;
    final position = latestValue.position;
    
    return Text(
      '${formatDuration(position)} / ${formatDuration(duration)}',
      style: TextStyle(
        color: Colors.white,
        fontSize: 12,
        fontWeight: FontWeight.bold,
      ),
    );
  }

  Widget _buildActionIcon(String label, String assetPath, VoidCallback? onTap) {
    return InkWell(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SvgPicture.asset(
            assetPath,
            color: Colors.white,
            width: 20,
            height: 20,
          ),
          SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(
              color: Colors.white,
              fontSize: 10,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
  
  // Unused legacy builders removed (PlayPause, Mute, Volume, etc) to clean up.


  void _showSpeedDialog() {
    final currentSpeed =
        chewieController?.videoPlayerController.value.playbackSpeed ?? 1.0;

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (BuildContext context) {
        return Container(
          decoration: BoxDecoration(
            color: Color(0xFF1E1E1E),
            borderRadius: BorderRadius.only(
              topLeft: Radius.circular(20),
              topRight: Radius.circular(20),
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Handle bar
              Container(
                margin: EdgeInsets.only(top: 12),
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey[600],
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              // Title
              Padding(
                padding: EdgeInsets.all(20),
                child: Row(
                  children: [
                    Icon(
                      Icons.speed,
                      color: Colors.white,
                      size: 24,
                    ),
                    SizedBox(width: 12),
                    Text(
                      'Kecepatan Pemutaran',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              // Speed options
              Expanded(
                child: ListView(
                  shrinkWrap: true,
                  children: [
                    _buildSpeedOption(
                        '0.25x', 'Sangat Lambat', 0.25, currentSpeed == 0.25),
                    _buildSpeedOption(
                        '0.5x', 'Lambat', 0.5, currentSpeed == 0.5),
                    _buildSpeedOption(
                        '0.75x', 'Agak Lambat', 0.75, currentSpeed == 0.75),
                    _buildSpeedOption(
                        'Normal', 'Kecepatan Normal', 1.0, currentSpeed == 1.0),
                    _buildSpeedOption(
                        '1.25x', 'Agak Cepat', 1.25, currentSpeed == 1.25),
                    _buildSpeedOption(
                        '1.5x', 'Cepat', 1.5, currentSpeed == 1.5),
                    _buildSpeedOption(
                        '2x', 'Sangat Cepat', 2.0, currentSpeed == 2.0),
                  ],
                ),
              ),
              SizedBox(height: 20),
            ],
          ),
        );
      },
    ).then((_) {
      // Restart timer when dialog closes, if playing
      if (controller?.value.isPlaying == true) {
        _startHideTimer();
      }
    });
  }

  Widget _buildSpeedOption(
      String speed, String description, double value, bool isSelected) {
    return InkWell(
      onTap: () {
        chewieController?.videoPlayerController.setPlaybackSpeed(value);
        Navigator.pop(context);
      },
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        child: Row(
          children: [
            Container(
              width: 20,
              height: 20,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: isSelected ? Colors.red : Colors.grey[600]!,
                  width: 2,
                ),
              ),
              child: isSelected
                  ? Center(
                      child: Container(
                        width: 10,
                        height: 10,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: Colors.red,
                        ),
                      ),
                    )
                  : null,
            ),
            SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    speed,
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight:
                          isSelected ? FontWeight.w600 : FontWeight.w400,
                    ),
                  ),
                  if (description.isNotEmpty)
                    Text(
                      description,
                      style: TextStyle(
                        color: Colors.grey[400],
                        fontSize: 14,
                      ),
                    ),
                ],
              ),
            ),
            if (isSelected)
              Icon(
                Icons.check,
                color: Colors.red,
                size: 20,
              ),
          ],
        ),
      ),
    );
  }

  void _showQualityDialog() {
    if (widget.qualityOptions.isEmpty) return;

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (BuildContext context) {
        return Container(
          decoration: BoxDecoration(
            color: Color(0xFF1E1E1E),
            borderRadius: BorderRadius.only(
              topLeft: Radius.circular(20),
              topRight: Radius.circular(20),
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Handle bar
              Container(
                margin: EdgeInsets.only(top: 12),
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey[600],
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              // Title
              Padding(
                padding: EdgeInsets.all(20),
                child: Row(
                  children: [
                    Icon(
                      Icons.tune,
                      color: Colors.white,
                      size: 24,
                    ),
                    SizedBox(width: 12),
                    Text(
                      'Kualitas Video',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              // Quality options
              Expanded(
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: widget.qualityOptions.length,
                  itemBuilder: (context, index) {
                    final item = widget.qualityOptions[index];
                    final isSelected =
                        widget.selectedQuality == item['quality'];
                    return _buildQualityOption(
                      item['quality'] ?? 'Unknown',
                      _getQualityDescription(item['quality'] ?? ''),
                      item['url'] ?? '',
                      item['quality'] ?? '',
                      isSelected,
                    );
                  },
                ),
              ),
              SizedBox(height: 20),
            ],
          ),
        );
      },
    ).then((_) {
      // Restart timer when dialog closes, if playing
      if (controller?.value.isPlaying == true) {
        _startHideTimer();
      }
    });
  }

  String _getQualityDescription(String quality) {
    switch (quality.toLowerCase()) {
      case '1080p':
        return 'Full HD';
      case '720p':
        return 'HD';
      case '480p':
        return 'SD';
      case '360p':
        return 'Rendah';
      case '240p':
        return 'Sangat Rendah';
      default:
        return '';
    }
  }

  Widget _buildQualityOption(String quality, String description, String url,
      String qualityValue, bool isSelected) {
    return InkWell(
      onTap: () {
        Navigator.pop(context);
        if (widget.onQualityChanged != null) {
          widget.onQualityChanged!(url, qualityValue);
        }
      },
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        child: Row(
          children: [
            Container(
              width: 20,
              height: 20,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: isSelected ? Colors.red : Colors.grey[600]!,
                  width: 2,
                ),
              ),
              child: isSelected
                  ? Center(
                      child: Container(
                        width: 10,
                        height: 10,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: Colors.red,
                        ),
                      ),
                    )
                  : null,
            ),
            SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    quality,
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight:
                          isSelected ? FontWeight.w600 : FontWeight.w400,
                    ),
                  ),
                  if (description.isNotEmpty)
                    Text(
                      description,
                      style: TextStyle(
                        color: Colors.grey[400],
                        fontSize: 14,
                      ),
                    ),
                ],
              ),
            ),
            if (isSelected)
              Icon(
                Icons.check,
                color: Colors.red,
                size: 20,
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildSubtitles(BuildContext context, VideoPlayerValue latestValue) {
    final subtitle = _subtitleOn
        ? chewieController!.subtitle?.getByPosition(latestValue.position)
        : null;
    if (subtitle == null) {
      return const SizedBox();
    }

    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: Colors.black.withOpacity(0.8),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: Colors.white.withOpacity(0.1),
            width: 1,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.3),
              blurRadius: 8,
              offset: Offset(0, 2),
            ),
          ],
        ),
        child: Text(
          subtitle.toString(),
          style: TextStyle(
            fontSize: 16,
            color: Colors.white,
            fontWeight: FontWeight.w500,
            letterSpacing: 0.3,
            height: 1.4,
          ),
          textAlign: TextAlign.center,
        ),
      ),
    );
  }

  void _playPause() {
    if (controller == null || !mounted) return;

    try {
      final isFinished = (controller!.value.position) >=
          (controller!.value.duration);

      setState(() {
        if (controller!.value.isPlaying) {
          notifier.hideStuff = false;
          _hideTimer?.cancel();
          controller!.pause();
        } else {
          _resetHideTimer();

          if (!controller!.value.isInitialized) {
            controller!.initialize().then((_) {
              if (mounted && controller != null) {
                controller!.play();
              }
            });
          } else {
            if (isFinished) {
              controller!.seekTo(Duration.zero);
            }
            controller!.play();
          }
        }
      });
    } catch (e) {
      print('Error in _playPause: $e');
    }
  }

  String formatDuration(Duration position) {
    final ms = position.inMilliseconds;

    int seconds = ms ~/ 1000;
    final int hours = seconds ~/ 3600;
    seconds = seconds % 3600;
    final minutes = seconds ~/ 60;
    seconds = seconds % 60;

    final hoursString = hours >= 10
        ? '$hours'
        : hours == 0
            ? '00'
            : '0$hours';

    final minutesString = minutes >= 10
        ? '$minutes'
        : minutes == 0
            ? '00'
            : '0$minutes';

    final secondsString = seconds >= 10
        ? '$seconds'
        : seconds == 0
            ? '00'
            : '0$seconds';

    final formattedTime =
        '${hoursString == '00' ? '' : '$hoursString:'}$minutesString:$secondsString';

    return formattedTime;
  }


  void _handleDoubleTap() {
    if (_lastTapDownPosition == null) return;

    final screenWidth = MediaQuery.of(context).size.width;
    final isRightSide = _lastTapDownPosition!.dx > screenWidth / 2;

    if (_isSkipping) {
      if (_isForwardSkip == isRightSide) {
        _incrementSkip();
      } else {
        _incrementSkip();
      }
    } else {
      // Start skipping
      setState(() {
        _isSkipping = true;
        _isForwardSkip = isRightSide;
        _skipAmount = 5; // Initial skip amount
        // Force HIDE controls when skipping starts
        notifier.hideStuff = true;
      });
      // Do NOT toggle controls here. Just start the skip timer.
      _startSkipResetTimer();
      
      // Cancel auto-hide timer since controls are hidden
      _hideTimer?.cancel();
    }
  }

  void _incrementSkip() {
    setState(() {
      _skipAmount += 5;
    });
    _startSkipResetTimer();
    // Again, do not touch control visibility timer
  }

  void _startSkipResetTimer() {
    _skipResetTimer?.cancel();
    _skipResetTimer = Timer(const Duration(milliseconds: 1000), () {
      _performSkip();
    });
  }

  void _performSkip() {
    if (controller == null || !controller!.value.isInitialized) return;

    final currentPos = controller!.value.position;
    final skipDuration = Duration(seconds: _skipAmount);
    final newPos = _isForwardSkip
        ? currentPos + skipDuration
        : currentPos - skipDuration;

    // Clamp position
    final duration = controller!.value.duration;
    final clampedPos = newPos < Duration.zero
        ? Duration.zero
        : (newPos > duration ? duration : newPos);

    controller!.seekTo(clampedPos);

    if (mounted) {
      setState(() {
        _isSkipping = false;
        _skipAmount = 0;
      });
    }
  }

  Widget _buildSkipOverlay() {
    return Positioned.fill(
      child: IgnorePointer(
        child: Row(
          children: [
            Expanded(
              child: !_isForwardSkip
                  ? Container(
                      color: Colors.white.withOpacity(0.1),
                      child: Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.fast_rewind_rounded,
                                size: 48, color: Colors.white),
                            SizedBox(height: 8),
                            Text(
                              '${_skipAmount}s',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),
                    )
                  : SizedBox(),
            ),
            Expanded(
              child: _isForwardSkip
                  ? Container(
                      color: Colors.white.withOpacity(0.1),
                      child: Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.fast_forward_rounded,
                                size: 48, color: Colors.white),
                            SizedBox(height: 8),
                            Text(
                              '+${_skipAmount}s',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),
                    )
                  : SizedBox(),
            ),
          ],
        ),
      ),
    );
  }
}

class _PlaybackSpeedDialog extends StatelessWidget {
  const _PlaybackSpeedDialog({
    Key? key,
    required List<double> speeds,
    required double selected,
  })  : _speeds = speeds,
        _selected = selected,
        super(key: key);

  final List<double> _speeds;
  final double _selected;

  @override
  Widget build(BuildContext context) {
    final Color selectedColor = Theme.of(context).primaryColor;

    return ListView.builder(
      shrinkWrap: true,
      physics: const ScrollPhysics(),
      itemBuilder: (context, index) {
        final _speed = _speeds[index];
        return ListTile(
          dense: true,
          title: Row(
            children: [
              if (_speed == _selected)
                Icon(
                  Icons.check,
                  size: 20.0,
                  color: selectedColor,
                )
              else
                Container(width: 20.0),
              const SizedBox(width: 16.0),
              Text(_speed.toString()),
            ],
          ),
          selected: _speed == _selected,
          onTap: () {
            Navigator.of(context).pop(_speed);
          },
        );
      },
      itemCount: _speeds.length,
    );
  }
}

class MaterialVideoProgressBar extends StatefulWidget {
  MaterialVideoProgressBar(
    this.controller, {
    ChewieProgressColors? colors,
    this.onDragEnd,
    this.onDragStart,
    this.onDragUpdate,
    Key? key,
  })  : colors = colors ?? ChewieProgressColors(),
        super(key: key);

  final VideoPlayerController controller;
  final ChewieProgressColors colors;
  final Function()? onDragStart;
  final Function()? onDragEnd;
  final Function()? onDragUpdate;

  @override
  _MaterialVideoProgressBarState createState() =>
      _MaterialVideoProgressBarState();
}

class _MaterialVideoProgressBarState extends State<MaterialVideoProgressBar> {
  void listener() {
    if (!mounted) return;

    try {
      // Check if controller is still valid before triggering setState
      if (controller.value.isInitialized) {
        setState(() {});
      }
    } catch (e) {
      print('Error in MaterialVideoProgressBar listener: $e');
    }
  }

  bool _controllerWasPlaying = false;

  VideoPlayerController get controller => widget.controller;

  @override
  void initState() {
    super.initState();
    try {
      if (controller.value.isInitialized) {
        controller.addListener(listener);
      }
    } catch (e) {
      print('Error adding listener in MaterialVideoProgressBar initState: $e');
    }
  }

  @override
  void deactivate() {
    try {
      controller.removeListener(listener);
    } catch (e) {
      print('Error removing listener in MaterialVideoProgressBar: $e');
    }
    super.deactivate();
  }

  @override
  Widget build(BuildContext context) {
    try {
      if (!controller.value.isInitialized) {
        return const SizedBox();
      }
    } catch (e) {
      print('Error accessing controller in MaterialVideoProgressBar build: $e');
      return const SizedBox();
    }

    Duration duration;
    Duration position;

    try {
      duration = controller.value.duration;
      position = controller.value.position;
    } catch (e) {
      print(
          'Error accessing controller values in MaterialVideoProgressBar: $e');
      return const SizedBox();
    }

    if (duration.inMilliseconds == 0) {
      return const SizedBox();
    }

    return SliderTheme(
      data: SliderTheme.of(context).copyWith(
        trackHeight: 1.5, // Thinner track (1.5) as requested
        trackShape: _CustomTrackShape(),
        thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6.0), // Smaller thumb
        overlayShape: const RoundSliderOverlayShape(overlayRadius: 12.0),
        activeTrackColor: Colors.red,
        inactiveTrackColor: Colors.white.withOpacity(0.2), // More subtle inactive track
        thumbColor: Colors.red,
        overlayColor: Colors.red.withAlpha(50),
      ),
      child: GestureDetector(
        onTapDown: (details) {
          try {
            if (!controller.value.isInitialized) return;

            // Calculate position based on tap location
            final RenderBox box = context.findRenderObject() as RenderBox;
            final Offset localOffset =
                box.globalToLocal(details.globalPosition);
            final double progress = localOffset.dx / box.size.width;
            final double seekPosition = progress * duration.inMilliseconds;

            if (seekPosition >= 0 && seekPosition <= duration.inMilliseconds) {
              controller.seekTo(Duration(milliseconds: seekPosition.toInt()));
            }
          } catch (e) {
            print('Error in MaterialVideoProgressBar onTapDown: $e');
          }
        },
        child: Slider(
          value: position.inMilliseconds.toDouble(),
          min: 0.0,
          max: duration.inMilliseconds.toDouble(),
          onChanged: (value) {
            try {
              if (controller.value.isInitialized) {
                setState(() {
                  controller.seekTo(Duration(milliseconds: value.toInt()));
                });
              }
              if (widget.onDragUpdate != null) {
                widget.onDragUpdate!();
              }
            } catch (e) {
              print('Error in MaterialVideoProgressBar onChanged: $e');
            }
          },
          onChangeStart: (value) {
            try {
              if (widget.onDragStart != null) {
                widget.onDragStart!();
              }
              _controllerWasPlaying =
                  controller.value.isInitialized && controller.value.isPlaying;
              if (_controllerWasPlaying && controller.value.isInitialized) {
                controller.pause();
              }
            } catch (e) {
              print('Error in MaterialVideoProgressBar onChangeStart: $e');
            }
          },
          onChangeEnd: (value) {
            try {
              if (_controllerWasPlaying && controller.value.isInitialized) {
                controller.play();
              }
              if (widget.onDragEnd != null) {
                widget.onDragEnd!();
              }
            } catch (e) {
              print('Error in MaterialVideoProgressBar onChangeEnd: $e');
            }
          },
        ),
      ),
    );
  }
}

class _CustomTrackShape extends RoundedRectSliderTrackShape {
  @override
  Rect getPreferredRect({
    required RenderBox parentBox,
    Offset offset = Offset.zero,
    required SliderThemeData sliderTheme,
    bool isEnabled = false,
    bool isDiscrete = false,
  }) {
    final trackHeight = sliderTheme.trackHeight;
    final trackLeft = offset.dx;
    final trackTop = offset.dy + (parentBox.size.height - trackHeight!) / 2;
    final trackWidth = parentBox.size.width;
    return Rect.fromLTWH(trackLeft, trackTop, trackWidth, trackHeight);
  }
}

class PlayerNotifier extends ChangeNotifier {
  bool _hideStuff = false;
  bool get hideStuff => _hideStuff;
  set hideStuff(bool value) {
    _hideStuff = value;
    notifyListeners();
  }
}

class Provider<T> extends InheritedWidget {
  final T value;

  const Provider({
    Key? key,
    required this.value,
    required Widget child,
  }) : super(key: key, child: child);

  static T of<T>(BuildContext context, {bool listen = true}) {
    final provider = listen
        ? context.dependOnInheritedWidgetOfExactType<Provider<T>>()
        : context.getElementForInheritedWidgetOfExactType<Provider<T>>()?.widget
            as Provider<T>?;
    if (provider == null) {
      throw FlutterError(
          'Provider<$T> not found. Make sure to wrap your widget tree with Provider<$T>.');
    }
    return provider.value;
  }

  @override
  bool updateShouldNotify(Provider<T> oldWidget) {
    return value != oldWidget.value;
  }
}