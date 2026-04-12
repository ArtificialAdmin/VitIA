import 'package:dio/dio.dart';
import 'package:image_picker/image_picker.dart';
import 'package:http_parser/http_parser.dart';
import 'package:vinas_mobile/core/models/coleccion_model.dart';

class ColeccionService {
  final Dio _dio;

  ColeccionService(this._dio);

  Future<void> saveToCollection({
    required XFile imageFile,
    required String nombreVariedad,
    String? notas,
    double? lat,
    double? lon,
    bool esPublica = true,
  }) async {
    try {
      final bytes = await imageFile.readAsBytes();

      FormData formData = FormData.fromMap({
        "file": MultipartFile.fromBytes(bytes,
            filename: imageFile.name, contentType: MediaType('image', 'jpeg')),
        "nombre_variedad": nombreVariedad,
        if (notas != null) "notas": notas,
        if (lat != null) "latitud": lat,
        if (lon != null) "longitud": lon,
        "es_publica": esPublica.toString(),
      });

      await _dio.post('/coleccion/', data: formData);
    } catch (e) {
      rethrow;
    }
  }

  Future<List<dynamic>> getCollection() async {
    try {
      final response = await _dio.get('/coleccion/');
      return response.data as List<dynamic>;
    } catch (e) {
      rethrow;
    }
  }

  Future<void> updateCollectionItem(int idColeccion, Map<String, dynamic> updates) async {
    try {
      await _dio.patch('/coleccion/$idColeccion', data: updates);
    } catch (e) {
      rethrow;
    }
  }

  Future<void> deleteCollectionItem(int idColeccion) async {
    try {
      await _dio.delete('/coleccion/$idColeccion');
    } catch (e) {
      rethrow;
    }
  }

  Future<List<dynamic>> getColeccionesMapa({String modo = 'publico'}) async {
    try {
      final response = await _dio.get('/coleccion/mapa', queryParameters: {'modo': modo});
      return response.data as List<dynamic>;
    } catch (e) {
      rethrow;
    }
  }
}
