/// Sedes en la sesión (2.0, ADR-009): lo que la aplicación lee del token.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:sian/domain/rol.dart';
import 'package:sian/domain/sesion.dart';
import 'package:sian/infrastructure/firebase/repositorio_sesion.dart';

void main() {
  UsuarioSesion usuario(Map<String, Rol> sedes) => UsuarioSesion(
    uid: 'u',
    correo: 'a@umg.edu.gt',
    nombre: 'A',
    rol: Rol.coordinador,
    activo: true,
    sedes: sedes,
  );

  test('un token sin sedes es de la sede inicial', () {
    expect(sedesDelToken(null), isEmpty);
    expect(usuario(<String, Rol>{}).sedePrincipal, sedeInicial);
  });

  test('las sedes del token, descartando lo que no tiene forma', () {
    expect(
      sedesDelToken(<String, Object?>{
        'bdm': 'COORDINADOR',
        'otra': 'CATEDRATICO',
        'Mal Id': 'COORDINADOR',
        'tercera': 'REY',
      }),
      <String, Rol>{'bdm': Rol.coordinador, 'otra': Rol.catedratico},
    );
  });

  test('la sede principal es la inicial si pertenece; si no, la primera', () {
    expect(
      usuario(<String, Rol>{
        'zeta': Rol.catedratico,
        'bdm': Rol.coordinador,
      }).sedePrincipal,
      'bdm',
    );
    expect(
      usuario(<String, Rol>{
        'zeta': Rol.catedratico,
        'alfa': Rol.coordinador,
      }).sedePrincipal,
      'alfa',
    );
  });
}
