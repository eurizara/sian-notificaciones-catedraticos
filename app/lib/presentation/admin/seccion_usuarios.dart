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
import '../../application/proveedores_catalogos.dart';
import '../../application/proveedores_sede.dart';
import '../../infrastructure/firebase/repositorio_catalogos.dart';
import '../../application/proveedores_sesion.dart';
import '../../domain/sesion.dart';
import 'personas_y_sedes.dart';

final Provider<RepositorioAdministracion> repositorioAdminProvider =
    Provider<RepositorioAdministracion>(
      (Ref ref) => RepositorioAdministracion(),
    );

final invitacionesProvider = StreamProvider<List<InvitacionVista>>(
  (Ref ref) => ref.watch(repositorioAdminProvider).observarInvitaciones(),
);

/// La gente de la sede de trabajo (2.0, RF-SED-05): un coordinador
/// administra a los de su sede, y el servidor rechaza lo demás.
final usuariosProvider = StreamProvider<List<UsuarioVista>>((Ref ref) {
  final String sede = ref.watch(sedeDeTrabajoProvider);
  return ref
      .watch(repositorioAdminProvider)
      .observarUsuarios()
      .map(
        (List<UsuarioVista> todos) =>
            todos.where((UsuarioVista u) => u.perteneceA(sede)).toList(),
      );
});

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
    // 2.0.1: entra en la sede de trabajo, y con las facultades que se elijan.
    final Set<String> facultades = <String>{};
    final List<ElementoCatalogo> catalogo =
        ref.read(facultadesActivasProvider).value ?? const <ElementoCatalogo>[];

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
                    if (catalogo.isNotEmpty) ...<Widget>[
                      const SizedBox(height: 12),
                      const Text(Textos.invitarFacultades),
                      Wrap(
                        spacing: 8,
                        children: <Widget>[
                          for (final ElementoCatalogo f in catalogo)
                            FilterChip(
                              label: Text(f.nombre),
                              selected: facultades.contains(f.id),
                              onSelected: (_) => recargar(() {
                                if (!facultades.remove(f.id)) {
                                  facultades.add(f.id);
                                }
                              }),
                            ),
                        ],
                      ),
                    ],
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
              facultades: facultades.toList(),
            );

      if (!context.mounted) {
        return;
      }

      // El detalle importa tanto como el conteo: sin el número de línea,
      // corregir un CSV de 200 filas es adivinar; y sin separar lo creado de lo
      // que ya estaba, una recarga completa parece un alta masiva.
      final String detalle = Textos.resumenCarga(
        creadas: r.creadas,
        actualizadas: r.actualizadas,
        yaEntraron: r.yaEntraron.length,
        rechazadas: r.rechazadas.length,
      );

      final bool hayDetalle =
          r.rechazadas.isNotEmpty || r.yaEntraron.isNotEmpty;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(detalle),
          duration: const Duration(seconds: 6),
          action: !hayDetalle
              ? null
              : SnackBarAction(
                  label: Textos.botonVerDetalle,
                  onPressed: () => showDialog<void>(
                    context: context,
                    builder: (BuildContext c) => AlertDialog(
                      title: Text(
                        r.rechazadas.isNotEmpty
                            ? Textos.tituloLineasRechazadas
                            : Textos.tituloYaEntraron,
                      ),
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

                            // Quien ya entró no es un error de la carga: es
                            // información que hay que dar, porque su rol NO
                            // cambió y quien cargó la lista probablemente creía
                            // que sí.
                            if (r.yaEntraron.isNotEmpty) ...<Widget>[
                              if (r.rechazadas.isNotEmpty) const Divider(),
                              Padding(
                                padding: const EdgeInsets.fromLTRB(
                                  16,
                                  8,
                                  16,
                                  4,
                                ),
                                child: Text(
                                  Textos.explicacionYaEntraron,
                                  style: Theme.of(c).textTheme.bodySmall,
                                ),
                              ),
                              for (final String correo in r.yaEntraron)
                                ListTile(
                                  dense: true,
                                  leading: const Icon(
                                    Icons.how_to_reg_outlined,
                                    size: 20,
                                  ),
                                  title: Text(correo),
                                ),
                            ],
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

/// Toda la gente, de todas las sedes: solo la administración general la ve,
/// para poner en una sede a quien hoy está en otra (2.0.4).
final StreamProvider<List<UsuarioVista>> usuariosDeTodasLasSedesProvider =
    StreamProvider<List<UsuarioVista>>(
      (Ref ref) => ref.watch(repositorioAdminProvider).observarUsuarios(),
    );

class _Usuarios extends ConsumerStatefulWidget {
  const _Usuarios();

  @override
  ConsumerState<_Usuarios> createState() => _UsuariosState();
}

class _UsuariosState extends ConsumerState<_Usuarios> {
  /// Solo para la administración general: ver también a la gente de otras
  /// sedes. Por omisión, la de la sede de trabajo.
  bool _todas = false;

  @override
  Widget build(BuildContext context) {
    final Sesion sesion = ref.watch(sesionActualProvider);
    final bool adminGeneral =
        sesion is SesionActiva && sesion.usuario.adminGeneral;
    final bool todas = adminGeneral && _todas;
    final AsyncValue<List<UsuarioVista>> lista = ref.watch(
      todas ? usuariosDeTodasLasSedesProvider : usuariosProvider,
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        if (adminGeneral)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
            child: SegmentedButton<bool>(
              segments: const <ButtonSegment<bool>>[
                ButtonSegment<bool>(
                  value: false,
                  label: Text(Textos.usuariosEstaSede),
                ),
                ButtonSegment<bool>(
                  value: true,
                  label: Text(Textos.usuariosTodasLasSedes),
                ),
              ],
              selected: <bool>{_todas},
              onSelectionChanged: (Set<bool> s) =>
                  setState(() => _todas = s.first),
            ),
          ),
        Expanded(
          child: lista.when(
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
          ),
        ),
      ],
    );
  }
}

class _FilaUsuario extends ConsumerWidget {
  const _FilaUsuario({required this.usuario});

  final UsuarioVista usuario;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final RepositorioAdministracion repo = ref.read(repositorioAdminProvider);
    // El rol que se ve y se cambia es el de la sede de trabajo (2.0).
    final String sede = ref.watch(sedeDeTrabajoProvider);
    final String rol = usuario.rolEn(sede);
    final Sesion sesion = ref.watch(sesionActualProvider);
    final bool esUnoMismo =
        sesion is SesionActiva && sesion.usuario.uid == usuario.uid;
    final bool soloCatedratico = usuario.sedesConRol.values.every(
      (String r) => r == 'CATEDRATICO',
    );
    // Mantener a qué facultades pertenece cada uno se puede en cuanto exista
    // una: cuando llegue la segunda, la gente ya estará bien repartida.
    final bool porFacultad =
        (ref.watch(facultadesActivasProvider).value ??
                const <ElementoCatalogo>[])
            .isNotEmpty;
    // 2.0.4: todo lo de una persona se maneja aquí. Sus sedes, solo la
    // administración general; alguien de otra sede (visto con «Todas las
    // sedes») solo muestra sus sedes: su rol y facultades de aquí no existen.
    final bool adminGeneral =
        sesion is SesionActiva && sesion.usuario.adminGeneral;
    final bool deEstaSede = usuario.perteneceA(sede);
    final List<ElementoCatalogo> sedes = adminGeneral
        ? (ref.watch(sedesProvider).value ?? const <ElementoCatalogo>[])
        : const <ElementoCatalogo>[];
    final Map<String, String> nombresDeSede = <String, String>{
      for (final ElementoCatalogo s in sedes) s.id: s.nombre,
    };
    final Widget filaSedes = ListTile(
      title: const Text(Textos.usuarioSedes),
      subtitle: Text(
        <String>[
          for (final MapEntry<String, String> e in usuario.sedesConRol.entries)
            '${nombresDeSede[e.key] ?? e.key} · ${Textos.nombreDeRol(e.value)}',
        ].join('\n'),
      ),
      trailing: Tooltip(
        message: Textos.cambiarSedesDe(
          usuario.nombre.isEmpty ? usuario.correo : usuario.nombre,
        ),
        child: TextButton(
          onPressed: () => showDialog<void>(
            context: context,
            builder: (BuildContext _) => DialogoSedes(
              persona: usuario,
              sedes: sedes,
              esUnoMismo: esUnoMismo,
            ),
          ),
          child: const Text(Textos.usuarioCambiar),
        ),
      ),
    );
    if (!deEstaSede) {
      return Card(
        margin: const EdgeInsets.only(bottom: 8),
        child: ExpansionTile(
          leading: const Icon(Icons.person_outline),
          title: Text(usuario.nombre.isEmpty ? usuario.correo : usuario.nombre),
          subtitle: Text('${usuario.correo} · ${Textos.usuarioDeOtraSede}'),
          children: <Widget>[filaSedes],
        ),
      );
    }

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
          '${usuario.correo} · $rol'
          '${usuario.activo ? '' : ' · ${Textos.usuarioDesactivado}'}',
        ),
        children: <Widget>[
          ListTile(
            title: const Text(Textos.etiquetaRol),
            trailing: DropdownButton<String>(
              value: rol.isEmpty ? null : rol,
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
                if (v == null || v == rol) {
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
          // RF-FAC-01: a qué facultades de la sede pertenece.
          if (porFacultad) _FacultadesDeLaPersona(usuario: usuario, sede: sede),
          // RF-SED-02: en qué sedes está, con qué rol en cada una. Solo el
          // superadministrador: la coordinación no pone a nadie en otra sede.
          if (adminGeneral) filaSedes,
          if (rol == 'ADMINISTRADORA') ...<Widget>[
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

          // Fuera del bloque de emisores: esta bandera aplica a cualquiera.
          // Es justo lo que permite que una persona emita Y reciba sin
          // necesitar dos cuentas — dos cuentas romperían la bitácora, que
          // registraría dos identidades para un mismo humano, y la
          // confirmación de lectura, que la firmaría la cuenta equivocada.
          SwitchListTile(
            title: const Text(Textos.etiquetaRecibeAvisos),
            subtitle: const Text(Textos.detalleRecibeAvisos),
            value: usuario.recibeAvisos,
            onChanged: (bool v) => _ejecutar(
              context,
              () =>
                  repo.cambiarAutorizaciones(uid: usuario.uid, recibeAvisos: v),
              Textos.autorizacionActualizada,
            ),
          ),

          // 2.0.4: solo un superadministrador designa o retira a otro, nunca a
          // sí mismo ni a un catedrático; el servidor tampoco deja retirar al
          // último (`motivoParaNoCambiarSuperadministrador`).
          if (adminGeneral)
            SwitchListTile(
              title: const Text(Textos.administracionGeneral),
              subtitle: Text(
                esUnoMismo
                    ? Textos.adminGeneralPropia
                    : (usuario.adminGeneral || !soloCatedratico)
                    ? Textos.administracionGeneralAyuda
                    : Textos.adminGeneralSinPanel,
              ),
              value: usuario.adminGeneral,
              onChanged:
                  esUnoMismo || (!usuario.adminGeneral && soloCatedratico)
                  ? null
                  : (bool v) => _ejecutar(
                      context,
                      () =>
                          repo.cambiarAdminGeneral(uid: usuario.uid, valor: v),
                      v ? Textos.adminGeneralDada : Textos.adminGeneralQuitada,
                    ),
            ),

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

/// A qué facultades de la sede pertenece (2.0, RF-FAC-01).
class _FacultadesDeLaPersona extends ConsumerWidget {
  const _FacultadesDeLaPersona({required this.usuario, required this.sede});

  final UsuarioVista usuario;
  final String sede;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final List<ElementoCatalogo> catalogo =
        ref.watch(facultadesActivasProvider).value ??
        const <ElementoCatalogo>[];
    final List<String> suyas = usuario.facultadesEn(sede);
    final List<String> nombres = <String>[
      for (final ElementoCatalogo f in catalogo)
        if (suyas.contains(f.id)) f.nombre,
    ];
    return ListTile(
      title: const Text(Textos.usuarioFacultades),
      subtitle: Text(
        nombres.isEmpty ? Textos.usuarioSinFacultad : nombres.join(', '),
      ),
      // El botón dice «Cambiar»; su nombre accesible dice de quién (WCAG 2.4.6).
      trailing: Tooltip(
        message: Textos.usuarioCambiarFacultadesDe(
          usuario.nombre.isEmpty ? usuario.correo : usuario.nombre,
        ),
        child: TextButton(
          onPressed: () => showDialog<void>(
            context: context,
            builder: (BuildContext _) => _DialogoFacultades(
              usuario: usuario,
              catalogo: catalogo,
              iniciales: suyas.toSet(),
            ),
          ),
          child: const Text(Textos.usuarioCambiar),
        ),
      ),
    );
  }
}

class _DialogoFacultades extends ConsumerStatefulWidget {
  const _DialogoFacultades({
    required this.usuario,
    required this.catalogo,
    required this.iniciales,
  });

  final UsuarioVista usuario;
  final List<ElementoCatalogo> catalogo;
  final Set<String> iniciales;

  @override
  ConsumerState<_DialogoFacultades> createState() => _DialogoFacultadesState();
}

class _DialogoFacultadesState extends ConsumerState<_DialogoFacultades> {
  late final Set<String> _elegidas = <String>{...widget.iniciales};
  bool _guardando = false;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(
        Textos.usuarioFacultadesDe(
          widget.usuario.nombre.isEmpty
              ? widget.usuario.correo
              : widget.usuario.nombre,
        ),
      ),
      content: Wrap(
        spacing: 8,
        children: <Widget>[
          for (final ElementoCatalogo f in widget.catalogo)
            FilterChip(
              label: Text(f.nombre),
              selected: _elegidas.contains(f.id),
              onSelected: (_) => setState(() {
                if (!_elegidas.remove(f.id)) {
                  _elegidas.add(f.id);
                }
              }),
            ),
        ],
      ),
      actions: <Widget>[
        TextButton(
          onPressed: _guardando ? null : () => Navigator.of(context).pop(),
          child: const Text(Textos.botonCancelar),
        ),
        FilledButton(
          onPressed: _guardando
              ? null
              : () async {
                  setState(() => _guardando = true);
                  final NavigatorState navegador = Navigator.of(context);
                  await _ejecutar(
                    context,
                    () => ref
                        .read(repositorioAdminProvider)
                        .cambiarFacultades(
                          uid: widget.usuario.uid,
                          facultades: _elegidas.toList(),
                        ),
                    Textos.usuarioFacultadesGuardadas,
                  );
                  if (mounted) {
                    navegador.pop();
                  }
                },
          child: const Text(Textos.grupoGuardar),
        ),
      ],
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
