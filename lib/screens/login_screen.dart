import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'home_screen.dart';
import 'register_screen.dart';
import '../theme/app_theme.dart';
import 'package:fluttertoast/fluttertoast.dart';

class LoginScreen extends StatefulWidget {
  @override
  _LoginScreenState createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isLoading = false;
  bool _obscurePassword = true;
  bool _rememberMe = false;

  Future<void> _login() async {
    if (_formKey.currentState!.validate()) {
      setState(() => _isLoading = true);
      
      // Simulate login delay
      await Future.delayed(Duration(seconds: 1));
      
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('isLoggedIn', true);
      
      if (_rememberMe) {
        await prefs.setString('email', _emailController.text);
      }
      
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
                  // Logo
                  Center(
                    child: Icon(
                      Icons.play_circle_fill,
                      size: 80,
                      color: AppTheme.primaryColor,
                    ),
                  ),
                  SizedBox(height: 24),
                  // Welcome text
                  Text(
                    'Welcome Back',
                    style: TextStyle(
                      fontSize: 32,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  SizedBox(height: 8),
                  Text(
                    'Login to continue watching your favorite anime and manga',
                    style: TextStyle(
                      color: AppTheme.textSecondaryColor,
                      fontSize: 14,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  SizedBox(height: 48),
                  // Email field
                  TextFormField(
                    controller: _emailController,
                    decoration: InputDecoration(
                      labelText: 'Email',
                      prefixIcon: Icon(Icons.email, color: AppTheme.textSecondaryColor),
                    ),
                    keyboardType: TextInputType.emailAddress,
                    style: TextStyle(color: Colors.white),
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
                  SizedBox(height: 16),
                  // Password field
                  TextFormField(
                    controller: _passwordController,
                    decoration: InputDecoration(
                      labelText: 'Password',
                      prefixIcon: Icon(Icons.lock, color: AppTheme.textSecondaryColor),
                      suffixIcon: IconButton(
                        icon: Icon(
                          _obscurePassword ? Icons.visibility : Icons.visibility_off,
                          color: AppTheme.textSecondaryColor,
                        ),
                        onPressed: () {
                          setState(() {
                            _obscurePassword = !_obscurePassword;
                          });
                        },
                      ),
                    ),
                    obscureText: _obscurePassword,
                    style: TextStyle(color: Colors.white),
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
                  SizedBox(height: 16),
                  // Remember me checkbox
                  Row(
                    children: [
                      Checkbox(
                        value: _rememberMe,
                        onChanged: (value) {
                          setState(() {
                            _rememberMe = value ?? false;
                          });
                        },
                        fillColor: MaterialStateProperty.resolveWith<Color>(
                          (Set<MaterialState> states) {
                            if (states.contains(MaterialState.selected)) {
                              return AppTheme.primaryColor;
                            }
                            return AppTheme.textSecondaryColor;
                          },
                        ),
                      ),
                      Text(
                        'Remember me',
                        style: TextStyle(color: AppTheme.textSecondaryColor),
                      ),
                      Spacer(),
                      TextButton(
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
                        child: Text(
                          'Forgot Password?',
                          style: TextStyle(color: AppTheme.accentColor),
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 24),
                  // Login button
                  ElevatedButton(
                    onPressed: _isLoading ? null : _login,
                    child: _isLoading
                        ? SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              color: Colors.white,
                              strokeWidth: 2,
                            ),
                          )
                        : Text(
                            'LOGIN',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.primaryColor,
                      padding: EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      elevation: 5,
                    ),
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
                      TextButton(
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(builder: (context) => RegisterScreen()),
                          );
                        },
                        child: Text(
                          'Register',
                          style: TextStyle(
                            color: AppTheme.accentColor,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 24),
                  // Or continue with
                  Row(
                    children: [
                      Expanded(child: Divider(color: AppTheme.textSecondaryColor)),
                      Padding(
                        padding: EdgeInsets.symmetric(horizontal: 16),
                        child: Text(
                          'OR CONTINUE WITH',
                          style: TextStyle(
                            color: AppTheme.textSecondaryColor,
                            fontSize: 12,
                          ),
                        ),
                      ),
                      Expanded(child: Divider(color: AppTheme.textSecondaryColor)),
                    ],
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
    return Expanded(
      child: OutlinedButton.icon(
        icon: Icon(icon, color: Colors.white),
        label: Text(platform),
        onPressed: () {
          Fluttertoast.showToast(
            msg: '$platform login coming soon',
            toastLength: Toast.LENGTH_SHORT,
            gravity: ToastGravity.BOTTOM,
            backgroundColor: AppTheme.primaryColor,
            textColor: Colors.white,
          );
        },
        style: OutlinedButton.styleFrom(
          foregroundColor: Colors.white,
          side: BorderSide(color: AppTheme.textSecondaryColor),
          padding: EdgeInsets.symmetric(vertical: 12),
        ),
      ),
    );
  }
}
