import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'login_screen.dart';
import '../theme/app_theme.dart';
import '../providers/app_state_provider.dart';
import 'package:fluttertoast/fluttertoast.dart';

class RegisterScreen extends StatefulWidget {
  @override
  _RegisterScreenState createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> with TickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  bool _isLoading = false;
  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;
  bool _acceptTerms = false;
  bool _isRegisterButtonHovered = false;
  bool _isLoginLinkHovered = false;
  late AnimationController _shimmerController;
  late Animation<double> _shimmerAnimation;

  Future<void> _register() async {
    if (_formKey.currentState!.validate() && _acceptTerms) {
      setState(() => _isLoading = true);
      
      // Start shimmer animation
      _shimmerController.repeat();
      
      // Simulate registration delay
      await Future.delayed(Duration(seconds: 2));
      
      // Stop shimmer animation
      _shimmerController.stop();
      _shimmerController.reset();
      
      // Save user data to AppStateProvider
      final appStateProvider = Provider.of<AppStateProvider>(context, listen: false);
      await appStateProvider.updateUserData(
        username: _nameController.text,
        email: _emailController.text,
        isLoggedIn: false, // User needs to login after registration
      );
      
      // Show success message
      Fluttertoast.showToast(
        msg: 'Registration successful! Please login.',
        toastLength: Toast.LENGTH_SHORT,
        gravity: ToastGravity.BOTTOM,
        backgroundColor: Colors.green,
        textColor: Colors.white,
      );
      
      // Navigate to login screen
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => LoginScreen()),
      );
    } else if (!_acceptTerms) {
      Fluttertoast.showToast(
        msg: 'Please accept Terms and Conditions',
        toastLength: Toast.LENGTH_SHORT,
        gravity: ToastGravity.BOTTOM,
        backgroundColor: Colors.red,
        textColor: Colors.white,
      );
    }
  }

  @override
  void initState() {
    super.initState();
    
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
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
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
                                  AppTheme.accentColor.withOpacity(0.15),
                                  AppTheme.accentColor.withOpacity(0.05),
                                  Colors.transparent,
                                ],
                                stops: [0.0, 0.7, 1.0],
                              ),
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: AppTheme.accentColor.withOpacity(0.4),
                                width: 1.5,
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: AppTheme.accentColor.withOpacity(0.4),
                                  blurRadius: 30,
                                  spreadRadius: 2,
                                ),
                                BoxShadow(
                                  color: AppTheme.accentColor.withOpacity(0.2),
                                  blurRadius: 60,
                                  spreadRadius: 5,
                                ),
                              ],
                            ),
                            child: Icon(
                              Icons.person_add,
                              size: 80,
                              color: AppTheme.accentColor,
                              shadows: [
                                Shadow(
                                  color: AppTheme.accentColor.withOpacity(0.5),
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
                    'Create Account',
                    style: Theme.of(context).textTheme.displayMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                      letterSpacing: -0.5,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  SizedBox(height: 12),
                  Text(
                    'Join AniWanTV to watch unlimited anime and comic',
                    style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                      color: AppTheme.textSecondaryColor,
                      height: 1.5,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  SizedBox(height: 56),
                  // Enhanced name field with improved glassmorphism
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
                              controller: _nameController,
                              decoration: InputDecoration(
                                labelText: 'Full Name',
                                prefixIcon: Icon(Icons.person_outlined, color: AppTheme.textSecondaryColor),
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
                              style: TextStyle(color: Colors.white, fontSize: 16),
                              validator: (value) {
                                if (value == null || value.isEmpty) {
                                  return 'Please enter your name';
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
                  // Enhanced email field with improved glassmorphism
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
                    duration: Duration(milliseconds: 800),
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
                                  return 'Please enter a password';
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
                  SizedBox(height: 20),
                  // Enhanced confirm password field with improved glassmorphism
                  TweenAnimationBuilder<double>(
                    tween: Tween(begin: 0.0, end: 1.0),
                    duration: Duration(milliseconds: 900),
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
                              controller: _confirmPasswordController,
                              decoration: InputDecoration(
                                labelText: 'Confirm Password',
                                prefixIcon: Icon(Icons.lock_outline, color: AppTheme.textSecondaryColor),
                                suffixIcon: IconButton(
                                  icon: Icon(
                                    _obscureConfirmPassword ? Icons.visibility_outlined : Icons.visibility_off_outlined,
                                    color: AppTheme.textSecondaryColor,
                                  ),
                                  onPressed: () {
                                    setState(() {
                                      _obscureConfirmPassword = !_obscureConfirmPassword;
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
                              obscureText: _obscureConfirmPassword,
                              style: TextStyle(color: Colors.white, fontSize: 16),
                              validator: (value) {
                                if (value == null || value.isEmpty) {
                                  return 'Please confirm your password';
                                }
                                if (value != _passwordController.text) {
                                  return 'Passwords do not match';
                                }
                                return null;
                              },
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                  SizedBox(height: 24),
                  // Simplified terms checkbox with better UX
                  TweenAnimationBuilder<double>(
                    tween: Tween(begin: 0.0, end: 1.0),
                    duration: Duration(milliseconds: 1000),
                    curve: Curves.easeOut,
                    builder: (context, value, child) {
                      return Opacity(
                        opacity: value,
                        child: Row(
                          children: [
                            Transform.scale(
                              scale: 0.9,
                              child: Checkbox(
                                value: _acceptTerms,
                                onChanged: (value) {
                                  setState(() {
                                    _acceptTerms = value!;
                                  });
                                },
                                activeColor: AppTheme.accentColor,
                                checkColor: Colors.white,
                                fillColor: MaterialStateProperty.all(
                                  _acceptTerms 
                                    ? AppTheme.accentColor.withOpacity(0.8)
                                    : Colors.white.withOpacity(0.1),
                                ),
                                side: BorderSide(
                                  color: _acceptTerms 
                                    ? AppTheme.accentColor
                                    : Colors.white.withOpacity(0.3),
                                  width: 1.5,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(4),
                                ),
                              ),
                            ),
                            SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                'I accept Terms and Conditions and Privacy Policy',
                                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                  color: AppTheme.textSecondaryColor,
                                  fontWeight: FontWeight.w500,
                                  height: 1.3,
                                ),
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                  SizedBox(height: 32),
                  // Enhanced register button with cinematic effects
                  TweenAnimationBuilder<double>(
                    tween: Tween(begin: 0.0, end: 1.0),
                    duration: Duration(milliseconds: 1100),
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
                                onEnter: (_) => setState(() => _isRegisterButtonHovered = true),
                                onExit: (_) => setState(() => _isRegisterButtonHovered = false),
                                child: AnimatedContainer(
                                  duration: Duration(milliseconds: 200),
                                  transform: Matrix4.identity()
                                    ..scale(_isLoading ? 0.98 : (_isRegisterButtonHovered ? 1.02 : 1.0)),
                                  child: Container(
                                    width: double.infinity,
                                    height: 56,
                                    decoration: BoxDecoration(
                                      gradient: LinearGradient(
                                        begin: Alignment.topLeft,
                                        end: Alignment.bottomRight,
                                        colors: _isRegisterButtonHovered && !_isLoading
                                          ? [
                                              AppTheme.accentColor.withOpacity(0.95),
                                              AppTheme.accentColor.withOpacity(0.75),
                                              AppTheme.primaryColor.withOpacity(0.65),
                                            ]
                                          : [
                                              AppTheme.accentColor,
                                              AppTheme.accentColor.withOpacity(0.8),
                                              AppTheme.primaryColor.withOpacity(0.7),
                                            ],
                                      ),
                                      borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
                                      boxShadow: _isRegisterButtonHovered && !_isLoading
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
                                        onTap: _isLoading ? null : _register,
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
                                                  'REGISTER',
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
                  SizedBox(height: 24),
                  // Login link
                  TweenAnimationBuilder<double>(
                    tween: Tween(begin: 0.0, end: 1.0),
                    duration: Duration(milliseconds: 1200),
                    curve: Curves.easeOut,
                    builder: (context, value, child) {
                      return Opacity(
                        opacity: value,
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              'Already have an account?',
                              style: TextStyle(color: AppTheme.textSecondaryColor),
                            ),
                            StatefulBuilder(
                              builder: (context, setState) {
                                return MouseRegion(
                                  cursor: SystemMouseCursors.click,
                                  onEnter: (_) => setState(() => _isLoginLinkHovered = true),
                                  onExit: (_) => setState(() => _isLoginLinkHovered = false),
                                  child: TextButton(
                                    onPressed: () {
                                      Navigator.pop(context);
                                    },
                                    child: AnimatedDefaultTextStyle(
                                      duration: Duration(milliseconds: 200),
                                      style: TextStyle(
                                        color: _isLoginLinkHovered
                                          ? AppTheme.primaryColor.withOpacity(0.8)
                                          : AppTheme.primaryColor,
                                        fontWeight: FontWeight.bold,
                                        fontSize: _isLoginLinkHovered ? 15 : 14,
                                      ),
                                      child: Text('Login'),
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
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
