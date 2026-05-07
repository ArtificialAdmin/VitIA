import 'package:dio/dio.dart';

class AuthService {
  final Dio _dio;

  AuthService(this._dio);

  Future<void> logout() async {
    try {
      await _dio.post('/auth/logout');
      _dio.options.headers.remove("Authorization");
    } catch (e) {
      rethrow;
    }
  }

  Future<void> registerFcmToken(String token) async {
    try {
      await _dio.post('/auth/fcm-token', data: FormData.fromMap({
        'fcm_token': token
      }));
    } catch (e) {
      rethrow;
    }
  }
}
