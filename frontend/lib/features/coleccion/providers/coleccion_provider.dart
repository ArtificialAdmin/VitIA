import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:vinas_mobile/features/coleccion/providers/coleccion_provider.dart';
import 'package:vinas_mobile/core/providers.dart';
import 'package:vinas_mobile/features/coleccion/services/coleccion_service.dart';


final coleccionDataSourceProvider = Provider<ColeccionService>((ref) => ref.watch(apiProvider).coleccionDataSource);
