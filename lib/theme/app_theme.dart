import 'package:flutter/material.dart';

class AppTheme {
  // Netflix & Manga inspired color palette
  static const Color primaryColor = Color(0xFFE50914); // Netflix Red
  static const Color accentColor = Color(0xFFF47521);  // Orange
  static const Color backgroundColor = Color(0xFF141414); // Dark background
  static const Color cardColor = Color(0xFF1F1F1F); // Slightly lighter dark
  static const Color errorColor = Color(0xFFB00020);
  static const Color textPrimaryColor = Colors.white;
  static const Color textSecondaryColor = Color(0xFFB3B3B3);

  // Light theme (though app will primarily use dark theme)
  static ThemeData lightTheme = ThemeData(
    primaryColor: primaryColor,
    colorScheme: ColorScheme.light(
      primary: primaryColor,
      secondary: accentColor,
      error: errorColor,
      background: Colors.white,
      surface: Colors.white,
    ),
    scaffoldBackgroundColor: Colors.white,
    cardColor: Colors.white,
    appBarTheme: AppBarTheme(
      backgroundColor: primaryColor,
      elevation: 0,
      iconTheme: IconThemeData(color: Colors.white),
      titleTextStyle: TextStyle(
        color: Colors.white, 
        fontSize: 20, 
        fontWeight: FontWeight.bold
      ),
    ),
    tabBarTheme: TabBarTheme(
      labelColor: Colors.white,
      unselectedLabelColor: Colors.white70,
      indicatorColor: accentColor,
      indicatorSize: TabBarIndicatorSize.tab,
    ),
    floatingActionButtonTheme: FloatingActionButtonThemeData(
      backgroundColor: accentColor,
      foregroundColor: Colors.white,
    ),
    textTheme: TextTheme(
      bodyLarge: TextStyle(color: Colors.black87),
      bodyMedium: TextStyle(color: Colors.black87),
      titleMedium: TextStyle(color: Colors.black, fontWeight: FontWeight.bold),
      titleSmall: TextStyle(color: Colors.black54),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: primaryColor,
        foregroundColor: Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
        ),
        padding: EdgeInsets.symmetric(vertical: 16, horizontal: 24),
      ),
    ),
  );

  // Dark theme (Netflix inspired)
  static ThemeData darkTheme = ThemeData(
    primaryColor: primaryColor,
    colorScheme: ColorScheme.dark(
      primary: primaryColor,
      secondary: accentColor,
      error: errorColor,
      background: backgroundColor,
      surface: cardColor,
    ),
    scaffoldBackgroundColor: backgroundColor,
    cardColor: cardColor,
    appBarTheme: AppBarTheme(
      backgroundColor: backgroundColor,
      elevation: 0,
      iconTheme: IconThemeData(color: Colors.white),
      titleTextStyle: TextStyle(
        color: Colors.white, 
        fontSize: 20, 
        fontWeight: FontWeight.bold
      ),
    ),
    tabBarTheme: TabBarTheme(
      labelColor: Colors.white,
      unselectedLabelColor: Colors.white70,
      indicatorColor: accentColor,
      indicatorSize: TabBarIndicatorSize.tab,
    ),
    bottomNavigationBarTheme: BottomNavigationBarThemeData(
      backgroundColor: backgroundColor,
      selectedItemColor: primaryColor,
      unselectedItemColor: textSecondaryColor,
    ),
    floatingActionButtonTheme: FloatingActionButtonThemeData(
      backgroundColor: primaryColor,
      foregroundColor: Colors.white,
    ),
    textTheme: TextTheme(
      bodyLarge: TextStyle(color: Colors.white),
      bodyMedium: TextStyle(color: Colors.white),
      titleMedium: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
      titleSmall: TextStyle(color: textSecondaryColor),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: primaryColor,
        foregroundColor: Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
        ),
        padding: EdgeInsets.symmetric(vertical: 16, horizontal: 24),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: Colors.white.withOpacity(0.1),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: BorderSide.none,
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: BorderSide(color: textSecondaryColor.withOpacity(0.3)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: BorderSide(color: accentColor),
      ),
      labelStyle: TextStyle(color: textSecondaryColor),
      hintStyle: TextStyle(color: textSecondaryColor.withOpacity(0.7)),
    ),
  );
}
