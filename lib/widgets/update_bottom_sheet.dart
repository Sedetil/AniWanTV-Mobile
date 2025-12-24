import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../theme/app_theme.dart';
import '../services/app_version_service.dart';

class UpdateBottomSheet extends StatefulWidget {
  final String? latestVersion;
  final String? changelog;

  const UpdateBottomSheet({
    Key? key,
    this.latestVersion,
    this.changelog,
  }) : super(key: key);

  static Future<void> show({
    required BuildContext context,
    String? latestVersion,
    String? changelog,
  }) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => UpdateBottomSheet(
        latestVersion: latestVersion,
        changelog: changelog,
      ),
    );
  }

  @override
  _UpdateBottomSheetState createState() => _UpdateBottomSheetState();
}

class _UpdateBottomSheetState extends State<UpdateBottomSheet> {
  bool _isDownloading = false;
  double _downloadProgress = 0.0;
  String _downloadStatus = 'Mempersiapkan download...';

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
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final isTablet = MediaQuery.of(context).size.width > 600;

    return Container(
      decoration: BoxDecoration(
        color: AppTheme.surfaceColor,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        border: Border(
          top: BorderSide(
            color: AppTheme.primaryColor.withOpacity(0.3),
            width: 1,
          ),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.5),
            blurRadius: 20,
            spreadRadius: 5,
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Drag Handle
          Center(
            child: Container(
              margin: EdgeInsets.only(top: 12, bottom: 8),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey[700],
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),

          // Header
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
            child: Row(
              children: [
                Container(
                  padding: EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppTheme.primaryColor.withOpacity(0.1),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    _isDownloading ? Icons.download_rounded : Icons.system_update_rounded,
                    color: AppTheme.primaryColor,
                    size: 28,
                  ),
                ),
                SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _isDownloading ? 'Mengunduh Update' : 'Update Tersedia',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      if (widget.latestVersion != null)
                        Text(
                          'Versi ${widget.latestVersion}',
                          style: TextStyle(
                            color: Colors.greenAccent,
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          Divider(color: Colors.white10),

          // Content
          Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (!_isDownloading) ...[
                  if (widget.changelog != null && widget.changelog!.isNotEmpty) ...[
                    Text(
                      'Apa yang baru:',
                      style: TextStyle(
                        color: AppTheme.textPrimaryColor,
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                    SizedBox(height: 12),
                    Container(
                      width: double.infinity,
                      padding: EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.black.withOpacity(0.3),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.white10),
                      ),
                      child: Text(
                        widget.changelog!,
                        style: TextStyle(
                          color: AppTheme.textSecondaryColor,
                          height: 1.5,
                        ),
                      ),
                    ),
                    SizedBox(height: 24),
                  ],
                ] else ...[
                  // Download Progress
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            _downloadStatus,
                            style: TextStyle(color: Colors.white70),
                          ),
                          Text(
                            '${(_downloadProgress * 100).toInt()}%',
                            style: TextStyle(
                              color: AppTheme.primaryColor,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                      SizedBox(height: 12),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: LinearProgressIndicator(
                          value: _downloadProgress,
                          backgroundColor: Colors.grey[800],
                          color: AppTheme.primaryColor,
                          minHeight: 8,
                        ),
                      ),
                      SizedBox(height: 24),
                    ],
                  ),
                ],

                // Buttons
                Row(
                  children: [
                    if (!_isDownloading)
                      Expanded(
                        child: TextButton(
                          onPressed: () => Navigator.pop(context),
                          style: TextButton.styleFrom(
                            padding: EdgeInsets.symmetric(vertical: 16),
                          ),
                          child: Text(
                            'Nanti Saja',
                            style: TextStyle(color: Colors.grey),
                          ),
                        ),
                      ),
                    if (!_isDownloading) SizedBox(width: 16),
                    Expanded(
                      flex: 2,
                      child: ElevatedButton(
                        onPressed: _isDownloading ? null : _onUpdatePressed,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppTheme.primaryColor,
                          padding: EdgeInsets.symmetric(vertical: 16),
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          disabledBackgroundColor: Colors.grey[800],
                        ),
                        child: Text(
                          _isDownloading ? 'Mohon Tunggu...' : 'Update Sekarang',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                SizedBox(height: MediaQuery.of(context).padding.bottom), // Safe area bottom
              ],
            ),
          ),
        ],
      ),
    );
  }
}