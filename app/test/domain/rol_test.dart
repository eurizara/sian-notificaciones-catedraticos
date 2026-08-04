/// Pruebas de los predicados de rol — documento 01, sección 2.2.
///
/// Se recorre la matriz RBAC entera. Si alguien mueve un permiso, esta prueba
/// falla y obliga a actualizar también el documento.
///
/// Recordatorio incómodo pero necesario: estos predicados deciden **qué se ve**,
/// no **qué se puede hacer**. La autorización real vive en los custom claims,
/// las reglas de Firestore y las Cloud Functions (RN-01).
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:sian/domain/rol.dart';

void main() {
  group('traducción del claim', () {
    test('reconoce los cuatro roles del documento 01', () {
      expect(Rol.desdeClaim('COORDINADOR'), Rol.coordinador);
      expect(Rol.desdeClaim('ADMINISTRADORA'), Rol.administradora);
      expect(Rol.desdeClaim('CATEDRATICO'), Rol.catedratico);
      expect(Rol.desdeClaim('AUDITOR'), Rol.auditor);
    });

    test('no inventa un rol por omisión ante un valor desconocido', () {
      // Devolver un rol aquí sería concederle acceso a alguien cuyo token no
      // dice nada. Ante la duda, nada.
      expect(Rol.desdeClaim(null), isNull);
      expect(Rol.desdeClaim(''), isNull);
      expect(Rol.desdeClaim('coordinador'), isNull); // distingue mayúsculas
      expect(Rol.desdeClaim('SUPERUSUARIO'), isNull);
      expect(Rol.desdeClaim(42), isNull);
      expect(Rol.desdeClaim(<String>['COORDINADOR']), isNull);
    });
  });

  group('matriz RBAC del documento 01, sección 2.2', () {
    test('quién usa el panel administrativo', () {
      expect(Rol.coordinador.usaPanelAdministrativo, isTrue);
      expect(Rol.administradora.usaPanelAdministrativo, isTrue);
      expect(Rol.auditor.usaPanelAdministrativo, isTrue);
      // El catedrático es receptor: su lugar es la PWA, no el panel.
      expect(Rol.catedratico.usaPanelAdministrativo, isFalse);
    });

    test('quién puede emitir mensajes', () {
      expect(Rol.coordinador.esEmisor, isTrue);
      expect(Rol.administradora.esEmisor, isTrue);
      expect(Rol.catedratico.esEmisor, isFalse);
      // El auditor es de solo lectura, sin poder emitir nada.
      expect(Rol.auditor.esEmisor, isFalse);
    });

    test('quién ve la bitácora completa (RF-BIT-04)', () {
      expect(Rol.coordinador.veBitacoraCompleta, isTrue);
      expect(Rol.auditor.veBitacoraCompleta, isTrue);
      expect(Rol.administradora.veBitacoraCompleta, isFalse);
      expect(Rol.catedratico.veBitacoraCompleta, isFalse);
    });

    test('quién recibe mensajes', () {
      expect(Rol.catedratico.recibeMensajes, isTrue);
      expect(Rol.coordinador.recibeMensajes, isTrue);
      expect(Rol.administradora.recibeMensajes, isTrue);
      // El auditor no entra en el reparto.
      expect(Rol.auditor.recibeMensajes, isFalse);
    });
  });

  test('el claim de cada rol coincide con el documento 05, sección 2.1', () {
    expect(Rol.values.map((Rol r) => r.claim).toList(), <String>[
      'COORDINADOR',
      'ADMINISTRADORA',
      'CATEDRATICO',
      'AUDITOR',
    ]);
  });
}
