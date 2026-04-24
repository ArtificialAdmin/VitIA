import 'package:dio/dio.dart';
import 'dart:ui';
import 'package:image_picker/image_picker.dart';
import 'package:vinas_mobile/features/auth/services/auth_service.dart';
import 'package:vinas_mobile/features/foro/services/foro_service.dart';
import 'package:vinas_mobile/features/coleccion/services/coleccion_service.dart';
import 'package:vinas_mobile/features/biblioteca/services/biblioteca_service.dart';
import 'package:vinas_mobile/features/perfil/services/perfil_service.dart';
import 'package:vinas_mobile/features/auth/services/auth_session_service.dart';
import 'package:vinas_mobile/core/models/prediction_model.dart';
import 'package:vinas_mobile/core/models/coleccion_model.dart';

class ApiClient {
  final Dio _dio;
  VoidCallback? onTokenExpired;

  late final AuthService _auth;
  late final ForoService _foro;
  late final ColeccionService _coleccion;
  late final BibliotecaService _biblioteca;
  late final PerfilService _perfil;

  ApiClient(String baseUrl) : _dio = Dio(BaseOptions(baseUrl: baseUrl)) {
    _dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) {
          // Inyectamos el token automáticamente si existe
          if (AuthSessionService.token != null) {
            options.headers["Authorization"] = "Bearer ${AuthSessionService.token}";
          }
          return handler.next(options);
        },
        onError: (DioException e, ErrorInterceptorHandler handler) {
          if (e.response?.statusCode == 401) {
            onTokenExpired?.call();
          }
          return handler.next(e);
        },
      ),
    );

    // Initializing DataSources
    _auth = AuthService(_dio);
    _foro = ForoService(_dio);
    _coleccion = ColeccionService(_dio);
    _biblioteca = BibliotecaService(_dio);
    _perfil = PerfilService(_dio);
  }

  // GETTERS for DataSources
  AuthService get authDataSource => _auth;
  ForoService get foroDataSource => _foro;
  ColeccionService get coleccionDataSource => _coleccion;
  BibliotecaService get bibliotecaDataSource => _biblioteca;
  PerfilService get perfilDataSource => _perfil;
  Dio get dioInstance => _dio;

  void setToken(String token) {
    _dio.options.headers["Authorization"] = "Bearer $token";
  }

  // Core / Health
  Future<Map<String, dynamic>> ping() async {
    final r = await _dio.get('/health/ping');
    return r.data as Map<String, dynamic>;
  }

  // Delegate Methods (Legacy Compatibility)
  
  // Auth
  Future<void> logout() => _auth.logout();

  // Foro
  Future<List<dynamic>> getPublicaciones() => _foro.getPublicaciones();
  Future<List<dynamic>> getUserPublicaciones() => _foro.getUserPublicaciones();
  Future<void> createPublicacion(String titulo, String texto, {XFile? imageFile, double? latitud, double? longitud, bool esPublica = true}) 
    => _foro.createPublicacion(titulo, texto, imageFile: imageFile, latitud: latitud, longitud: longitud, esPublica: esPublica);
  Future<void> deletePublicacion(int idPublicacion) => _foro.deletePublicacion(idPublicacion);
  Future<List<dynamic>> getComentariosPublicacion(int idPublicacion) => _foro.getComentariosPublicacion(idPublicacion);
  Future<void> likePublicacion(int idPublicacion) => _foro.likePublicacion(idPublicacion);
  Future<void> unlikePublicacion(int idPublicacion) => _foro.unlikePublicacion(idPublicacion);
  Future<void> likeComentario(int idComentario) => _foro.votarComentario(idComentario, true);
  Future<void> unlikeComentario(int idComentario) => _foro.votarComentario(idComentario, null);
  Future<void> createComentario(int idPublicacion, String texto, {int? idPadre}) => _foro.createComentario(idPublicacion, texto, idPadre: idPadre);
  Future<void> votarComentario(int idComentario, bool? esLike) => _foro.votarComentario(idComentario, esLike);
  Future<void> deleteComentario(int idComentario) => _foro.deleteComentario(idComentario);

  // Coleccion
  Future<void> saveToCollection({
    required XFile imageFile,
    required String nombreVariedad,
    String? notas,
    double? lat,
    double? lon,
    bool esPublica = true,
    List<XFile>? premiumFiles,
    String? analisisIA,
  }) =>
      _coleccion.saveToCollection(
        imageFile: imageFile,
        nombreVariedad: nombreVariedad,
        notas: notas,
        lat: lat,
        lon: lon,
        esPublica: esPublica,
        premiumFiles: premiumFiles,
        analisisIA: analisisIA,
      );
  Future<List<dynamic>> getCollection() => _coleccion.getCollection();
  Future<List<dynamic>> getUserCollection() => _coleccion.getCollection(); // Legacy support
  Future<void> updateCollectionItem(int idColeccion, Map<String, dynamic> updates) => _coleccion.updateCollectionItem(idColeccion, updates);
  Future<void> deleteCollectionItem(int idColeccion) => _coleccion.deleteCollectionItem(idColeccion);
  Future<List<dynamic>> getColeccionesMapa({String modo = 'publico'}) => _coleccion.getColeccionesMapa(modo: modo);

  // Biblioteca / IA
  Future<List<dynamic>> getVariedades() => _biblioteca.getVariedades();
  Future<List<PredictionModel>> predictImageBase(XFile file) => _biblioteca.predictImageBase(file);
  Future<Map<String, dynamic>> predictImagePremium(List<XFile> files) => _biblioteca.predictImagePremium(files);

  // Usuarios / Perfil
  Future<Map<String, dynamic>> getMe() => _perfil.getMe();
  Future<void> updateProfile(Map<String, dynamic> data) => _perfil.updateProfile(data);
  Future<void> uploadAvatar(XFile imageFile) => _perfil.uploadAvatar(imageFile);
  Future<void> toggleFavorite(int idVariedad) => _perfil.toggleFavorite(idVariedad);
  Future<List<dynamic>> getFavorites() => _perfil.getFavorites();
  Future<void> markTutorialAsComplete() => _perfil.markTutorialAsComplete();
}
