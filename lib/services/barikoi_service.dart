import 'dart:convert';

import 'package:http/http.dart' as http;

import '../config/barikoi_config.dart';

class BarikoiPlace {
  final double latitude;
  final double longitude;
  final String address;
  final String area;
  final String city;
  final String source;

  const BarikoiPlace({
    required this.latitude,
    required this.longitude,
    required this.address,
    required this.area,
    required this.city,
    required this.source,
  });

  String get displayLabel {
    final parts = [
      if (address.isNotEmpty) address,
      if (area.isNotEmpty && area != address) area,
      if (city.isNotEmpty && city != area) city,
    ];
    return parts.isEmpty ? 'Unknown location' : parts.join(', ');
  }
}

class BarikoiService {
  static const _host = 'barikoi.xyz';
  static const _timeout = Duration(seconds: 12);

  static Future<BarikoiPlace?> geocodeAddress(String query) async {
    final cleanQuery = query.trim();
    if (cleanQuery.isEmpty) return null;

    final candidates = <Uri>[
      Uri.https(_host, '/v2/api/search/autocomplete/place', {
        'api_key': BarikoiConfig.apiKey,
        'q': cleanQuery,
        'bangla': 'true',
        'country_code': 'BD',
      }),
      Uri.https(_host, '/v1/api/search/autocomplete/place', {
        'api_key': BarikoiConfig.apiKey,
        'q': cleanQuery,
        'bangla': 'true',
        'country_code': 'BD',
      }),
      Uri.https(_host, '/v2/api/search/place', {
        'api_key': BarikoiConfig.apiKey,
        'q': cleanQuery,
        'bangla': 'true',
      }),
      Uri.https(_host, '/v1/api/search/place', {
        'api_key': BarikoiConfig.apiKey,
        'q': cleanQuery,
        'bangla': 'true',
      }),
    ];

    for (final uri in candidates) {
      final result = await _getJson(uri);
      final place = _parseGeocodedPlace(result, cleanQuery);
      if (place != null) return place;
    }
    return null;
  }

  static Future<BarikoiPlace?> reverseGeocode({
    required double latitude,
    required double longitude,
  }) async {
    final candidates = <Uri>[
      Uri.https(_host, '/v2/api/search/reverse/geocode', {
        'api_key': BarikoiConfig.apiKey,
        'latitude': '$latitude',
        'longitude': '$longitude',
        'bangla': 'true',
        'address': 'true',
        'area': 'true',
        'district': 'true',
        'city': 'true',
        'country_code': 'BD',
      }),
      Uri.https(_host, '/v1/api/search/reverse/geocode', {
        'api_key': BarikoiConfig.apiKey,
        'latitude': '$latitude',
        'longitude': '$longitude',
        'bangla': 'true',
        'address': 'true',
        'area': 'true',
        'district': 'true',
        'city': 'true',
        'country_code': 'BD',
      }),
    ];

    for (final uri in candidates) {
      final result = await _getJson(uri);
      final place = _parseReverseGeocode(result, latitude, longitude);
      if (place != null) return place;
    }
    return null;
  }

  static Future<Map<String, dynamic>?> _getJson(Uri uri) async {
    try {
      final response = await http.get(uri).timeout(_timeout);
      if (response.statusCode < 200 || response.statusCode >= 300) return null;
      final decoded = jsonDecode(response.body);
      if (decoded is Map<String, dynamic>) return decoded;
    } catch (_) {}
    return null;
  }

  static BarikoiPlace? _parseGeocodedPlace(
    Map<String, dynamic>? payload,
    String fallbackQuery,
  ) {
    if (payload == null) return null;

    final dynamic places = payload['places'] ?? payload['results'];
    final Map<String, dynamic>? place = switch (places) {
      List list when list.isNotEmpty && list.first is Map<String, dynamic> =>
        list.first as Map<String, dynamic>,
      _ => null,
    };

    if (place == null) return null;

    final latitude = _asDouble(place['latitude'] ?? place['lat']);
    final longitude = _asDouble(place['longitude'] ?? place['lng']);
    if (latitude == null || longitude == null) return null;

    return BarikoiPlace(
      latitude: latitude,
      longitude: longitude,
      address: _bestString([
        place['address_bn'],
        place['address'],
        place['name_bn'],
        place['name'],
        fallbackQuery,
      ]),
      area: _bestString([
        place['area_bn'],
        place['area'],
        place['sub_area_bn'],
        place['sub_area'],
      ]),
      city: _bestString([
        place['city_bn'],
        place['city'],
        place['district_bn'],
        place['district'],
      ]),
      source: 'Barikoi search',
    );
  }

  static BarikoiPlace? _parseReverseGeocode(
    Map<String, dynamic>? payload,
    double latitude,
    double longitude,
  ) {
    if (payload == null) return null;
    final place = payload['place'];
    if (place is! Map<String, dynamic>) return null;

    return BarikoiPlace(
      latitude: _asDouble(place['latitude']) ?? latitude,
      longitude: _asDouble(place['longitude']) ?? longitude,
      address: _bestString([place['address_bn'], place['address']]),
      area: _bestString([
        place['area_bn'],
        place['area'],
        place['thana_bn'],
        place['thana'],
      ]),
      city: _bestString([
        place['city_bn'],
        place['city'],
        place['district_bn'],
        place['district'],
      ]),
      source: 'Barikoi reverse geocode',
    );
  }

  static String _bestString(List<dynamic> candidates) {
    for (final candidate in candidates) {
      if (candidate is String && candidate.trim().isNotEmpty) {
        return candidate.trim();
      }
    }
    return '';
  }

  static double? _asDouble(dynamic value) {
    if (value == null) return null;
    if (value is double) return value;
    if (value is int) return value.toDouble();
    return double.tryParse(value.toString());
  }
}
