/// SIAN — Bitácora del sistema (RF-BIT-01, RF-BIT-04, RF-BIT-05).
///
/// Solo lectura, y no por omisión: la bitácora es **inmutable** (RF-BIT-03).
/// Ni siquiera existe un camino en la interfaz para editar un asiento, porque
/// tampoco existe en las reglas ni en el servidor.
///
/// Es donde se verifica el criterio de aceptación de RF-AUT-03: que un intento
/// de acceso no autorizado «quede registrado en la bitácora». Por eso los
/// rechazos se destacan en rojo en lugar de perderse entre el resto.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../infrastructure/firebase/repositorio_administracion.dart';
import '../shared/tema.dart';
import '../shared/buscador.dart';
import '../shared/textos.dart';
import 'seccion_usuarios.dart' show repositorioAdminProvider;

/// Filtro por tipo de evento. Cadena vacía significa «todos».
class FiltroBitacora extends Notifier<String> {
  @override
  String build() => '';

  void cambiar(String tipo) => state = tipo;
}

final NotifierProvider<FiltroBitacora, String> filtroBitacoraProvider =
    NotifierProvider<FiltroBitacora, String>(FiltroBitacora.new);

final bitacoraProvider = StreamProvider<List<AsientoVista>>((Ref ref) {
  final String tipo = ref.watch(filtroBitacoraProvider);
  return ref.watch(repositorioAdminProvider).observarBitacora(tipo: tipo);
});

/// Los eventos que ya puede generar el sistema hoy. Crece con cada iteración.
const List<({String valor, String etiqueta})> _tiposFiltrables =
    <({String valor, String etiqueta})>[
      (valor: '', etiqueta: 'Todos los eventos'),
      (valor: 'SESION_INICIADA', etiqueta: 'Inicios de sesión'),
      (valor: 'SESION_RECHAZADA', etiqueta: 'Accesos rechazados'),
      (valor: 'USUARIO_CREADO', etiqueta: 'Altas de usuario'),
      (valor: 'USUARIO_ROL_CAMBIADO', etiqueta: 'Cambios de rol'),
      (valor: 'USUARIO_DESACTIVADO', etiqueta: 'Desactivaciones'),
      (valor: 'USUARIO_REACTIVADO', etiqueta: 'Reactivaciones'),
      (valor: 'INVITACION_CREADA', etiqueta: 'Invitaciones creadas'),
      (valor: 'INVITACION_ELIMINADA', etiqueta: 'Invitaciones revocadas'),
      (valor: 'GRUPO_CREADO', etiqueta: 'Grupos creados'),
      (valor: 'GRUPO_MODIFICADO', etiqueta: 'Grupos modificados'),
    ];

class SeccionBitacora extends ConsumerStatefulWidget {
  const SeccionBitacora({super.key});

  @override
  ConsumerState<SeccionBitacora> createState() => _SeccionBitacoraState();
}

class _SeccionBitacoraState extends ConsumerState<SeccionBitacora> {
  final TextEditingController _busqueda = TextEditingController();

  /// La bitácora crece sin parar y no se borra nunca (RF-BIT-03). Pintarla
  /// entera es lo que la vuelve inservible justo cuando hace falta consultarla.
  static const int _porPagina = 25;
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
    final AsyncValue<List<AsientoVista>> asientos = ref.watch(bitacoraProvider);
    final String filtro = ref.watch(filtroBitacoraProvider);

    return Column(
      children: <Widget>[
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
          child: Row(
            children: <Widget>[
              const Icon(Icons.filter_list),
              const SizedBox(width: 12),
              Expanded(
                child: DropdownButtonFormField<String>(
                  initialValue: filtro,
                  decoration: const InputDecoration(
                    labelText: Textos.filtroTipoEvento,
                    border: OutlineInputBorder(),
                    isDense: true,
                  ),
                  items: <DropdownMenuItem<String>>[
                    for (final ({String valor, String etiqueta}) t
                        in _tiposFiltrables)
                      DropdownMenuItem<String>(
                        value: t.valor,
                        child: Text(t.etiqueta),
                      ),
                  ],
                  onChanged: (String? v) {
                    setState(() => _visibles = _porPagina);
                    ref.read(filtroBitacoraProvider.notifier).cambiar(v ?? '');
                  },
                ),
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
          child: Buscador(
            controlador: _busqueda,
            etiqueta: Textos.buscarBitacora,
            resultados: asientos.maybeWhen(
              data: (List<AsientoVista> l) =>
                  filtrarAsientos(l, _busqueda.text).length,
              orElse: () => null,
            ),
          ),
        ),
        Expanded(
          child: asientos.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (Object e, StackTrace _) => Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(
                  '${Textos.errorCargarDatos}\n\n$e',
                  textAlign: TextAlign.center,
                ),
              ),
            ),
            data: (List<AsientoVista> todos) {
              if (todos.isEmpty) {
                return const Center(child: Text(Textos.bitacoraVacia));
              }

              final List<AsientoVista> filtrados = filtrarAsientos(
                todos,
                _busqueda.text,
              );

              if (filtrados.isEmpty) {
                return Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Text(
                      Textos.sinResultados(_busqueda.text.trim()),
                      textAlign: TextAlign.center,
                    ),
                  ),
                );
              }

              final int hasta = _visibles.clamp(0, filtrados.length);

              return ListView.builder(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                // Una fila de más al final para el botón de «ver más».
                itemCount: hasta + 1,
                itemBuilder: (BuildContext c, int i) {
                  if (i == hasta) {
                    return VerMas(
                      mostrados: hasta,
                      total: filtrados.length,
                      alPulsar: () => setState(() => _visibles += _porPagina),
                    );
                  }
                  return _Asiento(asiento: filtrados[i]);
                },
              );
            },
          ),
        ),
      ],
    );
  }
}

/// Filtra por texto en el resumen, el actor y la entidad.
///
/// Sobre lo ya cargado. Buscar «quién desactivó a fulano» suele ser buscar un
/// correo o un nombre, y eso está en el resumen y en el actor.
List<AsientoVista> filtrarAsientos(
  List<AsientoVista> asientos,
  String termino,
) {
  if (termino.trim().isEmpty) {
    return asientos;
  }
  return asientos
      .where(
        (AsientoVista a) => coincide(termino, <String>[
          a.resumen,
          a.actorCorreo,
          a.entidadId,
          a.tipo,
        ]),
      )
      .toList();
}

class _Asiento extends StatelessWidget {
  const _Asiento({required this.asiento});

  final AsientoVista asiento;

  @override
  Widget build(BuildContext context) {
    final ThemeData tema = Theme.of(context);
    final DateFormat formato = DateFormat('dd/MM/yyyy · HH:mm:ss');

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: Icon(
          _icono(asiento.tipo),
          // Los rechazos de acceso se destacan: son el evento que más interesa
          // auditar (criterio de aceptación de RF-AUT-03).
          color: asiento.esRechazo
              ? ColoresSian.urgente
              : tema.colorScheme.primary,
        ),
        title: Text(asiento.resumen),
        subtitle: Text(
          '${asiento.tipo} · ${asiento.actorCorreo} (${asiento.actorRol})'
          '${asiento.ocurridoEn == null ? '' : ' · ${formato.format(asiento.ocurridoEn!)}'}',
          style: tema.textTheme.bodySmall,
        ),
        isThreeLine: true,
      ),
    );
  }

  IconData _icono(String tipo) => switch (tipo) {
    'SESION_INICIADA' => Icons.login,
    'SESION_RECHAZADA' => Icons.block,
    'SESION_CERRADA' => Icons.logout,
    'USUARIO_CREADO' => Icons.person_add_alt,
    'USUARIO_ROL_CAMBIADO' => Icons.badge_outlined,
    'USUARIO_DESACTIVADO' => Icons.person_off_outlined,
    'USUARIO_REACTIVADO' => Icons.person_outline,
    'INVITACION_CREADA' => Icons.mail_outline,
    'INVITACION_ELIMINADA' => Icons.unsubscribe_outlined,
    'GRUPO_CREADO' || 'GRUPO_MODIFICADO' => Icons.groups_outlined,
    _ => Icons.circle_outlined,
  };
}
