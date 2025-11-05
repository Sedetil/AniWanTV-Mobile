import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';

class AppStateProvider extends ChangeNotifier {
  // User data
  String _username = 'Guest User';
  String _email = 'guest@example.com';
  bool _isLoggedIn = false;
  bool _isDarkMode = true;
  
  // App data
  List<dynamic> _favoriteAnime = [];
  List<dynamic> _favoriteComics = [];
  List<dynamic> _animeHistory = [];
  List<dynamic> _comicHistory = [];
  bool _isLoading = false;
  String _errorMessage = '';
  
  // Getters
  String get username => _username;
  String get email => _email;
  bool get isLoggedIn => _isLoggedIn;
  bool get isDarkMode => _isDarkMode;
  List<dynamic> get favoriteAnime => _favoriteAnime;
  List<dynamic> get favoriteComics => _favoriteComics;
  List<dynamic> get animeHistory => _animeHistory;
  List<dynamic> get comicHistory => _comicHistory;
  bool get isLoading => _isLoading;
  String get errorMessage => _errorMessage;
  
  // Initialize from SharedPreferences
  Future<void> initialize() async {
    await _loadUserData();
    await _loadFavorites();
    await _loadHistory();
  }
  
  // User data methods
  Future<void> _loadUserData() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      _username = prefs.getString('username') ?? 'Guest User';
      _email = prefs.getString('email') ?? 'guest@example.com';
      _isLoggedIn = prefs.getBool('isLoggedIn') ?? false;
      _isDarkMode = prefs.getBool('dark_mode') ?? true;
      notifyListeners();
    } catch (e) {
      _setErrorMessage('Failed to load user data: $e');
    }
  }
  
  Future<void> updateUserData({
    String? username,
    String? email,
    bool? isLoggedIn,
    bool? isDarkMode,
  }) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      
      if (username != null) {
        _username = username;
        await prefs.setString('username', username);
      }
      
      if (email != null) {
        _email = email;
        await prefs.setString('email', email);
      }
      
      if (isLoggedIn != null) {
        _isLoggedIn = isLoggedIn;
        await prefs.setBool('isLoggedIn', isLoggedIn);
      }
      
      if (isDarkMode != null) {
        _isDarkMode = isDarkMode;
        await prefs.setBool('dark_mode', isDarkMode);
      }
      
      notifyListeners();
    } catch (e) {
      _setErrorMessage('Failed to update user data: $e');
    }
  }
  
  Future<void> logout() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('username');
      await prefs.remove('email');
      await prefs.remove('isLoggedIn');
      
      _username = 'Guest User';
      _email = 'guest@example.com';
      _isLoggedIn = false;
      
      notifyListeners();
    } catch (e) {
      _setErrorMessage('Failed to logout: $e');
    }
  }
  
  // Favorites methods
  Future<void> _loadFavorites() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final animeJson = prefs.getString('favorite_anime') ?? '[]';
      final comicsJson = prefs.getString('favorite_comics') ?? '[]';
      
      _favoriteAnime = jsonDecode(animeJson);
      _favoriteComics = jsonDecode(comicsJson);
      notifyListeners();
    } catch (e) {
      _setErrorMessage('Failed to load favorites: $e');
    }
  }
  
  Future<void> addToFavorites(dynamic item, bool isAnime) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final key = isAnime ? 'favorite_anime' : 'favorite_comics';
      final list = isAnime ? _favoriteAnime : _favoriteComics;
      
      // Check if item already exists
      if (list.any((existingItem) => existingItem['url'] == item['url'])) {
        _setErrorMessage('Item already in favorites');
        return;
      }
      
      // Add new item
      final newItem = {
        ...item,
        'id': DateTime.now().millisecondsSinceEpoch.toString(),
        'type': isAnime ? 'anime' : 'comic',
      };
      
      list.insert(0, newItem);
      
      // Update state and storage
      if (isAnime) {
        _favoriteAnime = list;
      } else {
        _favoriteComics = list;
      }
      
      await prefs.setString(key, jsonEncode(list));
      notifyListeners();
    } catch (e) {
      _setErrorMessage('Failed to add to favorites: $e');
    }
  }
  
  Future<void> removeFromFavorites(String id, bool isAnime) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final key = isAnime ? 'favorite_anime' : 'favorite_comics';
      final list = isAnime ? _favoriteAnime : _favoriteComics;
      
      final updatedList = list.where((item) => item['id'] != id).toList();
      
      // Update state and storage
      if (isAnime) {
        _favoriteAnime = updatedList;
      } else {
        _favoriteComics = updatedList;
      }
      
      await prefs.setString(key, jsonEncode(updatedList));
      notifyListeners();
    } catch (e) {
      _setErrorMessage('Failed to remove from favorites: $e');
    }
  }
  
  // History methods
  Future<void> _loadHistory() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final animeJson = prefs.getString('anime_history') ?? '[]';
      final comicsJson = prefs.getString('comic_history') ?? '[]';
      
      _animeHistory = jsonDecode(animeJson);
      _comicHistory = jsonDecode(comicsJson);
      notifyListeners();
    } catch (e) {
      _setErrorMessage('Failed to load history: $e');
    }
  }
  
  Future<void> addToHistory(dynamic item, bool isAnime) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final key = isAnime ? 'anime_history' : 'comic_history';
      final list = isAnime ? _animeHistory : _comicHistory;
      
      // Remove existing item with same URL
      list.removeWhere((existingItem) => existingItem['url'] == item['url']);
      
      // Add new item at the beginning
      final newItem = {
        ...item,
        'id': DateTime.now().millisecondsSinceEpoch.toString(),
        'type': isAnime ? 'anime' : 'comic',
        'timestamp': DateTime.now().toString(),
      };
      
      list.insert(0, newItem);
      
      // Limit history to 50 items
      if (list.length > 50) {
        list.removeRange(50, list.length);
      }
      
      // Update state and storage
      if (isAnime) {
        _animeHistory = list;
      } else {
        _comicHistory = list;
      }
      
      await prefs.setString(key, jsonEncode(list));
      notifyListeners();
    } catch (e) {
      _setErrorMessage('Failed to add to history: $e');
    }
  }
  
  Future<void> removeFromHistory(String id, bool isAnime) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final key = isAnime ? 'anime_history' : 'comic_history';
      final list = isAnime ? _animeHistory : _comicHistory;
      
      final updatedList = list.where((item) => item['id'] != id).toList();
      
      // Update state and storage
      if (isAnime) {
        _animeHistory = updatedList;
      } else {
        _comicHistory = updatedList;
      }
      
      await prefs.setString(key, jsonEncode(updatedList));
      notifyListeners();
    } catch (e) {
      _setErrorMessage('Failed to remove from history: $e');
    }
  }
  
  Future<void> clearHistory(bool isAnime) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final key = isAnime ? 'anime_history' : 'comic_history';
      
      await prefs.setString(key, '[]');
      
      // Update state
      if (isAnime) {
        _animeHistory = [];
      } else {
        _comicHistory = [];
      }
      
      notifyListeners();
    } catch (e) {
      _setErrorMessage('Failed to clear history: $e');
    }
  }
  
  // Loading and error methods
  void setLoading(bool loading) {
    _isLoading = loading;
    notifyListeners();
  }
  
  void _setErrorMessage(String message) {
    _errorMessage = message;
    notifyListeners();
  }
  
  void clearErrorMessage() {
    _errorMessage = '';
    notifyListeners();
  }
}