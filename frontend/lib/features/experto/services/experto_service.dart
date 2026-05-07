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

  Future<Map<String, dynamic>> validateItem(
    int idValidacion, {
    required bool esCorrecta,
    String? feedbackExperto,
    List<Map<String, dynamic>>? evaluacionImagenes,
  }) async {
    try {
      final response = await _dio.post('/experto/validaciones/$idValidacion', data: {
        'es_correcta': esCorrecta,
        'feedback_experto': feedbackExperto,
        'evaluacion_imagenes': evaluacionImagenes,
      });
      return response.data as Map<String, dynamic>;
    } catch (e) {
      rethrow;
    }
  }
}
