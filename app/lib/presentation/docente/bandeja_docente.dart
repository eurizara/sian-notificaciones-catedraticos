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
import 'realce_mensaje.dart';
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
  const BandejaDocente({
    required this.usuario,
    this.conBarraPropia = true,
    super.key,
  });

  final UsuarioSesion usuario;

  /// Dentro del panel ya hay una barra: dos cabeceras apiladas roban media
  /// pantalla en un teléfono.
  final bool conBarraPropia;

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

  /// Controla el desplazamiento para poder volver arriba de un toque.
  final ScrollController _scroll = ScrollController();
  bool _lejosDelInicio = false;

  @override
  void initState() {
    super.initState();
    _busqueda.addListener(() {
      // Al buscar se vuelve al principio: seguir en la página 4 de un
      // resultado que tiene 2 elementos deja la pantalla vacía sin motivo.
      setState(() => _visibles = _porPagina);
    });

    _scroll.addListener(() {
      // El botón de volver arriba aparece cuando ya hay camino que desandar.
      // Mostrarlo desde el primer píxel sería taparle sitio a la lista para
      // ofrecer algo que no hace falta.
      final bool lejos = _scroll.hasClients && _scroll.offset > 600;
      if (lejos != _lejosDelInicio) {
        setState(() => _lejosDelInicio = lejos);
      }
    });
  }

  @override
  void dispose() {
    _busqueda.dispose();
    _scroll.dispose();
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
        appBar: widget.conBarraPropia
            ? BarraSesion(usuario: usuario, titulo: Textos.bandejaTitulo)
            : null,
        // Volver arriba de un toque. En una bandeja con meses de historial,
        // subir a pulso es un gesto que se repite decenas de veces.
        floatingActionButton: _lejosDelInicio
            ? FloatingActionButton.small(
                onPressed: () => _scroll.animateTo(
                  0,
                  duration: const Duration(milliseconds: 350),
                  curve: Curves.easeOut,
                ),
                tooltip: Textos.volverArriba,
                child: const Icon(Icons.arrow_upward),
              )
            : null,
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

                return Column(
                  children: <Widget>[
                    // ────────────────────────────────────────────────────
                    // FUERA de la lista, y no por gusto.
                    // ────────────────────────────────────────────────────
                    //
                    // Dentro, al volver a la cima la lista la destruía y la
                    // recreaba; su `initState` vuelve a consultar el permiso
                    // y al responder cambia de alto. Ese salto justo arriba
                    // empujaba la vista hacia abajo, y el desplazamiento se
                    // quedaba atrapado a un dedo del principio.
                    //
                    // Como cabecera fija se monta una vez y no vuelve a
                    // moverse. Ocupa una línea cuando todo va bien.
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                      child: Column(
                        children: <Widget>[
                          const TarjetaNotificaciones(),
                          // El buscador solo aparece cuando hay bastante que
                          // buscar: con tres mensajes estorba.
                          if (todos.length > 5)
                            Buscador(
                              controlador: _busqueda,
                              etiqueta: Textos.buscarMensajes,
                              resultados: filtrados.length,
                            ),
                        ],
                      ),
                    ),
                    Expanded(
                      child: ListView(
                        controller: _scroll,
                        padding: const EdgeInsets.all(16),
                        children: <Widget>[
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
                            alPulsar: () =>
                                setState(() => _visibles += _porPagina),
                          ),
                        ],
                      ),
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

  /// Plegado por omisión, salvo lo que exige atención.
  ///
  /// ──────────────────────────────────────────────────────────────────────
  /// Una bandeja se hojea; un mensaje se lee.
  /// ──────────────────────────────────────────────────────────────────────
  ///
  /// Con todo desplegado, tres avisos con imagen llenan la pantalla y hay que
  /// desplazarse mucho para saber si hay algo nuevo. Plegado, la lista cabe
  /// de un vistazo y se abre lo que interese.
  ///
  /// Lo urgente sin confirmar nace ABIERTO: esconder tras un toque justo lo
  /// que hay que atender sería exactamente al revés de lo que hace falta.
  late bool _desplegado = widget.mensaje.exigeAtencion;

  /// Se marca como abierto al DESPLEGARLO, no al pintar la lista.
  ///
  /// ──────────────────────────────────────────────────────────────────────
  /// «Abierto» tiene que significar que alguien lo miró.
  /// ──────────────────────────────────────────────────────────────────────
  ///
  /// Antes se marcaba en `initState`: bastaba con que la bandeja se dibujara
  /// para que todo constara como abierto. Eso hacía imposible resaltar lo no
  /// leído —nada seguía sin leer más de un instante— y, peor, convertía un
  /// dato con valor de seguimiento en una casilla que se marca sola.
  ///
  /// Ahora se marca cuando la persona despliega el mensaje, que es cuando el
  /// texto aparece delante de ella. Sigue sin ser confirmar: abrir dice que
  /// lo miró; confirmar, que lo declaró leído (RF-CNF-02).
  @override
  void initState() {
    super.initState();
    // Un urgente sin confirmar nace desplegado, así que se abre de entrada:
    // su contenido sí está delante de la persona desde el primer momento.
    if (_desplegado) {
      _marcarAbierto();
    }
  }

  bool _yaMarcado = false;

  void _marcarAbierto() {
    if (_yaMarcado || widget.mensaje.estado != 'ENTREGADO') {
      return;
    }
    _yaMarcado = true;
    unawaited(
      ref
          .read(repositorioProgramacionProvider)
          .marcarAbierto(widget.mensaje.mensajeId)
          .catchError((Object _) {
            // Que no se pueda marcar no puede impedir leer el mensaje.
          }),
    );
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
    final bool abierto = _desplegado;
    final ThemeData tema = Theme.of(context);
    // Patrón numérico a propósito: `DateFormat` con nombre de locale exige
    // inicializar los datos de `intl`, y sin eso lanza en tiempo de ejecución.
    // La localización completa entra con RNF-21 en la iteración 1.3.
    final DateFormat formato = DateFormat('dd/MM/yyyy · HH:mm');

    final Realce realce = realceDe(mensaje);

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      color: realce.fondo,
      child: InkWell(
        onTap: () {
          setState(() => _desplegado = !_desplegado);
          if (_desplegado) {
            _marcarAbierto();
          }
        },
        borderRadius: BorderRadius.circular(12),
        child: IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              // Franja lateral en vez de un fondo fuerte: se lee de un vistazo
              // recorriendo el borde, y no compite con el texto.
              if (realce.franja != null)
                Container(width: 5, color: realce.franja),
              Expanded(
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
                              style: tema.textTheme.titleMedium?.copyWith(
                                fontWeight: realce.tituloEnNegrita
                                    ? FontWeight.bold
                                    : null,
                              ),
                            ),
                          ),
                          if (realce.nivel == NivelAtencion.sinLeer)
                            Container(
                              width: 9,
                              height: 9,
                              margin: const EdgeInsets.only(right: 8),
                              decoration: const BoxDecoration(
                                color: ColoresSian.primario,
                                shape: BoxShape.circle,
                              ),
                            ),
                          Icon(
                            abierto ? Icons.expand_less : Icons.expand_more,
                            color: tema.colorScheme.onSurfaceVariant,
                          ),
                        ],
                      ),
                      if (!abierto) ...<Widget>[
                        const SizedBox(height: 4),
                        // Una línea del cuerpo: suficiente para reconocer el aviso sin
                        // tener que abrirlo.
                        Text(
                          mensaje.cuerpo,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: tema.textTheme.bodySmall?.copyWith(
                            color: tema.colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],

                      // Estado y fecha se ven SIEMPRE, plegado o no: son lo que se
                      // hojea. Esconderlos obligaría a abrir cada mensaje solo para
                      // saber cuál falta por confirmar.
                      const SizedBox(height: 10),
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

                      // ──────────────────────────────────────────────────────
                      // QUIÉN LO ENVÍA, VISIBLE SIN ABRIR.
                      // ──────────────────────────────────────────────────────
                      //
                      // Ante un aviso que pide salir del edificio, saber quién
                      // lo firma es parte de decidir si obedecerlo. Va en la
                      // fila plegada porque ahí es donde se decide qué abrir.
                      if (mensaje.emisor.isNotEmpty) ...<Widget>[
                        const SizedBox(height: 4),
                        Text(
                          Textos.enviadoPor(mensaje.emisor),
                          style: tema.textTheme.bodySmall?.copyWith(
                            color: tema.colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],

                      if (abierto) ...<Widget>[
                        const SizedBox(height: 8),
                        Text(mensaje.cuerpo),

                        // RF-ENT-08 y RF-ENT-09. Van bajo el texto y no tras un botón:
                        // una nota de voz que hay que buscar es una nota de voz que no se
                        // escucha, y en un aviso urgente puede ser lo único que importa.
                        //
                        // En el ORDEN en que los adjuntó quien envió. Ese orden
                        // dice algo —el plano, la voz que lo explica, la foto
                        // del punto de reunión— y agruparlos por tipo aquí lo
                        // destruiría sin que nadie se diera cuenta.
                        for (final AdjuntoRecibido adjunto
                            in mensaje.adjuntos) ...<Widget>[
                          const SizedBox(height: 12),
                          if (adjunto.esVoz)
                            NotaDeVoz(
                              ruta: adjunto.ruta,
                              duracionSeg: adjunto.duracionSeg,
                            )
                          else
                            ImagenAdjunta(ruta: adjunto.ruta),
                        ],

                        if (mensaje.requiereConfirmacion &&
                            !mensaje.estaConfirmado) ...[
                          const SizedBox(height: 12),
                          // Confirmar es irreversible y con valor probatorio: lo escribe
                          // el servidor, nunca el cliente (RF-CNF-04). Aquí solo se pide.
                          FilledButton.icon(
                            onPressed: _confirmando ? null : _confirmar,
                            icon: _confirmando
                                ? const SizedBox(
                                    height: 16,
                                    width: 16,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                    ),
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
                    ],
                  ),
                ),
              ),
            ],
          ),
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
