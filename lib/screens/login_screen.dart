import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:provider/provider.dart';
import 'home_screen.dart';
import 'register_screen.dart';
import '../theme/app_theme.dart';
import '../providers/app_state_provider.dart';
import 'package:fluttertoast/fluttertoast.dart';

class LoginScreen extends StatefulWidget {
  @override
  _LoginScreenState createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> with TickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isLoading = false;
  bool _obscurePassword = true;
  bool _rememberMe = false;
  bool _isLoginButtonHovered = false;
  bool _isForgotPasswordHovered = false;
  bool _isRegisterHovered = false;
  late AnimationController _shimmerController;
  late Animation<double> _shimmerAnimation;

  Future<void> _login() async {
    if (_formKey.currentState!.validate()) {
      setState(() => _isLoading = true);
      
      // Start shimmer animation
      _shimmerController.repeat();
      
      // Simulate login delay
      await Future.delayed(Duration(seconds: 2));
      
      // Stop shimmer animation
      _shimmerController.stop();
      _shimmerController.reset();
      
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('isLoggedIn', true);
      await prefs.setString('username', _emailController.text.split('@')[0]); // Extract username from email
      
      if (_rememberMe) {
        await prefs.setString('email', _emailController.text);
      }
      
      // Update AppStateProvider
      final appStateProvider = Provider.of<AppStateProvider>(context, listen: false);
      await appStateProvider.updateUserData(
        username: _emailController.text.split('@')[0],
        email: _emailController.text,
        isLoggedIn: true,
      );
      
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => HomeScreen()),
      );
    }
  }

  @override
  void initState() {
    super.initState();
    _loadSavedEmail();
    
    // Initialize AppStateProvider
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Provider.of<AppStateProvider>(context, listen: false).initialize();
    });
    
    // Initialize shimmer animation
    _shimmerController = AnimationController(
      vsync: this,
      duration: Duration(milliseconds: 1500),
    );
    
    _shimmerAnimation = Tween<double>(
      begin: -2.0,
      end: 2.0,
    ).animate(CurvedAnimation(
      parent: _shimmerController,
      curve: Curves.easeInOut,
    ));
  }
  
  @override
  void dispose() {
    _shimmerController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _loadSavedEmail() async {
    final prefs = await SharedPreferences.getInstance();
    final savedEmail = prefs.getString('email');
    if (savedEmail != null && savedEmail.isNotEmpty) {
      setState(() {
        _emailController.text = savedEmail;
        _rememberMe = true;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: EdgeInsets.all(24),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Enhanced logo with cinematic glow effect
                  Center(
                    child: TweenAnimationBuilder<double>(
                      tween: Tween(begin: 0.8, end: 1.0),
                      duration: Duration(milliseconds: 800),
                      builder: (context, value, child) {
                        return Transform.scale(
                          scale: value,
                          child: AnimatedContainer(
                            duration: Duration(milliseconds: 300),
                            padding: EdgeInsets.all(20),
                            decoration: BoxDecoration(
                              gradient: RadialGradient(
                                colors: [
                                  AppTheme.primaryColor.withOpacity(0.15),
                                  AppTheme.primaryColor.withOpacity(0.05),
                                  Colors.transparent,
                                ],
                                stops: [0.0, 0.7, 1.0],
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
                              Icons.play_circle_fill,
                              size: 80,
                              color: AppTheme.primaryColor,
                              shadows: [
                                Shadow(
                                  color: AppTheme.primaryColor.withOpacity(0.5),
                                  blurRadius: 10,
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                  SizedBox(height: 32),
                  // Enhanced welcome text with better typography
                  Text(
                    'Welcome Back',
                    style: Theme.of(context).textTheme.displayMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                      letterSpacing: -0.5,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  SizedBox(height: 12),
                  Text(
                    'Login to continue watching your favorite anime and comic',
                    style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                      color: AppTheme.textSecondaryColor,
                      height: 1.5,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  SizedBox(height: 56),
                  // Enhanced email field with improved glassmorphism
                  TweenAnimationBuilder<double>(
                    tween: Tween(begin: 0.0, end: 1.0),
                    duration: Duration(milliseconds: 600),
                    curve: Curves.easeOut,
                    builder: (context, value, child) {
                      return Transform.translate(
                        offset: Offset(0, 20 * (1 - value)),
                        child: Opacity(
                          opacity: value,
                          child: Container(
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                                colors: [
                                  Colors.white.withOpacity(0.08),
                                  Colors.white.withOpacity(0.03),
                                ],
                              ),
                              borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
                              border: Border.all(
                                color: Colors.white.withOpacity(0.15),
                                width: 1.2,
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.2),
                                  blurRadius: 8,
                                  offset: Offset(0, 4),
                                ),
                              ],
                            ),
                            child: TextFormField(
                              controller: _emailController,
                              decoration: InputDecoration(
                                labelText: 'Email',
                                prefixIcon: Icon(Icons.email_outlined, color: AppTheme.textSecondaryColor),
                                labelStyle: TextStyle(color: AppTheme.textSecondaryColor),
                                hintStyle: TextStyle(color: AppTheme.textSecondaryColor.withOpacity(0.7)),
                                filled: true,
                                fillColor: Colors.transparent,
                                border: InputBorder.none,
                                enabledBorder: InputBorder.none,
                                focusedBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
                                  borderSide: BorderSide(color: AppTheme.accentColor, width: 2),
                                ),
                                errorBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
                                  borderSide: BorderSide(color: AppTheme.errorColor, width: 2),
                                ),
                                contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                              ),
                              keyboardType: TextInputType.emailAddress,
                              style: TextStyle(color: Colors.white, fontSize: 16),
                              validator: (value) {
                                if (value == null || value.isEmpty) {
                                  return 'Please enter your email';
                                }
                                if (!value.contains('@')) {
                                  return 'Please enter a valid email';
                                }
                                return null;
                              },
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                  SizedBox(height: 20),
                  // Enhanced password field with improved glassmorphism
                  TweenAnimationBuilder<double>(
                    tween: Tween(begin: 0.0, end: 1.0),
                    duration: Duration(milliseconds: 700),
                    curve: Curves.easeOut,
                    builder: (context, value, child) {
                      return Transform.translate(
                        offset: Offset(0, 20 * (1 - value)),
                        child: Opacity(
                          opacity: value,
                          child: Container(
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                                colors: [
                                  Colors.white.withOpacity(0.08),
                                  Colors.white.withOpacity(0.03),
                                ],
                              ),
                              borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
                              border: Border.all(
                                color: Colors.white.withOpacity(0.15),
                                width: 1.2,
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.2),
                                  blurRadius: 8,
                                  offset: Offset(0, 4),
                                ),
                              ],
                            ),
                            child: TextFormField(
                              controller: _passwordController,
                              decoration: InputDecoration(
                                labelText: 'Password',
                                prefixIcon: Icon(Icons.lock_outline, color: AppTheme.textSecondaryColor),
                                suffixIcon: IconButton(
                                  icon: Icon(
                                    _obscurePassword ? Icons.visibility_outlined : Icons.visibility_off_outlined,
                                    color: AppTheme.textSecondaryColor,
                                  ),
                                  onPressed: () {
                                    setState(() {
                                      _obscurePassword = !_obscurePassword;
                                    });
                                  },
                                ),
                                labelStyle: TextStyle(color: AppTheme.textSecondaryColor),
                                hintStyle: TextStyle(color: AppTheme.textSecondaryColor.withOpacity(0.7)),
                                filled: true,
                                fillColor: Colors.transparent,
                                border: InputBorder.none,
                                enabledBorder: InputBorder.none,
                                focusedBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
                                  borderSide: BorderSide(color: AppTheme.accentColor, width: 2),
                                ),
                                errorBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
                                  borderSide: BorderSide(color: AppTheme.errorColor, width: 2),
                                ),
                                contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                              ),
                              obscureText: _obscurePassword,
                              style: TextStyle(color: Colors.white, fontSize: 16),
                              validator: (value) {
                                if (value == null || value.isEmpty) {
                                  return 'Please enter your password';
                                }
                                if (value.length < 6) {
                                  return 'Password must be at least 6 characters';
                                }
                                return null;
                              },
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                  SizedBox(height: 16),
                  // Simplified remember me checkbox with better UX
                  TweenAnimationBuilder<double>(
                    tween: Tween(begin: 0.0, end: 1.0),
                    duration: Duration(milliseconds: 800),
                    curve: Curves.easeOut,
                    builder: (context, value, child) {
                      return Opacity(
                        opacity: value,
                        child: Row(
                          children: [
                            Transform.scale(
                              scale: 0.9,
                              child: Checkbox(
                                value: _rememberMe,
                                onChanged: (value) {
                                  setState(() {
                                    _rememberMe = value!;
                                  });
                                },
                                activeColor: AppTheme.primaryColor,
                                checkColor: Colors.white,
                                fillColor: MaterialStateProperty.all(
                                  _rememberMe 
                                    ? AppTheme.primaryColor.withOpacity(0.8)
                                    : Colors.white.withOpacity(0.1),
                                ),
                                side: BorderSide(
                                  color: _rememberMe 
                                    ? AppTheme.primaryColor
                                    : Colors.white.withOpacity(0.3),
                                  width: 1.5,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(4),
                                ),
                              ),
                            ),
                            SizedBox(width: 8),
                            Text(
                              'Remember me',
                              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                color: AppTheme.textSecondaryColor,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            Spacer(),
                            StatefulBuilder(
                              builder: (context, setState) {
                                return MouseRegion(
                                  cursor: SystemMouseCursors.click,
                                  onEnter: (_) => setState(() => _isForgotPasswordHovered = true),
                                  onExit: (_) => setState(() => _isForgotPasswordHovered = false),
                                  child: TextButton(
                                    onPressed: () {
                                      // Forgot password functionality
                                      Fluttertoast.showToast(
                                        msg: 'Forgot password functionality coming soon',
                                        toastLength: Toast.LENGTH_SHORT,
                                        gravity: ToastGravity.BOTTOM,
                                        backgroundColor: AppTheme.primaryColor,
                                        textColor: Colors.white,
                                      );
                                    },
                                    style: TextButton.styleFrom(
                                      foregroundColor: AppTheme.accentColor,
                                      padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                    ),
                                    child: AnimatedDefaultTextStyle(
                                      duration: Duration(milliseconds: 200),
                                      style: TextStyle(
                                        color: _isForgotPasswordHovered
                                          ? AppTheme.accentColor.withOpacity(0.8)
                                          : AppTheme.accentColor,
                                        fontWeight: FontWeight.w600,
                                        letterSpacing: 0.5,
                                        fontSize: _isForgotPasswordHovered ? 13 : 12,
                                      ),
                                      child: Text('Forgot Password?'),
                                    ),
                                  ),
                                );
                              },
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                  SizedBox(height: 24),
                  // Enhanced login button with cinematic effects
                  TweenAnimationBuilder<double>(
                    tween: Tween(begin: 0.0, end: 1.0),
                    duration: Duration(milliseconds: 900),
                    curve: Curves.easeOut,
                    builder: (context, value, child) {
                      return Transform.translate(
                        offset: Offset(0, 30 * (1 - value)),
                        child: Opacity(
                          opacity: value,
                          child: StatefulBuilder(
                            builder: (context, setState) {
                              return MouseRegion(
                                cursor: SystemMouseCursors.click,
                                onEnter: (_) => setState(() => _isLoginButtonHovered = true),
                                onExit: (_) => setState(() => _isLoginButtonHovered = false),
                                child: AnimatedContainer(
                                  duration: Duration(milliseconds: 200),
                                  transform: Matrix4.identity()
                                    ..scale(_isLoading ? 0.98 : (_isLoginButtonHovered ? 1.02 : 1.0)),
                                  child: Container(
                                    width: double.infinity,
                                    height: 56,
                                    decoration: BoxDecoration(
                                      gradient: LinearGradient(
                                        begin: Alignment.topLeft,
                                        end: Alignment.bottomRight,
                                        colors: _isLoginButtonHovered && !_isLoading
                                          ? [
                                              AppTheme.primaryColor.withOpacity(0.95),
                                              AppTheme.primaryColor.withOpacity(0.75),
                                              AppTheme.accentColor.withOpacity(0.65),
                                            ]
                                          : [
                                              AppTheme.primaryColor,
                                              AppTheme.primaryColor.withOpacity(0.8),
                                              AppTheme.accentColor.withOpacity(0.7),
                                            ],
                                      ),
                                      borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
                                      boxShadow: _isLoginButtonHovered && !_isLoading
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
                                        onTap: _isLoading ? null : _login,
                                        borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
                                        splashColor: Colors.white.withOpacity(0.2),
                                        highlightColor: Colors.white.withOpacity(0.1),
                                        child: Center(
                                          child: _isLoading
                                              ? Stack(
                                                  alignment: Alignment.center,
                                                  children: [
                                                    // Shimmer effect
                                                    AnimatedBuilder(
                                                      animation: _shimmerAnimation,
                                                      builder: (context, child) {
                                                        return Container(
                                                          width: 120,
                                                          height: 20,
                                                          decoration: BoxDecoration(
                                                            borderRadius: BorderRadius.circular(10),
                                                            gradient: LinearGradient(
                                                              begin: Alignment(-1.0 + _shimmerAnimation.value, 0.0),
                                                              end: Alignment(1.0 + _shimmerAnimation.value, 0.0),
                                                              colors: [
                                                                Colors.transparent,
                                                                Colors.white.withOpacity(0.3),
                                                                Colors.transparent,
                                                              ],
                                                            ),
                                                          ),
                                                        );
                                                      },
                                                    ),
                                                    // Loading indicator
                                                    SizedBox(
                                                      width: 24,
                                                      height: 24,
                                                      child: CircularProgressIndicator(
                                                        valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                                                        strokeWidth: 3,
                                                      ),
                                                    ),
                                                  ],
                                                )
                                              : Text(
                                                  'LOGIN',
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
                        ),
                      );
                    },
                  ),
                  SizedBox(height: 16),
                  // Register link
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        'Don\'t have an account?',
                        style: TextStyle(color: AppTheme.textSecondaryColor),
                      ),
                      StatefulBuilder(
                        builder: (context, setState) {
                          return MouseRegion(
                            cursor: SystemMouseCursors.click,
                            onEnter: (_) => setState(() => _isRegisterHovered = true),
                            onExit: (_) => setState(() => _isRegisterHovered = false),
                            child: TextButton(
                              onPressed: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(builder: (context) => RegisterScreen()),
                                );
                              },
                              child: AnimatedDefaultTextStyle(
                                duration: Duration(milliseconds: 200),
                                style: TextStyle(
                                  color: _isRegisterHovered
                                    ? AppTheme.accentColor.withOpacity(0.8)
                                    : AppTheme.accentColor,
                                  fontWeight: FontWeight.bold,
                                  fontSize: _isRegisterHovered ? 15 : 14,
                                ),
                                child: Text('Register'),
                              ),
                            ),
                          );
                        },
                      ),
                    ],
                  ),
                  SizedBox(height: 24),
                  // Or continue with - more subtle design
                  TweenAnimationBuilder<double>(
                    tween: Tween(begin: 0.0, end: 1.0),
                    duration: Duration(milliseconds: 1000),
                    curve: Curves.easeOut,
                    builder: (context, value, child) {
                      return Opacity(
                        opacity: value,
                        child: Row(
                          children: [
                            Expanded(
                              child: Divider(
                                color: AppTheme.textSecondaryColor.withOpacity(0.3),
                                thickness: 0.5,
                              ),
                            ),
                            Padding(
                              padding: EdgeInsets.symmetric(horizontal: 16),
                              child: Text(
                                'OR CONTINUE WITH',
                                style: TextStyle(
                                  color: AppTheme.textSecondaryColor.withOpacity(0.6),
                                  fontSize: 11,
                                  fontWeight: FontWeight.w500,
                                  letterSpacing: 1.0,
                                ),
                              ),
                            ),
                            Expanded(
                              child: Divider(
                                color: AppTheme.textSecondaryColor.withOpacity(0.3),
                                thickness: 0.5,
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                  SizedBox(height: 24),
                  // Social login buttons
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      _buildSocialButton(Icons.g_mobiledata, 'Google'),
                      SizedBox(width: 16),
                      _buildSocialButton(Icons.facebook, 'Facebook'),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSocialButton(IconData icon, String platform) {
    bool _isHovered = false;
    
    return Expanded(
      child: TweenAnimationBuilder<double>(
        tween: Tween(begin: 0.0, end: 1.0),
        duration: Duration(milliseconds: 1100),
        curve: Curves.easeOut,
        builder: (context, value, child) {
          return Transform.translate(
            offset: Offset(0, 20 * (1 - value)),
            child: Opacity(
              opacity: value,
              child: StatefulBuilder(
                builder: (context, setState) {
                  return MouseRegion(
                    cursor: SystemMouseCursors.click,
                    onEnter: (_) => setState(() => _isHovered = true),
                    onExit: (_) => setState(() => _isHovered = false),
                    child: AnimatedContainer(
                      duration: Duration(milliseconds: 200),
                      transform: Matrix4.identity()
                        ..scale(_isHovered ? 1.05 : 1.0),
                      child: Material(
                        color: Colors.transparent,
                        child: InkWell(
                          onTap: () {
                            Fluttertoast.showToast(
                              msg: '$platform login coming soon',
                              toastLength: Toast.LENGTH_SHORT,
                              gravity: ToastGravity.BOTTOM,
                              backgroundColor: AppTheme.primaryColor,
                              textColor: Colors.white,
                            );
                          },
                          borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
                          splashColor: Colors.white.withOpacity(0.15),
                          highlightColor: Colors.white.withOpacity(0.08),
                          child: AnimatedContainer(
                            duration: Duration(milliseconds: 200),
                            height: 48,
                            margin: EdgeInsets.symmetric(horizontal: 4),
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                                colors: _isHovered
                                  ? [
                                      Colors.white.withOpacity(0.12),
                                      Colors.white.withOpacity(0.06),
                                    ]
                                  : [
                                      Colors.white.withOpacity(0.08),
                                      Colors.white.withOpacity(0.04),
                                    ],
                              ),
                              borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
                              border: Border.all(
                                color: _isHovered
                                  ? Colors.white.withOpacity(0.2)
                                  : Colors.white.withOpacity(0.12),
                                width: 1.2,
                              ),
                              boxShadow: _isHovered
                                ? [
                                    BoxShadow(
                                      color: Colors.black.withOpacity(0.25),
                                      blurRadius: 8,
                                      offset: Offset(0, 4),
                                    ),
                                  ]
                                : [
                                    BoxShadow(
                                      color: Colors.black.withOpacity(0.15),
                                      blurRadius: 6,
                                      offset: Offset(0, 3),
                                    ),
                                  ],
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  icon,
                                  color: _isHovered
                                    ? Colors.white
                                    : Colors.white.withOpacity(0.9),
                                  size: 20,
                                ),
                                SizedBox(width: 8),
                                Text(
                                  platform,
                                  style: TextStyle(
                                    color: _isHovered
                                      ? Colors.white
                                      : Colors.white.withOpacity(0.9),
                                    fontWeight: FontWeight.w600,
                                    fontSize: 14,
                                    letterSpacing: 0.5,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          );
        },
      ),
    );
  }
}
