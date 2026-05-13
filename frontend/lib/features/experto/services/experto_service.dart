import 'package:dio/dio.dart';

class ExpertoService {
  final Dio _dio;

  ExpertoService(this._dio);

  Future<List<dynamic>> getValidacionesPendientes({int skip = 0, int limit = 50}) async {
    try {
      final response = await _dio.get('/experto/validaciones/pendientes', queryParameters: {
        'skip': skip,
        'limit': limit,
      });
      return response.data as List<dynamic>;
    } catch (e) {
      rethrow;
    }
  }

  Future<Map<String, dynamic>> getValidacion(int id) async {
    try {
      final response = await _dio.get('/experto/validaciones/$id');
      return response.data as Map<String, dynamic>;
    } catch (e) {
      rethrow;
    }
  }

  Future<int> getValidacionesPendientesCount() async {
    try {
      final response = await _dio.get('/experto/validaciones/pendientes/count');
      return response.data['count'] as int;
    } catch (e) {
      rethrow;
    }
  }

  Future<Map<String, dynamic>> validateItem(
    int idValidacion, {
    required bool esCorrecta,
    String? feedbackExperto,
    List<Map<String, dynamic>>? evaluacionImagenes,
    int? idVariedadCorrecta,
    String? variedadSugerida,
  }) async {
    try {
      final response = await _dio.post('/experto/validaciones/$idValidacion', data: {
        'es_correcta': esCorrecta,
        'feedback_experto': feedbackExperto,
        'evaluacion_imagenes': evaluacionImagenes,
        'id_variedad_correcta': idVariedadCorrecta,
        'variedad_sugerida': variedadSugerida,
      });
      return response.data as Map<String, dynamic>;
    } catch (e) {
      rethrow;
    }
  }

  Future<List<dynamic>> getColeccionesDataset({int skip = 0, int limit = 100}) async {
    try {
      final response = await _dio.get('/experto/colecciones-dataset', queryParameters: {
        'skip': skip,
        'limit': limit,
      });
      return response.data as List<dynamic>;
    } catch (e) {
      rethrow;
    }
  }

  Future<Map<String, dynamic>> anotarColeccionDataset(
    int idColeccion, {
    required bool esCorrecta,
    String? feedbackExperto,
    List<Map<String, dynamic>>? evaluacionImagenes,
    int? idVariedadCorrecta,
    String? variedadSugerida,
  }) async {
    try {
      final response = await _dio.post('/experto/anotar-coleccion/$idColeccion', data: {
        'es_correcta': esCorrecta,
        'feedback_experto': feedbackExperto,
        'evaluacion_imagenes': evaluacionImagenes,
        'id_variedad_correcta': idVariedadCorrecta,
        'variedad_sugerida': variedadSugerida,
      });
      return response.data as Map<String, dynamic>;
    } catch (e) {
      rethrow;
    }
  }
}
