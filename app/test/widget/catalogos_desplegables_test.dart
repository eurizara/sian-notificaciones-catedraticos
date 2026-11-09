/// Catálogos en bloques desplegables (2.0.3).
///
/// Cada bloque empieza cerrado y dice en su encabezado cuánto contiene; se
/// abre el que se va a usar. Quien no tiene la administración general ve
/// quién mantiene las sedes en lugar de un hueco.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sian/application/proveedores_catalogos.dart';
import 'package:sian/application/proveedores_sesion.dart';
import 'package:sian/domain/rol.dart';
import 'package:sian/domain/sesion.dart';
import 'package:sian/infrastructure/firebase/repositorio_catalogos.dart';
import 'package:sian/presentation/admin/seccion_catalogos.dart';
import 'package:sian/presentation/shared/tema.dart';
import 'package:sian/presentation/shared/textos.dart';

import '../dobles/repositorios_falsos.dart';

void main() {
  const List<ElementoCatalogo> facultades = <ElementoCatalogo>[
    ElementoCatalogo(
      id: 'ing-sistemas',
      nombre: 'Ingeniería en Sistemas',
      activa: true,
    ),
    ElementoCatalogo(id: 'derecho', nombre: 'Derecho', activa: false),
  ];

  Future<void> montar(WidgetTester tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          sesionActualProvider.overrideWithValue(
            SesionActiva(usuarioDePrueba(rol: Rol.coordinador)),
          ),
          nombreDeSedeProvider.overrideWith(
            (Ref ref, String _) async => 'Boca del Monte',
          ),
          fuenteFacultadesProvider.overrideWith(
            (Ref ref, String _) => FuenteCatalogoEnMemoria(facultades),
          ),
        ],
        child: MaterialApp(
          theme: TemaSian.claro(),
          home: const Scaffold(body: SeccionCatalogos()),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('el bloque de facultades empieza cerrado y dice cuánto tiene', (
    WidgetTester tester,
  ) async {
    await montar(tester);
    expect(
      find.text(Textos.catalogoFacultadesDe('Boca del Monte')),
      findsOneWidget,
    );
    expect(find.text('1 facultad activa · 1 inactiva'), findsOneWidget);
    expect(find.text(Textos.catalogoAgregar('facultad')), findsNothing);

    await tester.tap(find.text(Textos.catalogoFacultadesDe('Boca del Monte')));
    await tester.pumpAndSettle();
    expect(find.text(Textos.catalogoAgregar('facultad')), findsOneWidget);
    expect(find.text('Ingeniería en Sistemas'), findsOneWidget);
  });

  testWidgets(
    'sin la administración general se dice quién mantiene las sedes',
    (WidgetTester tester) async {
      await montar(tester);
      expect(find.text(Textos.sedesSoloAdministracionGeneral), findsOneWidget);
      expect(find.text(Textos.personasYSedes), findsNothing);
    },
  );

  test('el resumen de un catálogo', () {
    expect(Textos.resumenCatalogo(null, 'sede', 'sedes'), 'Cargando…');
    expect(
      Textos.resumenCatalogo(const <ElementoCatalogo>[], 'sede', 'sedes'),
      'Ninguna sede todavía',
    );
    expect(
      Textos.resumenCatalogo(
        facultades.sublist(0, 1),
        'facultad',
        'facultades',
      ),
      '1 facultad activa',
    );
    expect(Textos.resumenPersonas(3), '3 personas en todas las sedes');
  });
}
