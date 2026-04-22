import 'dart:convert';
import 'package:http/http.dart' as http;
import 'recommendation.dart';

class PlantApiService {
  // Change to your machine's LAN IP when testing on a real device.
  // Android emulator: use 10.0.2.2 instead of localhost.
  static const String _baseUrl = 'http://10.0.2.2:8000';

  final http.Client _client;

  PlantApiService({http.Client? client}) : _client = client ?? http.Client();

  // ── Recommendations ────────────────────────────────────────────────────────

  Future<List<Recommendation>> fetchRecommendations({int? plantId}) async {
    final uri = Uri.parse('$_baseUrl/recommendations').replace(
      queryParameters: plantId != null ? {'plant_id': '$plantId'} : null,
    );

    final response = await _client.get(uri).timeout(const Duration(seconds: 10));

    if (response.statusCode != 200) {
      throw Exception('Failed to load recommendations: ${response.statusCode}');
    }

    final body = jsonDecode(response.body) as Map<String, dynamic>;
    final list  = body['alerts'] as List<dynamic>;
    return list
        .map((e) => Recommendation.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  // ── Plants ─────────────────────────────────────────────────────────────────

  Future<List<Plant>> fetchPlants() async {
    final response = await _client
        .get(Uri.parse('$_baseUrl/plants'))
        .timeout(const Duration(seconds: 10));

    if (response.statusCode != 200) {
      throw Exception('Failed to load plants: ${response.statusCode}');
    }

    final body = jsonDecode(response.body) as Map<String, dynamic>;
    final list  = body['plants'] as List<dynamic>;
    return list.map((e) => Plant.fromJson(e as Map<String, dynamic>)).toList();
  }
}
