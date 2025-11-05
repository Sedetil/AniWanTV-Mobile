import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../theme/app_theme.dart';
import '../services/app_version_service.dart';

class UpdateDialog extends StatefulWidget {
  final String? latestVersion;
  final String? changelog;

  const UpdateDialog({
    Key? key,
    this.latestVersion,
    this.changelog,
  }) : super(key: key);

  static Future<void> show({
    required BuildContext context,
    String? latestVersion,
    String? changelog,
  }) {
    return showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => UpdateDialog(
        latestVersion: latestVersion,
        changelog: changelog,
      ),
    );
  }

  @override
  _UpdateDialogState createState() => _UpdateDialogState();
}

class _UpdateDialogState extends State<UpdateDialog>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _scaleAnimation;
  bool _isDownloading = false;
  double _downloadProgress = 0.0;
  String _downloadStatus = 'Mempersiapkan download...';

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    _scaleAnimation = CurvedAnimation(
      parent: _animationController,
      curve: Curves.elasticOut,
    );
    _animationController.forward();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  Future<void> _onUpdatePressed() async {
    setState(() {
      _isDownloading = true;
      _downloadStatus = 'Mengunduh update...';
    });

    HapticFeedback.lightImpact();

    try {
      final downloadUrl = await AppVersionService.getDownloadUrl();
      if (downloadUrl == null) {
        _showError('URL download tidak tersedia');
        return;
      }

      await AppVersionService.downloadAndInstallApk(
        downloadUrl: downloadUrl,
        onProgress: (progress) {
          setState(() {
            _downloadProgress = progress;
            if (progress < 1.0) {
              _downloadStatus = 'Mengunduh... ${(progress * 100).toInt()}%';
            } else {
              _downloadStatus = 'Menginstall...';
            }
          });
        },
        onComplete: () {
          setState(() {
            _downloadStatus = 'Install selesai!';
            _downloadProgress = 1.0;
          });
          
          Future.delayed(const Duration(seconds: 2), () {
            if (mounted) {
              Navigator.of(context).pop();
            }
          });
        },
        onError: (error) {
          _showError(error);
        },
      );
    } catch (e) {
      _showError('Terjadi kesalahan: $e');
    }
  }

  void _showError(String message) {
    if (mounted) {
      setState(() {
        _isDownloading = false;
        _downloadStatus = message;
      });
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: AppTheme.errorColor,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppTheme.radiusSmall),
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final screenHeight = MediaQuery.of(context).size.height;
    final screenWidth = MediaQuery.of(context).size.width;
    final isTablet = screenWidth > 600;

    return ScaleTransition(
      scale: _scaleAnimation,
      child: Dialog(
        backgroundColor: Colors.transparent,
        child: Container(
          width: isTablet ? screenWidth * 0.4 : screenWidth * 0.85,
          constraints: BoxConstraints(
            maxHeight: screenHeight * 0.8,
            minHeight: _isDownloading ? 320 : 200,
          ),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                AppTheme.cardColor,
                AppTheme.surfaceColor,
              ],
            ),
            borderRadius: BorderRadius.circular(AppTheme.radiusLarge),
            border: Border.all(
              color: AppTheme.primaryColor.withOpacity(0.2),
              width: 1.5,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.3),
                blurRadius: 20,
                spreadRadius: 0,
                offset: Offset(0, 10),
              ),
              BoxShadow(
                color: AppTheme.primaryColor.withOpacity(0.2),
                blurRadius: 30,
                spreadRadius: 0,
                offset: Offset(0, 15),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Header dengan gradient
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  gradient: AppTheme.primaryGradient,
                  borderRadius: BorderRadius.only(
                    topLeft: Radius.circular(AppTheme.radiusLarge),
                    topRight: Radius.circular(AppTheme.radiusLarge),
                  ),
                ),
                child: Column(
                  children: [
                    Icon(
                      _isDownloading ? Icons.download : Icons.system_update,
                      color: Colors.white,
                      size: isTablet ? 48 : 40,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      _isDownloading ? 'Mengunduh Update' : 'Update Tersedia',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: isTablet ? 24 : 20,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 0.5,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    if (widget.latestVersion != null) ...[
                      const SizedBox(height: 8),
                      Text(
                        'Versi ${widget.latestVersion}',
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.9),
                          fontSize: isTablet ? 16 : 14,
                          fontWeight: FontWeight.w500,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ],
                ),
              ),

              // Content
              Flexible(
                child: Container(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (!_isDownloading) ...[
                        Text(
                          'Versi terbaru sudah tersedia. Silakan update untuk pengalaman terbaik.',
                          style: TextStyle(
                            color: AppTheme.textPrimaryColor,
                            fontSize: isTablet ? 16 : 14,
                            height: 1.5,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        if (widget.changelog != null && widget.changelog!.isNotEmpty) ...[
                          const SizedBox(height: 20),
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: AppTheme.backgroundColor.withOpacity(0.5),
                              borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
                              border: Border.all(
                                color: AppTheme.primaryColor.withOpacity(0.1),
                                width: 1,
                              ),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Apa yang baru:',
                                  style: TextStyle(
                                    color: AppTheme.primaryColor,
                                    fontSize: isTablet ? 16 : 14,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  widget.changelog!,
                                  style: TextStyle(
                                    color: AppTheme.textSecondaryColor,
                                    fontSize: isTablet ? 14 : 12,
                                    height: 1.4,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ] else ...[
                        const SizedBox(height: 20),
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: AppTheme.backgroundColor.withOpacity(0.5),
                            borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
                            border: Border.all(
                              color: AppTheme.primaryColor.withOpacity(0.1),
                              width: 1,
                            ),
                          ),
                          child: Column(
                            children: [
                              Container(
                                height: 8,
                                decoration: BoxDecoration(
                                  color: AppTheme.backgroundColor,
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Stack(
                                  children: [
                                    Container(
                                      width: double.infinity,
                                      height: 8,
                                      decoration: BoxDecoration(
                                        color: AppTheme.backgroundColor,
                                        borderRadius: BorderRadius.circular(4),
                                      ),
                                    ),
                                    AnimatedContainer(
                                      duration: const Duration(milliseconds: 300),
                                      width: MediaQuery.of(context).size.width * _downloadProgress * 0.7,
                                      height: 8,
                                      decoration: BoxDecoration(
                                        gradient: AppTheme.primaryGradient,
                                        borderRadius: BorderRadius.circular(4),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 12),
                              Text(
                                _downloadStatus,
                                style: TextStyle(
                                  color: AppTheme.textPrimaryColor,
                                  fontSize: isTablet ? 16 : 14,
                                  fontWeight: FontWeight.w500,
                                ),
                                textAlign: TextAlign.center,
                              ),
                              if (_downloadProgress > 0)
                                Column(
                                  children: [
                                    const SizedBox(height: 8),
                                    Text(
                                      '${(_downloadProgress * 100).toInt()}% Complete',
                                      style: TextStyle(
                                        color: AppTheme.primaryColor,
                                        fontSize: isTablet ? 14 : 12,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ],
                                ),
                            ],
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),

              // Action buttons
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: AppTheme.backgroundColor.withOpacity(0.3),
                  borderRadius: BorderRadius.only(
                    bottomLeft: Radius.circular(AppTheme.radiusLarge),
                    bottomRight: Radius.circular(AppTheme.radiusLarge),
                  ),
                ),
                child: _isDownloading
                    ? Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        child: Center(
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  valueColor: AlwaysStoppedAnimation<Color>(
                                    AppTheme.primaryColor,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Text(
                                _downloadStatus,
                                style: TextStyle(
                                  color: AppTheme.textPrimaryColor,
                                  fontSize: isTablet ? 16 : 14,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ),
                      )
                    : Row(
                        children: [
                          Expanded(
                            child: TextButton(
                              onPressed: () {
                                HapticFeedback.lightImpact();
                                Navigator.of(context).pop();
                              },
                              style: TextButton.styleFrom(
                                padding: const EdgeInsets.symmetric(vertical: 16),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(AppTheme.radiusSmall),
                                ),
                              ),
                              child: Text(
                                'Nanti Saja',
                                style: TextStyle(
                                  color: AppTheme.textSecondaryColor,
                                  fontSize: isTablet ? 16 : 14,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            flex: 2,
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 200),
                              decoration: BoxDecoration(
                                gradient: AppTheme.primaryGradient,
                                borderRadius: BorderRadius.circular(AppTheme.radiusSmall),
                                boxShadow: [
                                  BoxShadow(
                                    color: AppTheme.primaryColor.withOpacity(0.3),
                                    blurRadius: 8,
                                    spreadRadius: 0,
                                    offset: Offset(0, 4),
                                  ),
                                ],
                              ),
                              child: Material(
                                color: Colors.transparent,
                                child: InkWell(
                                  onTap: _onUpdatePressed,
                                  borderRadius: BorderRadius.circular(AppTheme.radiusSmall),
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(vertical: 16),
                                    child: Center(
                                      child: Text(
                                        'Update Sekarang',
                                        style: TextStyle(
                                          color: Colors.white,
                                          fontSize: isTablet ? 16 : 14,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ),
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
}