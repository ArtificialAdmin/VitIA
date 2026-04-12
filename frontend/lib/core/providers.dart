import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:vinas_mobile/core/api_client.dart';
import 'package:vinas_mobile/core/api_config.dart';
import 'package:vinas_mobile/features/auth/services/auth_session_service.dart';

// Importaciones de servicios para tipado opcional
import 'package:vinas_mobile/features/auth/services/auth_service.dart';
import 'package:vinas_mobile/features/foro/services/foro_service.dart';
import 'package:vinas_mobile/features/coleccion/services/coleccion_service.dart';
import 'package:vinas_mobile/features/biblioteca/services/biblioteca_service.dart';
import 'package:vinas_mobile/features/perfil/services/perfil_service.dart';

final apiBaseUrlProvider = Provider<String>((ref) {
  const env = String.fromEnvironment('API_BASE_URL');
  if (env.isNotEmpty) return env;
  return getBaseUrl();
});

// Provider para el token de sesión, inicializado con el valor actual de AuthSessionService
final sessionTokenProvider = StateProvider<String?>((ref) => AuthSessionService.token);

// Provider para el ID del usuario actual, inicializado con el valor actual de AuthSessionService
final userIdProvider = StateProvider<int?>((ref) => AuthSessionService.userId);

final apiProvider = Provider<ApiClient>((ref) {
  final baseUrl = ref.watch(apiBaseUrlProvider);
  final token = ref.watch(sessionTokenProvider);
  
  final client = ApiClient(baseUrl);
  
  client.onTokenExpired = () async {
    await AuthSessionService.clearSession();
    ref.read(sessionTokenProvider.notifier).state = null;
    ref.read(userIdProvider.notifier).state = null;
  };

  if (token != null) {
    client.setToken(token);
  }
  return client;
});

// Feature Service Providers
final authServiceProvider = Provider<AuthService>((ref) => ref.watch(apiProvider).authDataSource);
final foroServiceProvider = Provider<ForoService>((ref) => ref.watch(apiProvider).foroDataSource);
final coleccionServiceProvider = Provider<ColeccionService>((ref) => ref.watch(apiProvider).coleccionDataSource);
final bibliotecaServiceProvider = Provider<BibliotecaService>((ref) => ref.watch(apiProvider).bibliotecaDataSource);
final perfilServiceProvider = Provider<PerfilService>((ref) => ref.watch(apiProvider).perfilDataSource);
