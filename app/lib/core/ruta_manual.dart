/// SIAN — Qué manual abre cada persona (DT-28, mejora M-3).
///
/// Hay dos: el general, que explica el panel, y el del catedrático, que explica
/// la bandeja. Mandar a un catedrático al índice general lo obliga a buscar su
/// parte entre secciones que no le tocan; es la clase de fricción que hace que
/// la ayuda exista y no se use.
library;

import '../domain/rol.dart';

/// La ruta del manual que le corresponde a [rol].
///
/// ────────────────────────────────────────────────────────────────────────────
/// Es RELATIVA a propósito, sin dominio delante.
/// ────────────────────────────────────────────────────────────────────────────
///
/// El navegador la resuelve contra el origen desde el que se pulsa, así que
/// desde desarrollo abre el manual de desarrollo y desde producción el de
/// producción. Ya se cometió el error contrario: la dirección de desarrollo
/// quedó escrita en dieciocho sitios de los manuales y habría mandado a los
/// catedráticos al ambiente equivocado.
String rutaDelManual(Rol rol) => rol == Rol.catedratico
    ? '/manuales/catedratico/'
    : '/manuales/';
