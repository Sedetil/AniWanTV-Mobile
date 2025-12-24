import 'package:flutter/material.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart' as ads;
import 'package:provider/provider.dart';
import 'screens/home_screen.dart';
import 'screens/splash_screen.dart';
import 'theme/app_theme.dart';
import 'providers/app_state_provider.dart';
import 'services/ad_service.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:webview_flutter_android/webview_flutter_android.dart';
import 'package:flutter/services.dart';
import 'utils/toast_utils.dart';
import 'package:window_manager/window_manager.dart';
import 'dart:io' show Platform;

void main() async {
  // Initialize WebView platform
  WebViewPlatform.instance =
      WebViewPlatform.instance ?? AndroidWebViewPlatform();

  // Initialize Flutter binding
  WidgetsFlutterBinding.ensureInitialized();

  await SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
  SystemChrome.setSystemUIOverlayStyle(SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: Brightness.light,
    systemNavigationBarColor: Colors.black, // Set to black as requested
    systemNavigationBarIconBrightness: Brightness.light,
    systemNavigationBarDividerColor: Colors.transparent,
  ));

  // Initialize WindowManager for Desktop
  if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) {
    await windowManager.ensureInitialized();
    WindowOptions windowOptions = const WindowOptions(
      size: Size(1280, 720),
      center: true,
      backgroundColor: Colors.transparent,
      skipTaskbar: false,
      titleBarStyle: TitleBarStyle.normal,
      fullScreen: false,
    );
    await windowManager.waitUntilReadyToShow(windowOptions, () async {
      await windowManager.show();
      await windowManager.focus();
    });
  }

  // Initialize AdMob SDK only on supported platforms
  if (AdService.isMobileAdsSupported) {
    await MobileAds.instance.initialize();

    // Initialize UMP (User Messaging Platform) for GDPR/CCPA compliance
    ads.ConsentInformation.instance.requestConsentInfoUpdate(
      ads.ConsentRequestParameters(),
      () async {
        if (await ads.ConsentInformation.instance.isConsentFormAvailable()) {
          ads.ConsentForm.loadConsentForm(
            (ads.ConsentForm consentForm) async {
              consentForm.show(
                (formError) {
                  // Handle error if consent form fails to show
                  print('Consent form error: $formError');
                },
              );
            },
            (formError) {
              // Handle error if consent form fails to load
              print('Consent form load error: $formError');
            },
          );
        }
      },
      (formError) {
        // Handle error if consent info update fails
        print('Consent info update error: $formError');
      },
    );
  }

  runApp(
    ChangeNotifierProvider(
      create: (context) => AppStateProvider(),
      child: MyApp(),
    ),
  );
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Consumer<AppStateProvider>(
      builder: (context, appStateProvider, child) {
        return MaterialApp(
          scaffoldMessengerKey: ToastUtils.scaffoldMessengerKey,
          title: 'AniWanTV',
          theme: AppTheme.lightTheme,
          darkTheme: AppTheme.darkTheme,
          themeMode:
              appStateProvider.isDarkMode ? ThemeMode.dark : ThemeMode.light,
          home: SplashScreen(),
          debugShowCheckedModeBanner: false,
        );
      },
    );
  }
}
