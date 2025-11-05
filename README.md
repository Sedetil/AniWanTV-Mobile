# AniWanTV 📺

Aplikasi mobile streaming anime dan manga yang dibangun dengan Flutter. AniWanTV menyediakan akses ke ribuan anime dan manga dengan antarmuka yang modern dan user-friendly.

## 🌟 Fitur Utama

### 📱 Anime Streaming
- **Top Anime**: Daftar anime terpopuler dan rating tertinggi
- **Latest Releases**: Anime terbaru dengan sistem pagination
- **Episode Streaming**: Multiple quality options (360p, 480p, 720p, 1080p)
- **Custom Video Player**: Player dengan kontrol lengkap dan gesture support
- **Multiple Providers**: Dukungan berbagai server streaming (Krakenfiles, Mega, PixelDrain)

### 📚 Manga Reader
- **Manga/Comic Reading**: Reader dengan zoom dan scroll support
- **Chapter Navigation**: Navigasi mudah antar chapter
- **Reading Progress**: Auto-save posisi baca

### 🔍 Pencarian & Navigasi
- **Advanced Search**: Pencarian anime dan manga dengan filter
- **Genre Filtering**: Filter konten berdasarkan genre (Action, Romance, Comedy, dll)
- **Year-based Filtering**: Filter konten berdasarkan tahun rilis
- **Favorites System**: Simpan anime/manga favorit dengan local storage
- **Watch History**: Riwayat tontonan dengan auto-resume dan timestamp
- **Bottom Navigation**: Navigasi intuitif dengan 5 tab utama
- **Explore Screen**: Layar eksplorasi dengan tab Anime dan Manga terpisah

### 🎨 UI/UX Features
- **Dark Theme**: Tema gelap yang nyaman untuk mata dengan toggle option
- **Responsive Design**: Optimized untuk phone dan tablet
- **Carousel Slider**: Tampilan featured content yang menarik
- **Custom Widgets**: Komponen UI yang konsisten dan reusable
- **Error Handling**: Dialog error yang informatif dengan retry mechanism
- **Custom Loading Widgets**: Animasi loading yang menarik dengan shimmer effect
- **Progress Indicators**: Indikator progres dengan persentase untuk operasi async
- **Glass Morphism Design**: Desain modern dengan efek glass dan gradient
- **Hover Effects**: Efek hover yang smooth untuk desktop/web

### 💰 Monetization
- **Google AdMob**: Integrasi iklan dengan GDPR/CCPA compliance
- **UMP (User Messaging Platform)**: Consent management

### 🚀 Performance & Caching
- **API Response Caching**: Local cache dengan expiry 5 menit
- **Cache Management**: Kontrol cache untuk optimasi performa
- **Timeout Handling**: Timeout 30 detik untuk semua request
- **Error Recovery**: Fallback endpoints untuk critical operations
- **Lazy Loading**: Load data sesuai kebutuhan untuk menghemat bandwidth

## 🏗️ Arsitektur Aplikasi

### 📁 Struktur Folder
```
lib/
├── main.dart                 # Entry point aplikasi
├── screens/                  # Semua layar aplikasi
│   ├── splash_screen.dart    # Splash screen
│   ├── home_screen.dart      # Beranda utama
│   ├── search_screen.dart    # Pencarian
│   ├── explore_screen.dart   # Eksplorasi konten dengan genre filter
│   ├── anime_details_screen.dart  # Detail anime
│   ├── episode_streams_screen.dart # Daftar episode
│   ├── video_player_screen.dart   # Video player
│   ├── comic_details_screen.dart  # Detail manga/comic
│   ├── manga_reader_screen.dart   # Manga reader
│   ├── favorites_screen.dart      # Daftar favorit
│   ├── history_screen.dart        # Riwayat tontonan
│   ├── profile_screen.dart        # Profil user
│   ├── login_screen.dart          # Login
│   └── register_screen.dart       # Registrasi
├── widgets/                  # Custom widgets
│   ├── custom_bottom_nav_bar.dart # Bottom navigation
│   ├── custom_controls.dart       # Video player controls
│   ├── custom_error_dialog.dart   # Error dialog
│   ├── custom_loading_widget.dart # Loading animations
│   └── update_dialog.dart        # App update dialog with progress
├── services/                 # Backend services
│   ├── api_service.dart      # API integration dengan caching
│   ├── ad_service.dart       # AdMob integration
│   └── app_version_service.dart # App update and APK installation
├── providers/                # State management
│   └── app_state_provider.dart # Global app state
└── theme/                    # Theme configuration
    └── app_theme.dart        # App theme settings
```

### 🔧 Dependencies Utama

#### Core Flutter
- `flutter`: Framework utama
- `cupertino_icons`: iOS style icons

#### Networking & Data
- `http`: HTTP client untuk API calls
- `shared_preferences`: Local storage
- `flutter_cache_manager`: Cache management

#### UI Components
- `carousel_slider`: Carousel untuk featured content
- `cached_network_image`: Image caching
- `photo_view`: Image viewer dengan zoom
- `fluttertoast`: Toast notifications

#### Video & Media
- `video_player`: Video playback
- `chewie`: Advanced video player controls
- `webview_flutter`: WebView integration

#### State Management
- `provider`: State management dengan ChangeNotifier
- `shared_preferences`: Local storage persistence

#### Monetization
- `google_mobile_ads`: Google AdMob integration

#### Utilities
- `url_launcher`: Launch external URLs
- `flutter_launcher_icons`: Custom app icons
- `permission_handler`: Permission management for Android 13+
- `package_info_plus`: App version information
- `path_provider`: File system access
- `file_picker`: File selection dialog

## 🚀 Backend Integration

### API Endpoints
Aplikasi terhubung dengan Flask API backend yang di-deploy di Railway:
- **Base URL**: `https://web-production-0b9b9.up.railway.app`
- **Top Anime**: `/top-anime`
- **Latest Anime**: `/latest-anime?page={page}`
- **Anime Details**: `/anime-details?url={url}`
- **Episode Streams**: `/episode-streams-fast?url={url}`
- **Episode Streams (Fallback)**: `/episode-streams?url={url}`
- **Search Anime**: `/search?query={query}`
- **Search Comics**: `/search-comics?query={query}`
- **Latest Comics**: `/latest-comics?page={page}`
- **Comic Details**: `/comic-details?url={url}`
- **Chapter Images**: `/chapter-images?url={url}`
- **Genres**: `/genres`
- **Genre Content**: `/genre-content?url={url}&page={page}`
- **Cache Management**: `/clear-stream-cache`, `/cache-info`, `/optimization-status`

### Data Sources
Backend melakukan scraping dari:
- **winbu.tv**: Sumber utama anime
- **Various manga sites**: Untuk konten manga/comic

## 📱 Platform Support

- ✅ **Android**: Full support dengan AdMob
- ✅ **iOS**: Full support
- ✅ **Web**: PWA support
- ✅ **Windows**: Desktop support
- ✅ **macOS**: Desktop support
- ✅ **Linux**: Desktop support

## 🛠️ Setup & Installation

### Prerequisites
- Flutter SDK (>=3.3.0 <4.0.0)
- Dart SDK
- Android Studio / VS Code
- Git

### Installation Steps

1. **Clone Repository**
   ```bash
   git clone <repository-url>
   cd aniwantv
   ```

2. **Install Dependencies**
   ```bash
   flutter pub get
   ```

3. **Configure AdMob (Optional)**
   - Ganti AdMob App ID di `android/app/src/main/AndroidManifest.xml`
   - Update ad unit IDs di kode aplikasi

4. **Generate App Icons**
   ```bash
   flutter pub run flutter_launcher_icons:main
   ```

5. **Run Application**
   ```bash
   flutter run
   ```

### Build for Production

**Android APK:**
```bash
flutter build apk --release
```

**Android App Bundle:**
```bash
flutter build appbundle --release
```

**iOS:**
```bash
flutter build ios --release
```

**Web:**
```bash
flutter build web --release
```

## 🔧 Configuration

### App Configuration
- **App Name**: AniWanTV
- **Package Name**: `com.example.aniwantv`
- **Version**: 1.0.0+1

### AdMob Configuration
- **App ID**: `ca-app-pub-7591838535085655~9508273019`
- **Test Mode**: Enabled untuk development
- **GDPR Compliance**: UMP integration

### Permissions
- `INTERNET`: Network access
- `ACCESS_NETWORK_STATE`: Network state monitoring
- `READ_EXTERNAL_STORAGE`: File access (Android)
- `WRITE_EXTERNAL_STORAGE`: File write access (Android)
- `MANAGE_EXTERNAL_STORAGE`: Full storage access (Android 13+)
- `READ_MEDIA_*`: Granular media permissions (Android 13+)
- `REQUEST_INSTALL_PACKAGES`: APK installation permission

## 🔄 Pembaruan Terbaru

### 📋 Bug Fixes & Improvements (v1.0.1)
- [x] **Permission Handler Fix**: Memperbaiki `MissingPluginException` untuk permission_handler
- [x] **Android 13+ Compatibility**: Menambahkan granular media permissions (READ_MEDIA_*)
- [x] **APK Installation**: Implementasi native APK installation dengan MethodChannel
- [x] **FileProvider Configuration**: Konfigurasi secure file access untuk APK installation
- [x] **Storage Permission**: Improved permission handling untuk semua Android version
- [x] **Plugin Registration**: Proper plugin registration di MainActivity.kt dan AppDelegate.swift

### 🛠️ Technical Updates
- Added custom MethodChannel untuk APK installation
- Updated AndroidManifest.xml dengan lengkap permissions
- Created file_paths.xml untuk FileProvider configuration
- Improved error handling untuk permission requests
- Platform-specific permission checks (Android/iOS)

## 🎯 Fitur Mendatang

- [x] **Genre Filtering**: Filter konten berdasarkan kategori
- [x] **Year-based Filtering**: Filter konten berdasarkan tahun rilis
- [x] **Advanced Caching**: Local cache dengan expiry management
- [x] **Custom Loading Animations**: Loading widgets dengan shimmer effect
- [x] **Glass Morphism UI**: Desain modern dengan efek glass
- [x] **Auto Update System**: Automatic app update dengan progress indicator
- [ ] **User Authentication**: Login/Register system
- [ ] **Download Episodes**: Offline viewing
- [ ] **Push Notifications**: Episode release notifications
- [ ] **Social Features**: Comments dan ratings
- [ ] **Subtitle Support**: Multiple language subtitles
- [ ] **Chromecast Support**: Cast ke TV
- [ ] **Watchlist Management**: Daftar tonton terorganisir
- [ ] **Recommendation System**: Rekomendasi konten berdasarkan preferensi
