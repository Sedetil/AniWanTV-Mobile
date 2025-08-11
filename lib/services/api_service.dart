import 'dart:convert';
import 'package:http/http.dart' as http;

class ApiService {
  static const String baseUrl =
      'https://web-production-ced7.up.railway.app'; // Changed to port 5000 for optimized server

  Future<List<dynamic>> fetchTopAnime() async {
    final response = await http.get(Uri.parse('$baseUrl/top-anime'));
    if (response.statusCode == 200) {
      return jsonDecode(response.body)['data'];
    } else {
      throw Exception('Failed to load top anime');
    }
  }

  Future<List<dynamic>> fetchLatestAnime({int page = 1}) async {
    final response =
        await http.get(Uri.parse('$baseUrl/latest-anime?page=$page'));
    if (response.statusCode == 200) {
      return jsonDecode(response.body)['data']['anime_list'];
    } else {
      throw Exception('Failed to load latest anime');
    }
  }

  Future<dynamic> fetchAnimeDetails(String url) async {
    // Validasi URL telah dihapus karena URL bisa memiliki format yang berbeda
    // dari berbagai sumber seperti pencarian, favorit, atau riwayat

    final response =
        await http.get(Uri.parse('$baseUrl/anime-details?url=$url'));
    if (response.statusCode == 200) {
      return jsonDecode(response.body)['data'];
    } else {
      throw Exception('Failed to load anime details');
    }
  }

  Future<dynamic> fetchEpisodeStreams(String url) async {
    // Using optimized endpoint for faster streaming
    final response =
        await http.get(Uri.parse('$baseUrl/episode-streams-fast?url=$url'));
    if (response.statusCode == 200) {
      return jsonDecode(response.body)['data'];
    } else {
      throw Exception('Failed to load episode streams');
    }
  }

  // Fallback method using original endpoint if needed
  Future<dynamic> fetchEpisodeStreamsOriginal(String url) async {
    final response =
        await http.get(Uri.parse('$baseUrl/episode-streams?url=$url'));
    if (response.statusCode == 200) {
      return jsonDecode(response.body)['data'];
    } else {
      throw Exception('Failed to load episode streams');
    }
  }

  // Cache management methods
  Future<bool> clearStreamCache() async {
    try {
      final response =
          await http.post(Uri.parse('$baseUrl/clear-stream-cache'));
      return response.statusCode == 200;
    } catch (e) {
      return false;
    }
  }

  Future<dynamic> getCacheInfo() async {
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

  Future<dynamic> getOptimizationStatus() async {
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

  Future<List<dynamic>> searchAnime(String query) async {
    final response = await http.get(Uri.parse('$baseUrl/search?query=$query'));
    if (response.statusCode == 200) {
      final data = jsonDecode(response.body)['data'];
      // Tambahkan tipe 'anime' ke setiap item
      return data.map((item) => {...item, 'type': 'anime'}).toList();
    } else {
      throw Exception('Failed to search anime');
    }
  }

  Future<List<dynamic>> fetchLatestComics({int page = 1}) async {
    final response =
        await http.get(Uri.parse('$baseUrl/latest-comics?page=$page'));
    if (response.statusCode == 200) {
      return jsonDecode(response.body)['data']['comic_list'];
    } else {
      throw Exception('Failed to load latest comics');
    }
  }

  Future<dynamic> fetchComicDetails(String url) async {
    // Validasi URL telah dihapus karena URL bisa memiliki format yang berbeda
    // dari berbagai sumber seperti pencarian, favorit, atau riwayat

    final response =
        await http.get(Uri.parse('$baseUrl/comic-details?url=$url'));
    if (response.statusCode == 200) {
      return jsonDecode(response.body)['data'];
    } else {
      throw Exception('Failed to load comic details');
    }
  }

  Future<List<dynamic>> searchComics(String query) async {
    final response =
        await http.get(Uri.parse('$baseUrl/search-comics?query=$query'));
    if (response.statusCode == 200) {
      final data = jsonDecode(response.body)['data'];
      // Tambahkan tipe 'comic' ke setiap item
      return data.map((item) => {...item, 'type': 'comic'}).toList();
    } else {
      throw Exception('Failed to search comics');
    }
  }

  Future<dynamic> fetchChapterImages(String url) async {
    final response =
        await http.get(Uri.parse('$baseUrl/chapter-images?url=$url'));
    if (response.statusCode == 200) {
      return jsonDecode(response.body)['data'];
    } else {
      throw Exception('Failed to load chapter images');
    }
  }

  Future<List<dynamic>> fetchGenres() async {
    final response = await http.get(Uri.parse('$baseUrl/genres'));
    if (response.statusCode == 200) {
      return jsonDecode(response.body)['data'];
    } else {
      throw Exception('Failed to load genres');
    }
  }

  Future<dynamic> fetchGenreContent(String genreUrl, {int page = 1}) async {
    final response = await http
        .get(Uri.parse('$baseUrl/genre-content?url=$genreUrl&page=$page'));
    if (response.statusCode == 200) {
      return jsonDecode(response.body)['data'];
    } else {
      throw Exception('Failed to load genre content');
    }
  }
}
