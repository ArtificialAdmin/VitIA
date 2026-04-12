import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:vinas_mobile/features/perfil/providers/perfil_provider.dart';
import 'package:vinas_mobile/core/providers.dart';
import 'package:vinas_mobile/features/perfil/services/perfil_service.dart';


final perfilDataSourceProvider = Provider<PerfilService>((ref) => ref.watch(apiProvider).perfilDataSource);
