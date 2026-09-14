/// SIAN — En Android, que la aplicación pueda trabajar en segundo plano.
///
/// ────────────────────────────────────────────────────────────────────────────
/// Lo que se midió el 13 de septiembre de 2026
/// ────────────────────────────────────────────────────────────────────────────
///
/// En un Android con todo concedido —permiso del sitio, notificaciones de la
/// aplicación, canal «General» activo— los avisos llegaban tarde y **todos de
/// golpe**, y además con la cabecera «Chrome». El servidor los había entregado
/// en segundos y el service worker había dicho que los mostró.
///
/// La causa estaba en un ajuste del teléfono: **«Permitir uso en segundo
/// plano» venía apagado** para la aplicación instalada. Leyendo el código de
/// Chrome se entiende por qué eso retiene los avisos: cuando el sitio tiene una
/// aplicación instalada, Chrome se conecta a ella antes de mostrar cada
/// notificación, y si Android no la deja despertar, **espera sin plazo** y va
/// encolando las que llegan. Al dar la conexión por perdida las suelta todas, y
/// como no pudo hablar con la aplicación, a su propio nombre.
///
/// Con el ajuste encendido, los dos avisos siguientes llegaron en 3 y 4
/// segundos, y a nombre de SIAN.
///
/// ────────────────────────────────────────────────────────────────────────────
/// Por qué es una guía y no un arreglo
/// ────────────────────────────────────────────────────────────────────────────
///
/// Desde la web no hay nada que hacer por la persona:
///
///   · pedir que no le apliquen el ahorro de batería es un permiso de
///     aplicación nativa, y la aplicación instalada la genera Google;
///   · Chrome no deja abrir desde una página los ajustes del sistema;
///   · no existe forma de consultar si el ajuste está apagado.
///
/// Por eso se enseña **a todo Android con la aplicación instalada y las
/// notificaciones concedidas**, una sola vez: no se puede elegir solo a quien
/// lo tiene apagado. Sin la aplicación instalada no aplica —no hay aplicación a
/// la que conectarse—, y sin permiso lo primero es la tarjeta de activar.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../application/proveedores_dispositivos.dart';
import '../../core/navegador.dart';
import '../../core/plataforma/almacen_local.dart';
import '../../infrastructure/firebase/repositorio_dispositivos.dart';
import '../shared/tema.dart';
import '../shared/textos.dart';

/// Dónde se recuerda que la persona ya la vio. Por aparato, como el ajuste.
const String claveGuiaSegundoPlano = 'sian.guia-segundo-plano';

/// ¿Hay que enseñarla en este aparato?
bool debeMostrarGuiaSegundoPlano({
  required EntornoNavegador entorno,
  required EstadoPermiso permiso,
  required bool yaVista,
}) =>
    entorno.plataforma == PlataformaWeb.android &&
    entorno.instalada &&
    permiso == EstadoPermiso.concedido &&
    !yaVista;

class GuiaSegundoPlano extends ConsumerStatefulWidget {
  const GuiaSegundoPlano({super.key});

  @override
  ConsumerState<GuiaSegundoPlano> createState() => _GuiaSegundoPlanoState();
}

class _GuiaSegundoPlanoState extends ConsumerState<GuiaSegundoPlano> {
  EstadoPermiso? _permiso;
  bool _yaVista = leerLocal(claveGuiaSegundoPlano) == 'vista';

  @override
  void initState() {
    super.initState();
    if (!_yaVista) {
      _consultar();
    }
  }

  Future<void> _consultar() async {
    final EstadoPermiso p;
    try {
      p = await ref.read(repositorioDispositivosProvider).consultarPermiso();
    } on Object {
      // Sin saber el permiso no se enseña: una guía de ajustes a quien no
      // puede recibir notificaciones sería ruido encima del problema real.
      return;
    }
    if (mounted) {
      setState(() => _permiso = p);
    }
  }

  void _marcarVista() {
    guardarLocal(claveGuiaSegundoPlano, 'vista');
    setState(() => _yaVista = true);
  }

  @override
  Widget build(BuildContext context) {
    final EstadoPermiso? permiso = _permiso;
    if (permiso == null ||
        !debeMostrarGuiaSegundoPlano(
          entorno: ref.read(repositorioDispositivosProvider).entorno,
          permiso: permiso,
          yaVista: _yaVista,
        )) {
      return const SizedBox.shrink();
    }

    final ThemeData tema = Theme.of(context);
    final PaletaSian paleta = PaletaSian.de(context);

    Widget paso(int n, String texto) => Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          SizedBox(
            width: 24,
            child: Text('$n.', style: tema.textTheme.bodyMedium),
          ),
          Expanded(child: Text(texto, style: tema.textTheme.bodyMedium)),
        ],
      ),
    );

    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      color: paleta.primario.withValues(alpha: 0.08),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Row(
              children: <Widget>[
                Icon(Icons.battery_charging_full, color: paleta.primario),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    Textos.segundoPlanoTitulo,
                    style: tema.textTheme.titleMedium,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            const Text(Textos.segundoPlanoPorQue),
            paso(1, Textos.segundoPlanoPaso1),
            paso(2, Textos.segundoPlanoPaso2),
            paso(3, Textos.segundoPlanoPaso3),
            const SizedBox(height: 12),
            Text(
              Textos.segundoPlanoNoAnular,
              style: tema.textTheme.bodySmall?.copyWith(
                color: tema.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 12),
            FilledButton(
              onPressed: _marcarVista,
              child: const Text(Textos.botonSegundoPlanoListo),
            ),
          ],
        ),
      ),
    );
  }
}
