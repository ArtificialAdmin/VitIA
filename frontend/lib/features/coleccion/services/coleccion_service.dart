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
    List<XFile>? premiumFiles,
    String? analisisIA,
  }) async {
    try {
      final bytes = await imageFile.readAsBytes();

      FormData formData = FormData();
      formData.fields.addAll([
        MapEntry("nombre_variedad", nombreVariedad),
        if (notas != null) MapEntry("notas", notas),
        if (lat != null) MapEntry("latitud", lat.toString()),
        if (lon != null) MapEntry("longitud", lon.toString()),
        MapEntry("es_publica", esPublica.toString()),
        if (analisisIA != null) MapEntry("analisis_ia", analisisIA),
      ]);
      
      formData.files.add(MapEntry(
        "file",
        MultipartFile.fromBytes(bytes, filename: imageFile.name, contentType: MediaType('image', 'jpeg'))
      ));

      if (premiumFiles != null && premiumFiles.isNotEmpty) {
        for (var file in premiumFiles) {
          final pBytes = await file.readAsBytes();
          formData.files.add(MapEntry(
            "premium_files",
            MultipartFile.fromBytes(pBytes, filename: file.name, contentType: MediaType('image', 'jpeg'))
          ));
        }
      }

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
