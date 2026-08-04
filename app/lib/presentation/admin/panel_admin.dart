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
  });

  final IconData icono;
  final String etiqueta;
  final String titulo;
  final String descripcion;
  final List<String> requisitos;
  final String iteracion;

  /// Predicado sobre el rol. Refleja la matriz del documento 01, sección 2.2.
  final bool Function(Rol rol) visiblePara;
}

final List<SeccionAdmin> _secciones = <SeccionAdmin>[
  SeccionAdmin(
    icono: Icons.campaign_outlined,
    etiqueta: Textos.seccionMensajes,
    titulo: Textos.seccionMensajesTitulo,
    descripcion: Textos.seccionMensajesDescripcion,
    requisitos: const <String>['RF-MSG-01', 'RF-MSG-02', 'RF-MSG-13'],
    iteracion: Textos.iteracion13,
    visiblePara: (Rol rol) => rol.esEmisor,
  ),
  SeccionAdmin(
    icono: Icons.schedule_outlined,
    etiqueta: Textos.seccionProgramacion,
    titulo: Textos.seccionProgramacionTitulo,
    descripcion: Textos.seccionProgramacionDescripcion,
    requisitos: const <String>['RF-PRG-02', 'RF-PRG-05', 'RF-PRG-09'],
    iteracion: Textos.iteracion14,
    visiblePara: (Rol rol) => rol.esEmisor,
  ),
  SeccionAdmin(
    icono: Icons.groups_outlined,
    etiqueta: Textos.seccionGrupos,
    titulo: Textos.seccionGruposTitulo,
    descripcion: Textos.seccionGruposDescripcion,
    requisitos: const <String>['RF-USR-03', 'RF-USR-04', 'DT-08'],
    iteracion: Textos.iteracion12,
    visiblePara: (Rol rol) => rol.esEmisor,
  ),
  SeccionAdmin(
    icono: Icons.manage_accounts_outlined,
    etiqueta: Textos.seccionUsuarios,
    titulo: Textos.seccionUsuariosTitulo,
    descripcion: Textos.seccionUsuariosDescripcion,
    requisitos: const <String>['RF-USR-01', 'RF-USR-02', 'RF-AUT-03'],
    iteracion: Textos.iteracion12,
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
    visiblePara: (Rol rol) => rol.esEmisor || rol == Rol.auditor,
  ),
  SeccionAdmin(
    icono: Icons.receipt_long_outlined,
    etiqueta: Textos.seccionBitacora,
    titulo: Textos.seccionBitacoraTitulo,
    descripcion: Textos.seccionBitacoraDescripcion,
    requisitos: const <String>['RF-BIT-01', 'RF-BIT-04', 'RF-BIT-05'],
    iteracion: Textos.iteracion14,
    visiblePara: (Rol rol) => rol.veBitacoraCompleta,
  ),
];

/// Secciones visibles para un rol. Expuesta para poder probarla directamente.
List<SeccionAdmin> seccionesPara(Rol rol) =>
    _secciones.where((SeccionAdmin s) => s.visiblePara(rol)).toList();

class PanelAdmin extends StatefulWidget {
  const PanelAdmin({required this.usuario, super.key});

  final UsuarioSesion usuario;

  @override
  State<PanelAdmin> createState() => _PanelAdminState();
}

class _PanelAdminState extends State<PanelAdmin> {
  int _indice = 0;

  @override
  Widget build(BuildContext context) {
    final List<SeccionAdmin> visibles = seccionesPara(widget.usuario.rol);

    // Un rol sin ninguna sección no debería llegar aquí, pero si llega, lo
    // dice en lugar de reventar con un índice fuera de rango.
    if (visibles.isEmpty) {
      return Scaffold(
        appBar: BarraSesion(
          usuario: widget.usuario,
          titulo: Textos.nombreApp,
        ),
        body: const Center(child: Text(Textos.sinSeccionesDisponibles)),
      );
    }

    final int indice = _indice.clamp(0, visibles.length - 1);
    final SeccionAdmin actual = visibles[indice];

    return Scaffold(
      appBar: BarraSesion(usuario: widget.usuario, titulo: Textos.panelTitulo),
      body: Row(
        children: <Widget>[
          NavigationRail(
            selectedIndex: indice,
            onDestinationSelected: (int i) => setState(() => _indice = i),
            labelType: NavigationRailLabelType.all,
            destinations: <NavigationRailDestination>[
              for (final SeccionAdmin s in visibles)
                NavigationRailDestination(
                  icon: Icon(s.icono),
                  label: Text(s.etiqueta),
                ),
            ],
          ),
          const VerticalDivider(width: 1),
          Expanded(
            child: SeccionPendiente(
              key: ValueKey<String>(actual.etiqueta),
              titulo: actual.titulo,
              descripcion: actual.descripcion,
              requisitos: actual.requisitos,
              iteracion: actual.iteracion,
            ),
          ),
        ],
      ),
    );
  }
}
