/// El resumen de la semana en Entregas — DT-07, mejora M-1.
///
/// Lo que importa aquí es que la suma no mienta: que respete la ventana de siete
/// días, que mida siempre sobre el total de destinatarios, y que la confirmación
/// se calcule solo sobre los avisos que la pedían.
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sian/infrastructure/firebase/repositorio_programacion.dart';
import 'package:sian/presentation/admin/resumen_semanal.dart';
import 'package:sian/presentation/shared/tema.dart';
import 'package:sian/presentation/shared/textos.dart';

final DateTime ahora = DateTime(2026, 9, 11, 10);

MensajeProgramado aviso({
  required int haceDias,
  int total = 10,
  int entregados = 10,
  int confirmados = 0,
  bool pideConfirmacion = false,
  String id = 'm',
}) => MensajeProgramado(
  id: id,
  titulo: 'Aviso',
  tipo: 'INFORMATIVO',
  estado: 'ENVIADO',
  modo: 'INMEDIATO',
  creadoPor: 'coord',
  requiereConfirmacion: pideConfirmacion,
  modoDestinatarios: 'TODOS',
  formato: const <String>['TEXTO'],
  enviadoEn: ahora.subtract(Duration(days: haceDias)),
  totalDestinatarios: total,
  entregados: entregados,
  confirmados: confirmados,
);

void main() {
  group('calcularResumenSemanal · la ventana', () {
    test('suma solo lo enviado en los últimos siete días', () {
      final ResumenSemanal r = calcularResumenSemanal(<MensajeProgramado>[
        aviso(haceDias: 1),
        aviso(haceDias: 6),
        aviso(haceDias: 8), // fuera de la ventana
      ], ahora);

      expect(r.avisos, 2);
      expect(r.destinatarios, 20);
    });

    test('lo programado que todavía no salió no cuenta', () {
      final ResumenSemanal r = calcularResumenSemanal(<MensajeProgramado>[
        MensajeProgramado(
          id: 'futuro',
          titulo: 'Programado',
          tipo: 'INFORMATIVO',
          estado: 'PROGRAMADO',
          modo: 'PROGRAMADO',
          creadoPor: 'coord',
          requiereConfirmacion: false,
          modoDestinatarios: 'TODOS',
          formato: const <String>['TEXTO'],
        ),
        aviso(haceDias: 2),
      ], ahora);

      expect(r.avisos, 1);
    });
  });

  group('calcularResumenSemanal · el denominador', () {
    test('la entrega se mide sobre el total de destinatarios', () {
      final ResumenSemanal r = calcularResumenSemanal(<MensajeProgramado>[
        aviso(haceDias: 1, total: 22, entregados: 15),
      ], ahora);

      expect(r.porcentajeEntrega, 68);
      expect(r.sinEntregar, 7);
    });

    test('la confirmación se mide SOLO sobre los avisos que la pedían', () {
      // Mezclar avisos que no pedían confirmación la hundiría con ceros que
      // nadie tenía obligación de poner.
      final ResumenSemanal r = calcularResumenSemanal(<MensajeProgramado>[
        aviso(haceDias: 1, total: 10, confirmados: 8, pideConfirmacion: true),
        aviso(haceDias: 2, total: 10, confirmados: 0), // no la pedía
      ], ahora);

      expect(r.conConfirmacion, 1);
      expect(r.porcentajeConfirmacion, 80);
    });

    test('un contador desfasado no produce más del cien por ciento', () {
      // Un reintento puede dejar `entregados` por encima del total durante un
      // instante. Un 104 % no se discute: se descree de todo el reporte.
      final ResumenSemanal r = calcularResumenSemanal(<MensajeProgramado>[
        aviso(haceDias: 1, total: 10, entregados: 12),
      ], ahora);

      expect(r.porcentajeEntrega, 100);
      expect(r.sinEntregar, 0);
    });
  });

  group('calcularResumenSemanal · el silencio', () {
    test('sin avisos en la semana, sabe hace cuánto fue el último', () {
      final ResumenSemanal r = calcularResumenSemanal(<MensajeProgramado>[
        aviso(haceDias: 12),
      ], ahora);

      expect(r.hayAvisos, isFalse);
      expect(r.diasDesdeElUltimo, 12);
    });

    test('sin ningún aviso nunca, lo dice en vez de inventar un número', () {
      final ResumenSemanal r = calcularResumenSemanal(<MensajeProgramado>[], ahora);

      expect(r.diasDesdeElUltimo, isNull);
      expect(Textos.resumenSinAvisos(null), contains('ningún aviso'));
    });

    test('el aviso de silencio sugiere mirar Alcance', () {
      // Es cuando más registros caducan sin que nadie se entere: el 7 de
      // septiembre de 2026, tras ocho días sin mandar nada, un aviso no llegó
      // al 23 % (DT-22).
      expect(Textos.resumenSinAvisos(9), contains('Alcance'));
    });
  });

  group('Textos del resumen · concordancia', () {
    test('singular y plural escritos enteros', () {
      expect(Textos.resumenDetalle(1, 0), '1 aviso enviado, y llegó a todos.');
      expect(Textos.resumenDetalle(4, 0), '4 avisos enviados, y llegaron a todos.');
      expect(Textos.resumenDetalle(1, 1), '1 aviso enviado · 1 entrega no llegó.');
      expect(Textos.resumenDetalle(3, 7), '3 avisos enviados · 7 entregas no llegaron.');
    });
  });

  group('TarjetaResumenSemanal', () {
    Widget montar(ResumenSemanal r) => MaterialApp(
      theme: TemaSian.claro(),
      home: Scaffold(body: TarjetaResumenSemanal(resumen: r)),
    );

    testWidgets('con fallos, apunta a Alcance', (WidgetTester tester) async {
      await tester.pumpWidget(
        montar(
          calcularResumenSemanal(<MensajeProgramado>[
            aviso(haceDias: 1, total: 22, entregados: 15),
          ], ahora),
        ),
      );

      expect(find.text(Textos.resumenEntrega(68, 15, 22)), findsOneWidget);
      expect(find.text(Textos.resumenMirarAlcance), findsOneWidget);
    });

    testWidgets('si llegó a todos, no inventa un problema', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        montar(calcularResumenSemanal(<MensajeProgramado>[aviso(haceDias: 1)], ahora)),
      );

      expect(find.text(Textos.resumenMirarAlcance), findsNothing);
    });

    testWidgets('la barra nunca es roja', (WidgetTester tester) async {
      // El rojo está reservado a lo urgente. Si también significara «faltó
      // alguien», dejaría de significar «urgente» donde importa.
      await tester.pumpWidget(
        montar(
          calcularResumenSemanal(<MensajeProgramado>[
            aviso(haceDias: 1, total: 10, entregados: 2),
          ], ahora),
        ),
      );

      final LinearProgressIndicator barra = tester.widget(
        find.byType(LinearProgressIndicator),
      );
      expect(barra.color, isNot(ColoresSian.urgente));
      expect(barra.color, isNot(ColoresSian.rojoInstitucional));
    });
  });
}
