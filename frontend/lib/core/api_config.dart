import 'package:flutter/foundation.dart';
import 'package:vinas_mobile/features/auth/services/auth_session_service.dart';

// La dirección de desarrollo de tu servidor FastAPI/Uvicorn (localhost para Web/Desktop)
const String _localHostUrl = 'http://192.168.0.105:8000';

// Configuración de WeatherAPI
const String weatherBaseUrl = 'http://api.weatherapi.com/v1';
const String weatherApiKey =
    '10d519f407934518a30132259252511'; // 🚨 REEMPLAZA ESTO CON TU CLAVE REAL

String getBaseUrl() {
  String url = _localHostUrl;
  
  // 1. Si el usuario configuró una IP manual en el login, usamos esa.
  if (AuthSessionService.baseUrl != null && AuthSessionService.baseUrl!.isNotEmpty) {
    url = AuthSessionService.baseUrl!;
  }
  
  debugPrint("[ApiClient] Base URL resolved: $url");
  return url;
}
