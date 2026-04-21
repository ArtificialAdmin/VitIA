import 'package:dio/dio.dart';
import 'package:image_picker/image_picker.dart';
import 'package:http_parser/http_parser.dart';
import 'package:vinas_mobile/core/models/prediction_model.dart';

class BibliotecaService {
  final Dio _dio;

  BibliotecaService(this._dio);

  Future<List<dynamic>> getVariedades() async {
    try {
      final response = await _dio.get('/variedades/');
      return response.data as List<dynamic>;
    } catch (e) {
      rethrow;
    }
  }

  Future<List<PredictionModel>> predictImageBase(XFile file) async {
    try {
      final bytes = await file.readAsBytes();
      FormData formData = FormData.fromMap({
        "file": MultipartFile.fromBytes(
          bytes,
          filename: file.name,
          contentType: MediaType('image', 'jpeg'),
        ),
      });

      final response = await _dio.post('/ia/predict', data: formData);
      final List<dynamic> rawList = response.data['predicciones'];
      return rawList.map((e) => PredictionModel.fromJson(e)).toList();
    } catch (e) {
      rethrow;
    }
  }

  Future<List<PredictionModel>> predictImagePremium(List<XFile> files) async {
    try {
      final List<MultipartFile> multipartFiles = [];
      for (var file in files) {
        final bytes = await file.readAsBytes();
        multipartFiles.add(MultipartFile.fromBytes(
          bytes,
          filename: file.name,
          contentType: MediaType('image', 'jpeg'),
        ));
      }

      FormData formData = FormData.fromMap({
        "files": multipartFiles,
      });

      final response = await _dio.post('/ia/predict-premium', data: formData);
      final List<dynamic> rawList = response.data['predicciones'];
      return rawList.map((e) => PredictionModel.fromJson(e)).toList();
    } catch (e) {
      rethrow;
    }
  }
}
