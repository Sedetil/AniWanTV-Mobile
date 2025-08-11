import 'package:flutter/material.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart' as ads;
import 'screens/home_screen.dart';
import 'screens/splash_screen.dart';
import 'theme/app_theme.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:webview_flutter_android/webview_flutter_android.dart';

void main() async {
  // Initialize WebView platform
  WebViewPlatform.instance =
      WebViewPlatform.instance ?? AndroidWebViewPlatform();

  // Initialize Flutter binding
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize AdMob SDK
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

  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'AniWanTV',
      theme: AppTheme.lightTheme,
      home: SplashScreen(),
      debugShowCheckedModeBanner: false,
    );
  }
}
