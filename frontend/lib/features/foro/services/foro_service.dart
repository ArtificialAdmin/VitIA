import 'package:dio/dio.dart';
import 'package:image_picker/image_picker.dart';
import 'package:http_parser/http_parser.dart';

class ForoService {
  final Dio _dio;

  ForoService(this._dio);

  Future<List<dynamic>> getPublicaciones() async {
    try {
      final response = await _dio.get('/foro/');
      return response.data as List<dynamic>;
    } catch (e) {
      rethrow;
    }
  }

  Future<List<dynamic>> getUserPublicaciones() async {
    try {
      final response = await _dio.get('/foro/me'); // Ajustando a /foro/me si existiera o /foro/
      return response.data as List<dynamic>;
    } catch (e) {
      rethrow;
    }
  }

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
          contentType: MediaType('image', 'jpeg'),
        );
      }

      final formData = FormData.fromMap(dataMap);
      await _dio.post('/foro/', data: formData);
    } catch (e) {
      rethrow;
    }
  }

  Future<void> deletePublicacion(int idPublicacion) async {
    try {
      await _dio.delete('/foro/$idPublicacion');
    } catch (e) {
      rethrow;
    }
  }

  Future<List<dynamic>> getComentariosPublicacion(int idPublicacion) async {
    try {
      final response = await _dio.get('/foro/$idPublicacion/comentarios');
      return response.data as List<dynamic>;
    } catch (e) {
      rethrow;
    }
  }

  Future<void> likePublicacion(int idPublicacion) async {
    try {
      await _dio.post('/foro/$idPublicacion/voto', data: {"es_like": true});
    } catch (e) {
      rethrow;
    }
  }

  Future<void> unlikePublicacion(int idPublicacion) async {
    try {
      await _dio.post('/foro/$idPublicacion/voto', data: {"es_like": null});
    } catch (e) {
      rethrow;
    }
  }

  Future<void> createComentario(int idPublicacion, String texto, {int? idPadre}) async {
    try {
      await _dio.post('/foro/comentarios', data: {
        "texto": texto,
        "id_publicacion": idPublicacion,
        if (idPadre != null) "id_padre": idPadre,
      });
    } catch (e) {
      rethrow;
    }
  }

  Future<void> votarComentario(int idComentario, bool? esLike) async {
    try {
      await _dio.post('/foro/comentarios/$idComentario/voto', data: {
        "es_like": esLike,
      });
    } catch (e) {
      rethrow;
    }
  }

  Future<void> deleteComentario(int idComentario) async {
    try {
      await _dio.delete('/foro/comentarios/$idComentario');
    } catch (e) {
      rethrow;
    }
  }
}
