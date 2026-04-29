class PredictionModel {
  final String variedad;
  final double confianza;
  final String? color;

  PredictionModel({
    required this.variedad,
    required this.confianza,
    this.color,
  });

  factory PredictionModel.fromJson(Map<String, dynamic> json) {
    return PredictionModel(
      variedad: json['variedad'] ?? 'Desconocida',
      confianza: (json['confianza'] ?? 0.0).toDouble(),
      color: json['color'],
    );
  }
}