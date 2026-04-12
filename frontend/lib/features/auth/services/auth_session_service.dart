import 'package:shared_preferences/shared_preferences.dart';

class AuthSessionService {
  static String? _token;
  static int? _userId;

  // Clave para guardar en disco
  static const String _tokenKey = 'auth_token';
  static const String _userIdKey = 'auth_user_id';
  static const String _baseUrlKey = 'api_base_url'; // Nueva clave para la URL

  // Getters
  static String? get token => _token;
  static int? get userId => _userId;
  static String? get baseUrl => _baseUrl;

  static String? _baseUrl;

  // --- MÉTODOS ASÍNCRONOS PARA PERSISTENCIA ---

  /// Carga la sesión desde SharedPreferences al iniciar la app
  static Future<bool> loadSession() async {
    final prefs = await SharedPreferences.getInstance();
    _token = prefs.getString(_tokenKey);
    _userId = prefs.getInt(_userIdKey);
    _baseUrl = prefs.getString(_baseUrlKey); // Cargar URL personalizada

    // Sanidad: Si la URL guardada es basura o no empieza por http, la ignoramos
    if (_baseUrl != null && !_baseUrl!.startsWith('http')) {
      _baseUrl = null;
    }

    // Devolvemos true si hay token válido
    return _token != null && _token!.isNotEmpty;
  }

  /// Guarda el token y el ID en memoria y disco
  static Future<void> setToken(String token) async {
    _token = token;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_tokenKey, token);
  }

  static Future<void> setUserId(int id) async {
    _userId = id;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_userIdKey, id);
  }

  static Future<void> setBaseUrl(String url) async {
    _baseUrl = url;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_baseUrlKey, url);
  }

  /// Borra la sesión de memoria y disco (Logout)
  static Future<void> clearSession() async {
    _token = null;
    _userId = null;
    // IMPORTANTE: No borramos _baseUrl aquí para no obligar a reconfigurar la IP al cerrar sesión
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_tokenKey);
    await prefs.remove(_userIdKey);
  }
}
