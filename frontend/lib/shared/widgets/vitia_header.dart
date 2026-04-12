import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class VitiaHeader extends StatelessWidget {
  final String title;
  final Widget? leading; // Nuevo campo
  final Widget? actionIcon;
  final String? userPhotoUrl;
  final VoidCallback? onProfileTap;

  const VitiaHeader({
    super.key,
    required this.title,
    this.leading, // Nuevo
    this.actionIcon,
    this.userPhotoUrl,
    this.onProfileTap,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // 1. Logo Centrado Superior
        const SizedBox(height: 10),
        Center(
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
            child: RichText(
              text: TextSpan(
                children: [
                  TextSpan(
                    text: 'Vit',
                    style: GoogleFonts.lora(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      fontStyle: FontStyle.italic,
                      color: Colors.black,
                      letterSpacing: 1.0,
                    ),
                  ),
                  TextSpan(
                    text: 'IA',
                    style: GoogleFonts.ibmPlexSans(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.black,
                      letterSpacing: 1.0,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),

        // 2. Fila Título + Avatar/Acción
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 10),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              if (leading != null) leading!,

              if (title.isNotEmpty)
                Text(
                  title,
                  style: GoogleFonts.lora(
                    fontSize: 32,
                    fontWeight: FontWeight.w400,
                    color: const Color(0xFF1E2623),
                  ),
                ),
              // Prioridad: 1. actionIcon explícito, 2. Avatar de usuario
              if (actionIcon != null)
                actionIcon!
              else if (onProfileTap != null) // Mostrar avatar si hay callback
                GestureDetector(
                  onTap: onProfileTap,
                  child: CircleAvatar(
                    radius: 24,
                    backgroundColor: Colors.grey.shade200,
                    backgroundImage: userPhotoUrl != null
                        ? NetworkImage(userPhotoUrl!)
                        : null,
                    child: userPhotoUrl == null
                        ? const Icon(Icons.person, color: Colors.grey)
                        : null,
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }
}
