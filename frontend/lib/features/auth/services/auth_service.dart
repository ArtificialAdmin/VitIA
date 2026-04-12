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
}
