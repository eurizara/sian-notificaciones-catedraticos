// Los fallos del aparato llegan al servidor (DT-34).
//
// El 12/09/2026 el registro de dispositivos se colgó en todos los aparatos y
// nadie lo supo hasta que un aviso no llegó. Aquí se vigila que el aparato
// reporte sin mandar nada personal, sin insistir, y que cada tipo de fallo
// esté de verdad conectado a algún sitio del código.

import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:sian/core/fallos.dart';
import 'package:sian/core/plataforma/almacen_local_vm.dart';
import 'package:sian/core/plataforma/envio_reporte_vm.dart';
import 'package:sian/core/version.dart';

void main() {
  setUp(() {
    ReporteDeFallos.reiniciar();
    reportesDePrueba.clear();
    almacenLocalDePrueba.clear();
  });

  group('limpiarDetalle: nada personal sale del aparato', () {
    test('correos, números largos, claves y direcciones', () {
      expect(
        limpiarDetalle('user-not-found: ana.perez@miumg.edu.gt'),
        'user-not-found: [correo]',
      );
      expect(
        limpiarDetalle('carné 0905-21-12345 tel 5555 1234'),
        'carné [número] tel [número]',
      );
      expect(
        limpiarDetalle('token dKx9_aZ3-QwErTyUiOpAsDfGhJkL1234 inválido'),
        'token [clave] inválido',
      );
      expect(
        limpiarDetalle('fetch https://fcm.googleapis.com/fcm/send/a?auth=x'),
        'fetch https://fcm.googleapis.com/…',
      );
    });

    test(
      'lo corto se queda: una duración o un código no identifican a nadie',
      () {
        expect(
          limpiarDetalle(
            'TimeoutException after 0:00:12 en 1.6.10, código 404',
          ),
          'TimeoutException after 0:00:12 en 1.6.10, código 404',
        );
      },
    );

    test('se recorta a 200', () {
      final String r = limpiarDetalle('palabra ' * 100);
      expect(r.length, lessThanOrEqualTo(200));
      expect(r.endsWith('…'), isTrue);
      expect(limpiarDetalle(null), '');
    });
  });

  test('la dirección del ambiente, o la del emulador', () {
    expect(
      direccionDeReporte(proyecto: 'sian-umg-bdm-dev', usaEmulador: false),
      'https://us-central1-sian-umg-bdm-dev.cloudfunctions.net/reportarFallo',
    );
    expect(
      direccionDeReporte(proyecto: 'sian-umg-bdm-dev', usaEmulador: true),
      'http://localhost:5001/sian-umg-bdm-dev/us-central1/reportarFallo',
    );
  });

  test('sin configurar no se manda nada: no hay a dónde', () {
    ReporteDeFallos.reportar(TipoDeFallo.worker, 'x');
    expect(reportesDePrueba, isEmpty);
  });

  test('manda qué, versión, plataforma y un aparato al azar; nada más', () {
    ReporteDeFallos.configurar(proyecto: 'p', usaEmulador: false);
    ReporteDeFallos.reportar(
      TipoDeFallo.registroDispositivo,
      StateError('falló con ana@umg.edu.gt'),
    );

    expect(reportesDePrueba, hasLength(1));
    final Map<String, dynamic> cuerpo =
        jsonDecode(reportesDePrueba.single.cuerpo) as Map<String, dynamic>;
    expect(cuerpo.keys.toSet(), <String>{
      'que',
      'version',
      'plataforma',
      'aparato',
      'detalle',
    });
    expect(cuerpo['que'], 'registro-dispositivo');
    expect(cuerpo['version'], versionSian);
    expect(cuerpo['plataforma'], 'WEB_ESCRITORIO');
    expect(cuerpo['aparato'], matches(RegExp(r'^[A-Za-z0-9_-]{16,64}$')));
    expect(cuerpo['detalle'], 'Bad state: falló con [correo]');
  });

  test('el aparato es siempre el mismo en este navegador', () {
    ReporteDeFallos.configurar(proyecto: 'p', usaEmulador: false);
    ReporteDeFallos.reportar(TipoDeFallo.worker);
    ReporteDeFallos.reiniciar(conservarConfiguracion: true);
    ReporteDeFallos.reportar(TipoDeFallo.worker);
    final List<String> aparatos = <String>[
      for (final ReporteEnviado r in reportesDePrueba)
        (jsonDecode(r.cuerpo) as Map<String, dynamic>)['aparato'] as String,
    ];
    expect(aparatos, hasLength(2));
    expect(aparatos.toSet(), hasLength(1));
  });

  test('no insiste: el mismo tipo una vez cada 10 minutos; otro tipo sí', () {
    ReporteDeFallos.configurar(proyecto: 'p', usaEmulador: false);
    final DateTime t0 = DateTime(2026, 9, 26, 10);
    ReporteDeFallos.reportar(TipoDeFallo.worker, null, t0);
    ReporteDeFallos.reportar(
      TipoDeFallo.worker,
      null,
      t0.add(const Duration(minutes: 9)),
    );
    ReporteDeFallos.reportar(
      TipoDeFallo.notificacion,
      null,
      t0.add(const Duration(minutes: 9)),
    );
    ReporteDeFallos.reportar(
      TipoDeFallo.worker,
      null,
      t0.add(const Duration(minutes: 10)),
    );
    expect(
      reportesDePrueba
          .map(
            (ReporteEnviado r) =>
                (jsonDecode(r.cuerpo) as Map<String, dynamic>)['que'],
          )
          .toList(),
      <String>['worker', 'notificacion', 'worker'],
    );
  });

  test('los tipos son los mismos que acepta el servidor', () {
    final String dominio = File(
      '../functions/src/domain/fallo.ts',
    ).readAsStringSync();
    final String lista = RegExp(
      r'TIPOS_DE_FALLO = \[([\s\S]*?)\] as const',
    ).firstMatch(dominio)![1]!;
    final Set<String> delServidor = RegExp(
      r"^\s*'([a-z-]+)',",
      multiLine: true,
    ).allMatches(lista).map((RegExpMatch m) => m[1]!).toSet();
    expect(
      TipoDeFallo.values.map((TipoDeFallo t) => t.clave).toSet(),
      delServidor,
    );
  });

  test('cada tipo se reporta desde algún sitio del código', () {
    final String codigo = Directory('lib')
        .listSync(recursive: true)
        .whereType<File>()
        .where(
          (File f) =>
              f.path.endsWith('.dart') && !f.path.endsWith('core/fallos.dart'),
        )
        .map((File f) => f.readAsStringSync())
        .join('\n');
    for (final TipoDeFallo t in TipoDeFallo.values) {
      expect(
        codigo.contains('TipoDeFallo.${t.name}'),
        isTrue,
        reason: '${t.clave} no se reporta desde ningún sitio',
      );
    }
  });
}
