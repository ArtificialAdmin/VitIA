class ColeccionModel {
  final int id;
  final String pathFotoUsuario;
  final String? notas;
  final String nombreVariedad;
  final List<String>? fotosPremium;
  final String? analisisIA;
  final bool esPremium;
  final String? estadoValidacion;

  ColeccionModel({
    required this.id,
    required this.pathFotoUsuario,
    this.notas,
    required this.nombreVariedad,
    this.fotosPremium,
    this.analisisIA,
    this.esPremium = false,
    this.estadoValidacion,
  });

  factory ColeccionModel.fromJson(Map<String, dynamic> json) {
    return ColeccionModel(
      id: json['id_coleccion'],
      pathFotoUsuario: json['path_foto_usuario'] ?? '',
      notas: json['notas'],
      nombreVariedad: json['variedad'] != null ? json['variedad']['nombre'] : 'Variedad detectada',
      fotosPremium: json['fotos_premium'] != null ? List<String>.from(json['fotos_premium']) : null,
      analisisIA: json['analisis_ia'],
      esPremium: json['es_premium'] ?? false,
      estadoValidacion: json['validacion'] != null ? json['validacion']['estado'] : null,
    );
  }
}