import 'dart:convert';
import 'dart:async';
import 'dart:io';
import 'package:http/http.dart' as http;

class ApiService {
  static const String baseUrl =
      'https://web-production-0b9b9.up.railway.app';
  
  // Timeout duration for API requests
  static const Duration _timeout = Duration(seconds: 30);
  
  // Cache for API responses
  static final Map<String, dynamic> _cache = {};
  static const Duration _cacheExpiry = Duration(minutes: 5);
  static final Map<String, DateTime> _cacheTimestamps = {};

  // Generic request method with error handling
  static Future<Map<String, dynamic>> _makeRequest(
    String endpoint, {
    Map<String, String>? queryParameters,
    bool useCache = true,
  }) async {
    final cacheKey = '$endpoint${queryParameters?.toString() ?? ''}';
    
    // Check cache first
    if (useCache && _cache.containsKey(cacheKey)) {
      final timestamp = _cacheTimestamps[cacheKey];
      if (timestamp != null && DateTime.now().difference(timestamp) < _cacheExpiry) {
        print('Using cached response for $endpoint');
        return _cache[cacheKey];
      }
    }
    
    try {
      final uri = Uri.parse('$baseUrl$endpoint').replace(
        queryParameters: queryParameters,
      );
      
      print('Making request to: $uri');
      
      final response = await http.get(uri).timeout(_timeout);
      
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        
        // Cache response
        if (useCache) {
          _cache[cacheKey] = data;
          _cacheTimestamps[cacheKey] = DateTime.now();
        }
        
        return data;
      } else {
        throw ApiException(
          'Request failed with status code: ${response.statusCode}',
          statusCode: response.statusCode,
        );
      }
    } on SocketException catch (e) {
      throw ApiException(
        'Network error: Please check your internet connection',
        originalError: e as Exception,
      );
    } on TimeoutException catch (e) {
      throw ApiException(
        'Request timeout: Server is taking too long to respond',
        originalError: e,
      );
    } on FormatException catch (e) {
      throw ApiException(
        'Invalid response format: ${e.message}',
        originalError: e,
      );
    } catch (e) {
      throw ApiException(
        'Unexpected error: ${e.toString()}',
        originalError: e is Exception ? e : Exception(e.toString()),
      );
    }
  }

  // Clear cache
  static void clearCache() {
    _cache.clear();
    _cacheTimestamps.clear();
    print('API cache cleared');
  }

  // Get cache info
  static Map<String, dynamic> getLocalCacheInfo() {
    return {
      'size': _cache.length,
      'keys': _cache.keys.toList(),
    };
  }

  // API Methods
  static Future<List<dynamic>> fetchTopAnime() async {
    try {
      final response = await _makeRequest('/top-anime');
      if (response['data'] != null) {
        return response['data'];
      } else {
        throw ApiException('Invalid response format: missing data field');
      }
    } catch (e) {
      throw ApiException('Failed to load top anime: ${e.toString()}');
    }
  }

  static Future<List<dynamic>> fetchLatestAnime({int page = 1}) async {
    try {
      final response = await _makeRequest(
        '/latest-anime',
        queryParameters: {'page': page.toString()},
      );
      if (response['data'] != null && response['data']['anime_list'] != null) {
        return response['data']['anime_list'];
      } else {
        throw ApiException('Invalid response format: missing anime_list field');
      }
    } catch (e) {
      throw ApiException('Failed to load latest anime: ${e.toString()}');
    }
  }

  static Future<dynamic> fetchAnimeDetails(String url) async {
    try {
      final response = await _makeRequest(
        '/anime-details',
        queryParameters: {'url': url},
      );
      if (response['data'] != null) {
        return response['data'];
      } else {
        throw ApiException('Invalid response format: missing data field');
      }
    } catch (e) {
      throw ApiException('Failed to load anime details: ${e.toString()}');
    }
  }

  static Future<dynamic> fetchEpisodeStreams(String url) async {
    try {
      final response = await _makeRequest(
        '/episode-streams-fast',
        queryParameters: {'url': url},
      );
      if (response['data'] != null) {
        return response['data'];
      } else {
        throw ApiException('Invalid response format: missing data field');
      }
    } catch (e) {
      throw ApiException('Failed to load episode streams: ${e.toString()}');
    }
  }

  // Fallback method using original endpoint if needed
  static Future<dynamic> fetchEpisodeStreamsOriginal(String url) async {
    try {
      final response = await _makeRequest(
        '/episode-streams',
        queryParameters: {'url': url},
      );
      if (response['data'] != null) {
        return response['data'];
      } else {
        throw ApiException('Invalid response format: missing data field');
      }
    } catch (e) {
      throw ApiException('Failed to load episode streams: ${e.toString()}');
    }
  }

  // Cache management methods
  static Future<bool> clearStreamCache() async {
    try {
      final response =
          await http.post(Uri.parse('$baseUrl/clear-stream-cache'));
      return response.statusCode == 200;
    } catch (e) {
      return false;
    }
  }

  static Future<dynamic> getCacheInfo() async {
    try {
      final response = await http.get(Uri.parse('$baseUrl/cache-info'));
      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      }
    } catch (e) {
      // Ignore errors for cache info
    }
    return null;
  }

  static Future<dynamic> getOptimizationStatus() async {
    try {
      final response =
          await http.get(Uri.parse('$baseUrl/optimization-status'));
      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      }
    } catch (e) {
      // Ignore errors for optimization status
    }
    return null;
  }

  static Future<List<dynamic>> searchAnime(String query) async {
    try {
      final response = await _makeRequest(
        '/search',
        queryParameters: {'query': query},
      );
      if (response['data'] != null) {
        final data = response['data'];
        // Add type 'anime' to each item
        return data.map((item) => {...item, 'type': 'anime'}).toList();
      } else {
        throw ApiException('Invalid response format: missing data field');
      }
    } catch (e) {
      throw ApiException('Failed to search anime: ${e.toString()}');
    }
  }

  static Future<List<dynamic>> fetchLatestComics({int page = 1}) async {
    try {
      final response = await _makeRequest(
        '/latest-comics',
        queryParameters: {'page': page.toString()},
      );
      if (response['data'] != null && response['data']['comic_list'] != null) {
        return response['data']['comic_list'];
      } else {
        throw ApiException('Invalid response format: missing comic_list field');
      }
    } catch (e) {
      throw ApiException('Failed to load latest comics: ${e.toString()}');
    }
  }

  static Future<dynamic> fetchComicDetails(String url) async {
    try {
      final response = await _makeRequest(
        '/comic-details',
        queryParameters: {'url': url},
      );
      if (response['data'] != null) {
        return response['data'];
      } else {
        throw ApiException('Invalid response format: missing data field');
      }
    } catch (e) {
      throw ApiException('Failed to load comic details: ${e.toString()}');
    }
  }

  static Future<List<dynamic>> searchComics(String query) async {
    try {
      final response = await _makeRequest(
        '/search-comics',
        queryParameters: {'query': query},
      );
      if (response['data'] != null) {
        final data = response['data'];
        // Add type 'comic' to each item
        return data.map((item) => {...item, 'type': 'comic'}).toList();
      } else {
        throw ApiException('Invalid response format: missing data field');
      }
    } catch (e) {
      throw ApiException('Failed to search comics: ${e.toString()}');
    }
  }

  static Future<dynamic> fetchChapterImages(String url) async {
    try {
      final response = await _makeRequest(
        '/chapter-images',
        queryParameters: {'url': url},
      );
      if (response['data'] != null) {
        return response['data'];
      } else {
        throw ApiException('Invalid response format: missing data field');
      }
    } catch (e) {
      throw ApiException('Failed to load chapter images: ${e.toString()}');
    }
  }

  static Future<List<dynamic>> fetchGenres() async {
    try {
      final response = await _makeRequest('/genres');
      if (response['data'] != null) {
        return response['data'];
      } else {
        throw ApiException('Invalid response format: missing data field');
      }
    } catch (e) {
      throw ApiException('Failed to load genres: ${e.toString()}');
    }
  }

  static Future<dynamic> fetchGenreContent(String genreUrl, {int page = 1}) async {
    try {
      final response = await _makeRequest(
        '/genre-content',
        queryParameters: {'url': genreUrl, 'page': page.toString()},
      );
      if (response['data'] != null) {
        return response['data'];
      } else {
        throw ApiException('Invalid response format: missing data field');
      }
    } catch (e) {
      throw ApiException('Failed to load genre content: ${e.toString()}');
    }
  }
}

// Custom exception class for API errors
class ApiException implements Exception {
  final String message;
  final int? statusCode;
  final Exception? originalError;
  
  ApiException(this.message, {this.statusCode, this.originalError});
  
  @override
  String toString() => message;
}
