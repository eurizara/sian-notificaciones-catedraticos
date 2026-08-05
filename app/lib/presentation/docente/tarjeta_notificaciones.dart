/// SIAN — Estado de las notificaciones del dispositivo (RF-USR-09, RES-05,
/// RES-07).
///
/// Esta tarjeta responde una sola pregunta, y es la que más importa en todo el
/// sistema: **¿me va a llegar el aviso?** Todo lo demás —el panel, la
/// bitácora, la programación— no sirve de nada si la respuesta es «no» y nadie
/// se entera.
///
/// Por eso no se limita a pedir el permiso: distingue los tres motivos por los
/// que un dispositivo puede quedarse mudo, y para cada uno dice qué hacer.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../application/proveedores_dispositivos.dart';
import '../../core/navegador.dart';
import '../../infrastructure/firebase/repositorio_dispositivos.dart';
import '../shared/tema.dart';
import '../shared/textos.dart';

export '../../application/proveedores_dispositivos.dart'
    show repositorioDispositivosProvider;

class TarjetaNotificaciones extends ConsumerStatefulWidget {
  const TarjetaNotificaciones({super.key});

  @override
  ConsumerState<TarjetaNotificaciones> createState() =>
      _TarjetaNotificacionesState();
}

class _TarjetaNotificacionesState extends ConsumerState<TarjetaNotificaciones> {
  ResultadoRegistro? _resultado;
  EstadoPermiso? _permisoActual;
  bool _trabajando = false;

  @override
  void initState() {
    super.initState();
    _consultar();
  }

  Future<void> _consultar() async {
    final EstadoPermiso p = await ref
        .read(repositorioDispositivosProvider)
        .consultarPermiso();
    if (mounted) {
      setState(() => _permisoActual = p);
    }

    // Si ya estaba concedido, se refresca el identificador sin preguntar
    // nada. En iOS cambia solo, y refrescarlo en cada apertura es la
    // mitigación principal del riesgo R-01.
    if (p == EstadoPermiso.concedido) {
      await _activar(silencioso: true);
    }
  }

  Future<void> _activar({bool silencioso = false}) async {
    if (!silencioso) {
      setState(() => _trabajando = true);
    }

    final ResultadoRegistro r = await ref
        .read(repositorioDispositivosProvider)
        .pedirPermisoYRegistrar();

    if (!mounted) {
      return;
    }

    setState(() {
      _resultado = r;
      _permisoActual = r.permiso;
      _trabajando = false;
    });

    // «Te enviamos una prueba» es información de un momento, no un estado.
    // Vivía en la tarjeta y se quedaba ahí para siempre, ocupando sitio y
    // repitiendo algo ya resuelto. Como aviso pasajero dice lo mismo y se va.
    if (!silencioso && r.pruebaEnviada) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(Textos.notificacionPruebaEnviada),
          duration: Duration(seconds: 8),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData tema = Theme.of(context);
    final EntornoNavegador entorno = ref
        .read(repositorioDispositivosProvider)
        .entorno;
    final ResultadoRegistro? r = _resultado;

    final ({
      IconData icono,
      Color color,
      String titulo,
      String detalle,
      bool accion,
    })
    estado = _estado(entorno, r);

    // ────────────────────────────────────────────────────────────────────────
    // Cuando todo está bien, esta tarjeta no tiene nada que decir.
    // ────────────────────────────────────────────────────────────────────────
    //
    // Su trabajo es avisar de que un aviso NO va a llegar. Con las
    // notificaciones activas, ocupar el primer tercio de la bandeja de forma
    // permanente empuja los mensajes hacia abajo —que es justo lo que la
    // persona vino a leer— para repetir cada vez algo que ya está resuelto.
    //
    // Se queda en una línea, plegada. Sigue estando —hace falta poder
    // comprobar el estado— pero deja de estorbar, y se despliega al tocarla.
    if (!estado.accion && estado.color == ColoresSian.confirmado) {
      return _LineaCompacta(estado: estado, detalle: estado.detalle);
    }

    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      color: estado.color.withValues(alpha: 0.08),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Row(
              children: <Widget>[
                Icon(estado.icono, color: estado.color),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(estado.titulo, style: tema.textTheme.titleMedium),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(estado.detalle),

            if (estado.accion) ...<Widget>[
              const SizedBox(height: 12),
              FilledButton.icon(
                onPressed: _trabajando ? null : () => _activar(),
                icon: _trabajando
                    ? const SizedBox(
                        height: 16,
                        width: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.notifications_active_outlined),
                label: const Text(Textos.botonActivarNotificaciones),
              ),
            ],
          ],
        ),
      ),
    );
  }

  /// Traduce el estado a algo accionable.
  ///
  /// Los tres «no» no son equivalentes y no se pueden mezclar: uno se arregla
  /// con un botón, otro exige ir a los ajustes del navegador (RES-07), y el
  /// tercero exige instalar la aplicación (RES-05).
  ({IconData icono, Color color, String titulo, String detalle, bool accion})
  _estado(EntornoNavegador entorno, ResultadoRegistro? r) {
    if (!entorno.soportaNotificaciones) {
      return (
        icono: Icons.notifications_off_outlined,
        color: ColoresSian.urgente,
        titulo: Textos.notifSinSoporteTitulo,
        detalle: entorno.plataforma == PlataformaWeb.ios
            ? Textos.notifSinSoporteIos
            : Textos.notifSinSoporteNavegador,
        accion: false,
      );
    }

    if (entorno.necesitaInstructivoInstalacion) {
      return (
        icono: Icons.install_mobile_outlined,
        color: ColoresSian.dorado,
        titulo: Textos.notifInstalarTitulo,
        detalle: Textos.notifInstalarDetalle,
        accion: false,
      );
    }

    return switch (_permisoActual) {
      EstadoPermiso.concedido when r?.puedeRecibir ?? true => (
        icono: Icons.notifications_active,
        color: ColoresSian.confirmado,
        titulo: Textos.notifActivasTitulo,
        detalle: Textos.notifActivasDetalle(entorno.navegador),
        accion: false,
      ),
      EstadoPermiso.denegado => (
        icono: Icons.notifications_off,
        color: ColoresSian.urgente,
        titulo: Textos.notifDenegadasTitulo,
        detalle: Textos.comoRevertirPermiso(entorno.navegador),
        accion: false,
      ),
      _ => (
        icono: Icons.notifications_none,
        color: ColoresSian.primario,
        titulo: Textos.notifPendientesTitulo,
        detalle: Textos.notifPendientesDetalle,
        accion: true,
      ),
    };
  }
}

/// Estado plegado: una línea, sin tarjeta ni relleno.
///
/// Se despliega al tocarla. Que se pueda comprobar no significa que tenga que
/// estar gritándolo: el sitio de la pantalla es para los mensajes.
class _LineaCompacta extends StatefulWidget {
  const _LineaCompacta({required this.estado, required this.detalle});

  final ({
    IconData icono,
    Color color,
    String titulo,
    String detalle,
    bool accion,
  })
  estado;
  final String detalle;

  @override
  State<_LineaCompacta> createState() => _LineaCompactaState();
}

class _LineaCompactaState extends State<_LineaCompacta> {
  bool _desplegada = false;

  @override
  Widget build(BuildContext context) {
    final ThemeData tema = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: InkWell(
        onTap: () => setState(() => _desplegada = !_desplegada),
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 4),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Row(
                children: <Widget>[
                  Icon(
                    widget.estado.icono,
                    size: 18,
                    color: widget.estado.color,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      widget.estado.titulo,
                      style: tema.textTheme.bodySmall?.copyWith(
                        color: tema.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                  Icon(
                    _desplegada ? Icons.expand_less : Icons.expand_more,
                    size: 18,
                    color: tema.colorScheme.onSurfaceVariant,
                  ),
                ],
              ),
              if (_desplegada) ...<Widget>[
                const SizedBox(height: 6),
                Padding(
                  padding: const EdgeInsets.only(left: 26),
                  child: Text(
                    widget.detalle,
                    style: tema.textTheme.bodySmall?.copyWith(
                      color: tema.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
