/// Pruebas del panel de administración — matriz RBAC, documento 01, §2.2.
///
/// Verifican que cada rol ve exactamente las secciones que le corresponden.
/// El filtrado del menú es **comodidad, no seguridad**: aunque alguien forzara
/// la navegación, las reglas de Firestore seguirían rechazando cada lectura
/// (RN-01). Estas pruebas cubren la comodidad; las de `functions/test/reglas`
/// cubren la seguridad.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sian/application/proveedores_sesion.dart';
import 'package:sian/domain/rol.dart';
import 'package:sian/presentation/admin/panel_admin.dart';
import 'package:sian/presentation/admin/seccion_usuarios.dart';
import 'package:sian/presentation/shared/tema.dart';
import 'package:sian/presentation/shared/textos.dart';

import '../dobles/repositorios_falsos.dart';

void main() {
  List<String> etiquetasPara(Rol rol) =>
      seccionesPara(rol).map((SeccionAdmin s) => s.etiqueta).toList();

  group('secciones visibles por rol', () {
    test('el coordinador lo ve todo', () {
      expect(etiquetasPara(Rol.coordinador), <String>[
        Textos.seccionMensajes,
        Textos.seccionProgramacion,
        Textos.seccionGrupos,
        Textos.seccionUsuarios,
        Textos.seccionEntregas,
        Textos.seccionBitacora,
      ]);
    });

    test('la administradora emite, pero no administra usuarios ni ve bitácora', () {
      final List<String> etiquetas = etiquetasPara(Rol.administradora);

      expect(etiquetas, contains(Textos.seccionMensajes));
      expect(etiquetas, contains(Textos.seccionGrupos));
      expect(etiquetas, contains(Textos.seccionEntregas));

      // Las dos exclusiones que marca la matriz del documento 01.
      expect(etiquetas, isNot(contains(Textos.seccionUsuarios)));
      expect(etiquetas, isNot(contains(Textos.seccionBitacora)));
    });

    test('el auditor solo observa: bitácora y entregas', () {
      expect(etiquetasPara(Rol.auditor), <String>[
        Textos.seccionEntregas,
        Textos.seccionBitacora,
      ]);
    });

    test('el catedrático no tiene ninguna sección del panel', () {
      // No debería llegar nunca a esta pantalla, y si llegara, no vería nada.
      expect(etiquetasPara(Rol.catedratico), isEmpty);
    });
  });

  group('representación', () {
    Widget montar(Rol rol) {
      return ProviderScope(
        overrides: [
          repositorioSesionProvider.overrideWithValue(RepositorioSesionFalso()),
          repositorioAdminProvider.overrideWithValue(RepositorioAdminFalso()),
        ],
        child: MaterialApp(
          theme: TemaSian.claro(),
          home: PanelAdmin(usuario: usuarioDePrueba(rol: rol)),
        ),
      );
    }

    testWidgets('la administradora no ve la entrada de Usuarios en el menú', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(montar(Rol.administradora));
      await tester.pump();

      expect(find.text(Textos.seccionMensajes), findsOneWidget);
      expect(find.text(Textos.seccionUsuarios), findsNothing);
      expect(find.text(Textos.seccionBitacora), findsNothing);
    });

    testWidgets('el coordinador sí la ve', (WidgetTester tester) async {
      await tester.pumpWidget(montar(Rol.coordinador));
      await tester.pump();

      expect(find.text(Textos.seccionUsuarios), findsOneWidget);
      expect(find.text(Textos.seccionBitacora), findsOneWidget);
    });

    testWidgets('cada sección declara qué hará y en qué iteración', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(montar(Rol.coordinador));
      await tester.pump();

      // Arranca en la primera sección visible.
      expect(find.text(Textos.seccionMensajesTitulo), findsOneWidget);
      expect(find.text(Textos.iteracion13), findsOneWidget);
      // Y enseña los requisitos que cubrirá, no una maqueta vacía.
      expect(find.text('RF-MSG-13'), findsOneWidget);
    });

    testWidgets('cambiar de sección cambia el contenido', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(montar(Rol.coordinador));
      await tester.pump();

      expect(find.text(Textos.seccionMensajesTitulo), findsOneWidget);

      await tester.tap(find.text(Textos.seccionUsuarios));
      await tester.pump();
      await tester.pump();

      // Usuarios ya no es un marcador: muestra la sección real, con sus dos
      // pestañas.
      expect(find.text(Textos.pestanaInvitaciones), findsOneWidget);
      expect(find.text(Textos.seccionMensajesTitulo), findsNothing);
    });

    testWidgets('la barra muestra quién está dentro y con qué rol', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(montar(Rol.auditor));
      await tester.pump();

      expect(find.text('Persona de Prueba'), findsOneWidget);
      expect(find.text(Rol.auditor.etiqueta), findsOneWidget);
    });

    testWidgets('en pantalla estrecha la barra no desborda', (
      WidgetTester tester,
    ) async {
      // Regresión: con el escudo institucional en el título, la fila reclamaba
      // todo el ancho y empujaba las acciones fuera de la pantalla. En un
      // teléfono, que es donde más se usa, la barra reventaba.
      tester.view.physicalSize = const Size(390, 844); // iPhone
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(montar(Rol.coordinador));
      await tester.pump();

      expect(tester.takeException(), isNull);
      // El nombre cede el sitio; la identidad se conserva en la ayuda del
      // botón de salir.
      expect(find.text('Persona de Prueba'), findsNothing);
    });
  });
}
