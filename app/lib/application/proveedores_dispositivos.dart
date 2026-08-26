/// SIAN — Proveedor del repositorio de dispositivos.
///
/// Vive en la capa de aplicación y no junto a la tarjeta que lo estrenó,
/// porque ya no lo consulta solo la bandeja: la pantalla de ingreso necesita
/// saber si estamos en un iPhone sin instalar **antes** de que nadie entre, y
/// una pantalla compartida no debería tener que importar algo de `docente/`
/// para averiguarlo.
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../infrastructure/firebase/repositorio_dispositivos.dart';

final Provider<RepositorioDispositivos> repositorioDispositivosProvider =
    Provider<RepositorioDispositivos>((Ref ref) => RepositorioDispositivos());
