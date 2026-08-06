/// Pruebas de la ronda 5 — programación, recurrencia y confirmación.
///
/// RF-PRG-02, 04, 09, 10, 11 · RF-CNF-01, 02, 04, 07.
///
/// ────────────────────────────────────────────────────────────────────────────
/// Aquí lo que se prueba es lo que impide un desastre silencioso.
/// ────────────────────────────────────────────────────────────────────────────
///
/// Un patrón de repetición mal puesto no falla: funciona, y manda avisos a
/// horas absurdas durante meses. Una confirmación que se pudiera fabricar no
/// da error: da una evidencia falsa. Por eso las pruebas se centran en las
/// puertas —la vista previa obligatoria, el diálogo antes de confirmar, la
/// diferencia entre suspender y cancelar— y no en el camino feliz.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sian/application/proveedores_programacion.dart';
import 'package:sian/infrastructure/firebase/repositorio_programacion.dart';
import 'package:sian/presentation/admin/seccion_entregas.dart';
import 'package:sian/presentation/admin/seccion_programacion.dart';
import 'package:sian/presentation/shared/tema.dart';
import 'package:sian/presentation/shared/textos.dart';

import '../dobles/repositorios_falsos.dart';

MensajeProgramado programado({
  String id = 'm1',
  String titulo = 'Simulacro',
  String estado = 'PROGRAMADO',
  String modo = 'UNICO',
  DateTime? proxima,
  DateTime? enviado,
  int total = 0,
  int entregados = 0,
  int confirmados = 0,
  bool requiereConfirmacion = true,
  String modoDestinatarios = 'TODOS',
  List<String> nombresGrupos = const <String>[],
  List<String> formato = const <String>['TEXTO'],
}) {
  return MensajeProgramado(
    id: id,
    titulo: titulo,
    tipo: 'INFORMATIVO',
    estado: estado,
    modo: modo,
    creadoPor: 'uid-1',
    requiereConfirmacion: requiereConfirmacion,
    modoDestinatarios: modoDestinatarios,
    nombresGrupos: nombresGrupos,
    formato: formato,
    proximaOcurrencia: proxima ?? DateTime.utc(2026, 9, 1, 13),
    enviadoEn: enviado,
    totalDestinatarios: total,
    entregados: entregados,
    confirmados: confirmados,
  );
}

void main() {
  group('estado de un mensaje programado', () {
    test('lo ya enviado no se puede tocar (RN-03)', () {
      for (final String e in <String>[
        'ENVIADO',
        'ENVIADO_CON_FALLOS',
        'AGOTADO',
      ]) {
        final MensajeProgramado m = programado(estado: e);
        expect(m.yaSalio, isTrue, reason: e);
        expect(m.sePuedeIntervenir, isFalse, reason: e);
      }
    });

    test('lo programado y lo suspendido sí', () {
      expect(programado(estado: 'PROGRAMADO').sePuedeIntervenir, isTrue);
      expect(programado(estado: 'SUSPENDIDO').sePuedeIntervenir, isTrue);
    });

    test('lo cancelado ya no admite más acciones', () {
      expect(programado(estado: 'CANCELADO').sePuedeIntervenir, isFalse);
    });
  });

  group('un aviso SIN confirmación no se mide en confirmaciones', () {
    // ──────────────────────────────────────────────────────────────────────
    // Mezclarlos convertía un dato correcto en una alarma falsa.
    // ──────────────────────────────────────────────────────────────────────
    //
    // Un aviso informativo aparecía para siempre «al 0 %, faltan 40 por
    // confirmar», como si algo hubiera salido mal. No había salido mal: es
    // que nadie tenía que confirmarlo.
    test('no le faltan confirmaciones a nadie', () {
      final MensajeProgramado m = programado(
        total: 40,
        entregados: 40,
        confirmados: 0,
        requiereConfirmacion: false,
      );
      expect(m.faltanPorConfirmar, 0);
    });

    test('su avance se mide por entrega', () {
      final MensajeProgramado m = programado(
        total: 40,
        entregados: 40,
        requiereConfirmacion: false,
      );
      expect(m.porcentajeEntregado, 100);
    });

    test('entregado a medias es medio avance, no cero', () {
      final MensajeProgramado m = programado(
        total: 40,
        entregados: 20,
        requiereConfirmacion: false,
      );
      expect(m.porcentajeEntregado, 50);
    });

    test('uno CON confirmación sí cuenta lo que falta', () {
      final MensajeProgramado m = programado(
        total: 40,
        entregados: 40,
        confirmados: 15,
      );
      expect(m.faltanPorConfirmar, 25);
    });
  });

  group('RF-CNF-07 · el porcentaje se calcula sobre el TOTAL', () {
    test('no sobre los entregados', () {
      // Con denominador «entregados» esto daría 100 % teniendo 5 personas sin
      // enterarse, que es justo el dato por el que se hace un simulacro.
      final MensajeProgramado m = programado(
        total: 10,
        entregados: 5,
        confirmados: 5,
      );
      expect(m.porcentajeConfirmado, 50);
    });

    test('sin destinatarios es 0 y no revienta', () {
      expect(programado().porcentajeConfirmado, 0);
    });
  });

  group('RF-PRG-10 y 11 · suspender NO es cancelar', () {
    late RepositorioProgramacionFalso repo;

    Widget montar(List<MensajeProgramado> lista) {
      repo = RepositorioProgramacionFalso(programados: lista);
      return ProviderScope(
        overrides: [repositorioProgramacionProvider.overrideWithValue(repo)],
        child: MaterialApp(
          theme: TemaSian.claro(),
          home: const Scaffold(body: SeccionProgramacion()),
        ),
      );
    }

    testWidgets('sin nada programado lo explica', (WidgetTester tester) async {
      await tester.pumpWidget(montar(const <MensajeProgramado>[]));
      await tester.pumpAndSettle();

      expect(find.text(Textos.programadosVacia), findsOneWidget);
    });

    testWidgets('suspender no pide confirmación: se puede deshacer', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(montar(<MensajeProgramado>[programado()]));
      await tester.pumpAndSettle();

      await tester.tap(find.text(Textos.accionSuspender));
      await tester.pumpAndSettle();

      expect(repo.cambios, <({String mensajeId, String accion})>[
        (mensajeId: 'm1', accion: 'SUSPENDER'),
      ]);
    });

    testWidgets('cancelar SÍ la pide, y explica la diferencia', (
      WidgetTester tester,
    ) async {
      // Cancelar es definitivo. Que la diferencia con suspender se explique
      // justo donde hay que decidirla, y no en un manual, es el punto.
      await tester.pumpWidget(montar(<MensajeProgramado>[programado()]));
      await tester.pumpAndSettle();

      await tester.tap(find.text(Textos.accionCancelar));
      await tester.pumpAndSettle();

      expect(find.text(Textos.cancelarTitulo), findsOneWidget);
      expect(find.text(Textos.cancelarAviso), findsOneWidget);
      expect(repo.cambios, isEmpty, reason: 'todavía no debe haber actuado');
    });

    testWidgets('cancelar y arrepentirse no cambia nada', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(montar(<MensajeProgramado>[programado()]));
      await tester.pumpAndSettle();

      await tester.tap(find.text(Textos.accionCancelar));
      await tester.pumpAndSettle();

      // El botón de descartar NO dice «Cancelar»: en este diálogo habría dos
      // botones diciendo lo mismo con significados opuestos.
      expect(find.text(Textos.noCancelarNada), findsOneWidget);
      await tester.tap(find.text(Textos.noCancelarNada));
      await tester.pumpAndSettle();

      expect(repo.cambios, isEmpty);
    });

    testWidgets('uno suspendido ofrece reanudar, no suspender otra vez', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        montar(<MensajeProgramado>[programado(estado: 'SUSPENDIDO')]),
      );
      await tester.pumpAndSettle();

      expect(find.text(Textos.accionReanudar), findsOneWidget);
      expect(find.text(Textos.accionSuspender), findsNothing);
    });

    testWidgets('uno ya enviado no ofrece ninguna acción', (
      WidgetTester tester,
    ) async {
      // Un botón inerte invita a pulsarlo más fuerte. Mejor que no esté, con
      // la razón escrita.
      await tester.pumpWidget(
        montar(<MensajeProgramado>[programado(estado: 'ENVIADO', total: 5)]),
      );
      await tester.pumpAndSettle();

      expect(find.text(Textos.accionSuspender), findsNothing);
      expect(find.text(Textos.accionCancelar), findsNothing);
      expect(find.text(Textos.yaEnviadoNoSeToca), findsOneWidget);
    });

    testWidgets('los envíos inmediatos no aparecen aquí', (
      WidgetTester tester,
    ) async {
      // Un inmediato ya enviado no es «programación»: su sitio es el reporte
      // de entregas.
      await tester.pumpWidget(
        montar(<MensajeProgramado>[programado(modo: 'INMEDIATO')]),
      );
      await tester.pumpAndSettle();

      expect(find.text(Textos.programadosVacia), findsOneWidget);
    });
  });

  group('RF-CNF-06 · quién falta por confirmar', () {
    // ──────────────────────────────────────────────────────────────────────
    // «Faltan 6» no dice a QUIÉN hay que buscar.
    // ──────────────────────────────────────────────────────────────────────
    //
    // Y es lo único accionable del reporte: el porcentaje describe, la lista
    // permite actuar.
    late RepositorioProgramacionFalso repo;

    Widget montarConDetalle(List<DestinatarioEntrega> detalle) {
      repo = RepositorioProgramacionFalso(
        programados: <MensajeProgramado>[
          programado(total: 3, entregados: 3, confirmados: 1),
        ],
      )..detalle = detalle;

      return ProviderScope(
        overrides: [repositorioProgramacionProvider.overrideWithValue(repo)],
        child: MaterialApp(
          theme: TemaSian.claro(),
          home: const Scaffold(body: SeccionEntregas()),
        ),
      );
    }

    DestinatarioEntrega quien(String nombre, String estado) =>
        DestinatarioEntrega(
          uid: nombre,
          nombre: nombre,
          correo: '\$nombre@umg.edu.gt',
          estado: estado,
        );

    testWidgets('la lista NO se pide hasta que alguien la abre', (
      WidgetTester tester,
    ) async {
      // Son varias lecturas por mensaje. Hacerlas para los diez reportes de
      // la página sería pagar por información que casi nadie mira.
      await tester.pumpWidget(montarConDetalle(<DestinatarioEntrega>[]));
      await tester.pumpAndSettle();

      expect(repo.vecesQuePidioDetalle, 0);
    });

    testWidgets('al abrirla se ve quién confirmó y quién no', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        montarConDetalle(<DestinatarioEntrega>[
          quien('Ana', 'CONFIRMADO'),
          quien('Beto', 'ENTREGADO'),
        ]),
      );
      await tester.pumpAndSettle();

      await tester.ensureVisible(find.text(Textos.verQuienFalta));
      await tester.pumpAndSettle();
      await tester.tap(find.text(Textos.verQuienFalta));
      await tester.pumpAndSettle();

      expect(repo.vecesQuePidioDetalle, 1);
      expect(find.text('Ana'), findsOneWidget);
      expect(find.text('Beto'), findsOneWidget);
      expect(find.text(Textos.estadoSinConfirmar), findsOneWidget);
    });

    testWidgets('un fallo de entrega se distingue de un descuido', (
      WidgetTester tester,
    ) async {
      // Uno se resuelve revisando el dispositivo y el otro insistiendo a la
      // persona. Pintarlos igual mezclaría dos problemas distintos.
      await tester.pumpWidget(
        montarConDetalle(<DestinatarioEntrega>[
          quien('Carla', 'FALLIDO'),
          quien('Dario', 'ENTREGADO'),
        ]),
      );
      await tester.pumpAndSettle();

      await tester.ensureVisible(find.text(Textos.verQuienFalta));
      await tester.pumpAndSettle();
      await tester.tap(find.text(Textos.verQuienFalta));
      await tester.pumpAndSettle();

      expect(find.text(Textos.estadoNoLeLlego), findsOneWidget);
      expect(find.text(Textos.estadoSinConfirmar), findsOneWidget);
    });

    testWidgets('si todos confirmaron, lo dice', (WidgetTester tester) async {
      await tester.pumpWidget(
        montarConDetalle(<DestinatarioEntrega>[
          quien('Ana', 'CONFIRMADO'),
          quien('Beto', 'CONFIRMADO'),
        ]),
      );
      await tester.pumpAndSettle();

      await tester.ensureVisible(find.text(Textos.verQuienFalta));
      await tester.pumpAndSettle();
      await tester.tap(find.text(Textos.verQuienFalta));
      await tester.pumpAndSettle();

      expect(find.text(Textos.nadiePendiente), findsOneWidget);
    });
  });

  group('RF-CNF-06 · reporte de entregas', () {
    Widget montar(List<MensajeProgramado> lista) => ProviderScope(
      overrides: [
        repositorioProgramacionProvider.overrideWithValue(
          RepositorioProgramacionFalso(programados: lista),
        ),
      ],
      child: MaterialApp(
        theme: TemaSian.claro(),
        home: const Scaffold(body: SeccionEntregas()),
      ),
    );

    testWidgets('sin envíos lo explica', (WidgetTester tester) async {
      await tester.pumpWidget(montar(const <MensajeProgramado>[]));
      await tester.pumpAndSettle();

      expect(find.text(Textos.entregasVacia), findsOneWidget);
    });

    testWidgets('enseña entregados, confirmados y porcentaje', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        montar(<MensajeProgramado>[
          programado(total: 10, entregados: 9, confirmados: 4),
        ]),
      );
      await tester.pumpAndSettle();

      expect(find.text(Textos.entregasResumen(9, 10)), findsOneWidget);
      expect(find.text(Textos.entregasConfirmados(4, 10, 40)), findsOneWidget);
    });

    testWidgets('dice cuántos faltan por confirmar', (
      WidgetTester tester,
    ) async {
      // «4 de 10» obliga a restar. Decir cuántos faltan es lo que se necesita
      // para saber a quién perseguir.
      await tester.pumpWidget(
        montar(<MensajeProgramado>[
          programado(total: 10, entregados: 10, confirmados: 4),
        ]),
      );
      await tester.pumpAndSettle();

      expect(
        find.text(Textos.entregasPendientes(6), skipOffstage: false),
        findsOneWidget,
      );
    });

    testWidgets('enseña CUÁNDO se envió, no cuándo saldrá', (
      WidgetTester tester,
    ) async {
      // Es la primera pregunta al abrir este reporte: «¿cuándo se avisó?».
      // Antes se mostraba la próxima ocurrencia, que en un envío inmediato ni
      // siquiera existe: esos aparecían sin fecha ninguna.
      await tester.pumpWidget(
        montar(<MensajeProgramado>[
          programado(
            total: 5,
            entregados: 5,
            enviado: DateTime(2026, 8, 5, 14, 35),
          ),
        ]),
      );
      await tester.pumpAndSettle();

      expect(find.text(Textos.enviadoEl('05/08/2026 · 14:35')), findsOneWidget);
    });

    testWidgets('un recurrente dice ÚLTIMA salida, y también la próxima', (
      WidgetTester tester,
    ) async {
      // «Enviado el…» sería engañoso en algo que sale una y otra vez.
      await tester.pumpWidget(
        montar(<MensajeProgramado>[
          programado(
            modo: 'RECURRENTE',
            total: 5,
            entregados: 5,
            enviado: DateTime(2026, 8, 5, 7),
            proxima: DateTime(2026, 8, 6, 7),
          ),
        ]),
      );
      await tester.pumpAndSettle();

      expect(
        find.text(Textos.ultimaSalidaEl('05/08/2026 · 07:00')),
        findsOneWidget,
      );
      expect(
        find.text(Textos.proximaSalida('06/08/2026 · 07:00')),
        findsOneWidget,
      );
    });

    testWidgets('uno que aún no ha salido lo dice, en vez de callar', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        montar(<MensajeProgramado>[programado(total: 5, entregados: 0)]),
      );
      await tester.pumpAndSettle();

      expect(find.text(Textos.sinFechaDeEnvio), findsOneWidget);
    });

    testWidgets('sin confirmación exigida NO dice que falten confirmaciones', (
      WidgetTester tester,
    ) async {
      // Era el defecto reportado: aparecía «faltan 40 por confirmar» de un
      // aviso que nunca la pidió.
      await tester.pumpWidget(
        montar(<MensajeProgramado>[
          programado(
            total: 40,
            entregados: 40,
            confirmados: 0,
            requiereConfirmacion: false,
          ),
        ]),
      );
      await tester.pumpAndSettle();

      expect(find.text(Textos.entregasPendientes(40)), findsNothing);
      expect(find.text(Textos.entregasSinConfirmacion), findsOneWidget);
    });

    testWidgets('tampoco se inventa un 100 % de confirmación', (
      WidgetTester tester,
    ) async {
      // Sería igual de falso en la otra dirección: afirmaría que cuarenta
      // personas confirmaron algo que nunca se les pidió, en un reporte que
      // existe para sostener esa clase de afirmación.
      await tester.pumpWidget(
        montar(<MensajeProgramado>[
          programado(
            total: 40,
            entregados: 40,
            confirmados: 0,
            requiereConfirmacion: false,
          ),
        ]),
      );
      await tester.pumpAndSettle();

      expect(find.text(Textos.entregasConfirmados(0, 40, 0)), findsNothing);
      expect(find.text(Textos.entregasConfirmados(40, 40, 100)), findsNothing);
      // Lo que sí dice es cuántos lo recibieron.
      expect(find.text(Textos.entregasResumen(40, 40)), findsOneWidget);
    });

    testWidgets('lo no enviado todavía no aparece en el reporte', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        montar(<MensajeProgramado>[programado(total: 0)]),
      );
      await tester.pumpAndSettle();

      expect(find.text(Textos.entregasVacia), findsOneWidget);
    });
  });
}
