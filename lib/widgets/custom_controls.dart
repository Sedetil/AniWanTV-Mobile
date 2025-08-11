import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:chewie/chewie.dart';
import 'package:video_player/video_player.dart';
import 'dart:async';

class CustomControls extends StatefulWidget {
  final Color backgroundColor;
  final Color iconColor;
  final String title;
  final VoidCallback onBackPressed;
  final List<Map<String, String>> qualityOptions;
  final String selectedQuality;
  final Function(String, String)? onQualityChanged;

  const CustomControls({
    Key? key,
    this.backgroundColor = Colors.black54,
    this.iconColor = Colors.white,
    required this.title,
    required this.onBackPressed,
    this.qualityOptions = const [],
    this.selectedQuality = '',
    this.onQualityChanged,
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
      customAppBar: _buildCustomAppBar(context),
      qualityOptions: widget.qualityOptions,
      selectedQuality: widget.selectedQuality,
      onQualityChanged: widget.onQualityChanged,
    );
  }

  Widget _buildCustomAppBar(BuildContext context) {
    return Container(
      height: 70,
      padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Colors.black.withOpacity(0.85),
            Colors.black.withOpacity(0.6),
            Colors.transparent,
          ],
        ),
      ),
      child: SafeArea(
        child: Row(
          children: [
            Material(
              color: Colors.transparent,
              child: InkWell(
                borderRadius: BorderRadius.circular(20),
                onTap: widget.onBackPressed,
                child: Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.4),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: Colors.white.withOpacity(0.1),
                      width: 1,
                    ),
                  ),
                  child: Icon(
                    Icons.arrow_back_ios_rounded,
                    color: Colors.white,
                    size: 18,
                  ),
                ),
              ),
            ),
            SizedBox(width: 16),
            Expanded(
              child: Container(
                padding: EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.4),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: Colors.white.withOpacity(0.1),
                    width: 1,
                  ),
                ),
                child: Text(
                  widget.title,
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.3,
                  ),
                  overflow: TextOverflow.ellipsis,
                  maxLines: 1,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class MaterialControls extends StatefulWidget {
  const MaterialControls({
    Key? key,
    this.showPlayButton = true,
    this.backgroundColor = Colors.black54,
    this.iconColor = Colors.white,
    this.customAppBar,
    this.qualityOptions = const [],
    this.selectedQuality = '',
    this.onQualityChanged,
  }) : super(key: key);

  final bool showPlayButton;
  final Color backgroundColor;
  final Color iconColor;
  final Widget? customAppBar;
  final List<Map<String, String>> qualityOptions;
  final String selectedQuality;
  final Function(String, String)? onQualityChanged;

  @override
  State<MaterialControls> createState() => _MaterialControlsState();
}

class _MaterialControlsState extends State<MaterialControls>
    with TickerProviderStateMixin {
  late PlayerNotifier notifier;
  VideoPlayerValue? _latestValue;
  Timer? _hideTimer;
  Timer? _initTimer;
  late var _subtitlesPosition = Duration.zero;
  bool _subtitleOn = false;
  Timer? _showAfterExpandCollapseTimer;
  bool _dragging = false;
  bool _displayTapped = false;

  final barHeight = 48.0;
  final marginSize = 5.0;

  VideoPlayerController? controller;
  ChewieController? _chewieController;
  AnimationController? _controlsAnimationController;

  @override
  void initState() {
    super.initState();
    notifier = PlayerNotifier();
  }

  @override
  Widget build(BuildContext context) {
    if (_chewieController == null || _latestValue?.hasError == true) {
      return chewieController?.errorBuilder?.call(
            context,
            chewieController?.videoPlayerController.value.errorDescription ??
                'Error loading video',
          ) ??
          const Center(
            child: Icon(
              Icons.error,
              color: Colors.white,
              size: 42,
            ),
          );
    }

    return MouseRegion(
      onHover: (_) {
        if (notifier.hideStuff) {
          setState(() {
            notifier.hideStuff = false;
          });
          _startHideTimer();
        }
      },
      child: GestureDetector(
        onTap: () => _cancelAndRestartTimer(),
        child: AbsorbPointer(
          absorbing: false,
          child: Stack(
            children: [
              if (widget.customAppBar != null && !notifier.hideStuff)
                Positioned(
                  top: 0,
                  left: 0,
                  right: 0,
                  child: widget.customAppBar!,
                ),
              if (_latestValue?.isBuffering == true)
                const Center(
                  child: CircularProgressIndicator(),
                ),
              Column(
                mainAxisAlignment: MainAxisAlignment.end,
                children: <Widget>[
                  if (_subtitleOn)
                    Padding(
                      padding: EdgeInsets.only(
                        left: 20.0,
                        right: 20.0,
                        bottom: 5.0,
                      ),
                      child: _buildSubtitles(context),
                    ),
                  _buildBottomBar(context),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _dispose();
    notifier.dispose();
    super.dispose();
  }

  void _dispose() {
    print('Disposing MaterialControlsState');

    // Remove listener safely
    if (controller != null) {
      try {
        // Try to remove listener regardless of initialization state
        controller!.removeListener(_updateState);
        print('Listener removed successfully');
      } catch (e) {
        print('Error removing listener: $e');
      }
    }

    // Clear controller reference
    controller = null;

    // Cancel all timers
    _hideTimer?.cancel();
    _hideTimer = null;
    _initTimer?.cancel();
    _initTimer = null;
    _showAfterExpandCollapseTimer?.cancel();
    _showAfterExpandCollapseTimer = null;

    // Dispose animation controller
    if (_controlsAnimationController != null) {
      print('Disposing AnimationController');
      _controlsAnimationController!.dispose();
      _controlsAnimationController = null;
    }

    // Clear state
    _latestValue = null;
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    print('didChangeDependencies called');
    final _oldController = _chewieController;
    _chewieController = ChewieController.of(context);

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

      // Remove any existing listener first
      try {
        controller!.removeListener(_updateState);
      } catch (e) {
        print('Error removing existing listener: $e');
      }

      // Add new listener
      controller!.addListener(_updateState);
      // Initialize _latestValue immediately
      _latestValue = controller!.value;
      _updateState();
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
        });
      }
    });
  }

  void _updateState() {
    if (!mounted || controller == null) return;

    try {
      // Double check controller is still valid before accessing
      if (!controller!.value.isInitialized) {
        print('Controller not initialized in _updateState');
        return;
      }

      setState(() {
        _latestValue = controller!.value;
        _subtitlesPosition = controller!.value.position;
      });
    } catch (e) {
      print('Error updating state: $e');
      // If there's an error, try to clean up the controller reference
      controller = null;
    }
  }

  void _cancelAndRestartTimer() {
    _hideTimer?.cancel();

    setState(() {
      notifier.hideStuff = !notifier.hideStuff;
      _displayTapped = true;
    });

    if (!notifier.hideStuff) {
      _startHideTimer();
    }
  }

  void _startHideTimer() {
    _hideTimer = Timer(const Duration(seconds: 3), () {
      if (_latestValue?.isPlaying == true) {
        if (mounted) {
          setState(() {
            notifier.hideStuff = true;
          });
        }
      }
    });
  }

  Widget _buildBottomBar(BuildContext context) {
    final iconColor = widget.iconColor;
    final backgroundColor = widget.backgroundColor;

    return AnimatedOpacity(
      opacity: notifier.hideStuff ? 0.0 : 1.0,
      duration: const Duration(milliseconds: 300),
      child: IgnorePointer(
        ignoring: notifier.hideStuff,
        child: Container(
          height: 80,
          padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                Colors.transparent,
                Colors.black.withOpacity(0.6),
                Colors.black.withOpacity(0.85),
              ],
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Progress bar on top with better spacing
              Container(
                height: 16,
                margin: EdgeInsets.symmetric(horizontal: 4, vertical: 4),
                child: _buildProgressBar(),
              ),
              SizedBox(height: 8),
              // Controls row with better layout
              Expanded(
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    // Left controls
                    Row(
                      children: [
                        _buildPlayPause(controller),
                        SizedBox(width: 12),
                        if (chewieController!.allowMuting)
                          _buildMuteButton(controller),
                        SizedBox(width: 12),
                        _buildPosition(iconColor),
                      ],
                    ),
                    // Right controls
                    Row(
                      children: [
                        if (chewieController!.allowPlaybackSpeedChanging) ...[
                          _buildSpeedButton(controller),
                          SizedBox(width: 12),
                        ],
                        if (widget.qualityOptions.isNotEmpty) ...[
                          _buildQualityButton(),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPlayPause(VideoPlayerController? controller) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(24),
        onTap: _playPause,
        child: Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            color: Colors.black.withOpacity(0.4),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(
              color: Colors.white.withOpacity(0.2),
              width: 1,
            ),
          ),
          child: Icon(
            controller?.value.isPlaying == true
                ? Icons.pause_rounded
                : Icons.play_arrow_rounded,
            color: Colors.white,
            size: 24,
          ),
        ),
      ),
    );
  }

  Widget _buildMuteButton(VideoPlayerController? controller) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: () {
          if (controller != null) {
            setState(() {
              if (controller!.value.volume > 0) {
                controller!.setVolume(0);
              } else {
                controller!.setVolume(1.0);
              }
            });
          }
        },
        child: Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: Colors.black.withOpacity(0.3),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Icon(
            (controller?.value.volume ?? 0) > 0
                ? Icons.volume_up_rounded
                : Icons.volume_off_rounded,
            color: Colors.white,
            size: 20,
          ),
        ),
      ),
    );
  }

  Widget _buildPosition(Color iconColor) {
    final position = _latestValue?.position ?? Duration.zero;
    final duration = _latestValue?.duration ?? Duration.zero;

    return Container(
      padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.4),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: Colors.white.withOpacity(0.1),
          width: 1,
        ),
      ),
      child: Text(
        '${formatDuration(position)} / ${formatDuration(duration)}',
        style: TextStyle(
          fontSize: 12.0,
          color: Colors.white,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.5,
        ),
      ),
    );
  }

  Widget _buildProgressBar() {
    return Container(
      height: 12,
      padding: EdgeInsets.symmetric(vertical: 2),
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
                bufferedColor: Colors.white.withOpacity(0.3),
                backgroundColor: Colors.white.withOpacity(0.1),
              ),
            )
          : Container(
              height: 4,
              color: Colors.white.withOpacity(0.1),
            ),
    );
  }

  Widget _buildSpeedButton(VideoPlayerController? controller) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: () => _showSpeedDialog(),
        child: Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: Colors.black.withOpacity(0.3),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Icon(
            Icons.speed_rounded,
            color: Colors.white,
            size: 20,
          ),
        ),
      ),
    );
  }

  Widget _buildQualityButton() {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: () => _showQualityDialog(),
        child: Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: Colors.black.withOpacity(0.3),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Icon(
            Icons.tune_rounded,
            color: Colors.white,
            size: 20,
          ),
        ),
      ),
    );
  }

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
    );
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
    );
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

  Widget _buildSubtitles(BuildContext context) {
    final subtitle = _subtitleOn
        ? chewieController!.subtitle?.getByPosition(_subtitlesPosition)
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
      final isFinished = (_latestValue?.position ?? Duration.zero) >=
          (_latestValue?.duration ?? Duration.zero);

      setState(() {
        if (controller!.value.isPlaying) {
          notifier.hideStuff = false;
          _hideTimer?.cancel();
          controller!.pause();
        } else {
          _cancelAndRestartTimer();

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
        trackHeight: 4.0,
        trackShape: _CustomTrackShape(),
        thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 10.0),
        overlayShape: const RoundSliderOverlayShape(overlayRadius: 20.0),
        activeTrackColor: Colors.red,
        inactiveTrackColor: Colors.grey.shade800,
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
