import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

class CustomErrorDialog extends StatelessWidget {
  final String title;
  final String message;
  final VoidCallback? onRetry;
  final VoidCallback? onDismiss;

  const CustomErrorDialog({
    Key? key,
    required this.title,
    required this.message,
    this.onRetry,
    this.onDismiss,
  }) : super(key: key);

  static void show(
    BuildContext context, {
    required String title,
    required String message,
    VoidCallback? onRetry,
    VoidCallback? onDismiss,
  }) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => CustomErrorDialog(
        title: title,
        message: message,
        onRetry: onRetry,
        onDismiss: onDismiss ?? () => Navigator.of(context).pop(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      elevation: 0,
      child: Container(
        padding: EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: AppTheme.cardColor,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppTheme.primaryColor, width: 2),
          boxShadow: [
            BoxShadow(
              color: AppTheme.primaryColor.withOpacity(0.3),
              blurRadius: 15,
              spreadRadius: 5,
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Error icon
            Container(
              padding: EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppTheme.primaryColor.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.error_outline,
                color: AppTheme.primaryColor,
                size: 40,
              ),
            ),
            SizedBox(height: 16),
            
            // Title
            Text(
              title,
              style: TextStyle(
                color: Colors.white,
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
              textAlign: TextAlign.center,
            ),
            SizedBox(height: 8),
            
            // Message
            Text(
              message,
              style: TextStyle(
                color: AppTheme.textSecondaryColor,
                fontSize: 14,
              ),
              textAlign: TextAlign.center,
            ),
            SizedBox(height: 24),
            
            // Buttons
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (onRetry != null) ...[
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () {
                        Navigator.of(context).pop();
                        onRetry!();
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.accentColor,
                        foregroundColor: Colors.white,
                        padding: EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      child: Text('Retry'),
                    ),
                  ),
                  SizedBox(width: 12),
                ],
                Expanded(
                  child: ElevatedButton(
                    onPressed: () {
                      Navigator.of(context).pop();
                      if (onDismiss != null) onDismiss!();
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.primaryColor,
                      foregroundColor: Colors.white,
                      padding: EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    child: Text('Dismiss'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
