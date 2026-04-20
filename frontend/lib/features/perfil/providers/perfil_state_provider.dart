import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:vinas_mobile/core/providers.dart';

final userProfileProvider = FutureProvider<Map<String, dynamic>>((ref) async {
  final perfilService = ref.watch(perfilServiceProvider);
  return await perfilService.getMe();
});
