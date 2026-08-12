/// SIAN — Panel de administración.
///
/// Lo usan el coordinador, la administradora y el auditor. **Cada uno ve un
/// menú distinto**, calculado a partir de la matriz RBAC del documento 01,
/// sección 2.2.
///
/// Que el menú se filtre por rol es comodidad, no seguridad: aunque alguien
/// forzara la navegación a una sección que no le toca, cada lectura seguiría
/// rebotando contra las reglas de Firestore (RN-01).
library;

import 'package:flutter/material.dart';

import '../../domain/rol.dart';
import '../../domain/sesion.dart';
import '../shared/barra_sesion.dart';
import 'seccion_bitacora.dart';
import 'seccion_entregas.dart';
import 'seccion_mis_mensajes.dart';
import 'seccion_grupos.dart';
import 'seccion_programacion.dart';
import 'seccion_mensajes.dart';
import 'seccion_usuarios.dart';
import '../shared/seccion_pendiente.dart';
import '../shared/textos.dart';

@immutable
class SeccionAdmin {
  const SeccionAdmin({
    required this.icono,
    required this.etiqueta,
    required this.titulo,
    required this.descripcion,
    required this.requisitos,
    required this.iteracion,
    required this.visiblePara,
    this.construir,
    this.visibleSegunPersona,
  });

  final IconData icono;
  final String etiqueta;
  final String titulo;
  final String descripcion;
  final List<String> requisitos;
  final String iteracion;

  /// Predicado sobre el rol. Refleja la matriz del documento 01, sección 2.2.
  final bool Function(Rol rol) visiblePara;

  /// Condición extra sobre la persona concreta, no solo sobre su rol.
  ///
  /// Existe por «Mis mensajes»: quién la ve no depende del rol sino de una
  /// decisión del coordinador sobre esa persona. Sin esto habría que inventar
  /// un rol nuevo para algo que es una bandera.
  final bool Function(UsuarioSesion usuario)? visibleSegunPersona;

  /// Contenido real de la sección. Si es `null`, se muestra el marcador que
  /// declara qué hará y en qué iteración llega.
  final Widget Function()? construir;
}

final List<SeccionAdmin> _secciones = <SeccionAdmin>[
  // Va primero: quien la tiene es porque también es destinatario, y lo que le
  // llega a uno mismo pesa más que lo que uno manda.
  SeccionAdmin(
    icono: Icons.inbox_outlined,
    etiqueta: Textos.seccionMisMensajes,
    titulo: Textos.seccionMisMensajesTitulo,
    descripcion: Textos.seccionMisMensajesDescripcion,
    requisitos: const <String>['RF-ENT-12', 'RF-CNF-01'],
    iteracion: Textos.iteracion13,
    construir: SeccionMisMensajes.new,
    // Solo dentro del panel: un catedrático ya tiene la bandeja como pantalla
    // principal y no necesita una sección para lo mismo.
    visiblePara: (Rol rol) => rol.usaPanelAdministrativo,
    visibleSegunPersona: (UsuarioSesion u) => u.recibeAvisos,
  ),
  SeccionAdmin(
    icono: Icons.campaign_outlined,
    etiqueta: Textos.seccionMensajes,
    titulo: Textos.seccionMensajesTitulo,
    descripcion: Textos.seccionMensajesDescripcion,
    requisitos: const <String>['RF-MSG-01', 'RF-MSG-02', 'RF-MSG-13'],
    iteracion: Textos.iteracion13,
    construir: SeccionMensajes.new,
    visiblePara: (Rol rol) => rol.esEmisor,
  ),
  SeccionAdmin(
    icono: Icons.schedule_outlined,
    etiqueta: Textos.seccionProgramacion,
    titulo: Textos.seccionProgramacionTitulo,
    descripcion: Textos.seccionProgramacionDescripcion,
    requisitos: const <String>['RF-PRG-02', 'RF-PRG-05', 'RF-PRG-09'],
    iteracion: Textos.iteracion14,
    construir: SeccionProgramacion.new,
    visiblePara: (Rol rol) => rol.esEmisor,
  ),
  SeccionAdmin(
    icono: Icons.groups_outlined,
    etiqueta: Textos.seccionGrupos,
    titulo: Textos.seccionGruposTitulo,
    descripcion: Textos.seccionGruposDescripcion,
    requisitos: const <String>['RF-USR-03', 'RF-USR-04', 'DT-08'],
    iteracion: Textos.iteracion12,
    construir: SeccionGrupos.new,
    visiblePara: (Rol rol) => rol.esEmisor,
  ),
  SeccionAdmin(
    icono: Icons.manage_accounts_outlined,
    etiqueta: Textos.seccionUsuarios,
    titulo: Textos.seccionUsuariosTitulo,
    descripcion: Textos.seccionUsuariosDescripcion,
    requisitos: const <String>['RF-USR-01', 'RF-USR-02', 'RF-AUT-03'],
    iteracion: Textos.iteracion12,
    construir: SeccionUsuarios.new,
    // Solo el coordinador administra usuarios y roles.
    visiblePara: (Rol rol) => rol == Rol.coordinador,
  ),
  SeccionAdmin(
    icono: Icons.fact_check_outlined,
    etiqueta: Textos.seccionEntregas,
    titulo: Textos.seccionEntregasTitulo,
    descripcion: Textos.seccionEntregasDescripcion,
    requisitos: const <String>['RF-CNF-06', 'RF-CNF-07', 'RF-BIT-08'],
    iteracion: Textos.iteracion14,
    construir: SeccionEntregas.new,
    visiblePara: (Rol rol) => rol.esEmisor || rol == Rol.auditor,
  ),
  SeccionAdmin(
    icono: Icons.receipt_long_outlined,
    etiqueta: Textos.seccionBitacora,
    titulo: Textos.seccionBitacoraTitulo,
    descripcion: Textos.seccionBitacoraDescripcion,
    requisitos: const <String>['RF-BIT-01', 'RF-BIT-04', 'RF-BIT-05'],
    iteracion: Textos.iteracion14,
    construir: SeccionBitacora.new,
    visiblePara: (Rol rol) => rol.veBitacoraCompleta,
  ),
];

/// Secciones visibles para un rol. Expuesta para poder probarla directamente.
List<SeccionAdmin> seccionesPara(Rol rol) =>
    _secciones.where((SeccionAdmin s) => s.visiblePara(rol)).toList();

/// Secciones visibles para una persona concreta.
///
/// El rol decide casi todo, pero no todo: «Mis mensajes» depende de si el
/// coordinador la marcó como destinataria.
List<SeccionAdmin> seccionesParaUsuario(UsuarioSesion usuario) => _secciones
    .where(
      (SeccionAdmin s) =>
          s.visiblePara(usuario.rol) &&
          (s.visibleSegunPersona?.call(usuario) ?? true),
    )
    .toList();

class PanelAdmin extends StatefulWidget {
  const PanelAdmin({required this.usuario, super.key});

  final UsuarioSesion usuario;

  @override
  State<PanelAdmin> createState() => _PanelAdminState();
}

class _PanelAdminState extends State<PanelAdmin> {
  int _indice = 0;

  /// Una llave global por sección, viva mientras viva el panel.
  ///
  /// ──────────────────────────────────────────────────────────────────────────
  /// GIRAR EL TELÉFONO NO PUEDE BORRAR UN MENSAJE A MEDIO ESCRIBIR.
  /// ──────────────────────────────────────────────────────────────────────────
  ///
  /// El panel se dibuja de dos formas distintas según el ancho: con menú
  /// lateral, el contenido cuelga de una fila; sin él, cuelga directamente del
  /// cuerpo. Girar el aparato cruza ese umbral y **cambia el sitio** que ocupa
  /// el contenido en el árbol.
  ///
  /// Flutter conserva el estado de un widget por su posición, así que ese
  /// cambio de sitio lo daba por muerto y lo reconstruía desde cero: el título,
  /// el mensaje, los adjuntos y los destinatarios elegidos desaparecían de
  /// golpe. Con una alerta urgente a medio redactar, eso es perder el trabajo
  /// justo cuando corre prisa.
  ///
  /// Una llave global es lo único que hace que el estado **viaje** con el
  /// widget al moverse de sitio. Tiene que ser siempre la misma instancia, por
  /// eso vive aquí y no se crea en cada `build`.
  final Map<String, GlobalKey> _llaves = <String, GlobalKey>{};

  GlobalKey _llaveDe(String etiqueta) =>
      _llaves.putIfAbsent(etiqueta, GlobalKey.new);

  /// Por debajo de este ancho el menú lateral no cabe junto al contenido y se
  /// convierte en cajón desplegable.
  ///
  /// No es un capricho de diseño: un coordinador puede tener que lanzar una
  /// alerta de emergencia desde el teléfono, que es precisamente cuando no
  /// está sentado frente a un escritorio.
  static const double _anchoMinimoParaMenuLateral = 700;

  @override
  Widget build(BuildContext context) {
    final List<SeccionAdmin> visibles = seccionesParaUsuario(widget.usuario);

    // Un rol sin ninguna sección no debería llegar aquí, pero si llega, lo
    // dice en lugar de reventar con un índice fuera de rango.
    if (visibles.isEmpty) {
      return Scaffold(
        appBar: BarraSesion(usuario: widget.usuario, titulo: Textos.nombreApp),
        body: const Center(child: Text(Textos.sinSeccionesDisponibles)),
      );
    }

    final int indice = _indice.clamp(0, visibles.length - 1);
    final SeccionAdmin actual = visibles[indice];
    final bool cabeElMenuLateral =
        MediaQuery.sizeOf(context).width >= _anchoMinimoParaMenuLateral;

    final Widget contenido = actual.construir != null
        ? KeyedSubtree(
            key: _llaveDe(actual.etiqueta),
            child: actual.construir!(),
          )
        : SingleChildScrollView(
            child: SeccionPendiente(
              key: _llaveDe(actual.etiqueta),
              titulo: actual.titulo,
              descripcion: actual.descripcion,
              requisitos: actual.requisitos,
              iteracion: actual.iteracion,
            ),
          );

    return Scaffold(
      appBar: BarraSesion(usuario: widget.usuario, titulo: Textos.panelTitulo),
      drawer: cabeElMenuLateral
          ? null
          : Drawer(
              child: SafeArea(
                child: ListView(
                  children: <Widget>[
                    for (int i = 0; i < visibles.length; i += 1)
                      ListTile(
                        leading: Icon(visibles[i].icono),
                        title: Text(visibles[i].etiqueta),
                        selected: i == indice,
                        onTap: () {
                          setState(() => _indice = i);
                          Navigator.of(context).pop();
                        },
                      ),
                  ],
                ),
              ),
            ),
      body: cabeElMenuLateral
          ? Row(
              children: <Widget>[
                // ────────────────────────────────────────────────────────────
                // El menú se desplaza si no cabe.
                // ────────────────────────────────────────────────────────────
                //
                // Con siete secciones y el teléfono en horizontal no caben en
                // 390 píxeles de alto, y sin esto el menú se desbordaba por
                // abajo: las últimas entradas quedaban fuera de la pantalla y
                // no había forma de llegar a ellas.
                LayoutBuilder(
                  builder: (BuildContext _, BoxConstraints limites) =>
                      SingleChildScrollView(
                        child: ConstrainedBox(
                          constraints: BoxConstraints(
                            minHeight: limites.maxHeight,
                          ),
                          child: IntrinsicHeight(
                            child: NavigationRail(
                              selectedIndex: indice,
                              onDestinationSelected: (int i) =>
                                  setState(() => _indice = i),
                              labelType: NavigationRailLabelType.all,
                              destinations: <NavigationRailDestination>[
                                for (final SeccionAdmin s in visibles)
                                  NavigationRailDestination(
                                    icon: Icon(s.icono),
                                    label: Text(s.etiqueta),
                                  ),
                              ],
                            ),
                          ),
                        ),
                      ),
                ),
                const VerticalDivider(width: 1),
                Expanded(child: contenido),
              ],
            )
          : contenido,
    );
  }
}
