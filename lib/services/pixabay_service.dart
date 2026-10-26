import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../config/api_keys.dart';

class PixabayService {
  PixabayService._();
  static final PixabayService instance = PixabayService._();

  static const _baseUrl = 'https://pixabay.com/api/';

  /// Fetches an image URL for a group based on its name and optional description.
  /// Falls back to curated aesthetic photos if Pixabay returns 0 hits or if offline.
  static Future<String> fetchImageForGroup({
    required String name,
    String? description,
  }) async {
    try {
      final query = _extractBestSearchKeyword(name, description);
      if (query.isNotEmpty && ApiKeys.pixabayApiKey.isNotEmpty && ApiKeys.pixabayApiKey != 'YOUR_PIXABAY_API_KEY_HERE') {
        final encodedQuery = Uri.encodeComponent(query);
        final url = Uri.parse(
          '$_baseUrl?key=${ApiKeys.pixabayApiKey}&q=$encodedQuery&image_type=photo&orientation=horizontal&safesearch=true&per_page=5',
        );

        final res = await http.get(url).timeout(const Duration(seconds: 4));
        if (res.statusCode == 200) {
          final data = json.decode(res.body) as Map<String, dynamic>;
          final hits = data['hits'] as List<dynamic>?;
          if (hits != null && hits.isNotEmpty) {
            // Pick the first horizontal high-res photo
            final first = hits.first as Map<String, dynamic>;
            final imageUrl = (first['largeImageURL'] ?? first['webformatURL']) as String?;
            if (imageUrl != null && imageUrl.isNotEmpty) {
              return imageUrl;
            }
          }
        }
      }
    } catch (e) {
      debugPrint('PixabayService fetch error (using fallback): $e');
    }

    // Graceful fallback to curated high-resolution photography
    return getCuratedFallback(name);
  }

  /// Extracts the most meaningful keyword to search on Pixabay
  static String _extractBestSearchKeyword(String name, String? description) {
    final lower = name.toLowerCase();

    // Specific destination & activity mappings
    if (lower.contains('udaipur') || lower.contains('rajasthan') || lower.contains('jaipur')) return 'rajasthan palace';
    if (lower.contains('bali')) return 'bali indonesia temple';
    if (lower.contains('goa')) return 'goa beach sunset';
    if (lower.contains('manali') || lower.contains('himachal') || lower.contains('kasol')) return 'manali mountains snow';
    if (lower.contains('ladakh') || lower.contains('leh')) return 'ladakh mountains lake';
    if (lower.contains('kerala') || lower.contains('munnar')) return 'kerala backwaters tea';
    if (lower.contains('dubai')) return 'dubai skyline';
    if (lower.contains('thailand') || lower.contains('phuket')) return 'thailand tropical beach';
    if (lower.contains('paris')) return 'paris eiffel tower';
    if (lower.contains('london')) return 'london big ben';
    if (lower.contains('new york') || lower.contains('nyc')) return 'new york skyline';
    if (lower.contains('tokyo') || lower.contains('japan')) return 'japan mount fuji cherry blossom';
    if (lower.contains('trek') || lower.contains('hike') || lower.contains('camp')) return 'camping mountain trekking';
    if (lower.contains('beach') || lower.contains('sea') || lower.contains('resort')) return 'tropical beach resort vacation';
    if (lower.contains('flat') || lower.contains('room') || lower.contains('rent') || lower.contains('house')) return 'modern apartment living room';
    if (lower.contains('dinner') || lower.contains('lunch') || lower.contains('food') || lower.contains('party') || lower.contains('cafe')) return 'friends dinner party food table';
    if (lower.contains('office') || lower.contains('work') || lower.contains('project') || lower.contains('hackathon')) return 'modern office team work';
    if (lower.contains('wedding') || lower.contains('shaadi')) return 'indian wedding celebration';
    if (lower.contains('birthday')) return 'birthday celebration confetti';
    if (lower.contains('gym') || lower.contains('fitness')) return 'fitness gym workout';
    if (lower.contains('movie') || lower.contains('cinema')) return 'cinema theater popcorn';
    if (lower.contains('road') || lower.contains('drive') || lower.contains('bike')) return 'road trip scenic highway';

    // Remove noise words and extract meaningful terms
    final stopWords = {
      'the', 'a', 'an', 'and', 'or', 'for', 'with', 'to', 'in', 'at', 'by', 'of',
      'group', 'trip', 'tour', 'expenses', 'split', 'gang', 'boys', 'girls', 'fam',
      'family', 'friends', 'mates', '2024', '2025', '2026', '2027', 'di', 'ki', 'ka'
    };

    final words = lower
        .replaceAll(RegExp(r'[^a-zA-Z0-9\s]'), ' ')
        .split(RegExp(r'\s+'))
        .where((w) => w.length > 2 && !stopWords.contains(w))
        .toList();

    if (words.isNotEmpty) {
      return words.take(2).join(' ');
    }

    // If description has words, try description
    if (description != null && description.isNotEmpty) {
      final descWords = description.toLowerCase()
          .replaceAll(RegExp(r'[^a-zA-Z0-9\s]'), ' ')
          .split(RegExp(r'\s+'))
          .where((w) => w.length > 2 && !stopWords.contains(w))
          .toList();
      if (descWords.isNotEmpty) {
        return descWords.take(2).join(' ');
      }
    }

    return 'travel vacation landscape';
  }

  /// Curated fallback images if Pixabay API has 0 hits or is unreachable
  static String getCuratedFallback(String name) {
    final lower = name.toLowerCase();
    if (lower.contains('udaipur') || lower.contains('rajasthan') || lower.contains('palace') || lower.contains('jaipur')) {
      return 'https://images.unsplash.com/photo-1595846519845-68e298c2edd8?auto=format&fit=crop&w=1200&q=80';
    } else if (lower.contains('bali') || lower.contains('temple') || lower.contains('indonesia')) {
      return 'https://images.unsplash.com/photo-1537996194471-e657df975ab4?auto=format&fit=crop&w=1200&q=80';
    } else if (lower.contains('goa') || lower.contains('beach') || lower.contains('sea')) {
      return 'https://images.unsplash.com/photo-1512343879784-a960bf40e7f2?auto=format&fit=crop&w=1200&q=80';
    } else if (lower.contains('trek') || lower.contains('mountain') || lower.contains('manali') || lower.contains('hike') || lower.contains('camp')) {
      return 'https://images.unsplash.com/photo-1464822759023-fed622ff2c3b?auto=format&fit=crop&w=1200&q=80';
    } else if (lower.contains('flat') || lower.contains('room') || lower.contains('house') || lower.contains('rent') || lower.contains('home')) {
      return 'https://images.unsplash.com/photo-1502672260266-1c1ef2d93688?auto=format&fit=crop&w=1200&q=80';
    } else if (lower.contains('food') || lower.contains('dinner') || lower.contains('lunch') || lower.contains('party') || lower.contains('cafe')) {
      return 'https://images.unsplash.com/photo-1517248135467-4c7edcad34c4?auto=format&fit=crop&w=1200&q=80';
    } else if (lower.contains('office') || lower.contains('work') || lower.contains('project')) {
      return 'https://images.unsplash.com/photo-1486406146926-c627a92ad1ab?auto=format&fit=crop&w=1200&q=80';
    } else if (lower.contains('trip') || lower.contains('tour') || lower.contains('travel') || lower.contains('vacation')) {
      return 'https://images.unsplash.com/photo-1507525428034-b723cf961d3e?auto=format&fit=crop&w=1200&q=80';
    }
    return 'https://images.unsplash.com/photo-1507525428034-b723cf961d3e?auto=format&fit=crop&w=1200&q=80';
  }
}
