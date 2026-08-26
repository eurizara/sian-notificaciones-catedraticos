/// SIAN — Elección de cuándo sale un aviso (RF-PRG-02, 05..09).
///
/// ────────────────────────────────────────────────────────────────────────────
/// Un patrón de repetición es fácil de escribir y difícil de leer.
/// ────────────────────────────────────────────────────────────────────────────
///
/// «Cada 2 días a las 7:00, lunes y miércoles» suena claro hasta que se ven las
/// fechas reales. Por eso la vista previa no es un adorno ni un botón opcional
/// escondido: sin haber mirado las próximas fechas no se puede programar una
/// repetición (RF-PRG-09). Diez fechas concretas contestan lo que ninguna
/// descripción contesta, y es la última oportunidad de darse cuenta antes de
/// que el aviso empiece a salir solo.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../application/proveedores_programacion.dart';
import '../../infrastructure/firebase/repositorio_programacion.dart';
import '../shared/tema.dart';
import '../shared/textos.dart';

/// Cuándo sale el mensaje.
enum ModoEnvio { ahora, programado, recurrente }

/// Lo que el programador devuelve a la pantalla de redacción.
class EleccionEnvio {
  const EleccionEnvio({
    required this.modo,
    this.fecha,
    this.patron,
    this.vistaPreviaVista = false,
  });

  final ModoEnvio modo;
  final DateTime? fecha;
  final PatronRecurrencia? patron;

  /// Si ya se miraron las próximas fechas. Programar una repetición sin
  /// haberlas visto es exactamente lo que RF-PRG-09 quiere evitar.
  final bool vistaPreviaVista;

  bool get esAhora => modo == ModoEnvio.ahora;
}

class Programador extends ConsumerStatefulWidget {
  const Programador({
    required this.eleccion,
    required this.alCambiar,
    super.key,
  });

  final EleccionEnvio eleccion;
  final ValueChanged<EleccionEnvio> alCambiar;

  @override
  ConsumerState<Programador> createState() => _ProgramadorState();
}

class _ProgramadorState extends ConsumerState<Programador> {
  DateTime? _fecha;
  TimeOfDay? _hora;

  // Recurrencia
  UnidadIntervalo _unidad = UnidadIntervalo.dias;
  int _valor = 1;
  final Set<int> _dias = <int>{};
  TimeOfDay _horaDelDia = const TimeOfDay(hour: 7, minute: 0);
  DateTime? _desde;
  DateTime? _hasta;

  List<OcurrenciaPrevista>? _previa;
  bool _calculando = false;
  String? _error;

  ModoEnvio get _modo => widget.eleccion.modo;

  DateTime? get _fechaCompleta {
    final DateTime? f = _fecha;
    final TimeOfDay? h = _hora;
    if (f == null || h == null) {
      return null;
    }
    return DateTime(f.year, f.month, f.day, h.hour, h.minute);
  }

  PatronRecurrencia? get _patron {
    final DateTime? d = _desde;
    final DateTime? h = _hasta;
    if (d == null || h == null || !h.isAfter(d)) {
      return null;
    }
    return PatronRecurrencia(
      fechaInicio: d,
      fechaFin: h,
      unidad: _unidad,
      valor: _valor,
      diasSemana: _dias,
      horaDelDia:
          '${_horaDelDia.hour.toString().padLeft(2, '0')}:'
          '${_horaDelDia.minute.toString().padLeft(2, '0')}',
    );
  }

  void _publicar() {
    widget.alCambiar(
      EleccionEnvio(
        modo: _modo,
        fecha: _fechaCompleta,
        patron: _patron,
        vistaPreviaVista: _previa != null && _previa!.isNotEmpty,
      ),
    );
  }

  void _cambiarModo(ModoEnvio m) {
    setState(() {
      _previa = null;
      _error = null;
    });
    widget.alCambiar(
      EleccionEnvio(modo: m, fecha: _fechaCompleta, patron: _patron),
    );
  }

  Future<void> _elegirFecha({
    required bool esDesde,
    required bool esHasta,
  }) async {
    final DateTime ahora = DateTime.now();
    final DateTime? d = await showDatePicker(
      context: context,
      initialDate: ahora,
      firstDate: ahora.subtract(const Duration(days: 1)),
      lastDate: ahora.add(const Duration(days: 365 * 2)),
    );
    if (d == null) {
      return;
    }
    setState(() {
      if (esDesde) {
        _desde = d;
      } else if (esHasta) {
        _hasta = d;
      } else {
        _fecha = d;
      }
      // Cambiar el patrón invalida lo que se vio: obligar a mirar otra vez es
      // el punto de la vista previa.
      _previa = null;
    });
    _publicar();
  }

  Future<void> _elegirHora({required bool esDelPatron}) async {
    final TimeOfDay? h = await showTimePicker(
      context: context,
      initialTime: esDelPatron ? _horaDelDia : (_hora ?? TimeOfDay.now()),
    );
    if (h == null) {
      return;
    }
    setState(() {
      if (esDelPatron) {
        _horaDelDia = h;
      } else {
        _hora = h;
      }
      _previa = null;
    });
    _publicar();
  }

  Future<void> _calcularPrevia() async {
    final PatronRecurrencia? p = _patron;
    if (p == null) {
      setState(() => _error = Textos.validacionRangoInvalido);
      return;
    }

    setState(() {
      _calculando = true;
      _error = null;
    });

    try {
      final List<OcurrenciaPrevista> o = await ref
          .read(repositorioProgramacionProvider)
          .vistaPrevia(p);
      if (!mounted) {
        return;
      }
      setState(() {
        _previa = o;
        _error = o.isEmpty ? Textos.vistaPreviaVacia : null;
      });
      _publicar();
    } on Object catch (e) {
      if (mounted) {
        setState(() => _error = '$e');
      }
    } finally {
      if (mounted) {
        setState(() => _calculando = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData tema = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(Textos.cuandoEnviar, style: tema.textTheme.titleSmall),
        const SizedBox(height: 8),

        RadioGroup<ModoEnvio>(
          groupValue: _modo,
          onChanged: (ModoEnvio? m) => _cambiarModo(m ?? ModoEnvio.ahora),
          child: const Column(
            children: <Widget>[
              RadioListTile<ModoEnvio>(
                value: ModoEnvio.ahora,
                title: Text(Textos.cuandoAhora),
                contentPadding: EdgeInsets.zero,
              ),
              RadioListTile<ModoEnvio>(
                value: ModoEnvio.programado,
                title: Text(Textos.cuandoProgramado),
                contentPadding: EdgeInsets.zero,
              ),
              RadioListTile<ModoEnvio>(
                value: ModoEnvio.recurrente,
                title: Text(Textos.cuandoRecurrente),
                contentPadding: EdgeInsets.zero,
              ),
            ],
          ),
        ),

        if (_modo == ModoEnvio.programado) ...<Widget>[
          const SizedBox(height: 8),
          Wrap(
            spacing: 12,
            runSpacing: 8,
            children: <Widget>[
              OutlinedButton.icon(
                onPressed: () => _elegirFecha(esDesde: false, esHasta: false),
                icon: const Icon(Icons.event),
                label: Text(
                  _fecha == null
                      ? Textos.elegirFecha
                      : '${_fecha!.day}/${_fecha!.month}/${_fecha!.year}',
                ),
              ),
              OutlinedButton.icon(
                onPressed: () => _elegirHora(esDelPatron: false),
                icon: const Icon(Icons.schedule),
                label: Text(
                  _hora == null ? Textos.elegirHora : _hora!.format(context),
                ),
              ),
            ],
          ),
        ],

        if (_modo == ModoEnvio.recurrente) ...<Widget>[
          const SizedBox(height: 8),
          _Patron(
            unidad: _unidad,
            valor: _valor,
            dias: _dias,
            horaDelDia: _horaDelDia,
            desde: _desde,
            hasta: _hasta,
            alCambiarUnidad: (UnidadIntervalo u) {
              setState(() {
                _unidad = u;
                _previa = null;
              });
              _publicar();
            },
            alCambiarValor: (int v) {
              setState(() {
                _valor = v;
                _previa = null;
              });
              _publicar();
            },
            alAlternarDia: (int d) {
              setState(() {
                if (!_dias.remove(d)) {
                  _dias.add(d);
                }
                _previa = null;
              });
              _publicar();
            },
            alElegirDesde: () => _elegirFecha(esDesde: true, esHasta: false),
            alElegirHasta: () => _elegirFecha(esDesde: false, esHasta: true),
            alElegirHora: () => _elegirHora(esDelPatron: true),
          ),
          const SizedBox(height: 12),

          Text(
            Textos.vistaPreviaPorQue,
            style: tema.textTheme.bodySmall?.copyWith(
              color: tema.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 8),
          FilledButton.tonalIcon(
            onPressed: _calculando ? null : _calcularPrevia,
            icon: const Icon(Icons.event_repeat),
            label: Text(
              _calculando
                  ? Textos.vistaPreviaCalculando
                  : Textos.vistaPreviaCalcular,
            ),
          ),

          if (_previa != null && _previa!.isNotEmpty) ...<Widget>[
            const SizedBox(height: 12),
            Card(
              color: ColoresSian.primario.withValues(alpha: 0.06),
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      Textos.vistaPreviaTitulo,
                      style: tema.textTheme.titleSmall,
                    ),
                    const SizedBox(height: 8),
                    for (final OcurrenciaPrevista o in _previa!)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 2),
                        child: Text(
                          '${o.numero}.  ${o.local}',
                          style: tema.textTheme.bodySmall,
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ],
        ],

        if (_error != null) ...<Widget>[
          const SizedBox(height: 8),
          Text(
            _error!,
            style: tema.textTheme.bodySmall?.copyWith(
              color: ColoresSian.urgente,
            ),
          ),
        ],
      ],
    );
  }
}

class _Patron extends StatelessWidget {
  const _Patron({
    required this.unidad,
    required this.valor,
    required this.dias,
    required this.horaDelDia,
    required this.desde,
    required this.hasta,
    required this.alCambiarUnidad,
    required this.alCambiarValor,
    required this.alAlternarDia,
    required this.alElegirDesde,
    required this.alElegirHasta,
    required this.alElegirHora,
  });

  final UnidadIntervalo unidad;
  final int valor;
  final Set<int> dias;
  final TimeOfDay horaDelDia;
  final DateTime? desde;
  final DateTime? hasta;
  final ValueChanged<UnidadIntervalo> alCambiarUnidad;
  final ValueChanged<int> alCambiarValor;
  final ValueChanged<int> alAlternarDia;
  final VoidCallback alElegirDesde;
  final VoidCallback alElegirHasta;
  final VoidCallback alElegirHora;

  String _fmt(DateTime? d) => d == null ? '—' : '${d.day}/${d.month}/${d.year}';

  @override
  Widget build(BuildContext context) {
    final ThemeData tema = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Row(
          children: <Widget>[
            Text(Textos.repetirCada, style: tema.textTheme.bodyMedium),
            const SizedBox(width: 12),
            SizedBox(
              width: 72,
              child: DropdownButtonFormField<int>(
                initialValue: valor,
                isDense: true,
                items: <int>[1, 2, 3, 5, 7, 10, 15, 30]
                    .map(
                      (int v) =>
                          DropdownMenuItem<int>(value: v, child: Text('$v')),
                    )
                    .toList(),
                onChanged: (int? v) => alCambiarValor(v ?? 1),
              ),
            ),
            const SizedBox(width: 12),
            SizedBox(
              width: 130,
              child: DropdownButtonFormField<UnidadIntervalo>(
                initialValue: unidad,
                isDense: true,
                items: UnidadIntervalo.values
                    .map(
                      (UnidadIntervalo u) => DropdownMenuItem<UnidadIntervalo>(
                        value: u,
                        child: Text(u.etiqueta),
                      ),
                    )
                    .toList(),
                onChanged: (UnidadIntervalo? u) =>
                    alCambiarUnidad(u ?? UnidadIntervalo.dias),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),

        Wrap(
          spacing: 12,
          runSpacing: 8,
          children: <Widget>[
            OutlinedButton.icon(
              onPressed: alElegirDesde,
              icon: const Icon(Icons.event_available),
              label: Text('${Textos.repetirDesde}: ${_fmt(desde)}'),
            ),
            OutlinedButton.icon(
              onPressed: alElegirHasta,
              icon: const Icon(Icons.event_busy),
              label: Text('${Textos.repetirHasta}: ${_fmt(hasta)}'),
            ),
            if (unidad == UnidadIntervalo.dias)
              OutlinedButton.icon(
                onPressed: alElegirHora,
                icon: const Icon(Icons.schedule),
                label: Text(
                  '${Textos.repetirHora} ${horaDelDia.format(context)}',
                ),
              ),
          ],
        ),

        // Una repetición sin fecha de fin es un envío sin freno esperando a
        // que alguien se acuerde de pararlo (RF-PRG-14).
        if (hasta == null) ...<Widget>[
          const SizedBox(height: 8),
          Text(
            Textos.recurrenciaFinObligatoria,
            style: tema.textTheme.bodySmall?.copyWith(
              color: ColoresSian.doradoTexto,
            ),
          ),
        ],

        if (unidad == UnidadIntervalo.dias) ...<Widget>[
          const SizedBox(height: 12),
          Text(Textos.repetirDias, style: tema.textTheme.bodySmall),
          const SizedBox(height: 4),
          Wrap(
            spacing: 6,
            children: <Widget>[
              for (int d = 1; d <= 7; d += 1)
                FilterChip(
                  label: Text(Textos.diaSemanaCorto(d)),
                  selected: dias.contains(d),
                  onSelected: (_) => alAlternarDia(d),
                ),
            ],
          ),
          if (dias.isEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(
                Textos.repetirTodosLosDias,
                style: tema.textTheme.bodySmall?.copyWith(
                  color: tema.colorScheme.onSurfaceVariant,
                ),
              ),
            ),
        ],
      ],
    );
  }
}
