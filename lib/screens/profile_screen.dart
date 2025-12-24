import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:provider/provider.dart';
import 'package:flutter_svg/flutter_svg.dart';
import '../theme/app_theme.dart';
import '../widgets/custom_error_dialog.dart';
import '../screens/home_screen.dart';
import '../providers/app_state_provider.dart';
import 'favorites_screen.dart';
import 'login_screen.dart';
import '../utils/toast_utils.dart';
import '../services/api_service.dart';
import '../services/app_version_service.dart';
import 'splash_screen.dart';

class ProfileScreen extends StatefulWidget {
  @override
  _ProfileScreenState createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  String username = '';
  String email = '';
  bool isDarkMode = true; // Default to dark as per design
  bool isLoading = true;
  String _apiBaseUrl = '';
  String _appVersionUrl = '';
  
  // Dummy states for the UI mockup
  bool _streamCellular = true;
  bool _showMatureContent = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Provider.of<AppStateProvider>(context, listen: false).initialize();
    });
    _loadUserData();
    _loadApiConfig();
  }

  Future<void> _loadUserData() async {
    setState(() => isLoading = true);
    try {
      final appStateProvider = Provider.of<AppStateProvider>(context, listen: false);
      await appStateProvider.initialize();

      setState(() {
        username = appStateProvider.username;
        email = appStateProvider.email;
        isDarkMode = appStateProvider.isDarkMode;
        isLoading = false;
      });
    } catch (e) {
      setState(() => isLoading = false);
      _showErrorDialog('Error Loading Profile', 'Failed to load user data: $e');
    }
  }

  Future<void> _loadApiConfig() async {
    setState(() {
      _apiBaseUrl = ApiService.getBaseUrl();
      _appVersionUrl = AppVersionService.getBaseUrl();
    });
  }

  void _showErrorDialog(String title, String message) {
    CustomErrorDialog.show(
      context,
      title: title,
      message: message,
      onRetry: _loadUserData,
    );
  }

  Future<void> _logout() async {
    try {
      final appStateProvider = Provider.of<AppStateProvider>(context, listen: false);
      await appStateProvider.logout();

      ToastUtils.show('Logged out successfully', backgroundColor: AppTheme.accentColor);

      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (context) => LoginScreen()),
        (route) => false,
      );
    } catch (e) {
      _showErrorDialog('Error Logging Out', 'Failed to log out: $e');
    }
  }

  void _showEditApiDialog() {
    final apiController = TextEditingController(text: _apiBaseUrl);
    final appVersionController = TextEditingController(text: _appVersionUrl);
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppTheme.cardColor,
        title: Text('Edit API URLs', style: TextStyle(color: Colors.white)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: apiController,
              decoration: InputDecoration(
                labelText: 'API Base URL',
                labelStyle: TextStyle(color: AppTheme.textSecondaryColor),
                enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: AppTheme.textSecondaryColor)),
                focusedBorder: UnderlineInputBorder(borderSide: BorderSide(color: AppTheme.primaryColor)),
              ),
              style: TextStyle(color: Colors.white),
            ),
            SizedBox(height: 12),
            TextField(
              controller: appVersionController,
              decoration: InputDecoration(
                labelText: 'App Version URL',
                labelStyle: TextStyle(color: AppTheme.textSecondaryColor),
                enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: AppTheme.textSecondaryColor)),
                focusedBorder: UnderlineInputBorder(borderSide: BorderSide(color: AppTheme.primaryColor)),
              ),
              style: TextStyle(color: Colors.white),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Cancel', style: TextStyle(color: AppTheme.textSecondaryColor)),
          ),
          TextButton(
            onPressed: () async {
              final apiUrl = apiController.text.trim();
              final verUrl = appVersionController.text.trim();
              if (apiUrl.isNotEmpty) await ApiService.setBaseUrl(apiUrl);
              if (verUrl.isNotEmpty) await AppVersionService.setBaseUrl(verUrl);
              setState(() {
                _apiBaseUrl = ApiService.getBaseUrl();
                _appVersionUrl = AppVersionService.getBaseUrl();
              });
              ApiService.clearCache();
              Navigator.pop(context);
              Navigator.of(context).pushAndRemoveUntil(
                MaterialPageRoute(builder: (_) => SplashScreen()),
                (route) => false,
              );
            },
            child: Text('Save', style: TextStyle(color: AppTheme.primaryColor)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      body: SafeArea(
        child: isLoading
            ? Center(child: CircularProgressIndicator(color: AppTheme.primaryColor))
            : SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 16.0),
                child: Column(
                  children: [
                    // Header Title
                    Center(
                      child: Text(
                        'Profile',
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                    ),
                    const SizedBox(height: 32),
                    
                    // Avatar
                    SizedBox(
                      width: 160,
                      height: 160,
                      child: SvgPicture.asset(
                        'assets/images/anime_profile.svg',
                        fit: BoxFit.contain,
                      ),
                    ),
                    
                    const SizedBox(height: 40),
                    
                    // Account Section
                    _buildSectionContainer(
                      children: [
                         _buildMenuItem('Paket Berlangganan', onTap: () {}),
                         _buildMenuItem('Ganti Email', onTap: () {}),
                         _buildMenuItem('Ganti Password', onTap: () {}),
                         // Keeping API Endpoint here as requested
                         _buildMenuItem('API Endpoint', onTap: _showEditApiDialog),
                      ],
                    ),
                    
                    const SizedBox(height: 24),
                    
                    // Preferences Title
                    Align(
                      alignment: Alignment.centerLeft,
                      child: Padding(
                        padding: const EdgeInsets.only(left: 8.0, bottom: 8.0),
                        child: Text(
                          'Preferences',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                    
                    // Preferences Section
                    _buildSectionContainer(
                      children: [
                        _buildMenuItem('Bahasa Audio', trailing: 'Japanese', onTap: () {}),
                        _buildMenuItem('Bahasa Subtitle', trailing: 'English', onTap: () {}),
                        _buildSwitchItem('Gunakan Data Seluler', _streamCellular, (val) => setState(() => _streamCellular = val)),
                        _buildSwitchItem('Tampilkan Konten 18+', _showMatureContent, (val) => setState(() => _showMatureContent = val)),
                      ],
                    ),
                    
                    const SizedBox(height: 40),
                    
                    // Sign Out Button
                    Center(
                      child: ElevatedButton(
                        onPressed: _showLogoutDialog,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFFE53935), // merah
                          elevation: 0,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 40, // lebar tombol
                            vertical: 14,   // tinggi tombol
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(999), // pill shape
                          ),
                        ),
                        child: const Text(
                          'Sign out',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                  ],
                ),
              ),
      ),
    );
  }

  Widget _buildSectionContainer({required List<Widget> children}) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF1E1E1E),
        borderRadius: BorderRadius.circular(20),
      ),
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Column(
        children: children,
      ),
    );
  }

  Widget _buildMenuItem(String title, {String? trailing, VoidCallback? onTap}) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              title,
              style: TextStyle(
                color: Colors.grey[200],
                fontSize: 16,
                fontWeight: FontWeight.w500,
              ),
            ),
            Row(
              children: [
                if (trailing != null) ...[
                  Text(
                    trailing,
                    style: TextStyle(
                      color: Colors.grey[500],
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(width: 8),
                ],
                Icon(
                  Icons.arrow_forward_ios,
                  color: Colors.grey[600],
                  size: 16,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSwitchItem(String title, bool value, Function(bool) onChanged) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            title,
            style: TextStyle(
              color: Colors.grey[200],
              fontSize: 16,
              fontWeight: FontWeight.w500,
            ),
          ),
          Switch(
            value: value,
            onChanged: onChanged,
            activeColor: Colors.white,
            activeTrackColor: const Color(0xFFE53935), // Red track
            inactiveThumbColor: Colors.white,
            inactiveTrackColor: Colors.grey[700],
          ),
        ],
      ),
    );
  }
  
  void _showLogoutDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1E1E1E),
        title: Text('Logout', style: TextStyle(color: Colors.white)),
        content: Text('Are you sure you want to logout?', style: TextStyle(color: Colors.grey[400])),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Cancel', style: TextStyle(color: Colors.grey)),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _logout();
            },
            child: Text('Logout', style: TextStyle(color: const Color(0xFFE53935))),
          ),
        ],
      ),
    );
  }
}
