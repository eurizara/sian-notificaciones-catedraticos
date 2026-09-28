/// Guardar una imagen de un aviso (U-3).
///
/// En iPhone, «Guardar imagen» vive en el menú Compartir; en Android y en la
/// computadora, se descarga como archivo.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sian/application/proveedores_dispositivos.dart';
import 'package:sian/core/navegador.dart';
import 'package:sian/core/plataforma/descarga.dart';
import 'package:sian/presentation/docente/reproductor_adjuntos.dart';
import 'package:sian/presentation/shared/tema.dart';
import 'package:sian/presentation/shared/textos.dart';

import '../dobles/repositorios_falsos.dart';

void main() {
  setUp(imagenesGuardadas.clear);

  Future<void> montar(WidgetTester tester, PlataformaWeb plataforma) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          repositorioDispositivosProvider.overrideWithValue(
            RepositorioDispositivosFalso(
              entorno: EntornoNavegador(
                plataforma: plataforma,
                instalada: true,
                navegador: plataforma == PlataformaWeb.ios ? 'Safari' : 'Chrome',
                soportaNotificaciones: true,
                versionIos: plataforma == PlataformaWeb.ios ? 17 : null,
              ),
            ),
          ),
        ],
        child: MaterialApp(
          theme: TemaSian.claro(),
          home: Scaffold(
            body: Builder(
              builder: (BuildContext context) => TextButton(
                onPressed: () => showDialog<void>(
                  context: context,
                  builder: (BuildContext _) => const ImagenAmpliada(
                    url: 'https://ejemplo.invalid/plano.jpg',
                    ruta: 'mensajes/m-1/plano-evacuacion.jpg',
                  ),
                ),
                child: const Text('ampliar'),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('ampliar'));
    // La imagen de red no carga en pruebas: sale el aviso de error, y lo que
    // importa aquí es el botón.
    await tester.pumpAndSettle();
  }

  testWidgets('en Android se descarga como archivo, con el nombre del adjunto', (
    WidgetTester tester,
  ) async {
    await montar(tester, PlataformaWeb.android);
    await tester.tap(find.byTooltip(Textos.guardarImagen));
    await tester.pump();

    expect(imagenesGuardadas.single.nombre, 'plano-evacuacion.jpg');
    expect(imagenesGuardadas.single.compartir, isFalse);
  });

  testWidgets('en iPhone se abre Compartir, que es donde está «Guardar imagen»', (
    WidgetTester tester,
  ) async {
    await montar(tester, PlataformaWeb.ios);
    await tester.tap(find.byTooltip(Textos.guardarImagen));
    await tester.pump();

    expect(imagenesGuardadas.single.compartir, isTrue);
  });
}
