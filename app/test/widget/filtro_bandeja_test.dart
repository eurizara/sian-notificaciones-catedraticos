/// Los filtros de la bandeja — RF-ENT-12, RF-CNF-02.
///
/// ────────────────────────────────────────────────────────────────────────────
/// Lo que se prueba aquí es qué VE un catedrático al abrir la aplicación.
/// ────────────────────────────────────────────────────────────────────────────
///
/// La bandeja arranca en «Sin leer», así que el filtro decide si una alerta
/// llega a los ojos de alguien o se queda detrás de una pestaña. De ahí que la
/// regla viva fuera de la pantalla y que lo que más se compruebe aquí sea lo
/// que NO se puede esconder.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sian/application/proveedores_dispositivos.dart';
import 'package:sian/application/proveedores_sesion.dart';
import 'package:sian/core/navegador.dart';
import 'package:sian/domain/repositorios.dart';
import 'package:sian/domain/rol.dart';
import 'package:sian/infrastructure/firebase/repositorio_dispositivos.dart';
import 'package:sian/presentation/docente/bandeja_docente.dart';
import 'package:sian/presentation/docente/filtro_bandeja.dart';
import 'package:sian/presentation/shared/tema.dart';
import 'package:sian/presentation/shared/textos.dart';

import '../dobles/repositorios_falsos.dart';

MensajeRecibido msg({
  required String id,
  required String titulo,
  required String estado,
  bool pideConfirmacion = false,
  String tipo = 'INFORMATIVO',
}) => MensajeRecibido(
  mensajeId: id,
  titulo: titulo,
  cuerpo: 'Cuerpo',
  tipo: tipo,
  estado: estado,
  requiereConfirmacion: pideConfirmacion,
  entregadoEn: DateTime(2026, 3, 17, 8),
);

/// Uno de cada situación que se da en la práctica.
final List<MensajeRecibido> _todos = <MensajeRecibido>[
  msg(id: 'a', titulo: 'Sin abrir', estado: 'ENTREGADO'),
  msg(
    id: 'b',
    titulo: 'Sin abrir y pide confirmar',
    estado: 'ENTREGADO',
    pideConfirmacion: true,
  ),
  msg(
    id: 'c',
    titulo: 'Abierta urgente sin confirmar',
    estado: 'ABIERTO',
    pideConfirmacion: true,
    tipo: 'URGENTE',
  ),
  msg(id: 'd', titulo: 'Abierta sin más', estado: 'ABIERTO'),
  msg(
    id: 'e',
    titulo: 'Confirmada',
    estado: 'CONFIRMADO',
    pideConfirmacion: true,
  ),
];

List<String> titulos(List<MensajeRecibido> l) =>
    l.map((MensajeRecibido m) => m.titulo).toList();

void main() {
  group('qué entra en cada filtro', () {
    test('sin leer: solo lo que llegó y nadie abrió', () {
      expect(titulos(aplicarFiltro(FiltroBandeja.sinLeer, _todos)), <String>[
        'Sin abrir',
        'Sin abrir y pide confirmar',
      ]);
    });

    test('sin confirmar: lo pendiente, esté abierto o no', () {
      // Abrir no es confirmar. Un aviso abierto que sigue sin confirmarse
      // tiene una acción pendiente exactamente igual que uno sin abrir.
      expect(
        titulos(aplicarFiltro(FiltroBandeja.sinConfirmar, _todos)),
        <String>['Sin abrir y pide confirmar', 'Abierta urgente sin confirmar'],
      );
    });

    test('leídos: abiertos y confirmados', () {
      expect(titulos(aplicarFiltro(FiltroBandeja.leidos, _todos)), <String>[
        'Abierta urgente sin confirmar',
        'Abierta sin más',
        'Confirmada',
      ]);
    });

    test('todos no deja fuera a nadie', () {
      expect(aplicarFiltro(FiltroBandeja.todos, _todos).length, _todos.length);
    });

    test('«sin leer» y «sin confirmar» se solapan a propósito', () {
      // Un aviso que llegó, nadie abrió y pedía confirmación responde que sí a
      // las dos preguntas. Repartirlo en cajones excluyentes obligaría a elegir
      // uno, y esa elección sería arbitraria justo con lo que más importa.
      final MensajeRecibido b = _todos[1];
      expect(entraEn(FiltroBandeja.sinLeer, b), isTrue);
      expect(entraEn(FiltroBandeja.sinConfirmar, b), isTrue);
    });

    test('un aviso que NO llegó no cuenta como sin leer', () {
      // No está sin leer: no está. Decir que hay uno sin leer cuando nunca
      // llegó manda a buscar algo que no existe.
      final MensajeRecibido fallido = msg(
        id: 'f',
        titulo: 'No llegó',
        estado: 'FALLIDO',
      );
      expect(entraEn(FiltroBandeja.sinLeer, fallido), isFalse);
      expect(entraEn(FiltroBandeja.leidos, fallido), isFalse);
    });

    test('los contadores coinciden con lo que se muestra', () {
      for (final FiltroBandeja f in FiltroBandeja.values) {
        expect(
          contarEn(f, _todos),
          aplicarFiltro(f, _todos).length,
          reason: '$f',
        );
      }
    });
  });

  group('la bandeja con filtros', () {
    late RepositorioSesionFalso sesion;
    late RepositorioDispositivosFalso dispositivos;

    setUp(() {
      sesion = RepositorioSesionFalso();
      dispositivos = RepositorioDispositivosFalso(
        entorno: EntornoNavegador.desconocido,
        permiso: EstadoPermiso.concedido,
      );
    });
    tearDown(() async {
      await sesion.cerrar();
      await dispositivos.cerrar();
    });

    Widget montar(List<MensajeRecibido> mensajes) => ProviderScope(
      overrides: [
        repositorioSesionProvider.overrideWithValue(sesion),
        repositorioDispositivosProvider.overrideWithValue(dispositivos),
        repositorioBandejaProvider.overrideWithValue(
          RepositorioBandejaFalso(mensajes),
        ),
      ],
      child: MaterialApp(
        theme: TemaSian.claro(),
        home: BandejaDocente(usuario: usuarioDePrueba(rol: Rol.catedratico)),
      ),
    );

    testWidgets('arranca en «Sin leer»', (WidgetTester tester) async {
      await tester.pumpWidget(montar(_todos));
      await tester.pumpAndSettle();

      expect(find.text('Sin abrir'), findsOneWidget);
      expect(
        find.text('Abierta sin más'),
        findsNothing,
        reason: 'lo ya leído no estorba al abrir',
      );
    });

    testWidgets('el contador de cada pestaña dice cuánto hay', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(montar(_todos));
      await tester.pumpAndSettle();

      expect(find.text(Textos.filtroBandeja('sinLeer', 2)), findsOneWidget);
      expect(
        find.text(Textos.filtroBandeja('sinConfirmar', 2)),
        findsOneWidget,
      );
      expect(find.text(Textos.filtroBandeja('leidos', 3)), findsOneWidget);
      expect(find.text(Textos.filtroBandeja('todos', 5)), findsOneWidget);
    });

    testWidgets('cambiar de pestaña cambia lo que se ve', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(montar(_todos));
      await tester.pumpAndSettle();

      await tester.tap(find.text(Textos.filtroBandeja('leidos', 3)));
      await tester.pumpAndSettle();

      expect(find.text('Abierta sin más'), findsOneWidget);
      expect(find.text('Sin abrir'), findsNothing);
    });

    // ────────────────────────────────────────────────────────────────────────
    // LO QUE NO PUEDE ESCONDERSE DETRÁS DE UNA PESTAÑA.
    // ────────────────────────────────────────────────────────────────────────
    //
    // Una alerta urgente ya abierta y sin confirmar NO sale en «Sin leer», que
    // es el filtro de partida. Si además desapareciera el aviso, el sistema
    // estaría escondiendo justo aquello para lo que existe.
    testWidgets('el aviso de urgentes se ve aunque el filtro las excluya', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(montar(_todos));
      await tester.pumpAndSettle();

      expect(find.text('Abierta urgente sin confirmar'), findsNothing);
      expect(find.text(Textos.bandejaPendienteUno), findsOneWidget);
    });

    testWidgets('tocar el aviso lleva a las que faltan por confirmar', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(montar(_todos));
      await tester.pumpAndSettle();

      await tester.tap(find.text(Textos.bandejaPendienteUno));
      await tester.pumpAndSettle();

      expect(find.text('Abierta urgente sin confirmar'), findsOneWidget);
    });

    testWidgets('sin nada sin leer, lo dice y ofrece el historial', (
      WidgetTester tester,
    ) async {
      // Quien está al día se encontraría la pantalla vacía. Sin explicación,
      // eso se lee como que algo se perdió; con ella es lo contrario.
      await tester.pumpWidget(
        montar(<MensajeRecibido>[
          msg(id: 'x', titulo: 'Ya leída', estado: 'ABIERTO'),
        ]),
      );
      await tester.pumpAndSettle();

      expect(find.text(Textos.filtroVacio('sinLeer')), findsOneWidget);

      await tester.tap(find.text(Textos.filtroVerTodos));
      await tester.pumpAndSettle();

      expect(find.text('Ya leída'), findsOneWidget);
    });
  });
}
