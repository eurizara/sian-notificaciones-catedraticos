/// Mantenimiento de catálogos (2.0 · RF-CAT-01, RF-CAT-02, RF-CAT-03).
///
/// Un solo componente para todos los catálogos. Se prueba lo que la persona ve
/// y hace: la lista con el estado escrito, agregar, el mensaje del servidor
/// cuando el nombre se repite, y desactivar con confirmación, sin borrar.
library;

import 'dart:async';

import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sian/infrastructure/firebase/repositorio_catalogos.dart';
import 'package:sian/presentation/shared/mantenimiento_catalogo.dart';
import 'package:sian/presentation/shared/tema.dart';
import 'package:sian/presentation/shared/textos.dart';

class _FuenteEnMemoria implements FuenteCatalogo {
  _FuenteEnMemoria(List<ElementoCatalogo> inicial) : _elementos = inicial {
    _canal.add(ordenarCatalogo(_elementos));
  }

  List<ElementoCatalogo> _elementos;
  final StreamController<List<ElementoCatalogo>> _canal =
      StreamController<List<ElementoCatalogo>>.broadcast();
  final List<Map<String, Object?>> guardados = <Map<String, Object?>>[];

  @override
  Stream<List<ElementoCatalogo>> observar() async* {
    yield ordenarCatalogo(_elementos);
    yield* _canal.stream;
  }

  @override
  Future<void> guardar({
    required String nombre,
    String? id,
    bool? activa,
  }) async {
    guardados.add(<String, Object?>{
      'id': id,
      'nombre': nombre,
      'activa': activa,
    });
    if (id == null &&
        _elementos.any(
          (ElementoCatalogo e) =>
              e.nombre.toLowerCase() == nombre.toLowerCase(),
        )) {
      throw FirebaseFunctionsException(
        code: 'invalid-argument',
        message: 'Ya existe «$nombre» en este catálogo.',
      );
    }
    final String nuevoId = id ?? nombre.toLowerCase().replaceAll(' ', '-');
    _elementos = <ElementoCatalogo>[
      for (final ElementoCatalogo e in _elementos)
        if (e.id != nuevoId) e,
      ElementoCatalogo(
        id: nuevoId,
        nombre: nombre,
        activa:
            activa ??
            _elementos
                .where((ElementoCatalogo e) => e.id == nuevoId)
                .firstOrNull
                ?.activa ??
            true,
      ),
    ];
    _canal.add(ordenarCatalogo(_elementos));
  }
}

Future<_FuenteEnMemoria> _montar(
  WidgetTester tester,
  List<ElementoCatalogo> inicial,
) async {
  final _FuenteEnMemoria fuente = _FuenteEnMemoria(inicial);
  await tester.pumpWidget(
    MaterialApp(
      theme: TemaSian.claro(),
      home: Scaffold(
        body: ListView(
          children: <Widget>[
            MantenimientoCatalogo(
              fuente: fuente,
              titulo: 'Facultades de Boca del Monte',
              elemento: 'facultad',
            ),
          ],
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
  return fuente;
}

void main() {
  const ElementoCatalogo sistemas = ElementoCatalogo(
    id: 'ing-sistemas',
    nombre: 'Ingeniería en Sistemas',
    activa: true,
  );
  const ElementoCatalogo derecho = ElementoCatalogo(
    id: 'derecho',
    nombre: 'Derecho',
    activa: false,
  );

  testWidgets('la lista dice el estado con palabras, activas primero', (
    WidgetTester tester,
  ) async {
    await _montar(tester, <ElementoCatalogo>[derecho, sistemas]);
    expect(find.text('Facultades de Boca del Monte'), findsOneWidget);
    expect(find.text(Textos.catalogoActiva), findsOneWidget);
    expect(find.text(Textos.catalogoInactiva), findsOneWidget);
    expect(
      tester.getTopLeft(find.text('Ingeniería en Sistemas')).dy,
      lessThan(tester.getTopLeft(find.text('Derecho')).dy),
    );
    // Con pocas filas no estorba un buscador.
    expect(find.byType(TextField), findsNothing);
  });

  testWidgets('sin elementos, dice qué hacer', (WidgetTester tester) async {
    await _montar(tester, <ElementoCatalogo>[]);
    expect(find.text(Textos.catalogoVacio('facultad')), findsOneWidget);
  });

  testWidgets('agregar: un nombre muy corto no llega al servidor', (
    WidgetTester tester,
  ) async {
    final _FuenteEnMemoria fuente = await _montar(tester, <ElementoCatalogo>[
      sistemas,
    ]);
    await tester.tap(find.text(Textos.catalogoAgregar('facultad')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'x');
    await tester.tap(find.text(Textos.grupoGuardar));
    await tester.pumpAndSettle();
    expect(find.text(Textos.catalogoNombreCorto), findsOneWidget);
    expect(fuente.guardados, isEmpty);
  });

  testWidgets('RF-CAT-03: el mensaje del servidor dice qué corregir', (
    WidgetTester tester,
  ) async {
    await _montar(tester, <ElementoCatalogo>[sistemas]);
    await tester.tap(find.text(Textos.catalogoAgregar('facultad')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'ingeniería en sistemas');
    await tester.tap(find.text(Textos.grupoGuardar));
    await tester.pumpAndSettle();
    expect(
      find.text('Ya existe «ingeniería en sistemas» en este catálogo.'),
      findsOneWidget,
    );
    // El diálogo sigue abierto para corregir, no se pierde lo escrito.
    expect(find.byType(AlertDialog), findsOneWidget);
  });

  testWidgets('agregar una facultad nueva la muestra en la lista', (
    WidgetTester tester,
  ) async {
    await _montar(tester, <ElementoCatalogo>[sistemas]);
    await tester.tap(find.text(Textos.catalogoAgregar('facultad')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'Medicina');
    await tester.tap(find.text(Textos.grupoGuardar));
    await tester.pumpAndSettle();
    expect(find.byType(AlertDialog), findsNothing);
    expect(find.text('Medicina'), findsOneWidget);
  });

  testWidgets('RF-CAT-02: desactivar pide confirmación y no borra', (
    WidgetTester tester,
  ) async {
    final _FuenteEnMemoria fuente = await _montar(tester, <ElementoCatalogo>[
      sistemas,
    ]);
    await tester.tap(find.text(Textos.grupoDesactivar));
    await tester.pumpAndSettle();
    expect(
      find.text(Textos.catalogoDesactivarTitulo('Ingeniería en Sistemas')),
      findsOneWidget,
    );

    // Cancelar no cambia nada.
    await tester.tap(find.text(Textos.botonCancelar));
    await tester.pumpAndSettle();
    expect(fuente.guardados, isEmpty);

    await tester.tap(find.text(Textos.grupoDesactivar));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, Textos.grupoDesactivar));
    await tester.pumpAndSettle();
    expect(fuente.guardados.single, <String, Object?>{
      'id': 'ing-sistemas',
      'nombre': 'Ingeniería en Sistemas',
      'activa': false,
    });
    expect(
      find.text('Ingeniería en Sistemas'),
      findsOneWidget,
      reason: 'sigue en la lista',
    );
    expect(find.text(Textos.catalogoInactiva), findsOneWidget);
  });

  testWidgets('con muchas filas aparece el buscador, y filtra sin tildes', (
    WidgetTester tester,
  ) async {
    await _montar(tester, <ElementoCatalogo>[
      sistemas,
      for (int i = 0; i < 6; i++)
        ElementoCatalogo(id: 'f$i', nombre: 'Facultad $i', activa: true),
    ]);
    expect(find.byType(TextField), findsOneWidget);
    await tester.enterText(find.byType(TextField), 'ingenieria');
    await tester.pumpAndSettle();
    expect(find.text('Ingeniería en Sistemas'), findsOneWidget);
    expect(find.text('Facultad 0'), findsNothing);
  });

  testWidgets('cada botón de editar dice a qué elemento se refiere', (
    WidgetTester tester,
  ) async {
    await _montar(tester, <ElementoCatalogo>[sistemas]);
    expect(
      find.byTooltip(Textos.catalogoCambiarNombre('Ingeniería en Sistemas')),
      findsOneWidget,
    );
  });
}
