import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'api_client.dart';
import 'services/api_config.dart';
import 'services/user_sesion.dart';

final apiBaseUrlProvider = Provider<String>((ref) {
  const env = String.fromEnvironment('API_BASE_URL');
  if (env.isNotEmpty) return env;
  return getBaseUrl();
});

// Provider para el token de sesión, inicializado con el valor actual de UserSession
final sessionTokenProvider = StateProvider<String?>((ref) => UserSession.token);

final apiProvider = Provider<ApiClient>((ref) {
  final baseUrl = ref.watch(apiBaseUrlProvider);
  final token = ref.watch(sessionTokenProvider);
  
  final client = ApiClient(baseUrl);
  if (token != null) {
    client.setToken(token);
  }
  return client;
});
