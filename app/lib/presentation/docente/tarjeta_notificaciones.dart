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
import '../../core/plataforma/consola.dart';
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
    // Si consultar falla, `_permisoActual` se queda en nulo y la tarjeta
    // muestra «Activa las notificaciones» a alguien que ya las tiene activas.
    // De todos los estados posibles, ese es el que peor informa: acusa de un
    // problema inexistente y esconde el que hubiera.
    final EstadoPermiso p;
    try {
      p = await ref.read(repositorioDispositivosProvider).consultarPermiso();
    } on Object catch (e) {
      consolaError('SIAN.dispositivo consulta | $e');
      return;
    }

    if (mounted) {
      setState(() => _permisoActual = p);
    }

    // Si ya estaba concedido, se refresca el identificador sin preguntar
    // nada. En iOS cambia solo, y refrescarlo en cada apertura es la
    // mitigación principal del riesgo R-01.
    //
    // Una vez por apertura, no por cada vez que esta tarjeta se construye:
    // vive dentro de la lista de mensajes, así que desplazarse abajo y volver
    // arriba la destruye y la recrea. El repositorio recuerda si ya se hizo.
    final RepositorioDispositivos repo = ref.read(
      repositorioDispositivosProvider,
    );
    if (p == EstadoPermiso.concedido && !repo.yaRefrescado) {
      await _activar(silencioso: true);
    }
  }

  Future<void> _activar({bool silencioso = false}) async {
    if (!silencioso) {
      setState(() => _trabajando = true);
    }

    final ResultadoRegistro r = await ref
        .read(repositorioDispositivosProvider)
        // La prueba solo se envía cuando alguien pulsa «Activar»: en el
        // refresco automático es ruido.
        .pedirPermisoYRegistrar(enviarPrueba: !silencioso);

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
  ///
  /// ──────────────────────────────────────────────────────────────────────────
  /// EL ORDEN DE ESTAS COMPROBACIONES ES LA REGLA, NO UN DETALLE.
  /// ──────────────────────────────────────────────────────────────────────────
  ///
  /// En una **pestaña** de Safari en iOS, Apple no expone la API de
  /// notificaciones en absoluto: solo existe dentro de la aplicación instalada
  /// en la pantalla de inicio. Con «no hay API» comprobado primero, un iPhone
  /// moderno abierto en una pestaña acababa leyendo «tu versión de iOS es
  /// anterior a la 16.4» —falso— en lugar de «falta instalar la aplicación»,
  /// que es lo único que hay que hacer.
  ///
  /// Y quien ya la tenía instalada veía ese mismo mensaje mientras los avisos
  /// le llegaban perfectamente al icono de su pantalla de inicio. Un aviso que
  /// dice que el sistema no funciona, cuando funciona, gasta la confianza que
  /// hace falta el día que de verdad falle.
  ///
  /// Por eso la versión de iOS se comprueba con el dato de la versión, que es
  /// lo que de verdad lo determina, y la ausencia de API en iOS se lee como lo
  /// que casi siempre significa: que no está instalada.
  ({IconData icono, Color color, String titulo, String detalle, bool accion})
  _estado(EntornoNavegador entorno, ResultadoRegistro? r) {
    final bool esIos = entorno.plataforma == PlataformaWeb.ios;

    // Un iOS de verdad anterior a la 16.4. Esto no lo arregla instalar nada.
    if (entorno.iosDemasiadoAntiguo) {
      return (
        icono: Icons.notifications_off_outlined,
        color: ColoresSian.urgente,
        titulo: Textos.notifSinSoporteTitulo,
        detalle: Textos.notifSinSoporteIos,
        accion: false,
      );
    }

    // En iOS, sin instalar no hay API que valga: el instructivo va primero.
    if (esIos && entorno.necesitaInstructivoInstalacion) {
      return (
        icono: Icons.install_mobile_outlined,
        color: ColoresSian.dorado,
        titulo: Textos.notifInstalarTitulo,
        detalle: Textos.notifInstalarDetalle,
        accion: false,
      );
    }

    if (!entorno.soportaNotificaciones) {
      return (
        icono: Icons.notifications_off_outlined,
        color: ColoresSian.urgente,
        titulo: Textos.notifSinSoporteTitulo,
        detalle: esIos
            ? Textos.notifSinSoporteIos
            : Textos.notifSinSoporteNavegador,
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
