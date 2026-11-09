/// Catálogos en bloques desplegables (2.0.3) y catálogo único de facultades
/// (2.0.6).
///
/// Cada bloque empieza cerrado y dice en su encabezado cuánto contiene. La
/// coordinación ya no escribe facultades: marca, de la lista de la UMG, las
/// que ofrece su sede. El superadministrador mantiene esa lista y elige la
/// sede cuya oferta cambia. Quien no es superadministrador ve quién mantiene
/// las sedes en lugar de un hueco.
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
  // La lista de la UMG.
  const List<ElementoCatalogo> catalogo = <ElementoCatalogo>[
    ElementoCatalogo(
      id: 'ing-sistemas',
      nombre: 'Ingeniería en Sistemas',
      activa: true,
    ),
    ElementoCatalogo(id: 'psicologia', nombre: 'Psicología', activa: true),
    ElementoCatalogo(id: 'derecho', nombre: 'Derecho', activa: false),
  ];
  // Lo que ofrece Boca del Monte: Sistemas, y Psicología la retiró.
  const List<ElementoCatalogo> ofrecidas = <ElementoCatalogo>[
    ElementoCatalogo(
      id: 'ing-sistemas',
      nombre: 'Ingeniería en Sistemas',
      activa: true,
    ),
    ElementoCatalogo(id: 'psicologia', nombre: 'Psicología', activa: false),
  ];

  Future<RepositorioOfertaEnMemoria> montar(
    WidgetTester tester, {
    bool superadministrador = false,
    String? rechazo,
  }) async {
    tester.view.physicalSize = const Size(900, 2000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final RepositorioOfertaEnMemoria oferta = RepositorioOfertaEnMemoria(
      rechazo: rechazo,
    );
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          sesionActualProvider.overrideWithValue(
            SesionActiva(
              usuarioDePrueba(
                rol: Rol.coordinador,
                adminGeneral: superadministrador,
              ),
            ),
          ),
          nombreDeSedeProvider.overrideWith(
            (Ref ref, String _) async => 'Boca del Monte',
          ),
          fuenteFacultadesProvider.overrideWith(
            (Ref ref, String _) => FuenteCatalogoEnMemoria(ofrecidas),
          ),
          fuenteCatalogoFacultadesProvider.overrideWithValue(
            FuenteCatalogoEnMemoria(catalogo),
          ),
          fuenteSedesProvider.overrideWithValue(
            FuenteCatalogoEnMemoria(<ElementoCatalogo>[
              const ElementoCatalogo(
                id: 'bdm',
                nombre: 'Boca del Monte',
                activa: true,
              ),
              const ElementoCatalogo(
                id: 'villa-nueva',
                nombre: 'Villa Nueva',
                activa: true,
              ),
            ]),
          ),
          repositorioOfertaFacultadesProvider.overrideWithValue(oferta),
        ],
        child: MaterialApp(
          theme: TemaSian.claro(),
          home: const Scaffold(body: SeccionCatalogos()),
        ),
      ),
    );
    await tester.pumpAndSettle();
    return oferta;
  }

  CheckboxListTile casilla(WidgetTester tester, String nombre) => tester
      .widget<CheckboxListTile>(find.widgetWithText(CheckboxListTile, nombre));

  group('la coordinación', () {
    testWidgets(
      've lo que ofrece su sede, cerrado y con cuántas; no escribe facultades',
      (WidgetTester tester) async {
        await montar(tester);
        expect(
          find.text(Textos.catalogoFacultadesDe('Boca del Monte')),
          findsOneWidget,
        );
        expect(find.text('1 facultad ofrecida'), findsOneWidget);
        expect(find.text(Textos.catalogoFacultadesUnico), findsNothing);

        await tester.tap(
          find.text(Textos.catalogoFacultadesDe('Boca del Monte')),
        );
        await tester.pumpAndSettle();
        expect(find.text(Textos.catalogoAgregar('facultad')), findsNothing);
        expect(find.text(Textos.ofertaExplicacion), findsOneWidget);
        expect(casilla(tester, 'Ingeniería en Sistemas').value, isTrue);
        expect(casilla(tester, 'Psicología').value, isFalse);
        // Desactivada en la lista de la UMG y no ofrecida: no se ofrece elegirla.
        expect(find.text('Derecho'), findsNothing);
      },
    );

    testWidgets('marca una facultad de la lista de la UMG para su sede', (
      WidgetTester tester,
    ) async {
      final RepositorioOfertaEnMemoria oferta = await montar(tester);
      await tester.tap(
        find.text(Textos.catalogoFacultadesDe('Boca del Monte')),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Psicología'));
      await tester.pumpAndSettle();
      expect(oferta.pedidos, <String>['bdm psicologia true']);
      expect(
        find.text(Textos.ofertaOfrecida('Psicología', 'Boca del Monte')),
        findsOneWidget,
      );
    });

    testWidgets(
      'si alguien tiene la facultad, no se retira y se dice qué hacer',
      (WidgetTester tester) async {
        const String motivo =
            'La tienen 2 personas en esta sede. Quítesela primero en Usuarios '
            'y después retírela de la sede.';
        final RepositorioOfertaEnMemoria oferta = await montar(
          tester,
          rechazo: motivo,
        );
        await tester.tap(
          find.text(Textos.catalogoFacultadesDe('Boca del Monte')),
        );
        await tester.pumpAndSettle();
        await tester.tap(find.text('Ingeniería en Sistemas'));
        await tester.pumpAndSettle();
        expect(oferta.pedidos, <String>['bdm ing-sistemas false']);
        expect(find.text(motivo), findsOneWidget);
      },
    );

    testWidgets('se le dice quién mantiene las sedes', (
      WidgetTester tester,
    ) async {
      await montar(tester);
      expect(find.text(Textos.sedesSoloAdministracionGeneral), findsOneWidget);
      expect(find.text(Textos.personasYSedes), findsNothing);
    });
  });

  group('el superadministrador', () {
    testWidgets(
      'mantiene la lista de la UMG y elige la sede cuya oferta cambia',
      (WidgetTester tester) async {
        final RepositorioOfertaEnMemoria oferta = await montar(
          tester,
          superadministrador: true,
        );
        expect(find.text(Textos.catalogoFacultadesUnico), findsOneWidget);
        expect(find.text('2 facultades activas · 1 inactiva'), findsOneWidget);
        await tester.tap(find.text(Textos.catalogoFacultadesUnico));
        await tester.pumpAndSettle();
        expect(find.text(Textos.catalogoAgregar('facultad')), findsOneWidget);
        await tester.tap(find.text(Textos.catalogoFacultadesUnico));
        await tester.pumpAndSettle();

        await tester.tap(find.text(Textos.ofertaPorSede));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Boca del Monte').last);
        await tester.pumpAndSettle();
        await tester.tap(find.text('Villa Nueva').last);
        await tester.pumpAndSettle();
        await tester.tap(find.text('Psicología'));
        await tester.pumpAndSettle();
        expect(oferta.pedidos, <String>['villa-nueva psicologia true']);
      },
    );
  });

  test('los resúmenes', () {
    expect(Textos.resumenCatalogo(null, 'sede', 'sedes'), 'Cargando…');
    expect(
      Textos.resumenCatalogo(const <ElementoCatalogo>[], 'sede', 'sedes'),
      'Ninguna sede todavía',
    );
    expect(
      Textos.resumenCatalogo(catalogo.sublist(0, 1), 'facultad', 'facultades'),
      '1 facultad activa',
    );
    expect(Textos.resumenPersonas(3), '3 personas en todas las sedes');
    expect(Textos.resumenOferta(null), 'Cargando…');
    expect(Textos.resumenOferta(ofrecidas), '1 facultad ofrecida');
    expect(
      Textos.resumenOferta(const <ElementoCatalogo>[]),
      'Ninguna facultad ofrecida',
    );
  });
}
