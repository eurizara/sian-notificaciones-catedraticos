/// Las pantallas del panel que mezclaban sedes (2.0.9).
///
/// Revisión a fondo pedida por el responsable el 14/11/2026: la bitácora, las
/// invitaciones y las respuestas mostraban lo de todas las sedes a quien
/// coordina en una. Ahora, como Usuarios y Grupos, lo de la sede de trabajo.
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sian/application/proveedores_respuestas.dart';
import 'package:sian/application/proveedores_sede.dart';
import 'package:sian/application/proveedores_sesion.dart';
import 'package:sian/domain/rol.dart';
import 'package:sian/domain/sesion.dart';
import 'package:sian/infrastructure/firebase/repositorio_administracion.dart';
import 'package:sian/infrastructure/firebase/repositorio_respuestas.dart';
import 'package:sian/presentation/admin/seccion_bitacora.dart';
import 'package:sian/presentation/admin/seccion_usuarios.dart';

import '../dobles/repositorios_falsos.dart';

ProviderContainer _contenedor() {
  final ProviderContainer c = ProviderContainer(
    overrides: [
      sesionActualProvider.overrideWithValue(
        const SesionActiva(
          UsuarioSesion(
            uid: 'yo',
            correo: 'yo@umg.edu.gt',
            nombre: 'Yo',
            rol: Rol.coordinador,
            activo: true,
            sedes: <String, Rol>{
              'bdm': Rol.coordinador,
              'villa-nueva': Rol.coordinador,
            },
          ),
        ),
      ),
      repositorioAdminProvider.overrideWithValue(
        RepositorioAdminFalso(
          invitaciones: const <InvitacionVista>[
            InvitacionVista(
              correo: 'vieja@umg.edu.gt',
              rolAsignado: 'CATEDRATICO',
              nombre: 'De antes',
              consumida: false,
            ),
            InvitacionVista(
              correo: 'vn@umg.edu.gt',
              rolAsignado: 'CATEDRATICO',
              nombre: 'De Villa Nueva',
              consumida: false,
              sedeId: 'villa-nueva',
            ),
          ],
          asientos: const <AsientoVista>[
            AsientoVista(
              tipo: 'GRUPO_CREADO',
              actorCorreo: 'a',
              actorRol: 'COORDINADOR',
              entidad: 'GRUPO',
              entidadId: 'g1',
              resumen: 'En Boca del Monte',
            ),
            AsientoVista(
              tipo: 'GRUPO_CREADO',
              actorCorreo: 'a',
              actorRol: 'COORDINADOR',
              entidad: 'GRUPO',
              entidadId: 'g2',
              resumen: 'En Villa Nueva',
              sedeId: 'villa-nueva',
            ),
          ],
        ),
      ),
      repositorioRespuestasProvider.overrideWithValue(
        RepositorioRespuestasFalso(
          hilosDelEmisor: const <Hilo>[
            Hilo(
              mensajeId: 'm-bdm',
              uid: 'ana',
              nombre: 'Ana',
              emisorUid: 'yo',
              tituloAviso: 'Aviso de Boca del Monte',
            ),
            Hilo(
              mensajeId: 'm-vn',
              uid: 'maria',
              nombre: 'María',
              emisorUid: 'yo',
              tituloAviso: 'Aviso de Villa Nueva',
              sedeId: 'villa-nueva',
            ),
          ],
        ),
      ),
    ],
  );
  addTearDown(c.dispose);
  // La sede elegida se recuerda entre pruebas (como en el navegador): cada
  // prueba empieza en Boca del Monte.
  c.read(sedeDeTrabajoProvider.notifier).elegir('bdm');
  return c;
}

Future<List<String>> _leer<T>(
  ProviderContainer c,
  StreamProvider<List<T>> p,
  String Function(T) dato,
) async {
  c.listen(p, (_, _) {});
  return (await c.read(p.future)).map(dato).toList();
}

void main() {
  test('invitaciones: solo las de la sede de trabajo', () async {
    final ProviderContainer c = _contenedor();
    expect(
      await _leer(c, invitacionesProvider, (InvitacionVista i) => i.nombre),
      <String>['De antes'],
    );
    c.read(sedeDeTrabajoProvider.notifier).elegir('villa-nueva');
    expect(
      await _leer(c, invitacionesProvider, (InvitacionVista i) => i.nombre),
      <String>['De Villa Nueva'],
    );
  });

  test('bitácora: solo los asientos de la sede de trabajo', () async {
    final ProviderContainer c = _contenedor();
    expect(
      await _leer(c, bitacoraProvider, (AsientoVista a) => a.resumen),
      <String>['En Boca del Monte'],
    );
    c.read(sedeDeTrabajoProvider.notifier).elegir('villa-nueva');
    expect(
      await _leer(c, bitacoraProvider, (AsientoVista a) => a.resumen),
      <String>['En Villa Nueva'],
    );
  });

  test('respuestas: solo las de los avisos de la sede de trabajo', () async {
    final ProviderContainer c = _contenedor();
    expect(
      await _leer(
        c,
        avisosConRespuestasProvider,
        (AvisoConRespuestas a) => a.tituloAviso,
      ),
      <String>['Aviso de Boca del Monte'],
    );
    c.read(sedeDeTrabajoProvider.notifier).elegir('villa-nueva');
    expect(
      await _leer(
        c,
        avisosConRespuestasProvider,
        (AvisoConRespuestas a) => a.tituloAviso,
      ),
      <String>['Aviso de Villa Nueva'],
    );
  });
}
