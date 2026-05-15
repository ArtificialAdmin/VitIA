import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppColors {
  // Negro VitIA: #111D13
  static const Color negroVitIA = Color(0xFF111D13);

  // Verde VitIA: #83781B
  static const Color verdeVitIA = Color(0xFF83781B);

  // Vino VitIA: #A01B4C
  static const Color vinoVitIA = Color(0xFFA01B4C);
  static Color vinoVitIA50 = const Color(0xFFA01B4C).withOpacity(0.5);
  static Color vinoVitIA25 = const Color(0xFFA01B4C).withOpacity(0.25);

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

class AppTheme {
  static ThemeData get themeData {
    return ThemeData(
      useMaterial3: true,
      colorScheme: ColorScheme.fromSeed(
        seedColor: AppColors.verdeVitIA,
        primary: AppColors.negroVitIA,
        secondary: AppColors.verdeVitIA,
        error: AppColors.vinoVitIA,
        surface: AppColors.blancoCalidoVitIA,
      ),
      scaffoldBackgroundColor: AppColors.blancoCalidoVitIA,
      
      // Tipografía Global
      textTheme: GoogleFonts.interTextTheme().copyWith(
        displayLarge: AppColors.h1,
        displayMedium: AppColors.h2,
        titleLarge: AppColors.subtitulo,
        bodyLarge: AppColors.textoGrande,
        bodyMedium: AppColors.textoMediano,
        bodySmall: AppColors.textoPequeno,
      ),

      // App Bar estilo premium
      appBarTheme: AppBarTheme(
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: false,
        titleTextStyle: GoogleFonts.lora(
          fontSize: 24,
          fontWeight: FontWeight.bold,
          color: AppColors.negroVitIA,
        ),
        iconTheme: const IconThemeData(color: AppColors.negroVitIA),
      ),

      // Botones Premium (Dorados/Negros por defecto)
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFFD4AF37), // Oro
          foregroundColor: Colors.black,
          elevation: 0,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          textStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
        ),
      ),

      // Inputs (TextFields) modernos
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.grisClaro1VitIA,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: Color(0xFFD4AF37), width: 2),
        ),
        labelStyle: const TextStyle(color: AppColors.grisVitIA),
        hintStyle: const TextStyle(color: AppColors.grisVitIA),
      ),

      // Card Style
      cardTheme: CardThemeData(
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: const BorderSide(color: AppColors.grisClaro2VitIA, width: 1),
        ),
        color: Colors.white,
      ),

      // Notificaciones (SnackBars) estilo Tarjeta Premium Soft
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: AppColors.grisClaro1VitIA,
        contentTextStyle: GoogleFonts.inter(
          color: AppColors.negroVitIA,
          fontSize: 14,
          fontWeight: FontWeight.w600,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: const BorderSide(color: AppColors.grisClaro2VitIA, width: 0.8),
        ),
        elevation: 2,
      ),
    );
  }
}
