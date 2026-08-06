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
import '../../infrastructure/firebase/repositorio_programacion.dart';
import '../shared/buscador.dart';
import '../shared/tema.dart';
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

        final List<MensajeProgramado> filtrados = filtrarProgramados(
          enviados,
          _busqueda.text,
        );
        final List<MensajeProgramado> pagina = filtrados
            .take(_visibles)
            .toList();

        return ListView(
          padding: const EdgeInsets.all(16),
          children: <Widget>[
            if (enviados.length > 5) ...<Widget>[
              Buscador(
                controlador: _busqueda,
                etiqueta: Textos.buscarEntregas,
                resultados: filtrados.length,
              ),
              const SizedBox(height: 16),
            ],
            if (filtrados.isEmpty)
              Padding(
                padding: const EdgeInsets.all(24),
                child: Text(
                  Textos.sinResultados(_busqueda.text.trim()),
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
            const SizedBox(height: 6),

            Wrap(
              spacing: 6,
              runSpacing: 4,
              children: <Widget>[
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
              ],
            ),
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
                  ? ColoresSian.confirmado
                  : porcentaje >= 40
                  ? ColoresSian.dorado
                  : ColoresSian.urgente,
            ),
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
                    color: ColoresSian.doradoTexto,
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
                      color: ColoresSian.urgente,
                    ),
                  ),
                )
              else
                _ListaDestinatarios(
                  destinatarios:
                      _destinatarios ?? const <DestinatarioEntrega>[],
                  porConfirmacion: porConfirmacion,
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
  });

  final List<DestinatarioEntrega> destinatarios;
  final bool porConfirmacion;

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
              const Icon(
                Icons.verified_outlined,
                size: 16,
                color: ColoresSian.confirmado,
              ),
              const SizedBox(width: 8),
              Text(
                Textos.nadiePendiente,
                style: tema.textTheme.bodySmall?.copyWith(
                  color: ColoresSian.confirmado,
                ),
              ),
            ],
          ),

        for (final DestinatarioEntrega d in destinatarios)
          Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: Row(
              children: <Widget>[
                Icon(
                  d.fallo
                      ? Icons.error_outline
                      : d.confirmo
                      ? Icons.check_circle_outline
                      : Icons.schedule,
                  size: 16,
                  // Un fallo de entrega NO es lo mismo que un descuido: uno se
                  // resuelve revisando el dispositivo y el otro insistiendo a
                  // la persona. Pintarlos igual mezclaría dos problemas.
                  color: d.fallo
                      ? ColoresSian.urgente
                      : d.confirmo
                      ? ColoresSian.confirmado
                      : ColoresSian.doradoTexto,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    d.nombre,
                    style: tema.textTheme.bodySmall,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                Text(
                  d.fallo
                      ? Textos.estadoNoLeLlego
                      : d.confirmo
                      ? Textos.estadoConfirmado
                      : porConfirmacion
                      ? Textos.estadoSinConfirmar
                      : Textos.estadoEntregado,
                  style: tema.textTheme.bodySmall?.copyWith(
                    color: tema.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}
