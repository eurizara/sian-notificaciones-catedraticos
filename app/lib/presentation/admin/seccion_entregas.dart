/// SIAN — Reporte de entregas y confirmación (RF-CNF-06, RF-CNF-07, RF-BIT-08).
///
/// ────────────────────────────────────────────────────────────────────────────
/// Un aviso que no pedía confirmación no se mide en confirmaciones.
/// ────────────────────────────────────────────────────────────────────────────
///
/// Mezclarlos hacía que un aviso informativo apareciera para siempre «al 0 %,
/// faltan 40 por confirmar», como si algo hubiera salido mal. No había salido
/// mal: es que nadie tenía que confirmarlo. Para esos la medida real es cuántos
/// lo recibieron — o llegó, o no llegó.
///
/// Tampoco se les pone un 100 % de confirmación, que sería igual de falso en la
/// otra dirección: afirmaría que cuarenta personas confirmaron algo que nunca
/// se les pidió, en un reporte que existe precisamente para sostener esa clase
/// de afirmación delante de quien pregunte.
///
/// Cuando SÍ hubo confirmación, el porcentaje se calcula sobre el TOTAL y no
/// sobre los entregados: a quien no le llegó el aviso tampoco lo confirmó, y
/// con el otro denominador un simulacro daría 100 % teniendo cinco personas sin
/// enterarse — que es exactamente el dato por el que se hace un simulacro.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../application/proveedores_programacion.dart';
import '../../application/proveedores_respuestas.dart';
import '../../infrastructure/firebase/repositorio_programacion.dart';
import '../../infrastructure/firebase/repositorio_respuestas.dart';
import '../shared/buscador.dart';
import '../shared/tema.dart';
import 'resumen_semanal.dart';
import 'seccion_respuestas.dart';
import '../shared/textos.dart';
import 'seccion_programacion.dart' show Marca, filtrarProgramados;

class SeccionEntregas extends ConsumerStatefulWidget {
  const SeccionEntregas({super.key});

  @override
  ConsumerState<SeccionEntregas> createState() => _SeccionEntregasState();
}

class _SeccionEntregasState extends ConsumerState<SeccionEntregas> {
  final TextEditingController _busqueda = TextEditingController();

  /// Menos por página que en la bandeja: cada reporte lleva barra, marcas y
  /// varias cifras, así que diez ya llenan la pantalla.
  static const int _porPagina = 10;
  int _visibles = _porPagina;

  /// Qué reportes se muestran.
  ///
  /// Con veinte avisos enviados, lo que se busca casi siempre es el mismo:
  /// cuáles siguen esperando algo. Ese es el que hay que perseguir.
  _Filtro _filtro = _Filtro.todos;

  @override
  void initState() {
    super.initState();
    _busqueda.addListener(() => setState(() => _visibles = _porPagina));
  }

  @override
  void dispose() {
    _busqueda.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final AsyncValue<List<MensajeProgramado>> lista = ref.watch(
      programadosProvider,
    );

    return lista.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (Object e, StackTrace _) => Center(
        child: Padding(padding: const EdgeInsets.all(24), child: Text('$e')),
      ),
      data: (List<MensajeProgramado> todos) {
        final List<MensajeProgramado> enviados = todos
            .where((MensajeProgramado m) => m.totalDestinatarios > 0)
            .toList();

        if (enviados.isEmpty) {
          return const Center(
            child: Padding(
              padding: EdgeInsets.all(32),
              child: Text(Textos.entregasVacia, textAlign: TextAlign.center),
            ),
          );
        }

        final List<MensajeProgramado> porEstado = switch (_filtro) {
          _Filtro.todos => enviados,
          _Filtro.pendientes => enviados
              .where((MensajeProgramado m) => !m.estaCompleto)
              .toList(),
          _Filtro.completos => enviados
              .where((MensajeProgramado m) => m.estaCompleto)
              .toList(),
        };

        final List<MensajeProgramado> filtrados = filtrarProgramados(
          porEstado,
          _busqueda.text,
        );
        final List<MensajeProgramado> pagina = filtrados
            .take(_visibles)
            .toList();

        return ListView(
          padding: const EdgeInsets.all(16),
          children: <Widget>[
            // La suma de la semana va arriba de todo: es la pregunta que se trae
            // al entrar —«¿llegaron?»— y antes había que contestarla abriendo
            // los reportes uno por uno (DT-07). Se calcula sobre la lista
            // completa, no sobre la filtrada: la búsqueda no debe cambiarla.
            TarjetaResumenSemanal(
              resumen: calcularResumenSemanal(todos, DateTime.now()),
            ),
            const SizedBox(height: 16),
            if (enviados.length > 5) ...<Widget>[
              Buscador(
                controlador: _busqueda,
                etiqueta: Textos.buscarEntregas,
                resultados: filtrados.length,
              ),
              const SizedBox(height: 10),
            ],

            // El contador va en la propia pestaña: «Pendientes (3)» dice de un
            // vistazo si hay algo que perseguir, sin tener que entrar a mirar.
            SegmentedButton<_Filtro>(
              segments: <ButtonSegment<_Filtro>>[
                ButtonSegment<_Filtro>(
                  value: _Filtro.todos,
                  label: Text(Textos.filtroTodos(enviados.length)),
                ),
                ButtonSegment<_Filtro>(
                  value: _Filtro.pendientes,
                  label: Text(
                    Textos.filtroPendientes(
                      enviados
                          .where((MensajeProgramado m) => !m.estaCompleto)
                          .length,
                    ),
                  ),
                ),
                ButtonSegment<_Filtro>(
                  value: _Filtro.completos,
                  label: Text(
                    Textos.filtroCompletos(
                      enviados
                          .where((MensajeProgramado m) => m.estaCompleto)
                          .length,
                    ),
                  ),
                ),
              ],
              selected: <_Filtro>{_filtro},
              showSelectedIcon: false,
              style: const ButtonStyle(
                visualDensity: VisualDensity.compact,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              onSelectionChanged: (Set<_Filtro> s) => setState(() {
                _filtro = s.first;
                _visibles = _porPagina;
              }),
            ),
            const SizedBox(height: 12),
            if (filtrados.isEmpty)
              Padding(
                padding: const EdgeInsets.all(24),
                child: Text(
                  _busqueda.text.trim().isEmpty
                      ? Textos.entregasSinEsteEstado
                      : Textos.sinResultados(_busqueda.text.trim()),
                  textAlign: TextAlign.center,
                ),
              )
            else
              for (final MensajeProgramado m in pagina) _Reporte(mensaje: m),
            VerMas(
              mostrados: pagina.length,
              total: filtrados.length,
              alPulsar: () => setState(() => _visibles += _porPagina),
            ),
          ],
        );
      },
    );
  }
}

class _Reporte extends ConsumerStatefulWidget {
  const _Reporte({required this.mensaje});

  final MensajeProgramado mensaje;

  @override
  ConsumerState<_Reporte> createState() => _ReporteState();
}

class _ReporteState extends ConsumerState<_Reporte> {
  bool _mostrandoLista = false;
  bool _cargando = false;
  List<DestinatarioEntrega>? _destinatarios;
  String? _error;

  /// Carga la lista solo cuando se pide.
  ///
  /// Son varias lecturas por mensaje. Hacerlas para los diez reportes de la
  /// página al abrirla sería pagar por información que casi nadie mira, y
  /// justo cuando lo urgente es ver los porcentajes.
  Future<void> _alternar() async {
    if (_mostrandoLista) {
      setState(() => _mostrandoLista = false);
      return;
    }

    setState(() {
      _mostrandoLista = true;
      _error = null;
    });

    if (_destinatarios != null) {
      return;
    }

    setState(() => _cargando = true);
    try {
      final List<DestinatarioEntrega> l = await ref
          .read(repositorioProgramacionProvider)
          .detalleEntregas(widget.mensaje.id);
      if (mounted) {
        setState(() => _destinatarios = l);
      }
    } on Object catch (_) {
      if (mounted) {
        setState(() => _error = Textos.errorDetalleEntregas);
      }
    } finally {
      if (mounted) {
        setState(() => _cargando = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final MensajeProgramado mensaje = widget.mensaje;
    final ThemeData tema = Theme.of(context);
    final DateFormat formato = DateFormat('dd/MM/yyyy · HH:mm');
    // Un aviso sin confirmación se mide por entrega; uno con ella, por
    // confirmación. Son dos preguntas distintas y no admiten la misma barra.
    final bool porConfirmacion = mensaje.requiereConfirmacion;
    final int porcentaje = porConfirmacion
        ? mensaje.porcentajeConfirmado
        : mensaje.porcentajeEntregado;
    final int pendientes = mensaje.faltanPorConfirmar;

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
                      color: PaletaSian.de(context).fondoUrgente,
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
            const SizedBox(height: 6),

            Wrap(
              spacing: 6,
              runSpacing: 4,
              children: <Widget>[
                // Quién lo mandó, primero de todo. En una lista compartida por
                // el coordinador y varias administradoras, «de quién es esto»
                // es lo primero que se pregunta al mirarla.
                if (mensaje.emisor.isNotEmpty)
                  Marca(
                    icono: Icons.person_outline,
                    texto: Textos.enviadoPor(mensaje.emisor),
                  ),
                Marca(
                  icono: Icons.people_outline,
                  texto: switch (mensaje.modoDestinatarios) {
                    'GRUPOS' => Textos.destinatariosGruposCorto(
                      mensaje.nombresGrupos,
                    ),
                    'INDIVIDUAL' => Textos.destinatariosIndividual,
                    _ => Textos.destinatariosTodosCorto,
                  },
                ),
                if (mensaje.llevaVoz)
                  const Marca(
                    icono: Icons.graphic_eq,
                    texto: Textos.llevaNotaDeVoz,
                  ),
                if (mensaje.llevaImagen)
                  const Marca(
                    icono: Icons.image_outlined,
                    texto: Textos.llevaImagenAdjunta,
                  ),
                // Lo que de verdad experimentó la gente (DT-31). Va junto a lo
                // demás y no escondido: es el dato que faltaba para saber si un
                // aviso sirvió de algo.
                if (mensaje.acuseEsperado && mensaje.entregados > 0)
                  Marca(
                    icono: mensaje.entregadosSinMostrar > 0
                        ? Icons.notifications_off_outlined
                        : Icons.notifications_active_outlined,
                    texto: Textos.seMostroEn(
                      mensaje.mostrados,
                      mensaje.entregados,
                    ),
                  ),
              ],
            ),
            // Las respuestas, en el aviso al que contestan (DT-27). Solo en
            // los avisos propios: la consulta es de los hilos de quien mira.
            RespuestasDelAviso(mensajeId: mensaje.id),
            const SizedBox(height: 8),

            // Cuándo salió, no cuándo saldrá. Es la primera pregunta al abrir
            // este reporte: «¿cuándo se avisó?». En un recurrente es la
            // última salida, que es la que importa para contestarla.
            Row(
              children: <Widget>[
                Icon(
                  Icons.send_outlined,
                  size: 16,
                  color: tema.colorScheme.onSurfaceVariant,
                ),
                const SizedBox(width: 6),
                Text(
                  mensaje.enviadoEn == null
                      ? Textos.sinFechaDeEnvio
                      : mensaje.esRecurrente
                      ? Textos.ultimaSalidaEl(
                          formato.format(mensaje.enviadoEn!),
                        )
                      : Textos.enviadoEl(formato.format(mensaje.enviadoEn!)),
                  style: tema.textTheme.bodySmall?.copyWith(
                    color: tema.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),

            // En un recurrente, además, cuándo vuelve a salir.
            if (mensaje.esRecurrente && mensaje.proximaOcurrencia != null) ...[
              const SizedBox(height: 4),
              Row(
                children: <Widget>[
                  Icon(
                    Icons.event_repeat,
                    size: 16,
                    color: tema.colorScheme.onSurfaceVariant,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    Textos.proximaSalida(
                      formato.format(mensaje.proximaOcurrencia!),
                    ),
                    style: tema.textTheme.bodySmall?.copyWith(
                      color: tema.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ],

            const SizedBox(height: 12),

            Text(
              Textos.entregasResumen(
                mensaje.entregados,
                mensaje.totalDestinatarios,
              ),
              style: tema.textTheme.bodyMedium,
            ),
            const SizedBox(height: 12),

            // La barra usa el mismo denominador que el número: si dijeran
            // cosas distintas, la barra ganaría, porque es lo que se mira.
            LinearProgressIndicator(
              value: porcentaje / 100,
              minHeight: 8,
              borderRadius: BorderRadius.circular(4),
              color: porcentaje >= 80
                  ? PaletaSian.de(context).confirmado
                  : porcentaje >= 40
                  ? PaletaSian.de(context).dorado
                  : PaletaSian.de(context).urgente,
            ),
            const SizedBox(height: 8),

            // ────────────────────────────────────────────────────────────────
            // LA APERTURA, ENTRE LA ENTREGA Y LA CONFIRMACIÓN.
            // ────────────────────────────────────────────────────────────────
            //
            // Es la etapa de en medio, y se registra pida o no el aviso
            // confirmación. Para uno que no la pedía es lo único que distingue
            // «llegó al teléfono» de «llegó a la persona».
            //
            // Va en gris y sin barra propia a propósito: una segunda barra al
            // lado de la de confirmación las pondría al mismo nivel, y no lo
            // están.
            Text(
              Textos.entregasAbiertos(
                mensaje.abiertos,
                mensaje.totalDestinatarios,
                mensaje.porcentajeAbierto,
              ),
              style: tema.textTheme.bodyMedium?.copyWith(
                color: tema.colorScheme.onSurfaceVariant,
              ),
            ),
            if (mensaje.entregadosSinAbrir > 0) ...<Widget>[
              const SizedBox(height: 2),
              Text(
                Textos.entregasSinAbrir(mensaje.entregadosSinAbrir),
                style: tema.textTheme.bodySmall?.copyWith(
                  color: tema.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
            const SizedBox(height: 8),

            if (porConfirmacion) ...<Widget>[
              Text(
                Textos.entregasConfirmados(
                  mensaje.confirmados,
                  mensaje.totalDestinatarios,
                  porcentaje,
                ),
                style: tema.textTheme.bodyMedium,
              ),
              if (pendientes > 0) ...<Widget>[
                const SizedBox(height: 4),
                Text(
                  Textos.entregasPendientes(pendientes),
                  style: tema.textTheme.bodySmall?.copyWith(
                    color: PaletaSian.de(context).doradoTexto,
                  ),
                ),
              ],
            ] else
              // Ni «faltan N por confirmar» ni un 100 % inventado: se dice lo
              // que pasó, que es que nunca se pidió.
              Text(
                Textos.entregasSinConfirmacion,
                style: tema.textTheme.bodySmall?.copyWith(
                  color: tema.colorScheme.onSurfaceVariant,
                ),
              ),

            // «Faltan 6» no dice a QUIÉN hay que buscar, que es lo único
            // accionable de este reporte.
            const SizedBox(height: 4),
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton.icon(
                onPressed: _alternar,
                icon: Icon(
                  _mostrandoLista ? Icons.expand_less : Icons.expand_more,
                ),
                label: Text(
                  _mostrandoLista
                      ? Textos.ocultarQuienFalta
                      : Textos.verQuienFalta,
                ),
              ),
            ),

            if (_mostrandoLista)
              if (_cargando)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 12),
                  child: Row(
                    children: <Widget>[
                      SizedBox(
                        height: 16,
                        width: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                      SizedBox(width: 12),
                      Text(Textos.cargandoDestinatarios),
                    ],
                  ),
                )
              else if (_error != null)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: Text(
                    _error!,
                    style: tema.textTheme.bodySmall?.copyWith(
                      color: PaletaSian.de(context).urgente,
                    ),
                  ),
                )
              else
                _ListaDestinatarios(
                  destinatarios:
                      _destinatarios ?? const <DestinatarioEntrega>[],
                  porConfirmacion: porConfirmacion,
                  esperaAcuse: mensaje.acuseEsperado,
                ),
          ],
        ),
      ),
    );
  }
}

/// Quién recibió, quién no y quién confirmó.
class _ListaDestinatarios extends StatelessWidget {
  const _ListaDestinatarios({
    required this.destinatarios,
    required this.porConfirmacion,
    this.esperaAcuse = false,
  });

  final List<DestinatarioEntrega> destinatarios;
  final bool porConfirmacion;

  /// Si este aviso pidió acuse (DT-31). Sin él no se puede distinguir «no lo
  /// abrió» de «su teléfono nunca se lo enseñó».
  final bool esperaAcuse;

  @override
  Widget build(BuildContext context) {
    final ThemeData tema = Theme.of(context);

    if (destinatarios.isEmpty) {
      return const SizedBox.shrink();
    }

    final bool todoConfirmado =
        porConfirmacion &&
        destinatarios.every((DestinatarioEntrega d) => d.confirmo);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        const SizedBox(height: 4),
        Text(
          Textos.detalleFallidosPrimero,
          style: tema.textTheme.bodySmall?.copyWith(
            color: tema.colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 8),

        if (todoConfirmado)
          Row(
            children: <Widget>[
              Icon(
                Icons.verified_outlined,
                size: 16,
                color: PaletaSian.de(context).confirmado,
              ),
              const SizedBox(width: 8),
              Text(
                Textos.nadiePendiente,
                style: tema.textTheme.bodySmall?.copyWith(
                  color: PaletaSian.de(context).confirmado,
                ),
              ),
            ],
          ),

        for (final DestinatarioEntrega d in destinatarios)
          Builder(
            builder: (BuildContext _) {
              final SituacionEntrega s = situacionDe(
                d,
                porConfirmacion,
                esperaAcuse: esperaAcuse,
              );
              return Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Row(
                  children: <Widget>[
                    Icon(s.icono, size: 16, color: PaletaSian.de(context).adaptar(s.color)),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        d.nombre,
                        style: tema.textTheme.bodySmall,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    Text(
                      s.etiqueta,
                      style: tema.textTheme.bodySmall?.copyWith(
                        color: tema.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
      ],
    );
  }
}

/// Qué reportes se muestran en la lista.
enum _Filtro { todos, pendientes, completos }

/// Cómo se describe la situación de un destinatario en el detalle.
class SituacionEntrega {
  const SituacionEntrega({
    required this.etiqueta,
    required this.icono,
    required this.color,
  });

  final String etiqueta;
  final IconData icono;
  final Color color;
}

/// En qué situación está esta persona con este aviso.
///
/// ──────────────────────────────────────────────────────────────────────────
/// Cuatro situaciones distintas, y cada una se resuelve de otra manera.
/// ──────────────────────────────────────────────────────────────────────────
///
/// Antes se decía «Entregado» de todo lo que no estuviera confirmado ni
/// fallido, y ahí caían dos casos que no se parecen en nada: quien abrió el
/// aviso y no lo confirmó —lo vio y no respondió— y quien no lo ha abierto
/// siquiera. Al primero se le insiste; al segundo hay que averiguar si le
/// están llegando las notificaciones.
///
/// Se calcula aparte de la pantalla para poder comprobarlo: es la parte del
/// reporte de la que después salen decisiones sobre personas.
SituacionEntrega situacionDe(
  DestinatarioEntrega d,
  bool porConfirmacion, {
  bool esperaAcuse = false,
}) {
  // Un fallo de entrega NO es un descuido: uno se resuelve revisando el
  // dispositivo y el otro insistiendo a la persona.
  if (d.fallo) {
    return const SituacionEntrega(
      etiqueta: Textos.estadoNoLeLlego,
      icono: Icons.error_outline,
      color: ColoresSian.urgente,
    );
  }
  if (d.confirmo) {
    return const SituacionEntrega(
      etiqueta: Textos.estadoConfirmado,
      icono: Icons.check_circle_outline,
      color: ColoresSian.confirmado,
    );
  }
  if (!d.abrio) {
    // ────────────────────────────────────────────────────────────────────────
    // «No lo abrió» y «su teléfono nunca se lo enseñó» no son lo mismo (DT-31).
    // ────────────────────────────────────────────────────────────────────────
    //
    // Al primero se le insiste; al segundo hay que llamarlo y revisar los
    // ajustes de su aparato, porque va a pasarle con el próximo aviso también.
    // Antes los dos se veían igual, y por eso el 11 de septiembre no se pudo
    // contestar «¿a quién no le avisó el teléfono?».
    //
    // Solo se distingue en los avisos que pidieron acuse: en los anteriores,
    // que nadie dijera nada no significa nada.
    if (esperaAcuse && !d.seMostro) {
      return const SituacionEntrega(
        etiqueta: Textos.detalleNoSeMostro,
        icono: Icons.notifications_off_outlined,
        color: ColoresSian.urgente,
      );
    }
    return const SituacionEntrega(
      etiqueta: Textos.detalleNoAbrio,
      icono: Icons.mail_outline,
      color: ColoresSian.doradoTexto,
    );
  }
  // Lo abrió. Con confirmación pendiente sigue habiendo algo que hacer; sin
  // ella, es todo lo que se podía esperar.
  return porConfirmacion
      ? const SituacionEntrega(
          etiqueta: Textos.detalleAbrioSinConfirmar,
          icono: Icons.drafts_outlined,
          color: ColoresSian.doradoTexto,
        )
      : const SituacionEntrega(
          etiqueta: Textos.detalleAbrio,
          icono: Icons.drafts_outlined,
          color: ColoresSian.confirmado,
        );
}

/// «3 respuestas · 1 sin leer», y al tocarlo, las conversaciones de ese aviso.
///
/// No aparece si el aviso no tiene respuestas: una línea que dice «0
/// respuestas» en cada aviso sería ruido en el caso más común.
class RespuestasDelAviso extends ConsumerWidget {
  const RespuestasDelAviso({required this.mensajeId, super.key});

  final String mensajeId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final List<AvisoConRespuestas> avisos =
        ref.watch(avisosConRespuestasProvider).value ??
        const <AvisoConRespuestas>[];
    final AvisoConRespuestas? aviso = avisos
        .where((AvisoConRespuestas a) => a.mensajeId == mensajeId)
        .firstOrNull;
    if (aviso == null) {
      return const SizedBox.shrink();
    }

    final int sinLeer = aviso.sinLeer;
    final String texto = sinLeer > 0
        ? '${Textos.respuestasDeUnAviso(aviso.hilos.length)} · '
              '${Textos.sinLeer(sinLeer)}'
        : Textos.respuestasDeUnAviso(aviso.hilos.length);

    return Padding(
      padding: const EdgeInsets.only(top: 6),
      child: TextButton.icon(
        style: TextButton.styleFrom(
          foregroundColor: PaletaSian.de(context).primarioTexto,
          padding: const EdgeInsets.symmetric(horizontal: 8),
          minimumSize: const Size(48, 40),
        ),
        onPressed: () => showModalBottomSheet<void>(
          context: context,
          showDragHandle: true,
          isScrollControlled: true,
          builder: (BuildContext _) => SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: TarjetaAvisoConRespuestas(aviso: aviso),
            ),
          ),
        ),
        icon: const Icon(Icons.forum_outlined, size: 18),
        label: Text(
          texto,
          style: TextStyle(fontWeight: sinLeer > 0 ? FontWeight.w600 : null),
        ),
      ),
    );
  }
}

