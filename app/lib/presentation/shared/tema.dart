/// SIAN — Tema visual institucional.
///
/// Los colores están tomados **del escudo de la Universidad Mariano Gálvez**,
/// muestreados directamente del archivo original, no estimados a ojo:
///
///   · Azul   #1C72A5 — el campo central del escudo
///   · Rojo   #CB3332 — el anillo exterior
///   · Dorado #AE8436 — el filete que separa ambos
///
/// ────────────────────────────────────────────────────────────────────────────
/// Por qué el azul es el color primario y no el rojo
/// ────────────────────────────────────────────────────────────────────────────
///
/// El rojo institucional está reservado **en exclusiva** para las alertas
/// urgentes (RF-ENT-05). Si el rojo fuera también el color de la barra
/// superior, de los botones y de los encabezados, dejaría de significar
/// «urgente» para significar «SIAN», y en una emergencia real eso importa.
///
/// Hay además un motivo medible: el azul #1C72A5 y el rojo #CB3332 tienen casi
/// la misma luminancia —su relación de contraste entre sí es de 1.01—, de modo
/// que en escala de grises, o para quien no distingue el rojo del verde, son el
/// mismo color. Por eso el rojo de urgencia se oscurece a #A32826, que separa
/// la luminancia, y **nunca viaja solo**: siempre lo acompaña el distintivo
/// textual «URGENTE», que es la única mitigación disponible en iOS-PWA, donde
/// no se puede definir sonido ni vibración propios (DT-02).
///
/// Todos los pares texto/fondo declarados aquí cumplen WCAG 2.1 nivel AA
/// (RNF-13); los valores verificados van anotados en cada constante.
library;

import 'package:flutter/material.dart';

abstract final class ColoresSian {
  /// Azul del escudo. Color primario. Contraste 5.25:1 sobre blanco.
  static const Color primario = Color(0xFF1C72A5);

  /// Azul oscurecido, para texto sobre fondo claro. Contraste 7.59:1.
  static const Color primarioOscuro = Color(0xFF15597F);

  /// Rojo del anillo del escudo. Se usa **solo** en el escudo y en elementos
  /// de identidad, nunca como color de acción.
  static const Color rojoInstitucional = Color(0xFFCB3332);

  /// Rojo de alerta urgente (RF-ENT-05). Contraste 7.27:1 sobre blanco, y
  /// suficientemente más oscuro que el azul primario para distinguirse también
  /// sin color.
  static const Color urgente = Color(0xFFA32826);

  /// Dorado del filete del escudo. Contraste 3.41:1 sobre blanco: **solo para
  /// elementos gráficos y bordes**, jamás para texto pequeño.
  static const Color dorado = Color(0xFFAE8436);

  /// Dorado oscurecido, este sí apto para texto. Contraste 5.03:1.
  static const Color doradoTexto = Color(0xFF8A6A2B);

  /// Verde de confirmación de lectura.
  static const Color confirmado = Color(0xFF2D6A3E);
}

abstract final class TemaSian {
  static ThemeData claro() => _construir(Brightness.light);

  static ThemeData oscuro() => _construir(Brightness.dark);

  static ThemeData _construir(Brightness brillo) {
    final ColorScheme esquema =
        ColorScheme.fromSeed(
          seedColor: ColoresSian.primario,
          brightness: brillo,
          error: ColoresSian.urgente,
        ).copyWith(
          // Se fija el primario en el azul exacto del escudo en lugar de
          // dejar que la paleta generada lo desplace: es identidad, no
          // decoración.
          primary: brillo == Brightness.light
              ? ColoresSian.primario
              : const Color(0xFF7FC4E8),
          tertiary: ColoresSian.dorado,
        );

    return ThemeData(
      colorScheme: esquema,
      useMaterial3: true,
      // El cuerpo no baja de 16 px (RNF-13): quien lee un aviso urgente suele
      // hacerlo de prisa y en la calle.
      textTheme: const TextTheme(
        bodyLarge: TextStyle(fontSize: 16),
        bodyMedium: TextStyle(fontSize: 16),
        titleLarge: TextStyle(fontSize: 22, fontWeight: FontWeight.w600),
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: brillo == Brightness.light
            ? ColoresSian.primario
            : esquema.surface,
        foregroundColor: brillo == Brightness.light
            ? Colors.white
            : esquema.onSurface,
        centerTitle: false,
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          // Área táctil cómoda: se usa desde el teléfono, a veces caminando.
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
      navigationRailTheme: NavigationRailThemeData(
        indicatorColor: ColoresSian.primario.withValues(alpha: 0.14),
        selectedIconTheme: const IconThemeData(color: ColoresSian.primario),
      ),
    );
  }
}

/// El escudo institucional, con su proporción y su recorte circular.
///
/// Existe como componente para que el logotipo se dibuje igual en la pantalla
/// de ingreso, en la barra superior y donde haga falta, sin repetir rutas de
/// recursos por el código.
class EscudoUmg extends StatelessWidget {
  const EscudoUmg({this.tamano = 96, super.key});

  final double tamano;

  @override
  Widget build(BuildContext context) {
    return Image.asset(
      'assets/escudo-umg.png',
      width: tamano,
      height: tamano,
      // Descripción para lectores de pantalla (RNF-13).
      semanticLabel: 'Escudo de la Universidad Mariano Gálvez de Guatemala',
      filterQuality: FilterQuality.medium,
    );
  }
}
