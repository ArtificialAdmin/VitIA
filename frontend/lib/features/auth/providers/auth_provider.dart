import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:vinas_mobile/features/auth/providers/auth_provider.dart';
import 'package:vinas_mobile/core/providers.dart';
import 'package:vinas_mobile/features/auth/services/auth_service.dart';


final authDataSourceProvider = Provider<AuthService>((ref) => ref.watch(apiProvider).authDataSource);
