/// SIAN — El número pegado al icono de la aplicación instalada (RF-ENT-13).
///
/// ────────────────────────────────────────────────────────────────────────────
/// La insignia vale exactamente lo mismo que el filtro «Sin leer».
/// ────────────────────────────────────────────────────────────────────────────
///
/// Se podría haber contado también lo que está sin confirmar, que en rigor
/// también espera algo de la persona. No se hace, y el motivo es que el número
/// del icono y el número del filtro se ven juntos: la persona abre la
/// aplicación porque el icono decía «3», y lo primero que encuentra es la
/// bandeja con su fila de filtros. Si ahí dijera «Sin leer 2», el número de
/// afuera queda desmentido por el de adentro, y a partir de ese momento ninguno
/// de los dos se cree.
///
/// Un aviso que no se cree deja de servir. Así que la insignia repite un dato
/// que la bandeja ya muestra, en lugar de inventar uno propio.
library;

import '../../core/plataforma/insignia.dart';
import '../../domain/repositorios.dart';
import 'filtro_bandeja.dart';

/// Último número que se mandó, para no repetir trabajo en cada dibujado.
///
/// La sincronización se dispara desde `build`, que corre muchas más veces de
/// las que el número cambia. Sin esta memoria, cada redibujado —desplegar un
/// mensaje, escribir en el buscador, girar el teléfono— mandaría otra vez el
/// mismo dato al navegador y al service worker.
int? _ultimoEnviado;

/// Olvida lo último enviado. Solo para las pruebas, que comparten proceso.
void olvidarUltimaInsignia() => _ultimoEnviado = null;

/// Deja la insignia igual al número de mensajes sin leer.
///
/// Con cero, la retira: un icono con un «0» pegado se lee como si algo
/// estuviera pendiente.
///
/// Es idempotente y se puede llamar en cada dibujado. Se hace así, y no
/// escuchando solo los cambios del historial, porque un escuchador únicamente
/// se entera de lo que cambia **mientras está escuchando**: si la bandeja se
/// vuelve a montar con los datos ya resueltos —volver de otra pantalla, girar
/// el aparato— no llega ningún cambio y la insignia se queda como estaba.
void sincronizarInsignia(List<MensajeRecibido> mensajes) {
  final int sinLeer = contarEn(FiltroBandeja.sinLeer, mensajes);
  if (sinLeer == _ultimoEnviado) {
    return;
  }
  _ultimoEnviado = sinLeer;

  if (sinLeer > 0) {
    fijarInsignia(sinLeer);
  } else {
    retirarInsignia();
  }
}
