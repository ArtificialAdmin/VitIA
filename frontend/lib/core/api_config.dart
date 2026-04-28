import 'package:flutter/foundation.dart';
import 'package:vinas_mobile/features/auth/services/auth_session_service.dart';

// Usa localhost dinámico en web para evitar bloqueos CORS/PNA de Chrome
// Mantiene la IP local para testeos en emulador o dispositivo físico
const String _localHostUrl =
    kIsWeb ? 'http://127.0.0.1:8000' : 'http://192.168.0.105:8000';

// Configuración de WeatherAPI
const String weatherBaseUrl = 'http://api.weatherapi.com/v1';
const String weatherApiKey = '10d519f407934518a30132259252511';

String getBaseUrl() {
  String url = _localHostUrl;

  // 1. Si el usuario configuró una IP manual en el login, usamos esa.
  if (AuthSessionService.baseUrl != null &&
      AuthSessionService.baseUrl!.isNotEmpty) {
    url = AuthSessionService.baseUrl!;
  }

  debugPrint("[ApiClient] Base URL resolved: $url");
  return url;
}
