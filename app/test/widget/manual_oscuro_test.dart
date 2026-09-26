/// Los manuales siguen el modo claro u oscuro (U-5, RNF-24).
///
/// Un solo archivo de estilos para los tres documentos, y en él cada color
/// definido para los dos modos. Nada de esto falla al compilar: si se rompe,
/// alguien abre el manual de noche y lo ve en blanco, o ve texto que no se lee.
library;

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

const List<String> documentos = <String>[
  'web/manuales/index.html',
  'web/manuales/catedratico/index.html',
  'web/manuales/notas/index.html',
];

Set<String> variablesDe(String bloque) => RegExp(
  r'(--[a-z-]+)\s*:',
).allMatches(bloque).map((RegExpMatch m) => m.group(1)!).toSet();

void main() {
  final String css = File('web/manuales/estilo.css').readAsStringSync();

  test('los tres documentos usan el archivo compartido y no traen estilos propios', () {
    // Antes cada uno llevaba su copia, y un cambio había que hacerlo tres veces.
    for (final String d in documentos) {
      final String html = File(d).readAsStringSync();
      expect(html, contains('estilo.css'), reason: d);
      expect(html, isNot(contains('<style>')), reason: d);
    }
  });

  test('cada color del modo claro tiene su valor en el oscuro', () {
    final String claro = css.substring(
      css.indexOf(':root{'),
      css.indexOf('}', css.indexOf(':root{')),
    );
    final int i = css.indexOf(':root[data-tema="oscuro"]{');
    final String oscuro = css.substring(i, css.indexOf('}', i));
    final int j = css.indexOf(':root:not([data-tema="claro"]){');
    final String sistema = css.substring(j, css.indexOf('}', j));

    final Set<String> faltan = variablesDe(claro)
      ..remove('--ancho-menu')
      ..removeAll(variablesDe(oscuro));
    expect(faltan, isEmpty, reason: 'sin valor oscuro elegido');
    expect(variablesDe(sistema), variablesDe(oscuro),
        reason: 'el oscuro del dispositivo y el elegido deben ser el mismo');
  });

  test('fuera de las variables no quedan fondos claros escritos a mano', () {
    // Es lo que dejaba el manual con recuadros blancos en modo oscuro.
    final int fin = css.indexOf(
      '}',
      css.indexOf(':root[data-tema="oscuro"]{'),
    );
    final String reglas = css.substring(fin);
    final Iterable<String> fondos = RegExp(
      r'background\s*:\s*(#[0-9A-Fa-f]{3,6})',
    ).allMatches(reglas).map((RegExpMatch m) => m.group(1)!);
    // El único permitido: el círculo blanco del escudo y el botón «Volver»,
    // que van sobre la barra azul, que no cambia.
    expect(fondos.where((String c) => c.toLowerCase() != '#fff'), isEmpty);
  });

  test('siguen la apariencia elegida en SIAN, con la misma clave que la app', () {
    final String clave = File(
      'lib/presentation/shared/apariencia.dart',
    ).readAsStringSync();
    expect(clave, contains("'sian.apariencia'"));
    for (final String d in documentos) {
      final String html = File(d).readAsStringSync();
      expect(html, contains("localStorage.getItem('sian.apariencia')"), reason: d);
      // Antes de los estilos: si no, pinta en blanco y cambia después.
      expect(
        html.indexOf("getItem('sian.apariencia')"),
        lessThan(html.indexOf('estilo.css')),
        reason: d,
      );
    }
  });
}
