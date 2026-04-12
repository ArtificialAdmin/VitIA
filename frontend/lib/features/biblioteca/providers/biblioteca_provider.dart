import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:vinas_mobile/features/biblioteca/providers/biblioteca_provider.dart';
import 'package:vinas_mobile/core/providers.dart';
import 'package:vinas_mobile/features/biblioteca/services/biblioteca_service.dart';


final bibliotecaDataSourceProvider = Provider<BibliotecaService>((ref) => ref.watch(apiProvider).bibliotecaDataSource);
