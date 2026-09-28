/// El tabulador recorre los formularios del panel en orden (U-4, RNF-23).
///
/// Reportado el 23/09/2026 al redactar: desde «Título», Tab saltaba a tres
/// opciones del menú lateral, volvía a «Mensaje» y saltaba otra vez al menú.
/// Flutter ordena el foco por renglones de pantalla, y el menú comparte
/// renglones con el formulario. El arreglo agrupa el menú y el contenido por
/// separado, así que vale para todas las secciones del panel.
library;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sian/application/proveedores_sesion.dart';
import 'package:sian/domain/rol.dart';
import 'package:sian/domain/sesion.dart';
import 'package:sian/presentation/admin/panel_admin.dart';
import 'package:sian/presentation/admin/seccion_mensajes.dart';
import 'package:sian/presentation/shared/tema.dart';
import 'package:sian/presentation/shared/textos.dart';
import 'package:sian/presentation/shared/version_app.dart';

import '../dobles/repositorios_falsos.dart';

/// ¿El foco está dentro de un widget de este tipo?
bool dentroDe<T extends Widget>(FocusNode? nodo) {
  bool esta = false;
  nodo?.context?.visitAncestorElements((Element e) {
    if (e.widget is T) {
      esta = true;
      return false;
    }
    return true;
  });
  return esta;
}

void main() {
  testWidgets('al redactar, Tab recorre todo el formulario sin pasar por el menú', (
    WidgetTester tester,
  ) async {
    tester.view.physicalSize = const Size(1400, 1100);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final RepositorioSesionFalso sesion = RepositorioSesionFalso(
      inicial: SesionActiva(
        usuarioDePrueba(rol: Rol.administradora, puedeEmitirUrgentes: true),
      ),
    );
    addTearDown(sesion.cerrar);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          repositorioSesionProvider.overrideWithValue(sesion),
          repositorioEnvioProvider.overrideWithValue(RepositorioEnvioFalso()),
          versionPublicadaProvider.overrideWith((Ref ref) async => null),
        ],
        child: MaterialApp(
          theme: TemaSian.claro(),
          home: PanelAdmin(
            usuario: usuarioDePrueba(
              rol: Rol.administradora,
              puedeEmitirUrgentes: true,
            ),
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.pump();
    await tester.tap(find.text(Textos.seccionMensajes).first);
    await tester.pump();
    await tester.pump();

    await tester.tap(find.byType(TextFormField).first);
    await tester.pump();

    // Título, mensaje, cuándo, adjuntos, tipo, destinatarios, confirmación y
    // Enviar: ocho paradas, todas en el formulario.
    final List<FocusNode?> paradas = <FocusNode?>[];
    for (int i = 0; i < 8; i += 1) {
      paradas.add(FocusManager.instance.primaryFocus);
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.pump();
    }

    for (int i = 0; i < paradas.length; i += 1) {
      expect(
        dentroDe<NavigationRail>(paradas[i]),
        isFalse,
        reason: 'la parada $i cayó en el menú lateral',
      );
    }
    // Las dos primeras, los dos campos de texto, en ese orden.
    expect(dentroDe<TextField>(paradas[0]), isTrue);
    expect(dentroDe<TextField>(paradas[1]), isTrue);
    expect(paradas[0], isNot(same(paradas[1])));
    // La última, el botón de enviar.
    expect(dentroDe<FilledButton>(paradas[7]), isTrue);
    // Y los campos van de arriba abajo: ninguno vuelve atrás.
    expect(
      paradas[1]!.rect.top,
      greaterThan(paradas[0]!.rect.top),
      reason: 'Mensaje va debajo de Título',
    );
  });
}
