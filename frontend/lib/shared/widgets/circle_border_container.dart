import 'package:flutter/material.dart';

class CircleBorderContainer extends StatelessWidget {
  const CircleBorderContainer({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(2), // Borde
      decoration: BoxDecoration(
        color: Colors.white,
        shape: BoxShape.circle,
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: const CircleAvatar(
        radius: 20,
        backgroundColor: Colors.transparent,
        backgroundImage: AssetImage('assets/images/user_avatar.png'),
        // Fallback si no hay imagen
        child: Icon(Icons.person, color: Colors.grey),
      ),
    );
  }
}
