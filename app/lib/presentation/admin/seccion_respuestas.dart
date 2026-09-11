/// SIAN — Respuestas a los avisos propios (DT-27, mejora M-5).
///
/// ────────────────────────────────────────────────────────────────────────────
/// Agrupadas, pero ancladas al aviso.
/// ────────────────────────────────────────────────────────────────────────────
///
/// Un aviso a veintidós personas puede volver con veintidós respuestas: el
/// emisor necesita verlas juntas. Pero una bandeja suelta de mensajes perdería
/// de qué habla cada uno. Por eso la lista es de **avisos**, y dentro de cada
/// uno, sus conversaciones. Lo que tiene algo sin leer va primero.
///
/// Esto no es una mensajería: el emisor no puede iniciar conversaciones, solo
/// contestar a quien le escribió. Lo decide el servidor, no esta pantalla.
library;

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../application/proveedores_respuestas.dart';
import '../../application/proveedores_sesion.dart';
import '../../core/plataforma/notificacion_sistema.dart';
import '../../domain/sesion.dart';
import '../../infrastructure/firebase/repositorio_respuestas.dart';
import '../docente/tarjeta_notificaciones.dart';
import '../shared/conversacion.dart';
import '../shared/tema.dart';
import '../shared/textos.dart';

class SeccionRespuestas extends ConsumerWidget {
  const SeccionRespuestas({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final Sesion sesion = ref.watch(sesionActualProvider);
    final AsyncValue<List<AvisoConRespuestas>> avisos = ref.watch(
      avisosConRespuestasProvider,
    );
    final ThemeData tema = Theme.of(context);

    // Quien además recibe avisos ya tiene la tarjeta en «Mis mensajes» y el
    // dispositivo registrado. Quien no, necesita un sitio donde activarlas, y
    // es este: aquí es donde se echa de menos enterarse.
    final bool necesitaTarjeta =
        sesion is SesionActiva && !sesion.usuario.recibeAvisos;

    return ListView(
      padding: const EdgeInsets.all(16),
      children: <Widget>[
        Text(Textos.seccionRespuestasTitulo, style: tema.textTheme.titleLarge),
        const SizedBox(height: 4),
        Text(
          Textos.seccionRespuestasDescripcion,
          style: tema.textTheme.bodyMedium?.copyWith(
            color: tema.colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 16),
        if (necesitaTarjeta) ...<Widget>[
          const TarjetaNotificaciones(
            detallePendiente: Textos.respuestasNotifPendienteDetalle,
            detalleActivo: Textos.respuestasNotifActivasDetalle,
          ),
          const SizedBox(height: 8),
        ],
        ...avisos.when(
          data: (List<AvisoConRespuestas> lista) => lista.isEmpty
              ? <Widget>[const _Vacio()]
              : <Widget>[
                  for (final AvisoConRespuestas a in lista)
                    TarjetaAvisoConRespuestas(aviso: a),
                ],
          loading: () => <Widget>[
            const Padding(
              padding: EdgeInsets.all(32),
              child: Center(child: CircularProgressIndicator()),
            ),
          ],
          error: (Object _, StackTrace _) => <Widget>[
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 24),
              child: Text(Textos.respuestasFallo),
            ),
          ],
        ),
      ],
    );
  }
}

class _Vacio extends StatelessWidget {
  const _Vacio();

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 32),
    child: Row(
      children: <Widget>[
        Icon(
          Icons.forum_outlined,
          color: Theme.of(context).colorScheme.onSurfaceVariant,
        ),
        const SizedBox(width: 12),
        const Expanded(child: Text(Textos.respuestasVacio)),
      ],
    ),
  );
}

/// Un aviso con sus conversaciones.
class TarjetaAvisoConRespuestas extends StatelessWidget {
  const TarjetaAvisoConRespuestas({required this.aviso, super.key});

  final AvisoConRespuestas aviso;

  @override
  Widget build(BuildContext context) {
    final ThemeData tema = Theme.of(context);
    final int sinLeer = aviso.sinLeer;
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 6),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Text(
              aviso.tituloAviso,
              style: tema.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              sinLeer > 0
                  ? '${Textos.conversaciones(aviso.hilos.length)} · '
                        '${Textos.sinLeer(sinLeer)}'
                  : Textos.conversaciones(aviso.hilos.length),
              style: tema.textTheme.bodySmall?.copyWith(
                color: sinLeer > 0
                    ? PaletaSian.de(context).primarioTexto
                    : tema.colorScheme.onSurfaceVariant,
                fontWeight: sinLeer > 0 ? FontWeight.w600 : null,
              ),
            ),
            const SizedBox(height: 4),
            for (final Hilo h in aviso.hilos) FilaDeHilo(hilo: h),
          ],
        ),
      ),
    );
  }
}

/// Una conversación, en una línea: quién, lo último que se dijo, y si hay
/// algo sin leer.
class FilaDeHilo extends StatelessWidget {
  const FilaDeHilo({required this.hilo, super.key});

  final Hilo hilo;

  @override
  Widget build(BuildContext context) {
    final ThemeData tema = Theme.of(context);
    final bool porLeer = hilo.sinLeerEmisor > 0;
    final String prefijo = hilo.ultimoLado == LadoHilo.emisor
        ? '${Textos.tu}: '
        : '';
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: CircleAvatar(
        backgroundColor: PaletaSian.de(context).fondoPrimario,
        foregroundColor: PaletaSian.sobreFondo,
        child: Text(hilo.nombre.isEmpty ? '?' : hilo.nombre[0].toUpperCase()),
      ),
      title: Text(
        hilo.nombre,
        style: porLeer ? const TextStyle(fontWeight: FontWeight.bold) : null,
      ),
      subtitle: Text(
        '$prefijo${hilo.ultimaVista}',
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
      ),
      trailing: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: <Widget>[
          if (hilo.actualizadoEn != null)
            Text(
              DateFormat('dd/MM · HH:mm').format(hilo.actualizadoEn!),
              style: tema.textTheme.bodySmall?.copyWith(
                color: tema.colorScheme.onSurfaceVariant,
              ),
            ),
          if (porLeer) ...<Widget>[
            const SizedBox(height: 4),
            Badge(
              label: Text('${hilo.sinLeerEmisor}'),
              backgroundColor: PaletaSian.de(context).fondoPrimario,
              textColor: PaletaSian.sobreFondo,
            ),
          ],
        ],
      ),
      onTap: () => Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (BuildContext _) => PantallaHilo(hilo: hilo),
        ),
      ),
    );
  }
}

/// Una conversación completa, vista por quien emitió el aviso.
class PantallaHilo extends ConsumerStatefulWidget {
  const PantallaHilo({required this.hilo, super.key});

  final Hilo hilo;

  @override
  ConsumerState<PantallaHilo> createState() => _PantallaHiloState();
}

class _PantallaHiloState extends ConsumerState<PantallaHilo> {
  @override
  void initState() {
    super.initState();
    // Abrirla es leerla. Y la notificación de esas respuestas ya no dice nada
    // nuevo; en Android, una olvidada deja el icono marcado (DT-26).
    unawaited(
      ref
          .read(repositorioRespuestasProvider)
          .marcarLeido(
            mensajeId: widget.hilo.mensajeId,
            hiloUid: widget.hilo.uid,
          )
          .catchError((Object _) {}),
    );
    unawaited(
      cerrarNotificacionesDelSistema('respuestas-${widget.hilo.mensajeId}'),
    );
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData tema = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(widget.hilo.nombre, overflow: TextOverflow.ellipsis),
            Text(
              Textos.sobreElAviso(widget.hilo.tituloAviso),
              overflow: TextOverflow.ellipsis,
              style: tema.textTheme.bodySmall?.copyWith(
                color: tema.appBarTheme.foregroundColor,
              ),
            ),
          ],
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 720),
              child: Conversacion(
                mensajeId: widget.hilo.mensajeId,
                hiloUid: widget.hilo.uid,
                miLado: LadoHilo.emisor,
                nombreDelOtro: widget.hilo.nombre,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
