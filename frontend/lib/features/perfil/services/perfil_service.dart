import 'package:dio/dio.dart';
import 'package:image_picker/image_picker.dart';
import 'package:vinas_mobile/features/auth/services/auth_session_service.dart';
import 'package:http_parser/http_parser.dart';

class PerfilService {
  final Dio _dio;

  PerfilService(this._dio);

  Future<Map<String, dynamic>> getMe() async {
    try {
      final response = await _dio.get('/users/me');
      return response.data as Map<String, dynamic>;
    } catch (e) {
      rethrow;
    }
  }

  Future<void> updateProfile(Map<String, dynamic> data) async {
    try {
      await _dio.patch('/users/me', data: data);
    } catch (e) {
      rethrow;
    }
  }

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
      rethrow;
    }
  }

  Future<void> toggleFavorite(int idVariedad) async {
    try {
      await _dio.post('/variedades/$idVariedad/favorito');
    } catch (e) {
      rethrow;
    }
  }

  Future<List<dynamic>> getFavorites() async {
    try {
      final response = await _dio.get('/users/me/favoritos');
      return response.data as List<dynamic>;
    } catch (e) {
      rethrow;
    }
  }

  Future<void> markTutorialAsComplete() async {
    try {
      await _dio.patch('/users/me', data: {"tutorial_superado": true});
    } catch (e) {
      rethrow;
    }
  }
}
