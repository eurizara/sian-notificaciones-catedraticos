/// SIAN — «Tu teléfono recibió el aviso y no te lo mostró» (DT-31, C-5).
///
/// ────────────────────────────────────────────────────────────────────────────
/// El fallo que nadie podía ver, dicho en la pantalla de quien lo sufre.
/// ────────────────────────────────────────────────────────────────────────────
///
/// El 11 de septiembre de 2026 varias personas con el aviso «entregado» no
/// vieron ninguna notificación y se enteraron por WhatsApp. Desde C-5 el
/// service worker avisa cuando muestra una, así que la aplicación sabe cuándo
/// eso no ocurrió — y puede decirlo en vez de dejar a cada quien pensando que
/// el sistema no le manda nada.
///
/// Aparece solo cuando hay algo que decir y en los últimos días: una tarjeta
/// permanente sobre algo resuelto es exactamente lo que se quitó de la tarjeta
/// de notificaciones cuando estorbaba.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../application/proveedores_dispositivos.dart';
import '../../core/plataforma/almacen_local.dart';
import '../../domain/repositorios.dart';
import '../shared/tema.dart';
import '../shared/textos.dart';

/// Cuántos días atrás se mira. Más allá, lo que pasó ya no dice nada del
/// estado de hoy: pudo arreglarse solo al cambiar un ajuste.
const int diasQueSeMiranSinMostrar = 7;

/// Los avisos que llegaron a este aparato y no se mostraron.
///
/// Fuera del widget para poder probar la regla sin montar pantalla: es la
/// decisión de cuándo se molesta a alguien, y conviene que sea exacta.
List<MensajeRecibido> avisosQueNoSeMostraron(
  List<MensajeRecibido> mensajes,
  DateTime ahora, {
  DateTime? ultimaVezQueMostro,
}) {
  final DateTime desde = ahora.subtract(
    const Duration(days: diasQueSeMiranSinMostrar),
  );
  // Desde que el aparato demostró que sí enseña notificaciones, lo de antes
  // dejó de describir su estado: pudo ser un ajuste que ya se cambió, o una
  // versión que ya se actualizó. Insistir con eso una semana entera es lo que
  // convierte un aviso útil en uno que se ignora.
  final DateTime corte =
      ultimaVezQueMostro != null && ultimaVezQueMostro.isAfter(desde)
      ? ultimaVezQueMostro
      : desde;
  return mensajes
      .where(
        (MensajeRecibido m) =>
            m.llegoYNoSeMostro && m.entregadoEn!.isAfter(corte),
      )
      .toList();
}

/// Cuándo este aparato mostró una notificación por última vez, según él mismo.
///
/// Lo escribe el service worker por mensaje a la ventana, y se guarda en este
/// navegador: es del aparato, no de la cuenta.
const String claveUltimaMostrada = 'sian.ultimaMostrada';

DateTime? ultimaVezQueEsteAparatoMostro() =>
    DateTime.tryParse(leerLocal(claveUltimaMostrada) ?? '');

void anotarQueEsteAparatoMostro(DateTime cuando) {
  guardarLocal(claveUltimaMostrada, cuando.toIso8601String());
}

class AvisoNoMostrado extends ConsumerStatefulWidget {
  const AvisoNoMostrado({required this.cuantos, super.key});

  final int cuantos;

  @override
  ConsumerState<AvisoNoMostrado> createState() => _AvisoNoMostradoState();
}

class _AvisoNoMostradoState extends ConsumerState<AvisoNoMostrado> {
  bool _probando = false;

  Future<void> _probar() async {
    setState(() => _probando = true);
    try {
      // El mismo camino que el registro: el servidor manda una notificación de
      // prueba de verdad. Si esa tampoco aparece, el problema está en los
      // ajustes del teléfono y no en el canal.
      await ref
          .read(repositorioDispositivosProvider)
          .pedirPermisoYRegistrar(enviarPrueba: true);
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text(Textos.pruebaEnviada)));
      }
    } on Object {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text(Textos.errorInesperado)));
      }
    } finally {
      if (mounted) {
        setState(() => _probando = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData tema = Theme.of(context);
    final PaletaSian paleta = PaletaSian.de(context);

    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      color: paleta.doradoTexto.withValues(alpha: 0.08),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Icon(
                  Icons.notifications_off_outlined,
                  color: paleta.doradoTexto,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    Textos.avisosQueNoSeMostraron(widget.cuantos),
                    style: tema.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            const Text(Textos.porQueNoSeMostro),
            const SizedBox(height: 12),
            Align(
              alignment: Alignment.centerLeft,
              child: FilledButton.icon(
                onPressed: _probando ? null : _probar,
                icon: _probando
                    ? const SizedBox(
                        height: 16,
                        width: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.notifications_active_outlined),
                label: Text(
                  _probando
                      ? Textos.probandoNotificacion
                      : Textos.botonProbarNotificacion,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
