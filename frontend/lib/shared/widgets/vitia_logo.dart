import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class VitIALogo extends StatelessWidget {
  final double fontSize;
  final Color color;

  const VitIALogo({
    super.key,
    this.fontSize = 50,
    this.color = const Color(0xFF142018),
  });

  @override
  Widget build(BuildContext context) {
    return RichText(
      text: TextSpan(
        children: [
          TextSpan(
            text: 'Vit',
            style: GoogleFonts.lora(
              fontSize: fontSize,
              fontWeight: FontWeight.bold, // Lora Bold
              fontStyle: FontStyle.italic, // Italic
              color: color,
            ),
          ),
          TextSpan(
            text: 'IA',
            style: GoogleFonts.ibmPlexSans(
              fontSize: fontSize,
              fontWeight: FontWeight.bold, // IBM Plex Sans Bold
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}
