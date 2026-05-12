import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppColors {
  // Negro VitIA: #111D13
  static const Color negroVitIA = Color(0xFF111D13);

  // Verde VitIA: #83781B
  static const Color verdeVitIA = Color(0xFF83781B);

  // Vino VitIA: #A01B4C
  static const Color vinoVitIA = Color(0xFFA01B4C);
  static Color vinoVitIA50 = const Color(0xFFA01B4C).withValues(alpha: 0.5);
  static Color vinoVitIA25 = const Color(0xFFA01B4C).withValues(alpha: 0.25);

  // Amarillo VitIA: #F9F5A5
  static const Color amarilloVitIA = Color(0xFFF9F5A5);

  // Blanco cálido VitIA: #FFFEFB
  static const Color blancoCalidoVitIA = Color(0xFFFFFEFB);

  // Gris claro 1 VitIA: #F7F7F3
  static const Color grisClaro1VitIA = Color(0xFFF7F7F3);

  // Gris claro 2 VitIA: #ECECEC
  static const Color grisClaro2VitIA = Color(0xFFECECEC);

  // Gris VitIA: #868686
  static const Color grisVitIA = Color(0xFF868686);

  // --- ESTILOS DE TEXTO ---

  // Títulos H1: Lora Medium 36pt
  static TextStyle h1 = GoogleFonts.lora(
    fontSize: 36,
    fontWeight: FontWeight.w500, // Medium
    color: negroVitIA,
  );

  // Títulos H2: Lora Medium 32pt
  static TextStyle h2 = GoogleFonts.lora(
    fontSize: 32,
    fontWeight: FontWeight.w500, // Medium
    color: negroVitIA,
  );

  // Subtítulos: Inter Regular 20pt
  static TextStyle subtitulo = GoogleFonts.inter(
    fontSize: 20,
    fontWeight: FontWeight.w400, // Regular
    color: negroVitIA,
  );

  // Textos grandes: Inter Regular 16pt
  static TextStyle textoGrande = GoogleFonts.inter(
    fontSize: 16,
    fontWeight: FontWeight.w400,
    color: negroVitIA,
  );

  // Textos medianos: Inter Regular 14pt
  static TextStyle textoMediano = GoogleFonts.inter(
    fontSize: 14,
    fontWeight: FontWeight.w400,
    color: negroVitIA,
  );

  // Textos pequeños: Inter Regular 12pt
  static TextStyle textoPequeno = GoogleFonts.inter(
    fontSize: 12,
    fontWeight: FontWeight.w400,
    color: negroVitIA,
  );
}
