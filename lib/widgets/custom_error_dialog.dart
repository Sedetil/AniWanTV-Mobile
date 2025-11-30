import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

class CustomErrorDialog extends StatefulWidget {
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
        onDismiss: onDismiss,
      ),
    );
  }

  @override
  _CustomErrorDialogState createState() => _CustomErrorDialogState();
}

class _CustomErrorDialogState extends State<CustomErrorDialog> with TickerProviderStateMixin {
  late AnimationController _scaleController;
  late AnimationController _shimmerController;
  late Animation<double> _scaleAnimation;
  late Animation<double> _shimmerAnimation;

  @override
  void initState() {
    super.initState();
    
    // Initialize scale animation
    _scaleController = AnimationController(
      duration: Duration(milliseconds: 300),
      vsync: this,
    );
    _scaleAnimation = Tween<double>(
      begin: 0.8,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _scaleController,
      curve: Curves.elasticOut,
    ));
    
    // Initialize shimmer animation
    _shimmerController = AnimationController(
      duration: Duration(milliseconds: 2000),
      vsync: this,
    );
    _shimmerAnimation = Tween<double>(
      begin: -2.0,
      end: 2.0,
    ).animate(CurvedAnimation(
      parent: _shimmerController,
      curve: Curves.easeInOut,
    ));
    
    // Start animations
    _scaleController.forward();
    _shimmerController.repeat();
  }
  
  @override
  void dispose() {
    _scaleController.dispose();
    _shimmerController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      elevation: 0,
      insetPadding: EdgeInsets.symmetric(horizontal: 24, vertical: 24),
      child: AnimatedBuilder(
        animation: _scaleAnimation,
        builder: (context, child) {
          return Transform.scale(
            scale: _scaleAnimation.value,
            child: Container(
              padding: EdgeInsets.all(24),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    AppTheme.surfaceColor,
                    AppTheme.cardColor,
                  ],
                ),
                borderRadius: BorderRadius.circular(AppTheme.radiusLarge),
                border: Border.all(
                  color: AppTheme.primaryColor.withOpacity(0.3),
                  width: 1.2,
                ),
                boxShadow: [
                  BoxShadow(
                    color: AppTheme.primaryColor.withOpacity(0.2),
                    blurRadius: 20,
                    spreadRadius: 0,
                    offset: Offset(0, 10),
                  ),
                  BoxShadow(
                    color: Colors.black.withOpacity(0.3),
                    blurRadius: 15,
                    spreadRadius: 0,
                    offset: Offset(0, 5),
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Error icon with glow effect
                  AnimatedContainer(
                    duration: Duration(milliseconds: 500),
                    padding: EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      gradient: RadialGradient(
                        colors: [
                          AppTheme.primaryColor.withOpacity(0.2),
                          AppTheme.primaryColor.withOpacity(0.05),
                        ],
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
                      Icons.error_outline,
                      size: 48,
                      color: AppTheme.primaryColor,
                      shadows: [
                        Shadow(
                          color: AppTheme.primaryColor.withOpacity(0.5),
                          blurRadius: 10,
                        ),
                      ],
                    ),
                  ),
                  SizedBox(height: 20),
                  
                  // Title
                  Text(
                    widget.title,
                    style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 0.15,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  SizedBox(height: 12),
                  
                  // Message
                  Text(
                    widget.message,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: AppTheme.textSecondaryColor,
                      height: 1.5,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  SizedBox(height: 28),
                  
                  // Buttons with enhanced styling
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      if (widget.onRetry != null) ...[
                        StatefulBuilder(
                          builder: (context, setState) {
                            bool _isHovered = false;
                            return MouseRegion(
                              cursor: SystemMouseCursors.click,
                              onEnter: (_) => setState(() => _isHovered = true),
                              onExit: (_) => setState(() => _isHovered = false),
                              child: AnimatedContainer(
                                duration: Duration(milliseconds: 200),
                                transform: Matrix4.identity()
                                  ..scale(_isHovered ? 1.05 : 1.0),
                                child: Container(
                                  height: 48,
                                  decoration: BoxDecoration(
                                    gradient: _isHovered
                                      ? LinearGradient(
                                          begin: Alignment.topLeft,
                                          end: Alignment.bottomRight,
                                          colors: [
                                            AppTheme.accentColor.withOpacity(0.95),
                                            AppTheme.accentColor.withOpacity(0.75),
                                            AppTheme.primaryColor.withOpacity(0.65),
                                          ],
                                        )
                                      : LinearGradient(
                                          begin: Alignment.topLeft,
                                          end: Alignment.bottomRight,
                                          colors: [
                                            AppTheme.accentColor,
                                            AppTheme.accentColor.withOpacity(0.8),
                                            AppTheme.primaryColor.withOpacity(0.7),
                                          ],
                                        ),
                                    borderRadius: BorderRadius.circular(AppTheme.radiusSmall),
                                    boxShadow: _isHovered
                                      ? [
                                          BoxShadow(
                                            color: AppTheme.accentColor.withOpacity(0.5),
                                            blurRadius: 20,
                                            spreadRadius: 0,
                                            offset: Offset(0, 8),
                                          ),
                                          BoxShadow(
                                            color: Colors.black.withOpacity(0.4),
                                            blurRadius: 12,
                                            spreadRadius: 0,
                                            offset: Offset(0, 6),
                                          ),
                                        ]
                                      : [
                                          BoxShadow(
                                            color: AppTheme.accentColor.withOpacity(0.4),
                                            blurRadius: 16,
                                            spreadRadius: 0,
                                            offset: Offset(0, 6),
                                          ),
                                          BoxShadow(
                                            color: Colors.black.withOpacity(0.3),
                                            blurRadius: 10,
                                            spreadRadius: 0,
                                            offset: Offset(0, 4),
                                          ),
                                        ],
                                  ),
                                  child: Material(
                                    color: Colors.transparent,
                                    child: InkWell(
                                      onTap: () {
                                        Navigator.of(context).pop();
                                        widget.onRetry!();
                                      },
                                      borderRadius: BorderRadius.circular(AppTheme.radiusSmall),
                                      splashColor: Colors.white.withOpacity(0.2),
                                      highlightColor: Colors.white.withOpacity(0.1),
                                      child: Center(
                                        child: Text(
                                          'Retry',
                                          style: TextStyle(
                                            fontSize: 16,
                                            fontWeight: FontWeight.bold,
                                            color: Colors.white,
                                            letterSpacing: 1.2,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            );
                          },
                        ),
                        SizedBox(width: 16),
                      ],
                      StatefulBuilder(
                        builder: (context, setState) {
                          bool _isHovered = false;
                          return MouseRegion(
                            cursor: SystemMouseCursors.click,
                            onEnter: (_) => setState(() => _isHovered = true),
                            onExit: (_) => setState(() => _isHovered = false),
                            child: AnimatedContainer(
                              duration: Duration(milliseconds: 200),
                              transform: Matrix4.identity()
                                ..scale(_isHovered ? 1.05 : 1.0),
                              child: Container(
                                height: 48,
                                decoration: BoxDecoration(
                                  gradient: _isHovered
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
                                  borderRadius: BorderRadius.circular(AppTheme.radiusSmall),
                                  boxShadow: _isHovered
                                    ? [
                                        BoxShadow(
                                          color: AppTheme.primaryColor.withOpacity(0.5),
                                          blurRadius: 20,
                                          spreadRadius: 0,
                                          offset: Offset(0, 8),
                                        ),
                                        BoxShadow(
                                          color: Colors.black.withOpacity(0.4),
                                          blurRadius: 12,
                                          spreadRadius: 0,
                                          offset: Offset(0, 6),
                                        ),
                                      ]
                                    : [
                                        BoxShadow(
                                          color: AppTheme.primaryColor.withOpacity(0.4),
                                          blurRadius: 16,
                                          spreadRadius: 0,
                                          offset: Offset(0, 6),
                                        ),
                                        BoxShadow(
                                          color: Colors.black.withOpacity(0.3),
                                          blurRadius: 10,
                                          spreadRadius: 0,
                                          offset: Offset(0, 4),
                                        ),
                                      ],
                                ),
                                child: Material(
                                  color: Colors.transparent,
                                  child: InkWell(
                                    onTap: () {
                                      Navigator.of(context).pop();
                                      if (widget.onDismiss != null) widget.onDismiss!();
                                    },
                                    borderRadius: BorderRadius.circular(AppTheme.radiusSmall),
                                    splashColor: Colors.white.withOpacity(0.2),
                                    highlightColor: Colors.white.withOpacity(0.1),
                                    child: Center(
                                      child: Text(
                                        'Dismiss',
                                        style: TextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.bold,
                                          color: Colors.white,
                                          letterSpacing: 1.2,
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                    ],
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
