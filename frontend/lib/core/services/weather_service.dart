import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'api_config.dart';

class WeatherService {
  final Dio _dio = Dio();

  Future<Map<String, dynamic>?> getWeather({String? location, double? lat, double? lon}) async {
    // Si no hay API key configurada, retornamos null o lanzamos error
    if (weatherApiKey == 'YOUR_API_KEY_HERE') {
      debugPrint("⚠️ WeatherAPI Key no configurada.");
      return null;
    }

    try {
      String? query;
      
      // 1. Priorizar coordenadas para máxima precisión
      if (lat != null && lon != null) {
        query = "$lat,$lon";
      } else if (location != null && location.isNotEmpty) {
        // 2. Si no hay coordenadas, usar el string
        query = location.replaceAll("España", "Spain");
        if (!query.contains(",")) {
          query = "$query, Spain";
        }
      }

      if (query == null) return null;

      debugPrint("Fetching weather for: '$query'");

      final response = await _dio.get(
        '$weatherBaseUrl/forecast.json',
        queryParameters: {
          'key': weatherApiKey,
          'q': query,
          'days': 3,
          'lang': 'es', // Español
          'aqi': 'no',
          'alerts': 'no',
        },
      );

      if (response.statusCode == 200) {
        return response.data as Map<String, dynamic>;
      } else {
        debugPrint(
            "Error WeatherAPI: ${response.statusCode} - ${response.statusMessage}");
        return null;
      }
    } catch (e) {
      debugPrint("Excepción WeatherService: $e");
      return null;
    }
  }
}
