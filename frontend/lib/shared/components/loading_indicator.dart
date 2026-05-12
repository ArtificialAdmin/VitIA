import 'package:flutter/material.dart';
import 'package:vinas_mobile/shared/widgets/vitia_loading.dart';

class LoadingIndicator extends StatelessWidget {
  final String? label;
  const LoadingIndicator({super.key, this.label});

  @override
  Widget build(BuildContext context) {
    return Center(child: VitiaLoading(label: label));
  }
}
