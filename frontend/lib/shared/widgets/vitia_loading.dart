import 'package:flutter/material.dart';
import 'package:vinas_mobile/shared/styles/app_theme.dart';

class VitiaLoading extends StatefulWidget {
  final String? label;
  final double size;

  const VitiaLoading({
    super.key,
    this.label,
    this.size = 50,
  });

  @override
  State<VitiaLoading> createState() => _VitiaLoadingState();
}

class _VitiaLoadingState extends State<VitiaLoading>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        RotationTransition(
          turns: _controller,
          child: Image.asset(
            'assets/home/icon_home_loading.png',
            width: widget.size,
            height: widget.size,
          ),
        ),
        if (widget.label != null) ...[
          const SizedBox(height: 16),
          Text(
            widget.label!,
            style: AppColors.textoMediano.copyWith(
              color: AppColors.negroVitIA.withValues(alpha: 0.7),
            ),
          ),
        ],
      ],
    );
  }
}
