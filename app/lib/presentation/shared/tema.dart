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
///
/// ────────────────────────────────────────────────────────────────────────────
/// Los azules medios del sitio institucional NO sirven para texto
/// ────────────────────────────────────────────────────────────────────────────
///
/// El sitio `umg.edu.gt` usa además #207FAF, #2984BB y #1D94CF. Se midieron:
/// dan 4.45:1, 4.11:1 y 3.39:1 sobre blanco, y AA exige 4.5:1 para texto
/// normal. Los tres se quedan cortos, así que aquí no entran: se toma el azul
/// marino, que es el que el sitio usa para titulares, y los medios se dejan
/// donde son legítimos —bordes, fondos, elementos gráficos— o no se usan.
/// Parecerse al sitio no llega hasta copiarle un problema de contraste.
library;

import 'package:flutter/material.dart';

abstract final class ColoresSian {
  /// Azul del escudo. Color primario. Contraste 5.25:1 sobre blanco.
  static const Color primario = Color(0xFF1C72A5);

  /// Azul oscurecido, para texto sobre fondo claro. Contraste 7.59:1.
  static const Color primarioOscuro = Color(0xFF15597F);

  /// Azul marino de los titulares del sitio institucional `umg.edu.gt`.
  ///
  /// Muestreado del sitio en agosto de 2026, donde es con diferencia el color
  /// más presente después del negro de texto. Se incorpora para que la portada
  /// de SIAN se parezca a la de la universidad y no a una aplicación cualquiera
  /// con el escudo pegado encima.
  ///
  /// Contraste 12.81:1 sobre blanco, y **el mismo 12.81:1 con blanco encima**:
  /// sirve igual para texto oscuro sobre fondo claro que para una banda oscura
  /// con texto blanco, que es como lo usa el sitio.
  static const Color navyInstitucional = Color(0xFF003168);

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

/// Los colores con significado, en la versión que le toca a cada tema (DT-21).
///
/// ────────────────────────────────────────────────────────────────────────────
/// Por qué no bastan las constantes de `ColoresSian`
/// ────────────────────────────────────────────────────────────────────────────
///
/// Están calculadas contra fondo blanco. Sobre la superficie del tema oscuro
/// (#101417) se midieron **todas por debajo de AA**: el rojo de urgente daba
/// 2.55:1, el verde de confirmado 2.86:1, el azul marino 1.44:1. Encender el
/// tema oscuro con ellas habría sido servir justo lo que RNF-13 prohíbe, y en
/// el peor sitio: la etiqueta de un aviso urgente.
///
/// El remedio no es un color intermedio que «más o menos» sirva en los dos,
/// sino un par por significado. El tema claro usa **exactamente** las
/// constantes de siempre —ni un píxel cambia para quien no active el oscuro— y
/// el oscuro usa tonos claros del mismo matiz, medidos contra la superficie
/// oscura más clara que usa la aplicación (#313539), que es el caso peor.
///
/// ────────────────────────────────────────────────────────────────────────────
/// Texto y fondo son colores distintos
/// ────────────────────────────────────────────────────────────────────────────
///
/// Sobre fondo claro, el mismo rojo sirve para escribir «urgente» y para
/// rellenar la etiqueta con letra blanca. Sobre fondo oscuro no: el rojo que se
/// lee como texto es demasiado claro para llevar blanco encima. Por eso cada
/// color de relleno tiene su campo `fondo…`, pensado para texto blanco.
@immutable
class PaletaSian extends ThemeExtension<PaletaSian> {
  const PaletaSian({
    required this.primario,
    required this.primarioTexto,
    required this.urgente,
    required this.confirmado,
    required this.dorado,
    required this.doradoTexto,
    required this.fondoPrimario,
    required this.fondoUrgente,
    required this.fondoConfirmado,
    required this.fondoDorado,
  });

  /// Azul para iconos, barras y bordes.
  final Color primario;

  /// Azul para títulos y texto destacado.
  final Color primarioTexto;

  /// Rojo de urgencia, para texto e iconos sobre la superficie.
  final Color urgente;

  /// Verde de confirmado, para texto e iconos.
  final Color confirmado;

  /// Dorado para elementos gráficos (franjas, barras). Nunca texto pequeño.
  final Color dorado;

  /// Dorado apto para texto.
  final Color doradoTexto;

  /// Rellenos pensados para llevar texto blanco encima (≥ 4.5:1 con blanco).
  final Color fondoPrimario;
  final Color fondoUrgente;
  final Color fondoConfirmado;
  final Color fondoDorado;

  /// El texto que va sobre cualquiera de los `fondo…`, en los dos temas.
  static const Color sobreFondo = Colors.white;

  /// La de siempre: las constantes de `ColoresSian`, sin tocar.
  static const PaletaSian clara = PaletaSian(
    primario: ColoresSian.primario,
    primarioTexto: ColoresSian.primarioOscuro,
    urgente: ColoresSian.urgente,
    confirmado: ColoresSian.confirmado,
    dorado: ColoresSian.dorado,
    doradoTexto: ColoresSian.doradoTexto,
    fondoPrimario: ColoresSian.primario,
    fondoUrgente: ColoresSian.urgente,
    fondoConfirmado: ColoresSian.confirmado,
    fondoDorado: ColoresSian.doradoTexto,
  );

  /// Contrastes medidos contra #313539 (texto) o contra blanco (rellenos); la
  /// prueba `tema_oscuro_test.dart` los vuelve a medir en cada compilación.
  static const PaletaSian oscura = PaletaSian(
    // El mismo primario del esquema oscuro. 6.45:1.
    primario: Color(0xFF7FC4E8),
    // 8.10:1.
    primarioTexto: Color(0xFFA8D8F2),
    // Se prefirió a #FFB4AB, el rojo que propone Material para el tema oscuro:
    // aquel tira a salmón, y este sigue leyéndose como rojo. 5.41:1.
    urgente: Color(0xFFFF8A80),
    // 6.80:1.
    confirmado: Color(0xFF7DD29A),
    // 5.08:1: holgado para gráficos, que piden 3:1.
    dorado: Color(0xFFC9A04F),
    // 6.60:1.
    doradoTexto: Color(0xFFE0B866),
    // El azul del escudo sirve igual: 5.25:1 con blanco y 3.53:1 contra la
    // superficie, así que la forma se distingue del fondo.
    fondoPrimario: ColoresSian.primario,
    // El #A32826 del tema claro se funde con la superficie oscura (2.55:1).
    // Este mantiene el blanco en 5.62:1 y se separa del fondo (3.29:1).
    fondoUrgente: Color(0xFFC62828),
    // Ídem: 5.26:1 con blanco, 3.52:1 contra la superficie.
    fondoConfirmado: Color(0xFF2F7A45),
    fondoDorado: ColoresSian.doradoTexto,
  );

  /// La paleta del tema en uso. Sin tema de SIAN encima —una prueba que monta
  /// un widget suelto—, la clara, que es la que siempre hubo.
  static PaletaSian de(BuildContext context) =>
      Theme.of(context).extension<PaletaSian>() ?? clara;

  /// Traduce una constante de `ColoresSian` a su equivalente en este tema.
  ///
  /// Para los colores que viajan dentro de un dato —el estado de una entrega,
  /// el realce de un mensaje— y se decidieron lejos de cualquier tema. El dato
  /// sigue diciendo «urgente» con la constante de siempre, y quien lo pinta lo
  /// adapta. Conserva la transparencia: los fondos tenues son el mismo color
  /// con opacidad baja, y deben seguir siéndolo.
  ///
  /// Un color que no es de la paleta se devuelve tal cual.
  Color adaptar(Color color) {
    final Color opaco = color.withValues(alpha: 1);
    final Color? equivalente = switch (opaco) {
      ColoresSian.primario => primario,
      ColoresSian.primarioOscuro => primarioTexto,
      ColoresSian.urgente => urgente,
      ColoresSian.confirmado => confirmado,
      ColoresSian.dorado => dorado,
      ColoresSian.doradoTexto => doradoTexto,
      _ => null,
    };
    return equivalente?.withValues(alpha: color.a) ?? color;
  }

  @override
  PaletaSian copyWith({
    Color? primario,
    Color? primarioTexto,
    Color? urgente,
    Color? confirmado,
    Color? dorado,
    Color? doradoTexto,
    Color? fondoPrimario,
    Color? fondoUrgente,
    Color? fondoConfirmado,
    Color? fondoDorado,
  }) => PaletaSian(
    primario: primario ?? this.primario,
    primarioTexto: primarioTexto ?? this.primarioTexto,
    urgente: urgente ?? this.urgente,
    confirmado: confirmado ?? this.confirmado,
    dorado: dorado ?? this.dorado,
    doradoTexto: doradoTexto ?? this.doradoTexto,
    fondoPrimario: fondoPrimario ?? this.fondoPrimario,
    fondoUrgente: fondoUrgente ?? this.fondoUrgente,
    fondoConfirmado: fondoConfirmado ?? this.fondoConfirmado,
    fondoDorado: fondoDorado ?? this.fondoDorado,
  );

  @override
  PaletaSian lerp(PaletaSian? otra, double t) {
    if (otra == null) {
      return this;
    }
    Color l(Color a, Color b) => Color.lerp(a, b, t)!;
    return PaletaSian(
      primario: l(primario, otra.primario),
      primarioTexto: l(primarioTexto, otra.primarioTexto),
      urgente: l(urgente, otra.urgente),
      confirmado: l(confirmado, otra.confirmado),
      dorado: l(dorado, otra.dorado),
      doradoTexto: l(doradoTexto, otra.doradoTexto),
      fondoPrimario: l(fondoPrimario, otra.fondoPrimario),
      fondoUrgente: l(fondoUrgente, otra.fondoUrgente),
      fondoConfirmado: l(fondoConfirmado, otra.fondoConfirmado),
      fondoDorado: l(fondoDorado, otra.fondoDorado),
    );
  }
}

abstract final class TemaSian {
  static ThemeData claro() => _construir(Brightness.light);

  static ThemeData oscuro() => _construir(Brightness.dark);

  static ThemeData _construir(Brightness brillo) {
    final bool claro = brillo == Brightness.light;
    final PaletaSian paleta = claro ? PaletaSian.clara : PaletaSian.oscura;
    final ColorScheme esquema =
        ColorScheme.fromSeed(
          seedColor: ColoresSian.primario,
          brightness: brillo,
          error: paleta.urgente,
        ).copyWith(
          // Se fija el primario en el azul exacto del escudo en lugar de
          // dejar que la paleta generada lo desplace: es identidad, no
          // decoración.
          primary: paleta.primario,
          tertiary: paleta.dorado,
          // En el oscuro, el error es un rojo claro: lo que va encima tiene
          // que ser oscuro. El generado para el rojo del tema claro daba
          // 1.80:1 sobre él.
          onError: claro ? null : const Color(0xFF3B0907),
        );

    return ThemeData(
      colorScheme: esquema,
      extensions: <ThemeExtension<dynamic>>[paleta],
      useMaterial3: true,
      // Urbanist es la tipografía del sitio institucional umg.edu.gt. Se aplica
      // a toda la aplicación y no solo a la portada: una pantalla con la letra
      // de la universidad y la siguiente con la letra por omisión del sistema
      // no se lee como estilo, se lee como si algo hubiera fallado al cargar.
      //
      // Va empaquetada con la aplicación (ver pubspec). Si el archivo faltara,
      // Flutter cae a la fuente del sistema: se vería distinto, nunca vacío.
      fontFamily: 'Urbanist',
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
      // Del primario del esquema y no del azul fijo: en el oscuro, el azul
      // del escudo como icono seleccionado daba 3.53:1 contra la superficie.
      navigationRailTheme: NavigationRailThemeData(
        indicatorColor: esquema.primary.withValues(alpha: 0.14),
        selectedIconTheme: IconThemeData(color: esquema.primary),
      ),
    );
  }
}

/// El escudo institucional, con su proporción y su recorte circular.
///
/// Existe como componente para que el logotipo se dibuje igual en la pantalla
/// de ingreso, en la barra superior y donde haga falta, sin repetir rutas de
/// recursos por el código.
///
/// En el tema oscuro se dibuja sobre un disco blanco: el anillo rojo del
/// escudo, directamente sobre la superficie oscura, perdía el borde. Es lo que
/// ya hacía la barra superior sobre el azul, y por el mismo motivo. En el tema
/// claro no hay disco —sería blanco sobre casi blanco— y se ve como siempre.
class EscudoUmg extends StatelessWidget {
  const EscudoUmg({this.tamano = 96, super.key});

  final double tamano;

  @override
  Widget build(BuildContext context) {
    final bool oscuro = Theme.of(context).brightness == Brightness.dark;
    // El disco no agranda el escudo: sale del mismo tamaño pedido.
    final double margen = oscuro ? tamano * 0.06 : 0;
    final Widget imagen = Image.asset(
      'assets/escudo-umg.png',
      width: tamano - 2 * margen,
      height: tamano - 2 * margen,
      // Descripción para lectores de pantalla (RNF-13).
      semanticLabel: 'Escudo de la Universidad Mariano Gálvez de Guatemala',
      filterQuality: FilterQuality.medium,
    );
    if (!oscuro) {
      return imagen;
    }
    return Container(
      width: tamano,
      height: tamano,
      padding: EdgeInsets.all(margen),
      decoration: const BoxDecoration(
        color: Colors.white,
        shape: BoxShape.circle,
      ),
      child: imagen,
    );
  }
}
