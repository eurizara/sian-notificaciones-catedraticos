/// SIAN — Bandeja del catedrático (RF-ENT-12).
///
/// Lee de verdad contra Firestore: es la primera pantalla del sistema que
/// muestra datos reales pasando por las reglas de seguridad. Si un catedrático
/// ve aquí un mensaje, es porque las reglas lo dejaron leerlo.
library;

import 'dart:async';

import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../application/proveedores_programacion.dart';
import '../../core/entorno.dart';
import '../../domain/repositorios.dart';
import '../../domain/sesion.dart';
import '../../infrastructure/firebase/repositorio_bandeja.dart';
import '../../core/navegador.dart';
import '../shared/barra_sesion.dart';
import '../shared/buscador.dart';
import 'aviso_en_primer_plano.dart';
import 'instructivo_ios.dart';
import 'reproductor_adjuntos.dart';
import 'tarjeta_notificaciones.dart';
import '../shared/tema.dart';
import '../shared/textos.dart';

final Provider<RepositorioBandeja> repositorioBandejaProvider =
    Provider<RepositorioBandeja>((Ref ref) => RepositorioBandejaFirebase());

final historialProvider = StreamProvider.family<List<MensajeRecibido>, String>((
  Ref ref,
  String uid,
) {
  return ref.watch(repositorioBandejaProvider).observarHistorial(uid);
});

class BandejaDocente extends ConsumerStatefulWidget {
  const BandejaDocente({required this.usuario, super.key});

  final UsuarioSesion usuario;

  @override
  ConsumerState<BandejaDocente> createState() => _BandejaDocenteState();
}

class _BandejaDocenteState extends ConsumerState<BandejaDocente> {
  /// El instructivo de iOS se muestra una vez por sesión y se puede omitir.
  ///
  /// Bloquear la aplicación hasta instalarla dejaría al catedrático sin poder
  /// ni leer sus mensajes, que es peor que dejarlo sin notificaciones (R-02).
  bool _instructivoOmitido = false;

  final TextEditingController _busqueda = TextEditingController();

  /// Cuántos mensajes se muestran de golpe.
  ///
  /// Con veinte años de avisos, pintar el historial entero al abrir es lo que
  /// convierte una bandeja en una pantalla que tarda. Lo urgente está arriba;
  /// el resto se pide.
  static const int _porPagina = 15;
  int _visibles = _porPagina;

  @override
  void initState() {
    super.initState();
    _busqueda.addListener(() {
      // Al buscar se vuelve al principio: seguir en la página 4 de un
      // resultado que tiene 2 elementos deja la pantalla vacía sin motivo.
      setState(() => _visibles = _porPagina);
    });
  }

  @override
  void dispose() {
    _busqueda.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final UsuarioSesion usuario = widget.usuario;
    final EntornoNavegador entorno = ref
        .read(repositorioDispositivosProvider)
        .entorno;

    // RES-05: en iPhone sin instalar no llega ninguna notificación, así que
    // el instructivo aparece solo, antes que nada.
    if (entorno.necesitaInstructivoInstalacion && !_instructivoOmitido) {
      return InstructivoIos(
        entorno: entorno,
        alOmitir: () => setState(() => _instructivoOmitido = true),
      );
    }

    final AsyncValue<List<MensajeRecibido>> historial = ref.watch(
      historialProvider(usuario.uid),
    );

    // Con la bandeja abierta, el navegador no muestra ninguna notificación del
    // sistema: entrega el mensaje a la aplicación y se desentiende. Es la
    // aplicación la que tiene que hacerse notar.
    return AvisoEnPrimerPlano(
      child: Scaffold(
        appBar: BarraSesion(usuario: usuario, titulo: Textos.bandejaTitulo),
        body: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 720),
            child: historial.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (Object e, StackTrace _) => _Error(detalle: e.toString()),
              data: (List<MensajeRecibido> todos) {
                final List<MensajeRecibido> filtrados = filtrarMensajes(
                  todos,
                  _busqueda.text,
                );
                final List<MensajeRecibido> pagina = filtrados
                    .take(_visibles)
                    .toList();

                return ListView(
                  padding: const EdgeInsets.all(16),
                  children: <Widget>[
                    const TarjetaNotificaciones(),

                    // El buscador solo aparece cuando hay bastante que
                    // buscar: con tres mensajes estorba más de lo que ayuda.
                    if (todos.length > 5) ...<Widget>[
                      Buscador(
                        controlador: _busqueda,
                        etiqueta: Textos.buscarMensajes,
                        resultados: filtrados.length,
                      ),
                      const SizedBox(height: 16),
                    ],

                    if (todos.isEmpty)
                      const _BandejaVacia()
                    else if (filtrados.isEmpty)
                      Padding(
                        padding: const EdgeInsets.all(24),
                        child: Text(
                          Textos.sinResultados(_busqueda.text.trim()),
                          textAlign: TextAlign.center,
                        ),
                      )
                    else
                      ...filasDeMensajes(context, pagina),

                    VerMas(
                      mostrados: pagina.length,
                      total: filtrados.length,
                      alPulsar: () => setState(() => _visibles += _porPagina),
                    ),
                  ],
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}

/// Filtra por texto en el título y el cuerpo.
///
/// Sobre lo ya cargado, no consultando al servidor: Firestore no sabe buscar
/// dentro de un campo de texto y hacerlo exigiría un índice externo de pago
/// (ADR-008). Expuesta aparte para poder probar la coincidencia sin montar
/// ninguna pantalla.
List<MensajeRecibido> filtrarMensajes(
  List<MensajeRecibido> mensajes,
  String termino,
) {
  if (termino.trim().isEmpty) {
    return mensajes;
  }
  return mensajes
      .where(
        (MensajeRecibido m) => coincide(termino, <String>[m.titulo, m.cuerpo]),
      )
      .toList();
}

/// Construye las filas de la bandeja.
///
/// Devuelve widgets sueltos en vez de su propio `ListView` para poder
/// convivir con la tarjeta de notificaciones dentro de una sola lista
/// desplazable: dos listas anidadas se desplazarían por separado, que es
/// exactamente lo que nadie espera al deslizar.
List<Widget> filasDeMensajes(
  BuildContext context,
  List<MensajeRecibido> mensajes,
) {
  final int sinConfirmar = mensajes
      .where((MensajeRecibido m) => m.exigeAtencion)
      .length;

  return <Widget>[
    if (sinConfirmar > 0)
      Card(
        color: Theme.of(context).colorScheme.errorContainer,
        child: ListTile(
          leading: const Icon(Icons.priority_high),
          title: Text(
            sinConfirmar == 1
                ? Textos.bandejaPendienteUno
                : Textos.bandejaPendienteVarios(sinConfirmar),
          ),
          subtitle: const Text(Textos.bandejaPendienteDetalle),
        ),
      ),
    for (final MensajeRecibido mensaje in mensajes)
      _Fila(key: ValueKey<String>(mensaje.mensajeId), mensaje: mensaje),
    if (Entorno.usaEmulador)
      const Padding(
        padding: EdgeInsets.only(top: 16),
        child: Text(Textos.avisoEmuladorSinPush, textAlign: TextAlign.center),
      ),
  ];
}

class _Fila extends ConsumerStatefulWidget {
  const _Fila({required this.mensaje, super.key});

  final MensajeRecibido mensaje;

  @override
  ConsumerState<_Fila> createState() => _FilaState();
}

class _FilaState extends ConsumerState<_Fila> {
  bool _confirmando = false;

  /// Marca el mensaje como abierto al pintarlo (RF-CNF-02).
  ///
  /// Abrir NO es confirmar: dice que la aplicación lo mostró, no que alguien
  /// declarara haberlo leído. Mantenerlos separados es lo que convierte la
  /// confirmación en evidencia y no en suposición.
  @override
  void initState() {
    super.initState();
    if (widget.mensaje.estado == 'ENTREGADO') {
      unawaited(
        ref
            .read(repositorioProgramacionProvider)
            .marcarAbierto(widget.mensaje.mensajeId)
            .catchError((Object _) {
              // Que no se pueda marcar no puede impedir leer el mensaje.
            }),
      );
    }
  }

  Future<void> _confirmar() async {
    final bool? seguro = await showDialog<bool>(
      context: context,
      builder: (BuildContext c) => AlertDialog(
        title: const Text(Textos.confirmarTitulo),
        content: const Text(Textos.confirmarAviso),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(c).pop(false),
            child: const Text(Textos.botonCancelar),
          ),
          FilledButton(
            onPressed: () => Navigator.of(c).pop(true),
            child: const Text(Textos.confirmarSi),
          ),
        ],
      ),
    );

    if (seguro != true || !mounted) {
      return;
    }

    setState(() => _confirmando = true);

    try {
      await ref
          .read(repositorioProgramacionProvider)
          .confirmarLectura(
            mensajeId: widget.mensaje.mensajeId,
            dispositivo: EntornoNavegador.detectar().navegador,
          );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(Textos.confirmacionHecha),
            backgroundColor: ColoresSian.confirmado,
          ),
        );
      }
    } on FirebaseFunctionsException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.message ?? Textos.errorInesperado)),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _confirmando = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final MensajeRecibido mensaje = widget.mensaje;
    final ThemeData tema = Theme.of(context);
    // Patrón numérico a propósito: `DateFormat` con nombre de locale exige
    // inicializar los datos de `intl`, y sin eso lanza en tiempo de ejecución.
    // La localización completa entra con RNF-21 en la iteración 1.3.
    final DateFormat formato = DateFormat('dd/MM/yyyy · HH:mm');

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Row(
              children: <Widget>[
                if (mensaje.esUrgente)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 2,
                    ),
                    margin: const EdgeInsets.only(right: 8),
                    decoration: BoxDecoration(
                      color: ColoresSian.urgente,
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: const Text(
                      Textos.etiquetaUrgente,
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                Expanded(
                  child: Text(
                    mensaje.titulo,
                    style: tema.textTheme.titleMedium,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(mensaje.cuerpo),

            // RF-ENT-08 y RF-ENT-09. Van bajo el texto y no tras un botón:
            // una nota de voz que hay que buscar es una nota de voz que no se
            // escucha, y en un aviso urgente puede ser lo único que importa.
            if (mensaje.llevaVoz) ...<Widget>[
              const SizedBox(height: 12),
              NotaDeVoz(
                ruta: mensaje.rutaVoz!,
                duracionSeg: mensaje.duracionVozSeg,
              ),
            ],
            if (mensaje.llevaImagen) ...<Widget>[
              const SizedBox(height: 12),
              ImagenAdjunta(ruta: mensaje.rutaImagen!),
            ],

            const SizedBox(height: 12),
            Row(
              children: <Widget>[
                Icon(
                  _iconoDeEstado(mensaje.estado),
                  size: 16,
                  color: mensaje.estaConfirmado
                      ? ColoresSian.confirmado
                      : tema.colorScheme.onSurfaceVariant,
                ),
                const SizedBox(width: 6),
                Text(
                  _etiquetaDeEstado(mensaje.estado),
                  style: tema.textTheme.bodySmall?.copyWith(
                    color: mensaje.estaConfirmado
                        ? ColoresSian.confirmado
                        : tema.colorScheme.onSurfaceVariant,
                  ),
                ),
                const Spacer(),
                if (mensaje.entregadoEn != null)
                  Text(
                    formato.format(mensaje.entregadoEn!),
                    style: tema.textTheme.bodySmall?.copyWith(
                      color: tema.colorScheme.onSurfaceVariant,
                    ),
                  ),
              ],
            ),
            if (mensaje.requiereConfirmacion && !mensaje.estaConfirmado) ...[
              const SizedBox(height: 12),
              // Confirmar es irreversible y con valor probatorio: lo escribe
              // el servidor, nunca el cliente (RF-CNF-04). Aquí solo se pide.
              FilledButton.icon(
                onPressed: _confirmando ? null : _confirmar,
                icon: _confirmando
                    ? const SizedBox(
                        height: 16,
                        width: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.check),
                label: Text(
                  _confirmando
                      ? Textos.confirmandoLectura
                      : Textos.botonConfirmarLectura,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  IconData _iconoDeEstado(String estado) => switch (estado) {
    'CONFIRMADO' => Icons.verified_outlined,
    'ABIERTO' => Icons.drafts_outlined,
    'ENTREGADO' => Icons.mark_email_unread_outlined,
    'FALLIDO' || 'DESCARTADO' => Icons.error_outline,
    _ => Icons.schedule_outlined,
  };

  String _etiquetaDeEstado(String estado) => switch (estado) {
    'CONFIRMADO' => Textos.estadoConfirmado,
    'ABIERTO' => Textos.estadoAbierto,
    'ENTREGADO' => Textos.estadoEntregado,
    'FALLIDO' => Textos.estadoFallido,
    'DESCARTADO' => Textos.estadoDescartado,
    _ => Textos.estadoPendiente,
  };
}

class _BandejaVacia extends StatelessWidget {
  const _BandejaVacia();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Icon(
            Icons.inbox_outlined,
            size: 56,
            color: Theme.of(context).colorScheme.outline,
          ),
          const SizedBox(height: 16),
          const Text(Textos.bandejaVacia),
        ],
      ),
    );
  }
}

class _Error extends StatelessWidget {
  const _Error({required this.detalle});

  final String detalle;

  @override
  Widget build(BuildContext context) {
    final ThemeData tema = Theme.of(context);

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Icon(Icons.error_outline, size: 48, color: tema.colorScheme.error),
            const SizedBox(height: 16),
            Text(Textos.bandejaError, style: tema.textTheme.titleMedium),
            const SizedBox(height: 8),
            // El detalle se muestra tal cual: en desarrollo, «falta el índice»
            // o «permiso denegado» es exactamente lo que hay que leer.
            Text(
              detalle,
              textAlign: TextAlign.center,
              style: tema.textTheme.bodySmall?.copyWith(
                color: tema.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
