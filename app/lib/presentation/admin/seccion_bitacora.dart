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

class SeccionBitacora extends ConsumerWidget {
  const SeccionBitacora({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AsyncValue<List<AsientoVista>> asientos = ref.watch(bitacoraProvider);
    final String filtro = ref.watch(filtroBitacoraProvider);

    return Column(
      children: <Widget>[
        Padding(
          padding: const EdgeInsets.all(16),
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
                    for (final ({String valor, String etiqueta}) t in _tiposFiltrables)
                      DropdownMenuItem<String>(
                        value: t.valor,
                        child: Text(t.etiqueta),
                      ),
                  ],
                  onChanged: (String? v) =>
                      ref.read(filtroBitacoraProvider.notifier).cambiar(v ?? ''),
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: asientos.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (Object e, StackTrace _) => Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text('${Textos.errorCargarDatos}\n\n$e', textAlign: TextAlign.center),
              ),
            ),
            data: (List<AsientoVista> lista) => lista.isEmpty
                ? const Center(child: Text(Textos.bitacoraVacia))
                : ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    itemCount: lista.length,
                    itemBuilder: (BuildContext c, int i) => _Asiento(asiento: lista[i]),
                  ),
          ),
        ),
      ],
    );
  }
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
          color: asiento.esRechazo ? ColoresSian.urgente : tema.colorScheme.primary,
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
