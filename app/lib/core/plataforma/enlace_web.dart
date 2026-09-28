/// Abre un enlace tocado en un aviso o una respuesta (U-2).
///
/// **Solo `http`, `https`, `mailto` y `tel`.** El texto lo escribió una persona
/// y viaja a muchas: un `javascript:` o un `data:` convertidos en enlace serían
/// una puerta para ejecutar algo en el aparato de otro. El detector ya no los
/// produce; esta es la segunda cerradura.
///
///   · La web se abre **en otra pestaña y sin darle acceso a SIAN**
///     (`noopener,noreferrer`): la página destino no puede tocar esta.
///   · El correo y el teléfono se entregan al sistema, que abre la aplicación
///     de correo o el marcador. En un iPhone instalado, abrirlos «en otra
///     pestaña» no hace nada; asignarlos a la ubicación, sí.
library;

import 'package:web/web.dart' as web;

void abrirEnlace(Uri destino) {
  switch (destino.scheme) {
    case 'http':
    case 'https':
      web.window.open(destino.toString(), '_blank', 'noopener,noreferrer');
    case 'mailto':
    case 'tel':
      web.window.location.assign(destino.toString());
    default:
      // Cualquier otro esquema no se abre.
      break;
  }
}
