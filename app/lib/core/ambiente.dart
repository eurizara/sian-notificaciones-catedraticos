/// SIAN — En qué ambiente se está ejecutando la aplicación (DT-20).
///
/// ────────────────────────────────────────────────────────────────────────────
/// En el navegador el ambiente se lee en la barra de direcciones. Instalada
/// como aplicación, esa barra no existe.
/// ────────────────────────────────────────────────────────────────────────────
///
/// Quien administra tiene los tres instalados para poder probar, y desde dentro
/// se ven exactamente iguales: mismo escudo, mismo azul, misma pantalla de
/// ingreso. El riesgo no es incomodidad, es abrir la de producción creyendo que
/// es la de pruebas y redactar un aviso para veintidós catedráticos reales.
///
/// El riesgo es asimétrico: un mensaje de prueba en calidad no le pasa a nadie;
/// uno de prueba en producción lo reciben veintidós personas en el teléfono.
library;

/// Los tres ambientes, más el caso de no saberlo.
enum Ambiente {
  desarrollo,
  calidad,
  produccion,

  /// Ni el identificador conocido ni vacío. Se trata como «no es producción»:
  /// ante la duda conviene avisar de más, no de menos.
  desconocido,
}

/// Identificadores reales de los tres proyectos de Firebase.
///
/// ────────────────────────────────────────────────────────────────────────────
/// PRODUCCIÓN NO LLEVA SUFIJO. Es la trampa de este archivo.
/// ────────────────────────────────────────────────────────────────────────────
///
/// Los tres no siguen el mismo patrón porque producción se creó antes que los
/// otros dos. Comprobar «termina en `-prd`» no encuentra nada y deja producción
/// sin identificar, que es justamente el ambiente donde equivocarse cuesta.
///
/// Por eso se comparan los tres nombres completos, en una tabla explícita, en
/// lugar de deducir el ambiente de un sufijo.
const String proyectoDesarrollo = 'sian-umg-bdm-dev';
const String proyectoCalidad = 'sian-umg-bdm-qa';
const String proyectoProduccion = 'sian-umg-bdm';

/// Traduce el identificador del proyecto de Firebase al ambiente.
///
/// Se recorta y se pasa a minúsculas porque el valor llega de un archivo
/// generado y no cuesta nada tolerar un espacio de más.
Ambiente ambienteDe(String? proyectoId) {
  switch ((proyectoId ?? '').trim().toLowerCase()) {
    case proyectoDesarrollo:
      return Ambiente.desarrollo;
    case proyectoCalidad:
      return Ambiente.calidad;
    case proyectoProduccion:
      return Ambiente.produccion;
    default:
      return Ambiente.desconocido;
  }
}

/// ¿Hay que avisar en pantalla de en qué ambiente se está?
///
/// ────────────────────────────────────────────────────────────────────────────
/// Producción NO lleva distintivo, y es una decisión, no un olvido.
/// ────────────────────────────────────────────────────────────────────────────
///
/// Es el estado normal y el que ven los catedráticos; llenarles la pantalla de
/// etiquetas técnicas no les aporta nada y les quita sitio. Los que deben gritar
/// son desarrollo y calidad, que es donde estar equivocado no cuesta nada y
/// creerse en otro sitio sí.
bool ambienteNecesitaAviso(Ambiente ambiente) => ambiente != Ambiente.produccion;
