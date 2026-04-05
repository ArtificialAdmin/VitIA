import 'package:dio/dio.dart';
import './models/prediction_model.dart';
import 'package:image_picker/image_picker.dart';
import 'models/coleccion_model.dart';
import 'package:http_parser/http_parser.dart';
import 'dart:ui'; // Import for VoidCallback

class ApiClient {
  final Dio _dio;
  // Callback opcional para manejar expiración de sesión (401)
  VoidCallback? onTokenExpired;

  ApiClient(String baseUrl) : _dio = Dio(BaseOptions(baseUrl: baseUrl)) {
    _dio.interceptors.add(
      InterceptorsWrapper(
        onError: (DioException e, ErrorInterceptorHandler handler) {
          if (e.response?.statusCode == 401) {
            // Si el servidor devuelve 401 Unauthorized, llamamos al callback
            onTokenExpired?.call();
          }
          return handler.next(e);
        },
      ),
    );
  }

  Future<Map<String, dynamic>> ping() async {
    final r = await _dio.get('/health/ping');
    return r.data as Map<String, dynamic>;
  }

  Future<List<dynamic>> getVariedades() async {
    try {
      final response = await _dio.get('/variedades/');
      return response.data as List<dynamic>;
    } catch (e) {
      print("Error al obtener variedades: $e");
      rethrow;
    }
  }

  Future<List<PredictionModel>> predictImage(XFile file) async {
    try {
      // 1. Leemos los bytes del archivo (Funciona en Web y Móvil)
      final bytes = await file.readAsBytes();

      // 2. Usamos fromBytes en lugar de fromFile
      FormData formData = FormData.fromMap({
        "file": MultipartFile.fromBytes(
          bytes,
          filename: file.name, // XFile ya trae el nombre
          contentType: MediaType(
              'image', 'jpeg'), // Ajusta según el tipo real si es necesario
        ),
      });

      final response = await _dio.post('/ia/predict', data: formData);

      final List<dynamic> rawList = response.data['predicciones'];
      return rawList.map((e) => PredictionModel.fromJson(e)).toList();
    } catch (e) {
      throw Exception('Error al analizar imagen: $e');
    }
  }

  // Método para guardar en la colección subiendo la imagen
  Future<void> saveToCollection({
    required XFile imageFile,
    required String nombreVariedad, // <--- CAMBIO DE TIPO
    String? notas,
    double? lat,
    double? lon,
    bool esPublica = true, // <--- NUEVO CAMPO
  }) async {
    try {
      final bytes = await imageFile.readAsBytes();

      FormData formData = FormData.fromMap({
        "file": MultipartFile.fromBytes(bytes,
            filename: imageFile.name, contentType: MediaType('image', 'jpeg')),
        "nombre_variedad": nombreVariedad, // <--- Enviamos el nombre
        if (notas != null) "notas": notas,
        if (lat != null) "latitud": lat,
        if (lon != null) "longitud": lon,
        "es_publica": esPublica.toString(), // <--- Enviamos la privacidad
      });

      await _dio.post('/coleccion/upload', data: formData);
    } catch (e) {
      throw Exception('Error al guardar: $e');
    }
  }

  void setToken(String token) {
    _dio.options.headers["Authorization"] = "Bearer $token";
  }

  Future<List<dynamic>> getUserCollection() async {
    try {
      final response = await _dio.get('/coleccion/');
      return response.data as List<dynamic>;
    } catch (e) {
      print("Error al obtener colección: $e");
      rethrow;
    }
  }

  Future<void> updateCollectionItem(
      int idColeccion, Map<String, dynamic> updates) async {
    try {
      // El backend espera un PATCH a /coleccion/{id}
      await _dio.patch('/coleccion/$idColeccion', data: updates);
    } catch (e) {
      print("Error al actualizar item: $e");
      rethrow;
    }
  }

  Future<void> deleteCollectionItem(int idColeccion) async {
    try {
      await _dio.delete('/coleccion/$idColeccion');
    } catch (e) {
      print("Error al eliminar item: $e");
      rethrow;
    }
  }

  Future<void> logout() async {
    try {
      // Notifica al servidor (aunque JWT es stateless, es una buena práctica)
      await _dio.post('/auth/logout');

      // Limpiar el token de la cabecera del cliente Dio inmediatamente
      _dio.options.headers.remove("Authorization");
    } catch (e) {
      // Ignoramos errores, ya que la acción crítica es la limpieza local.
      print("Advertencia: Fallo al notificar cierre de sesión al servidor: $e");
    }
  }

  // --- SECCIÓN FORO / PUBLICACIONES ---

  // 1. Obtener el feed global (Todos)
  Future<List<dynamic>> getPublicaciones() async {
    try {
      final response = await _dio.get('/publicaciones/');
      return response.data as List<dynamic>;
    } catch (e) {
      print("Error al obtener feed: $e");
      return [];
    }
  }

  // Obtener las colecciones para el mapa (Solo coordenadas)
  Future<List<dynamic>> getColeccionesMapa({String modo = 'publico'}) async {
    try {
      final response = await _dio.get('/coleccion/mapa', queryParameters: {'modo': modo});
      return response.data as List<dynamic>;
    } catch (e) {
      print("Error al obtener colecciones para el mapa: $e");
      return [];
    }
  }

  // 2. Obtener mis hilos (Solo usuario actual)
  Future<List<dynamic>> getUserPublicaciones() async {
    try {
      final response = await _dio.get('/publicaciones/me');
      return response.data as List<dynamic>;
    } catch (e) {
      print("Error al obtener mis publicaciones: $e");
      rethrow;
    }
  }

  // 3. Crear nueva publicación (con soporte para imagen y ubicación)
  Future<void> createPublicacion(String titulo, String texto,
      {XFile? imageFile, double? latitud, double? longitud, bool esPublica = true}) async {
    try {
      final Map<String, dynamic> dataMap = {
        "titulo": titulo,
        "texto": texto,
        "es_publica": esPublica.toString(),
      };

      if (latitud != null) dataMap["latitud"] = latitud;
      if (longitud != null) dataMap["longitud"] = longitud;

      if (imageFile != null) {
        final bytes = await imageFile.readAsBytes();
        dataMap['file'] = MultipartFile.fromBytes(
          bytes,
          filename: imageFile.name,
          contentType: MediaType('image', 'jpeg'), // Ajustar si es necesario
        );
      }

      final formData = FormData.fromMap(dataMap);

      await _dio.post('/publicaciones/', data: formData);
    } catch (e) {
      print("Error al crear publicación: $e");
      rethrow;
    }
  }

  // 4. Eliminar publicación
  Future<void> deletePublicacion(int idPublicacion) async {
    try {
      await _dio.delete('/publicaciones/$idPublicacion');
    } catch (e) {
      print("Error al eliminar publicación: $e");
      rethrow;
    }
  }

  // 5. Obtener comentarios de una publicación
  Future<List<dynamic>> getComentariosPublicacion(int idPublicacion) async {
    try {
      final response =
          await _dio.get('/comentarios/publicacion/$idPublicacion');
      return response.data as List<dynamic>;
    } catch (e) {
      print("Error al obtener comentarios: $e");
      return [];
    }
  }

  // 6. Dar Like
  Future<void> likePublicacion(int idPublicacion) async {
    try {
      await _dio.post('/publicaciones/$idPublicacion/like');
    } catch (e) {
      print("Error al dar like: $e");
      rethrow;
    }
  }

  // 6.b Quitar Like
  Future<void> unlikePublicacion(int idPublicacion) async {
    try {
      await _dio.post('/publicaciones/$idPublicacion/unlike');
    } catch (e) {
      print("Error al quitar like: $e");
      rethrow;
    }
  }

  // 7. Crear comentario
  Future<void> createComentario(int idPublicacion, String texto) async {
    try {
      await _dio.post('/comentarios/', data: {
        "texto": texto,
        "id_publicacion": idPublicacion,
      });
    } catch (e) {
      print("Error al crear comentario: $e");
      rethrow;
    }
  }

  // Función para descargar tus fotos
  Future<List<ColeccionModel>> getCollection() async {
    try {
      final response = await _dio.get('/coleccion/');
      final List<dynamic> data = response.data;
      return data.map((json) => ColeccionModel.fromJson(json)).toList();
    } catch (e) {
      throw Exception('Error al cargar la colección: $e');
    }
  }

  // --- SECCIÓN TUTORIAL ---

  /// Obtiene el estado 'tutorial_superado' del usuario actual (GET /users/me).
  Future<bool> getTutorialStatus() async {
    try {
      // Esta llamada requiere que el token haya sido configurado previamente.
      final response = await _dio.get('/users/me');

      // La respuesta de /users/me contiene el objeto Usuario con el campo
      return response.data['tutorial_superado'] as bool? ?? false;
    } catch (e) {
      print("Error al obtener el estado del tutorial (GET /users/me): $e");
      // Fallback defensivo: Si falla (401, red), asumimos true para no bloquear el build
      return true;
    }
  }

  /// Obtiene la información del usuario actual (GET /users/me).
  Future<Map<String, dynamic>> getMe() async {
    try {
      final response = await _dio.get('/users/me');
      return response.data as Map<String, dynamic>;
    } catch (e) {
      print("Error al obtener perfil usuario: $e");
      rethrow;
    }
  }

  /// Llama a PATCH /users/me para actualizar 'tutorial_superado' a true.
  Future<void> markTutorialAsComplete() async {
    try {
      // Reutilizamos PATCH /users/me enviando SOLO el campo a actualizar
      await _dio.patch('/users/me', data: {"tutorial_superado": true});
    } catch (e) {
      print("Error al marcar tutorial como completo (PATCH /users/me): $e");
      throw Exception(
          'Fallo al actualizar estado del tutorial en el servidor.');
    }
  }

  // Actualizar perfil de usuario (Nombre, Apellidos, Ubicación)
  Future<void> updateProfile(Map<String, dynamic> data) async {
    try {
      await _dio.patch('/users/me', data: data);
    } catch (e) {
      print("Error al actualizar perfil: $e");
      rethrow;
    }
  }

  // Subir foto de perfil `/users/me/avatar`
  Future<void> uploadAvatar(XFile imageFile) async {
    try {
      final bytes = await imageFile.readAsBytes();

      FormData formData = FormData.fromMap({
        "file": MultipartFile.fromBytes(
          bytes,
          filename: imageFile.name,
          contentType: MediaType('image', 'jpeg'),
        ),
      });

      await _dio.post('/users/me/avatar', data: formData);
    } catch (e) {
      print("Error al subir avatar: $e");
      rethrow;
    }
  }

  // --- FAVORITOS ---

  Future<void> toggleFavorite(int idVariedad) async {
    try {
      await _dio.post('/variedades/$idVariedad/favorito');
    } catch (e) {
      print("Error al cambiar favorito: $e");
      rethrow;
    }
  }

  Future<List<dynamic>> getFavorites() async {
    try {
      // GET /users/me/favoritos
      final response = await _dio.get('/users/me/favoritos');
      return response.data as List<dynamic>;
    } catch (e) {
      print("Error al obtener favoritos: $e");
      rethrow;
    }
  }
}
