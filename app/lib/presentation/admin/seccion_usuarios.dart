/// SIAN — Usuarios, roles e invitaciones (RF-USR-01, RF-USR-02, RF-AUT-08).
///
/// Solo el coordinador llega aquí. El filtrado del menú es comodidad; lo que
/// de verdad lo impide es que cada Function comprueba el permiso contra los
/// custom claims antes de tocar nada (RN-01).
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../infrastructure/firebase/repositorio_administracion.dart';
import '../shared/textos.dart';

final Provider<RepositorioAdministracion> repositorioAdminProvider =
    Provider<RepositorioAdministracion>(
      (Ref ref) => RepositorioAdministracion(),
    );

final invitacionesProvider = StreamProvider<List<InvitacionVista>>(
  (Ref ref) => ref.watch(repositorioAdminProvider).observarInvitaciones(),
);

final usuariosProvider = StreamProvider<List<UsuarioVista>>(
  (Ref ref) => ref.watch(repositorioAdminProvider).observarUsuarios(),
);

class SeccionUsuarios extends ConsumerWidget {
  const SeccionUsuarios({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return const DefaultTabController(
      length: 2,
      child: Column(
        children: <Widget>[
          TabBar(
            tabs: <Widget>[
              Tab(
                text: Textos.pestanaInvitaciones,
                icon: Icon(Icons.mail_outline),
              ),
              Tab(
                text: Textos.pestanaUsuarios,
                icon: Icon(Icons.people_outline),
              ),
            ],
          ),
          Expanded(
            child: TabBarView(children: <Widget>[_Invitaciones(), _Usuarios()]),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Invitaciones — la lista blanca (RF-AUT-03)
// ---------------------------------------------------------------------------

class _Invitaciones extends ConsumerWidget {
  const _Invitaciones();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AsyncValue<List<InvitacionVista>> lista = ref.watch(
      invitacionesProvider,
    );

    return Scaffold(
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _abrirDialogo(context, ref),
        icon: const Icon(Icons.person_add_alt),
        label: const Text(Textos.botonInvitar),
      ),
      body: lista.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (Object e, StackTrace _) => _Error(detalle: e.toString()),
        data: (List<InvitacionVista> invitaciones) => invitaciones.isEmpty
            ? const _Vacio(mensaje: Textos.sinInvitaciones)
            : ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: invitaciones.length,
                itemBuilder: (BuildContext c, int i) {
                  final InvitacionVista inv = invitaciones[i];
                  return Card(
                    margin: const EdgeInsets.only(bottom: 8),
                    child: ListTile(
                      leading: Icon(
                        inv.consumida
                            ? Icons.how_to_reg
                            : Icons.mark_email_unread_outlined,
                        color: inv.consumida
                            ? Theme.of(c).colorScheme.primary
                            : Theme.of(c).colorScheme.tertiary,
                      ),
                      title: Text(inv.correo),
                      subtitle: Text(
                        '${inv.rolAsignado}'
                        '${inv.nombre.isEmpty ? '' : ' · ${inv.nombre}'}'
                        ' · ${inv.consumida ? Textos.invitacionConsumida : Textos.invitacionPendiente}',
                      ),
                      trailing: inv.consumida
                          // Revocar una invitación ya consumida no haría nada:
                          // el usuario ya tiene perfil. Para retirarle el
                          // acceso hay que desactivar su cuenta (RN-10).
                          ? null
                          : IconButton(
                              icon: const Icon(Icons.delete_outline),
                              tooltip: Textos.botonRevocar,
                              onPressed: () =>
                                  _revocar(context, ref, inv.correo),
                            ),
                    ),
                  );
                },
              ),
      ),
    );
  }

  Future<void> _revocar(
    BuildContext context,
    WidgetRef ref,
    String correo,
  ) async {
    final bool? confirmado = await showDialog<bool>(
      context: context,
      builder: (BuildContext c) => AlertDialog(
        title: const Text(Textos.botonRevocar),
        content: Text(Textos.confirmarRevocar(correo)),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.pop(c, false),
            child: const Text(Textos.botonCancelar),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(c, true),
            child: const Text(Textos.botonRevocar),
          ),
        ],
      ),
    );

    if (confirmado != true || !context.mounted) {
      return;
    }
    await _ejecutar(
      context,
      () => ref.read(repositorioAdminProvider).revocarInvitacion(correo),
      Textos.invitacionRevocada,
    );
  }

  Future<void> _abrirDialogo(BuildContext context, WidgetRef ref) async {
    final TextEditingController correo = TextEditingController();
    final TextEditingController nombre = TextEditingController();
    final TextEditingController csv = TextEditingController();
    String rol = 'CATEDRATICO';
    bool masiva = false;

    final bool? enviar = await showDialog<bool>(
      context: context,
      builder: (BuildContext c) => StatefulBuilder(
        builder: (BuildContext c, StateSetter recargar) => AlertDialog(
          title: Text(masiva ? Textos.tituloCargaMasiva : Textos.tituloInvitar),
          content: SizedBox(
            width: 420,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: <Widget>[
                  SegmentedButton<bool>(
                    segments: const <ButtonSegment<bool>>[
                      ButtonSegment<bool>(
                        value: false,
                        label: Text(Textos.modoUnaAUna),
                      ),
                      ButtonSegment<bool>(
                        value: true,
                        label: Text(Textos.modoCsv),
                      ),
                    ],
                    selected: <bool>{masiva},
                    onSelectionChanged: (Set<bool> s) =>
                        recargar(() => masiva = s.first),
                  ),
                  const SizedBox(height: 16),
                  if (!masiva) ...<Widget>[
                    TextField(
                      controller: correo,
                      decoration: const InputDecoration(
                        labelText: Textos.etiquetaCorreo,
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: nombre,
                      decoration: const InputDecoration(
                        labelText: Textos.etiquetaNombre,
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String>(
                      initialValue: rol,
                      decoration: const InputDecoration(
                        labelText: Textos.etiquetaRol,
                        border: OutlineInputBorder(),
                      ),
                      items: const <DropdownMenuItem<String>>[
                        DropdownMenuItem<String>(
                          value: 'CATEDRATICO',
                          child: Text('Catedrático'),
                        ),
                        DropdownMenuItem<String>(
                          value: 'ADMINISTRADORA',
                          child: Text('Administradora Académica'),
                        ),
                        DropdownMenuItem<String>(
                          value: 'AUDITOR',
                          child: Text('Auditor'),
                        ),
                        DropdownMenuItem<String>(
                          value: 'COORDINADOR',
                          child: Text('Coordinador Académico'),
                        ),
                      ],
                      onChanged: (String? v) => recargar(() => rol = v ?? rol),
                    ),
                  ] else ...<Widget>[
                    const Text(Textos.ayudaCsv),
                    const SizedBox(height: 12),
                    TextField(
                      controller: csv,
                      minLines: 5,
                      maxLines: 10,
                      decoration: const InputDecoration(
                        border: OutlineInputBorder(),
                        hintText:
                            'correo,rol,nombre\nana@umg.edu.gt,CATEDRATICO,Ana Pérez',
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.pop(c, false),
              child: const Text(Textos.botonCancelar),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(c, true),
              child: const Text(Textos.botonInvitar),
            ),
          ],
        ),
      ),
    );

    if (enviar != true || !context.mounted) {
      return;
    }

    final RepositorioAdministracion repo = ref.read(repositorioAdminProvider);
    try {
      final ResultadoCarga r = masiva
          ? await repo.cargarCsv(csv.text)
          : await repo.crearInvitacion(
              correo: correo.text,
              rol: rol,
              nombre: nombre.text,
            );

      if (!context.mounted) {
        return;
      }

      // El detalle de lo rechazado importa tanto como el conteo de lo creado:
      // sin el número de línea, corregir un CSV de 200 filas es adivinar.
      final String detalle = r.rechazadas.isEmpty
          ? Textos.cargaCorrecta(r.creadas)
          : Textos.cargaParcial(r.creadas, r.rechazadas.length);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(detalle),
          duration: const Duration(seconds: 6),
          action: r.rechazadas.isEmpty
              ? null
              : SnackBarAction(
                  label: Textos.botonVerDetalle,
                  onPressed: () => showDialog<void>(
                    context: context,
                    builder: (BuildContext c) => AlertDialog(
                      title: const Text(Textos.tituloLineasRechazadas),
                      content: SizedBox(
                        width: 420,
                        child: ListView(
                          shrinkWrap: true,
                          children: <Widget>[
                            for (final ({int numero, String error}) x
                                in r.rechazadas)
                              ListTile(
                                dense: true,
                                leading: Text('${x.numero}'),
                                title: Text(x.error),
                              ),
                          ],
                        ),
                      ),
                      actions: <Widget>[
                        TextButton(
                          onPressed: () => Navigator.pop(c),
                          child: const Text(Textos.botonCerrar),
                        ),
                      ],
                    ),
                  ),
                ),
        ),
      );
    } on Object catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('${Textos.errorOperacion} $e')));
      }
    }
  }
}

// ---------------------------------------------------------------------------
// Usuarios ya dados de alta — RF-USR-02, RF-AUT-08
// ---------------------------------------------------------------------------

class _Usuarios extends ConsumerWidget {
  const _Usuarios();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AsyncValue<List<UsuarioVista>> lista = ref.watch(usuariosProvider);

    return lista.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (Object e, StackTrace _) => _Error(detalle: e.toString()),
      data: (List<UsuarioVista> usuarios) => usuarios.isEmpty
          ? const _Vacio(mensaje: Textos.sinUsuarios)
          : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: usuarios.length,
              itemBuilder: (BuildContext c, int i) =>
                  _FilaUsuario(usuario: usuarios[i]),
            ),
    );
  }
}

class _FilaUsuario extends ConsumerWidget {
  const _FilaUsuario({required this.usuario});

  final UsuarioVista usuario;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final RepositorioAdministracion repo = ref.read(repositorioAdminProvider);

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ExpansionTile(
        leading: Icon(
          usuario.activo ? Icons.person_outline : Icons.person_off_outlined,
          color: usuario.activo
              ? Theme.of(context).colorScheme.primary
              : Theme.of(context).colorScheme.outline,
        ),
        title: Text(usuario.nombre.isEmpty ? usuario.correo : usuario.nombre),
        subtitle: Text(
          '${usuario.correo} · ${usuario.rol}'
          '${usuario.activo ? '' : ' · ${Textos.usuarioDesactivado}'}',
        ),
        children: <Widget>[
          ListTile(
            title: const Text(Textos.etiquetaRol),
            trailing: DropdownButton<String>(
              value: usuario.rol.isEmpty ? null : usuario.rol,
              items: const <DropdownMenuItem<String>>[
                DropdownMenuItem<String>(
                  value: 'CATEDRATICO',
                  child: Text('Catedrático'),
                ),
                DropdownMenuItem<String>(
                  value: 'ADMINISTRADORA',
                  child: Text('Administradora'),
                ),
                DropdownMenuItem<String>(
                  value: 'AUDITOR',
                  child: Text('Auditor'),
                ),
                DropdownMenuItem<String>(
                  value: 'COORDINADOR',
                  child: Text('Coordinador'),
                ),
              ],
              onChanged: (String? v) {
                if (v == null || v == usuario.rol) {
                  return;
                }
                _ejecutar(
                  context,
                  () => repo.cambiarRol(uid: usuario.uid, rol: v),
                  Textos.rolCambiado,
                );
              },
            ),
          ),
          // Solo tienen sentido para quien emite.
          if (usuario.rol == 'ADMINISTRADORA') ...<Widget>[
            SwitchListTile(
              title: const Text(Textos.autorizacionUrgentes),
              subtitle: const Text(Textos.autorizacionUrgentesAyuda),
              value: usuario.puedeEmitirUrgentes,
              onChanged: (bool v) => _ejecutar(
                context,
                () => repo.cambiarAutorizaciones(
                  uid: usuario.uid,
                  puedeEmitirUrgentes: v,
                ),
                Textos.autorizacionActualizada,
              ),
            ),
            SwitchListTile(
              title: const Text(Textos.autorizacionRecurrentes),
              value: usuario.puedeCrearRecurrentes,
              onChanged: (bool v) => _ejecutar(
                context,
                () => repo.cambiarAutorizaciones(
                  uid: usuario.uid,
                  puedeCrearRecurrentes: v,
                ),
                Textos.autorizacionActualizada,
              ),
            ),
          ],
          SwitchListTile(
            title: const Text(Textos.cuentaActiva),
            // RN-10: se desactiva, no se borra. El historial queda íntegro.
            subtitle: const Text(Textos.cuentaActivaAyuda),
            value: usuario.activo,
            onChanged: (bool v) => _ejecutar(
              context,
              () => repo.cambiarEstado(uid: usuario.uid, activo: v),
              v ? Textos.cuentaReactivada : Textos.cuentaDesactivada,
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------

Future<void> _ejecutar(
  BuildContext context,
  Future<void> Function() accion,
  String exito,
) async {
  try {
    await accion();
    if (context.mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(exito)));
    }
  } on Object catch (e) {
    if (context.mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('${Textos.errorOperacion} $e')));
    }
  }
}

class _Vacio extends StatelessWidget {
  const _Vacio({required this.mensaje});

  final String mensaje;

  @override
  Widget build(BuildContext context) => Center(
    child: Padding(padding: const EdgeInsets.all(24), child: Text(mensaje)),
  );
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
            Icon(Icons.error_outline, size: 40, color: tema.colorScheme.error),
            const SizedBox(height: 12),
            Text(Textos.errorCargarDatos, style: tema.textTheme.titleMedium),
            const SizedBox(height: 8),
            Text(
              detalle,
              textAlign: TextAlign.center,
              style: tema.textTheme.bodySmall,
            ),
          ],
        ),
      ),
    );
  }
}
