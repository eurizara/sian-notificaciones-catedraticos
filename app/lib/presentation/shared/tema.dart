/// SIAN — Tema visual.
///
/// **Marcadores de posición neutros** hasta recibir el branding institucional
/// (RES-09). Los colores están declarados en un solo sitio precisamente para
/// que sustituirlos sea cambiar este archivo y nada más.
///
/// El contraste de los pares texto/fondo definidos aquí se verifica contra
/// WCAG 2.1 nivel AA en la auditoría de accesibilidad (RNF-13).
library;

import 'package:flutter/material.dart';

abstract final class ColoresSian {
  /// Azul institucional. Marcador de posición.
  static const Color primario = Color(0xFF1A3A6B);

  /// Acento cálido, para elementos destacados que no son urgentes.
  static const Color acento = Color(0xFFC8952A);

  /// Rojo de alerta urgente. Se usa **solo** para mensajes de tipo URGENTE:
  /// si todo es rojo, nada es urgente (RF-ENT-05).
  static const Color urgente = Color(0xFFB3261E);

  /// Verde de confirmación de lectura.
  static const Color confirmado = Color(0xFF2D6A3E);
}

abstract final class TemaSian {
  static ThemeData claro() => _construir(Brightness.light);

  static ThemeData oscuro() => _construir(Brightness.dark);

  static ThemeData _construir(Brightness brillo) {
    final ColorScheme esquema = ColorScheme.fromSeed(
      seedColor: ColoresSian.primario,
      brightness: brillo,
      error: ColoresSian.urgente,
    );

    return ThemeData(
      colorScheme: esquema,
      useMaterial3: true,
      // Tamaños de texto conformes a WCAG 2.1 AA (RNF-13): el cuerpo no baja
      // de 16 px, porque quien lee un aviso urgente suele hacerlo de prisa y
      // en la calle.
      textTheme: const TextTheme(
        bodyLarge: TextStyle(fontSize: 16),
        bodyMedium: TextStyle(fontSize: 16),
        titleLarge: TextStyle(fontSize: 22, fontWeight: FontWeight.w600),
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: esquema.primary,
        foregroundColor: esquema.onPrimary,
        centerTitle: false,
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          // Área táctil mínima cómoda: se usa desde el teléfono, a veces
          // caminando.
          minimumSize: const Size(88, 48),
        ),
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(color: esquema.outlineVariant),
        ),
      ),
    );
  }
}
