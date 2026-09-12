/// SIAN — Responder desde dentro del aviso (DT-27, mejora M-5).
///
/// ────────────────────────────────────────────────────────────────────────────
/// Dentro del mensaje, no en una pestaña aparte.
/// ────────────────────────────────────────────────────────────────────────────
///
/// Lo que da sentido a «no puedo asistir» es el aviso que lo provocó. Sacar la
/// respuesta a una bandeja propia obligaría a reconstruir ese vínculo leyendo,
/// y el catedrático nunca tiene más de una conversación por aviso, siempre con
/// quien se lo mandó: no hay nada que ordenar en otra pantalla.
///
/// Plegada por omisión: un botón «Responder». La mayoría de los avisos no se
/// contestan, y un cuadro de texto abierto en cada uno empujaría hacia abajo
/// lo que la persona vino a leer.
library;

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../application/proveedores_respuestas.dart';
import '../../application/proveedores_sesion.dart';
import '../../core/plataforma/notificacion_sistema.dart';
import '../../domain/repositorios.dart';
import '../../domain/sesion.dart';
import '../../infrastructure/firebase/repositorio_respuestas.dart';
import '../shared/conversacion.dart';
import '../shared/textos.dart';

class RespuestaAlAviso extends ConsumerStatefulWidget {
  const RespuestaAlAviso({required this.mensaje, super.key});

  final MensajeRecibido mensaje;

  @override
  ConsumerState<RespuestaAlAviso> createState() => _RespuestaAlAvisoState();
}

class _RespuestaAlAvisoState extends ConsumerState<RespuestaAlAviso> {
  bool _redactando = false;
  Stream<Hilo?>? _hilo;
  String? _uid;

  /// Lo último que se marcó como leído, para no repetir la llamada en cada
  /// redibujado mientras llega la confirmación.
  int _marcadoHasta = 0;

  void _marcarLeido(Hilo hilo) {
    if (hilo.sinLeerCatedratico == 0 ||
        hilo.sinLeerCatedratico == _marcadoHasta) {
      return;
    }
    _marcadoHasta = hilo.sinLeerCatedratico;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      unawaited(
        ref
            .read(repositorioRespuestasProvider)
            .marcarLeido(mensajeId: widget.mensaje.mensajeId)
            .catchError((Object _) {
              // Que no se pueda marcar no puede impedir leer la respuesta.
            }),
      );
      // La notificación de esa respuesta ya no dice nada nuevo, y en Android
      // una olvidada deja el icono marcado (DT-26).
      unawaited(
        cerrarNotificacionesDelSistema('respuesta-${widget.mensaje.mensajeId}'),
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final Sesion sesion = ref.watch(sesionActualProvider);
    if (sesion is! SesionActiva) {
      return const SizedBox.shrink();
    }
    final String uid = sesion.usuario.uid;

    // Un aviso propio no se responde: sería hablar solo.
    if (widget.mensaje.creadoPor.isNotEmpty &&
        widget.mensaje.creadoPor == uid) {
      return const SizedBox.shrink();
    }

    if (_uid != uid) {
      _uid = uid;
      _hilo = ref
          .read(repositorioRespuestasProvider)
          .observarHilo(widget.mensaje.mensajeId, uid);
    }

    return StreamBuilder<Hilo?>(
      stream: _hilo,
      builder: (BuildContext context, AsyncSnapshot<Hilo?> s) {
        final Hilo? hilo = s.data;
        if (hilo != null) {
          _marcarLeido(hilo);
        }

        if (hilo == null && !_redactando) {
          return Align(
            alignment: Alignment.centerLeft,
            child: OutlinedButton.icon(
              onPressed: () => setState(() => _redactando = true),
              icon: const Icon(Icons.reply_outlined),
              label: Text(Textos.botonResponderA(widget.mensaje.emisor)),
            ),
          );
        }

        return Conversacion(
          mensajeId: widget.mensaje.mensajeId,
          hiloUid: uid,
          miLado: LadoHilo.catedratico,
          nombreDelOtro: widget.mensaje.emisor,
        );
      },
    );
  }
}
