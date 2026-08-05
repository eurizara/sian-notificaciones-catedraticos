/// SIAN — Avisos que llegan con la aplicación abierta (RF-ENT-06, DT-02).
///
/// ────────────────────────────────────────────────────────────────────────────
/// Con la aplicación en primer plano, el navegador NO muestra nada.
/// ────────────────────────────────────────────────────────────────────────────
///
/// El mensaje llega —por el mismo canal de siempre—, pero el service worker no
/// interviene: los push solo pasan por él cuando la pestaña está en segundo
/// plano o cerrada. En primer plano el navegador entrega el mensaje a la
/// aplicación y se desentiende de mostrarlo.
///
/// Sin este widget, un catedrático mirando su bandeja no vería llegar nada, y
/// el aviso quedaría solo en el historial. Es exactamente lo que ocurría con la
/// notificación de prueba del registro: el servidor la enviaba, FCM la
/// aceptaba, el dispositivo la recibía, y nadie la pintaba.
library;

import 'dart:async';

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../application/proveedores_dispositivos.dart';
import '../shared/tema.dart';
import '../shared/textos.dart';

/// Envuelve una pantalla y muestra los avisos que lleguen mientras esté visible.
class AvisoEnPrimerPlano extends ConsumerStatefulWidget {
  const AvisoEnPrimerPlano({required this.child, super.key});

  final Widget child;

  @override
  ConsumerState<AvisoEnPrimerPlano> createState() => _AvisoEnPrimerPlanoState();
}

class _AvisoEnPrimerPlanoState extends ConsumerState<AvisoEnPrimerPlano> {
  StreamSubscription<RemoteMessage>? _suscripcion;

  @override
  void initState() {
    super.initState();
    _suscripcion = ref
        .read(repositorioDispositivosProvider)
        .mensajesEnPrimerPlano()
        .listen(_mostrar);
  }

  @override
  void dispose() {
    unawaited(_suscripcion?.cancel());
    super.dispose();
  }

  void _mostrar(RemoteMessage mensaje) {
    if (!mounted) {
      return;
    }

    final ({String titulo, String cuerpo, bool urgente}) aviso = leerAviso(
      mensaje,
    );

    ScaffoldMessenger.of(context)
      ..clearMaterialBanners()
      ..showMaterialBanner(
        MaterialBanner(
          backgroundColor: aviso.urgente
              ? ColoresSian.urgente
              : ColoresSian.primario,
          leading: Icon(
            aviso.urgente ? Icons.priority_high : Icons.notifications_active,
            color: Colors.white,
          ),
          content: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Text(
                aviso.titulo,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
              if (aviso.cuerpo.isNotEmpty) ...<Widget>[
                const SizedBox(height: 4),
                Text(
                  aviso.cuerpo,
                  style: const TextStyle(color: Colors.white),
                ),
              ],
            ],
          ),
          actions: <Widget>[
            TextButton(
              onPressed: () =>
                  ScaffoldMessenger.of(context).hideCurrentMaterialBanner(),
              child: const Text(
                Textos.botonCerrarAviso,
                style: TextStyle(color: Colors.white),
              ),
            ),
          ],
        ),
      );
  }

  @override
  Widget build(BuildContext context) => widget.child;
}

/// Extrae título, cuerpo y urgencia de un mensaje recibido.
///
/// Mira primero en `data` y luego en `notification`. El servidor envía solo
/// datos —para decidir aquí el prefijo «URGENTE» y no dejárselo al navegador—,
/// pero leer ambos evita que un desajuste de nombres deje el aviso mudo, que
/// es como se perdió la notificación de prueba.
({String titulo, String cuerpo, bool urgente}) leerAviso(RemoteMessage m) {
  final Map<String, dynamic> datos = m.data;
  final bool urgente = datos['tipo'] == 'URGENTE';

  final String base =
      (datos['titulo'] as String?) ?? m.notification?.title ?? Textos.nombreApp;

  return (
    titulo: urgente ? 'URGENTE · $base' : base,
    cuerpo: (datos['cuerpo'] as String?) ?? m.notification?.body ?? '',
    urgente: urgente,
  );
}
