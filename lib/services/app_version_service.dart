import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:package_info_plus/package_info_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:flutter/services.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as path;
import 'package:shared_preferences/shared_preferences.dart';

class AppVersionService {
  static String _baseUrl = 'http://38.47.176.56:5000/api/app_version';
  static const String _prefsKeyAppVersionUrl = 'app_version_url';
  static bool _baseUrlLoaded = false;

  static Future<void> _ensureBaseUrlLoaded() async {
    if (_baseUrlLoaded) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      final saved = prefs.getString(_prefsKeyAppVersionUrl);
      if (saved != null && saved.isNotEmpty) {
        _baseUrl = saved;
      }
    } catch (_) {}
    _baseUrlLoaded = true;
  }

  static Future<void> setBaseUrl(String url) async {
    _baseUrl = url;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_prefsKeyAppVersionUrl, url);
    } catch (_) {}
  }

  static String getBaseUrl() {
    return _baseUrl;
  }

  // Mendapatkan informasi versi terbaru dari server
  static Future<Map<String, dynamic>?> getAppVersion() async {
    try {
      await _ensureBaseUrlLoaded();
      final response = await http.get(
        Uri.parse(_baseUrl),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        return json.decode(response.body);
      } else {
        print('Failed to load app version: ${response.statusCode}');
        return null;
      }
    } catch (e) {
      print('Error checking app version: $e');
      return null;
    }
  }

  // Mendapatkan versi aplikasi saat ini
  static Future<String> getCurrentVersion() async {
    try {
      final packageInfo = await PackageInfo.fromPlatform();
      return packageInfo.version;
    } catch (e) {
      print('Error getting current version: $e');
      return '1.0.0'; // Default version
    }
  }

  // Membandingkan versi
  // Return: -1 jika current < latest, 0 jika sama, 1 jika current > latest
  static int compareVersions(String current, String latest) {
    try {
      final currentParts =
          current.split('.').map((e) => int.tryParse(e) ?? 0).toList();
      final latestParts =
          latest.split('.').map((e) => int.tryParse(e) ?? 0).toList();

      // Make both lists the same length by padding with zeros
      final maxLength = currentParts.length > latestParts.length
          ? currentParts.length
          : latestParts.length;

      while (currentParts.length < maxLength) currentParts.add(0);
      while (latestParts.length < maxLength) latestParts.add(0);

      for (int i = 0; i < maxLength; i++) {
        if (currentParts[i] < latestParts[i]) return -1;
        if (currentParts[i] > latestParts[i]) return 1;
      }

      return 0;
    } catch (e) {
      print('Error comparing versions: $e');
      return 0;
    }
  }

  // Mengecek apakah ada update tersedia
  static Future<bool> isUpdateAvailable() async {
    try {
      final versionData = await getAppVersion();
      if (versionData == null || !versionData.containsKey('version')) {
        return false;
      }

      final latestVersion = versionData['version'];
      final currentVersion = await getCurrentVersion();

      return compareVersions(currentVersion, latestVersion) < 0;
    } catch (e) {
      print('Error checking for update: $e');
      return false;
    }
  }

  // Membuka URL download
  static Future<bool> openDownloadUrl() async {
    try {
      final versionData = await getAppVersion();
      if (versionData == null || !versionData.containsKey('download_url')) {
        return false;
      }

      final downloadUrl = versionData['download_url'];
      final uri = Uri.parse(downloadUrl);

      if (await canLaunchUrl(uri)) {
        return await launchUrl(
          uri,
          mode: LaunchMode.externalApplication,
        );
      } else {
        print('Could not launch $downloadUrl');
        return false;
      }
    } catch (e) {
      print('Error opening download URL: $e');
      return false;
    }
  }

  // Mendapatkan URL download
  static Future<String?> getDownloadUrl() async {
    try {
      final versionData = await getAppVersion();
      if (versionData == null || !versionData.containsKey('download_url')) {
        return null;
      }

      return versionData['download_url'];
    } catch (e) {
      print('Error getting download URL: $e');
      return null;
    }
  }

  // Mendapatkan changelog
  static Future<String?> getChangelog() async {
    try {
      final versionData = await getAppVersion();
      if (versionData == null || !versionData.containsKey('changelog')) {
        return null;
      }

      return versionData['changelog'];
    } catch (e) {
      print('Error getting changelog: $e');
      return null;
    }
  }

  // Download dan install APK dengan progress
  static Future<void> downloadAndInstallApk({
    required String downloadUrl,
    required Function(double) onProgress,
    Function()? onComplete,
    Function(String)? onError,
  }) async {
    try {
      // Request storage permission untuk Android
      if (await _requestStoragePermission()) {
        // Get temporary directory
        final tempDir = await getTemporaryDirectory();
        final savePath = path.join(tempDir.path, 'aniwantv_update.apk');

        // Download file dengan progress
        final request = http.Request('GET', Uri.parse(downloadUrl));
        final streamedResponse = await request.send();

        final contentLength = streamedResponse.contentLength ?? 0;
        if (contentLength == 0) {
          onError?.call('Invalid file size');
          return;
        }

        final file = File(savePath);
        final sink = file.openWrite();
        int downloadedBytes = 0;

        await for (final chunk in streamedResponse.stream) {
          sink.add(chunk);
          downloadedBytes += chunk.length;
          onProgress(downloadedBytes / contentLength);
        }

        await sink.close();

        // Install APK
        onProgress(1.0); // Complete download

        try {
          // Use platform channel to trigger APK installation
          const platform = MethodChannel('com.streaming.aniwantv/installer');
          final result = await platform.invokeMethod('installApk', {'path': savePath});
          
          if (result == 'success') {
            onComplete?.call();
          } else {
            onError?.call('Installation failed: $result');
          }
        } catch (e) {
          print('Error installing APK: $e');
          onError?.call('Installation error: $e');
        }
      } else {
        onError?.call('Storage permission denied');
      }
    } catch (e) {
      print('Error downloading APK: $e');
      onError?.call('Error: $e');
    }
  }

  // Request storage permission
  static Future<bool> _requestStoragePermission() async {
    try {
      // For Android 13+ (API 33+) use more granular permissions
      // For older versions use WRITE_EXTERNAL_STORAGE
      if (Platform.isAndroid) {
        // Check if we already have permission
        if (await Permission.storage.isGranted ||
            await Permission.manageExternalStorage.isGranted) {
          return true;
        }
        
        // Request storage permission
        final storageStatus = await Permission.storage.request();
        if (storageStatus.isGranted) {
          return true;
        }
        
        // If storage permission is denied, try manage external storage
        final manageStatus = await Permission.manageExternalStorage.request();
        if (manageStatus.isGranted) {
          return true;
        }
        
        return false;
      } else {
        // iOS doesn't need these permissions for downloading to app directory
        return true;
      }
    } catch (e) {
      print('Error requesting permission: $e');
      return false;
    }
  }

  // Check if update is available and return update info
  static Future<Map<String, dynamic>?> getUpdateInfo() async {
    try {
      final isUpdateAvailable = await AppVersionService.isUpdateAvailable();
      if (!isUpdateAvailable) return null;

      final versionData = await getAppVersion();
      final changelog = await getChangelog();
      final downloadUrl = await getDownloadUrl();

      return {
        'version': versionData?['version'],
        'downloadUrl': downloadUrl,
        'changelog': changelog,
        'versionData': versionData,
      };
    } catch (e) {
      print('Error getting update info: $e');
      return null;
    }
  }
}
