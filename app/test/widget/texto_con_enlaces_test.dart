/// Enlaces tocables en avisos y respuestas (U-2) y copiar un aviso (U-1).
library;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sian/core/plataforma/enlace.dart';
import 'package:sian/presentation/docente/copiar_aviso.dart';
import 'package:sian/presentation/shared/tema.dart';
import 'package:sian/presentation/shared/texto_con_enlaces.dart';
import 'package:sian/presentation/shared/textos.dart';

List<Uri?> destinos(String texto) => <Uri?>[
  for (final TrozoDeTexto t in separarEnlaces(texto))
    if (t.destino != null) t.destino,
];

void main() {
  group('qué se vuelve enlace', () {
    test('una dirección web', () {
      expect(destinos('Ver https://umg.edu.gt/calendario hoy'), <Uri>[
        Uri.parse('https://umg.edu.gt/calendario'),
      ]);
    });

    test('«www.» sin esquema se abre como https', () {
      expect(destinos('Entren a www.umg.edu.gt'), <Uri>[
        Uri.parse('https://www.umg.edu.gt'),
      ]);
    });

    test('la puntuación que cierra la frase no es parte del enlace', () {
      for (final String final_ in <String>['.', ',', ';', ':', '!', '?', '»', ').']) {
        final List<TrozoDeTexto> t = separarEnlaces('Visiten (www.umg.edu.gt$final_');
        final TrozoDeTexto e = t.firstWhere((TrozoDeTexto x) => x.destino != null);
        expect(e.texto, 'www.umg.edu.gt', reason: final_);
        // Y el texto no se pierde: al unirlo sale igual.
        expect(t.map((TrozoDeTexto x) => x.texto).join(), 'Visiten (www.umg.edu.gt$final_');
      }
    });

    test('un paréntesis que es parte de la dirección se conserva', () {
      expect(destinos('https://es.wikipedia.org/wiki/Guatemala_(país)'), <Uri>[
        Uri.parse('https://es.wikipedia.org/wiki/Guatemala_(país)'),
      ]);
    });

    test('un correo abre la aplicación de correo', () {
      expect(destinos('Escriban a coordinacion@miumg.edu.gt.'), <Uri>[
        Uri(scheme: 'mailto', path: 'coordinacion@miumg.edu.gt'),
      ]);
    });

    test('teléfonos de Guatemala, en sus formas habituales', () {
      for (final String t in <String>[
        '5555 1234',
        '5555-1234',
        '55551234',
        '+502 2222 3333',
        '+502-2222-3333',
      ]) {
        final List<Uri?> d = destinos('Llamen al $t por favor');
        expect(d, hasLength(1), reason: t);
        expect(d.single!.scheme, 'tel', reason: t);
        expect(d.single!.path, startsWith('+502'), reason: t);
      }
    });

    test('el texto se conserva entero, sin perder ni duplicar nada', () {
      const String texto =
          'Reunión 9:00 en www.umg.edu.gt o al 5555-1234; dudas: a@b.com.';
      expect(
        separarEnlaces(texto).map((TrozoDeTexto t) => t.texto).join(),
        texto,
      );
    });
  });

  group('qué NO se vuelve enlace', () {
    test('esquemas que podrían ejecutar algo', () {
      // El texto lo escribió una persona y lo leen muchas.
      for (final String malo in <String>[
        'javascript:alert(1)',
        'data:text/html,<b>x</b>',
        'file:///etc/passwd',
        'ftp://servidor/archivo',
      ]) {
        expect(destinos('Toque $malo aquí'), isEmpty, reason: malo);
      }
    });

    test('números que no son teléfonos: fechas, horas, carnés, montos', () {
      for (final String n in <String>[
        '2026-09-26',
        '26/09/2026',
        '10:30',
        '0900-20-12345',
        '123456789',
        '1234 5678', // empieza por 1: no es un número de Guatemala
        'Q 8,500.00',
      ]) {
        expect(destinos('Dato: $n'), isEmpty, reason: n);
      }
    });

    test('un texto sin nada tocable queda como un solo trozo', () {
      expect(separarEnlaces('Mañana hay actividades normales.'), <TrozoDeTexto>[
        const TrozoDeTexto(TipoDeTrozo.texto, 'Mañana hay actividades normales.'),
      ]);
    });
  });

  group('en pantalla', () {
    testWidgets('tocar el enlace lo abre', (WidgetTester tester) async {
      enlacesAbiertos.clear();
      await tester.pumpWidget(
        MaterialApp(
          theme: TemaSian.claro(),
          home: const Scaffold(body: TextoConEnlaces('Ver www.umg.edu.gt ahora')),
        ),
      );
      final Offset centro = tester.getCenter(find.byType(SelectableText));
      // El enlace está en medio del texto: se toca por el texto que lo lleva.
      await tester.tapAt(centro);
      await tester.pump();
      expect(enlacesAbiertos, <Uri>[Uri.parse('https://www.umg.edu.gt')]);
    });
  });

  group('copiar (U-1)', () {
    test('qué va al portapapeles en cada opción', () {
      expect(textoACopiar(QueCopiar.todo, titulo: 'T', cuerpo: 'C'), 'T\n\nC');
      expect(textoACopiar(QueCopiar.titulo, titulo: 'T', cuerpo: 'C'), 'T');
      expect(textoACopiar(QueCopiar.mensaje, titulo: 'T', cuerpo: 'C'), 'C');
    });

    testWidgets('el botón copia y lo confirma', (WidgetTester tester) async {
      String? copiado;
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        (MethodCall llamada) async {
          if (llamada.method == 'Clipboard.setData') {
            copiado = (llamada.arguments as Map<Object?, Object?>)['text'] as String?;
          }
          return null;
        },
      );
      addTearDown(
        () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
          SystemChannels.platform,
          null,
        ),
      );

      await tester.pumpWidget(
        MaterialApp(
          theme: TemaSian.claro(),
          home: const Scaffold(
            body: Center(
              child: BotonCopiarAviso(titulo: 'Reunión', cuerpo: 'Mañana a las 9.'),
            ),
          ),
        ),
      );
      await tester.tap(find.text(Textos.botonCopiar));
      await tester.pumpAndSettle();
      await tester.tap(find.text(Textos.copiarTodo));
      await tester.pumpAndSettle();

      expect(copiado, 'Reunión\n\nMañana a las 9.');
      expect(find.text(Textos.copiado), findsOneWidget);
    });
  });
}
