/// SIAN — Quién no recibiría un aviso enviado ahora mismo (DT-22).
///
/// ────────────────────────────────────────────────────────────────────────────
/// Ordenada por gravedad, no alfabéticamente.
/// ────────────────────────────────────────────────────────────────────────────
///
/// Una lista alfabética obliga a leerla entera para encontrar lo urgente. Aquí
/// el orden es el de buscar a la gente: primero quien no puede recibir nada,
/// después quien la tiene sin instalar, al final quien lleva tiempo sin abrirla.
///
/// Y se enseña **solo a quien tiene algo que corregir**. Una lista que incluye a
/// los veintidós es una lista que nadie repasa.
///
/// ────────────────────────────────────────────────────────────────────────────
/// Cada fila dice qué le pasa Y qué hay que pedirle
/// ────────────────────────────────────────────────────────────────────────────
///
/// Saber que alguien «no está alcanzable» no sirve si no se sabe qué hacer. No
/// es lo mismo pedirle que instale la aplicación que pedirle que vuelva a dar el
/// permiso, y confundirlo hace perder una llamada.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../application/proveedores_sesion.dart';
import '../../core/version.dart';
import '../../domain/sesion.dart';
import '../../infrastructure/firebase/repositorio_canal.dart';
import '../../infrastructure/firebase/repositorio_envio.dart';
import '../shared/tema.dart';
import '../shared/textos.dart';
import '../shared/version_app.dart';
import 'borrador_prefijado.dart';

final Provider<RepositorioCanal> repositorioCanalProvider =
    Provider<RepositorioCanal>((Ref ref) => RepositorioCanal());

final FutureProvider<RevisionDeCanal> revisionDeCanalProvider =
    FutureProvider<RevisionDeCanal>(
      (Ref ref) => ref.read(repositorioCanalProvider).revisar(),
    );

class SeccionCanal extends ConsumerWidget {
  const SeccionCanal({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AsyncValue<RevisionDeCanal> revision = ref.watch(
      revisionDeCanalProvider,
    );

    return revision.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (Object e, StackTrace _) => _Fallo(
        alReintentar: () => ref.invalidate(revisionDeCanalProvider),
      ),
      data: (RevisionDeCanal r) => _Contenido(
        revision: r,
        // La publicada en este ambiente (`version.json`). Si todavía no se
        // sabe, la de esta misma aplicación: quien mira Alcance acaba de
        // cargarla, así que es la mejor aproximación disponible.
        publicada: ref.watch(versionPublicadaProvider).value ?? versionSian,
        alReintentar: () => ref.invalidate(revisionDeCanalProvider),
      ),
    );
  }
}

class _Fallo extends StatelessWidget {
  const _Fallo({required this.alReintentar});

  final VoidCallback alReintentar;

  @override
  Widget build(BuildContext context) => Center(
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Icon(Icons.error_outline, size: 40, color: PaletaSian.de(context).urgente),
        const SizedBox(height: 12),
        const Text(Textos.canalFallo, textAlign: TextAlign.center),
        const SizedBox(height: 12),
        FilledButton.tonalIcon(
          onPressed: alReintentar,
          icon: const Icon(Icons.refresh),
          label: const Text(Textos.canalReintentar),
        ),
      ],
    ),
  );
}

class _Contenido extends StatelessWidget {
  const _Contenido({
    required this.revision,
    required this.publicada,
    required this.alReintentar,
  });

  final RevisionDeCanal revision;
  final String publicada;
  final VoidCallback alReintentar;

  @override
  Widget build(BuildContext context) {
    final ClasificacionDeVersiones versiones = clasificarVersiones(
      revision.versiones,
      publicada,
    );

    // Una sola lista con las dos partes: con dos listas desplazables en la
    // misma pantalla, la de abajo quedaba sin sitio en un teléfono.
    return ListView(
      children: <Widget>[
        Row(
          children: <Widget>[
            Expanded(
              child: Text(
                Textos.canalResumen(revision.total, revision.catedraticos),
                style: Theme.of(context).textTheme.titleMedium,
              ),
            ),
            IconButton(
              onPressed: alReintentar,
              icon: const Icon(Icons.refresh),
              tooltip: Textos.canalReintentar,
            ),
          ],
        ),
        const SizedBox(height: 12),
        if (revision.todoEnOrden)
          const _TodoEnOrden()
        else
          _Desplegable(
            clave: const Key('desplegable-canal'),
            titulo: Textos.canalVerPersonas(revision.personas.length),
            hijos: <Widget>[
              for (int i = 0; i < revision.personas.length; i += 1) ...<Widget>[
                if (i > 0) const Divider(height: 1),
                _Fila(persona: revision.personas[i]),
              ],
            ],
          ),
        const SizedBox(height: 24),
        _Versiones(
          clasificacion: versiones,
          conAparato: revision.versiones.length,
          publicada: publicada,
        ),
        const SizedBox(height: 24),
        _Fallos(fallos: revision.fallos),
      ],
    );
  }
}

/// Lo que los aparatos reportaron que les falló en las últimas 24 h (DT-34).
///
/// El 12/09/2026 el registro se colgó en todos los aparatos y nadie lo supo
/// hasta que un aviso no llegó. Esto es lo que habría avisado antes.
class _Fallos extends StatelessWidget {
  const _Fallos({required this.fallos});

  final FallosDeAparatos fallos;

  @override
  Widget build(BuildContext context) {
    final TextTheme texto = Theme.of(context).textTheme;
    final PaletaSian paleta = PaletaSian.de(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(Textos.canalFallosTitulo, style: texto.titleMedium),
        const SizedBox(height: 4),
        Text(Textos.canalFallosResumen(fallos.aparatos)),
        if (fallos.porTipo.isNotEmpty) ...<Widget>[
          const SizedBox(height: 8),
          for (final TipoDeFallosResumido t in fallos.porTipo)
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: Icon(Icons.report_gmailerrorred, color: paleta.urgente),
              title: Text(Textos.nombreFallo(t.que)),
              subtitle: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(Textos.canalFalloCuenta(t.aparatos, t.veces)),
                  Text(
                    <String>[
                      t.plataformas.map(Textos.nombrePlataforma).join(', '),
                      if (t.versiones.isNotEmpty) t.versiones.join(', '),
                    ].join(' · '),
                  ),
                  if (t.ultimoDetalle.isNotEmpty)
                    SelectableText(
                      t.ultimoDetalle,
                      style: texto.bodySmall?.copyWith(fontFamily: 'monospace'),
                    ),
                ],
              ),
            ),
        ],
        const SizedBox(height: 4),
        Text(Textos.canalFallosNota, style: texto.bodySmall),
      ],
    );
  }
}

/// Quién tiene algún aparato sin la versión publicada.
///
/// La lista de arriba solo trae a quien tiene problemas de canal. Alguien que
/// recibe perfectamente con una versión vieja no salía en ningún sitio, y es
/// justo a quien hay que pedirle actualizar: las correcciones de canal y del
/// acuse viajan con la versión.
class _Versiones extends ConsumerStatefulWidget {
  const _Versiones({
    required this.clasificacion,
    required this.conAparato,
    required this.publicada,
  });

  final ClasificacionDeVersiones clasificacion;
  final int conAparato;
  final String publicada;

  @override
  ConsumerState<_Versiones> createState() => _VersionesState();
}

class _VersionesState extends ConsumerState<_Versiones> {
  bool _verReemplazados = false;

  /// Retira un registro, con confirmación (1.6). Solo coordinación: el mismo
  /// permiso que administrar usuarios. Queda en la bitácora.
  Future<void> _retirar(VersionesDePersona persona, AparatoConVersion a) async {
    final String aparato = Textos.nombrePlataforma(a.plataforma);
    final String quien = persona.nombre.isEmpty ? persona.correo : persona.nombre;
    final bool? si = await showDialog<bool>(
      context: context,
      builder: (BuildContext c) => AlertDialog(
        title: const Text(Textos.retirarTitulo),
        content: Text(Textos.retirarDetalle(aparato, quien)),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(c).pop(false),
            child: const Text(Textos.botonCancelar),
          ),
          FilledButton(
            onPressed: () => Navigator.of(c).pop(true),
            child: const Text(Textos.botonRetirar),
          ),
        ],
      ),
    );
    if (si != true || !mounted) {
      return;
    }
    try {
      await ref
          .read(repositorioCanalProvider)
          .retirar(uid: persona.uid, dispositivoId: a.id);
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text(Textos.registroRetirado)));
      ref.invalidate(revisionDeCanalProvider);
    } on Object {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text(Textos.registroNoRetirado)),
        );
      }
    }
  }

  /// Prepara el recordatorio para quien sigue atrasado y pasa a redactarlo.
  void _recordar() {
    ref
        .read(borradorPrefijadoProvider.notifier)
        .preparar(
          BorradorPrefijado(
            personas: <PersonaDestinataria>[
              for (final VersionesDePersona p in widget.clasificacion.atrasados)
                PersonaDestinataria(uid: p.uid, nombre: p.nombre, correo: p.correo),
            ],
            titulo: Textos.recordatorioTitulo,
            cuerpo: Textos.recordatorioCuerpo(widget.publicada),
          ),
        );
  }

  Widget _lineaDeAparato(
    VersionesDePersona persona,
    AparatoConVersion a, {
    required bool puedeRetirar,
  }) => Row(
    children: <Widget>[
      Expanded(
        child: Text(
          '${Textos.nombrePlataforma(a.plataforma)} · '
          '${Textos.versionDeLaPersona(a.versionApp)} · '
          '${_desdeCuando(a.ultimaActividad)}',
        ),
      ),
      if (puedeRetirar && a.id.isNotEmpty)
        IconButton(
          tooltip: Textos.retirarRegistro,
          visualDensity: VisualDensity.compact,
          icon: const Icon(Icons.delete_outline, size: 20),
          onPressed: () => _retirar(persona, a),
        ),
    ],
  );

  @override
  Widget build(BuildContext context) {
    final ThemeData tema = Theme.of(context);
    final PaletaSian paleta = PaletaSian.de(context);
    final List<VersionesDePersona> atrasados = widget.clasificacion.atrasados;
    final int reemplazados = widget.clasificacion.reemplazados;
    final Sesion sesion = ref.watch(sesionActualProvider);
    final bool puedeRetirar =
        sesion is SesionActiva && sesion.usuario.rol.administraUsuarios;
    final bool puedeRecordar =
        sesion is SesionActiva && sesion.usuario.rol.esEmisor;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(Textos.canalVersionesTitulo, style: tema.textTheme.titleMedium),
        const SizedBox(height: 8),
        Row(
          children: <Widget>[
            Icon(
              atrasados.isEmpty
                  ? Icons.check_circle_outline
                  : Icons.system_update_alt,
              color: atrasados.isEmpty ? paleta.confirmado : paleta.doradoTexto,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                Textos.canalVersionesResumen(
                  atrasados.length,
                  widget.conAparato,
                  widget.publicada,
                ),
              ),
            ),
          ],
        ),
        // Registros de instalaciones anteriores de aparatos que ya están al
        // día. Se dicen, para que no parezca que desaparecieron, pero no se
        // cuentan como gente a la que pedirle nada. Coordinación puede verlos
        // y retirarlos; si no, se retiran solos a los 14 días.
        if (reemplazados > 0) ...<Widget>[
          const SizedBox(height: 4),
          Text(
            Textos.canalVersionesReemplazados(reemplazados),
            style: tema.textTheme.bodySmall?.copyWith(
              color: tema.colorScheme.onSurfaceVariant,
            ),
          ),
          if (puedeRetirar)
            TextButton(
              onPressed: () =>
                  setState(() => _verReemplazados = !_verReemplazados),
              child: Text(
                _verReemplazados
                    ? Textos.ocultarReemplazados
                    : Textos.verReemplazados,
              ),
            ),
          if (puedeRetirar && _verReemplazados)
            for (final ({VersionesDePersona persona, AparatoConVersion aparato})
                r in widget.clasificacion.registrosReemplazados)
              Padding(
                padding: const EdgeInsets.only(left: 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      r.persona.nombre.isEmpty
                          ? r.persona.correo
                          : r.persona.nombre,
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                    _lineaDeAparato(
                      r.persona,
                      r.aparato,
                      puedeRetirar: puedeRetirar,
                    ),
                  ],
                ),
              ),
        ],
        if (atrasados.isNotEmpty) ...<Widget>[
          const SizedBox(height: 4),
          Text(
            Textos.canalVersionesPedir,
            style: tema.textTheme.bodySmall?.copyWith(
              color: tema.colorScheme.onSurfaceVariant,
            ),
          ),
          if (puedeRecordar) ...<Widget>[
            const SizedBox(height: 8),
            FilledButton.tonalIcon(
              onPressed: _recordar,
              icon: const Icon(Icons.campaign_outlined),
              label: Text(Textos.botonRecordarVersion(atrasados.length)),
            ),
          ],
          const SizedBox(height: 8),
          _Desplegable(
            clave: const Key('desplegable-versiones'),
            titulo: Textos.canalVerAtrasados(atrasados.length),
            hijos: <Widget>[
          for (int i = 0; i < atrasados.length; i += 1) ...<Widget>[
            if (i > 0) const Divider(height: 1),
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(
                atrasados[i].nombre.isEmpty
                    ? atrasados[i].correo
                    : atrasados[i].nombre,
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
              subtitle: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  for (final AparatoConVersion a in atrasados[i].aparatos)
                    _lineaDeAparato(atrasados[i], a, puedeRetirar: puedeRetirar),
                ],
              ),
            ),
          ],
            ],
          ),
        ],
      ],
    );
  }
}

/// Una lista plegada bajo un encabezado con su número (26/09/2026).
///
/// Con veinte personas en cada lista, Alcance era una pantalla larguísima
/// donde lo importante —los resúmenes y el botón de recordar— quedaba
/// perdido entre nombres. Plegadas, se ve de un vistazo cuántas hay en cada
/// una, y se abre solo la que interesa.
class _Desplegable extends StatelessWidget {
  const _Desplegable({
    required this.clave,
    required this.titulo,
    required this.hijos,
  });

  final Key clave;
  final String titulo;
  final List<Widget> hijos;

  @override
  Widget build(BuildContext context) => Card(
    margin: EdgeInsets.zero,
    child: Theme(
      // Sin las líneas que ExpansionTile pone arriba y abajo al abrirse: la
      // tarjeta ya marca el borde.
      data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
      child: ExpansionTile(
        key: clave,
        title: Text(
          titulo,
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
        childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
        expandedCrossAxisAlignment: CrossAxisAlignment.start,
        children: hijos,
      ),
    ),
  );
}

class _TodoEnOrden extends StatelessWidget {
  const _TodoEnOrden();

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 32),
    child: Row(
      children: <Widget>[
        Icon(
          Icons.check_circle_outline,
          color: PaletaSian.de(context).confirmado,
        ),
        const SizedBox(width: 8),
        const Text(Textos.canalTodoEnOrden),
      ],
    ),
  );
}

class _Fila extends StatelessWidget {
  const _Fila({required this.persona});

  final PersonaSinCanal persona;

  @override
  Widget build(BuildContext context) {
    final ThemeData tema = Theme.of(context);

    return ListTile(
      leading: Icon(
        _icono(persona.estado),
        color: PaletaSian.de(context).adaptar(_color(persona.estado)),
      ),
      title: Text(
        persona.nombre.isEmpty ? persona.correo : persona.nombre,
        style: const TextStyle(fontWeight: FontWeight.w600),
      ),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          // El estado va en texto, no solo en el color del icono: quien no
          // distinga los colores lee exactamente lo mismo (RNF-13).
          Text(_queLePasa(persona.estado)),
          const SizedBox(height: 2),
          Text(
            _quePedirle(persona.estado),
            style: tema.textTheme.bodySmall?.copyWith(
              color: tema.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
      trailing: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: <Widget>[
          Text(
            _desdeCuando(persona.ultimaActividad),
            style: tema.textTheme.bodySmall,
          ),
          // Con qué versión está. Importa para leer bien el resto: desde C-5,
          // el acuse de que una notificación se mostró lo manda el service
          // worker, así que un aparato atrasado informa distinto.
          if (persona.versionApp.isNotEmpty)
            Text(
              Textos.versionDeLaPersona(persona.versionApp),
              style: tema.textTheme.bodySmall?.copyWith(
                color: persona.versionApp == versionSian
                    ? tema.colorScheme.onSurfaceVariant
                    : PaletaSian.de(context).doradoTexto,
              ),
            ),
        ],
      ),
      isThreeLine: true,
    );
  }
}

IconData _icono(EstadoCanal estado) => switch (estado) {
  EstadoCanal.sinDispositivo => Icons.phonelink_erase_outlined,
  EstadoCanal.ultimoEnvioFallo => Icons.report_problem_outlined,
  EstadoCanal.tokenMuerto => Icons.link_off_outlined,
  EstadoCanal.permisoDenegado => Icons.notifications_off_outlined,
  EstadoCanal.soloEnPestana => Icons.tab_outlined,
  EstadoCanal.sinActividadReciente => Icons.hourglass_bottom_outlined,
  EstadoCanal.reenganchadoSinComprobar => Icons.pending_outlined,
  EstadoCanal.alDia => Icons.check_circle_outline,
};

/// El color acompaña al texto; nunca lo sustituye.
///
/// No se usa el rojo institucional: está reservado en exclusiva a las alertas
/// urgentes, y si aquí también significara «problema» dejaría de significar
/// «urgente» donde importa.
Color _color(EstadoCanal estado) => switch (estado) {
  EstadoCanal.sinDispositivo ||
  EstadoCanal.ultimoEnvioFallo ||
  EstadoCanal.tokenMuerto ||
  EstadoCanal.permisoDenegado => ColoresSian.doradoTexto,
  EstadoCanal.soloEnPestana ||
  EstadoCanal.sinActividadReciente => ColoresSian.primarioOscuro,
  // Verde apagado: respondió. No es un problema que atender, pero tampoco una
  // confirmación — por eso no es el verde pleno de «confirmado».
  EstadoCanal.reenganchadoSinComprobar => ColoresSian.confirmado,
  EstadoCanal.alDia => ColoresSian.confirmado,
};

String _queLePasa(EstadoCanal estado) => switch (estado) {
  EstadoCanal.sinDispositivo => Textos.canalSinDispositivo,
  EstadoCanal.ultimoEnvioFallo => Textos.canalUltimoEnvioFallo,
  EstadoCanal.tokenMuerto => Textos.canalTokenMuerto,
  EstadoCanal.permisoDenegado => Textos.canalPermisoDenegado,
  EstadoCanal.soloEnPestana => Textos.canalSoloEnPestana,
  EstadoCanal.sinActividadReciente => Textos.canalSinActividad,
  EstadoCanal.reenganchadoSinComprobar => Textos.canalReenganchado,
  EstadoCanal.alDia => '',
};

String _quePedirle(EstadoCanal estado) => switch (estado) {
  EstadoCanal.sinDispositivo => Textos.canalPedirRegistrar,
  EstadoCanal.ultimoEnvioFallo => Textos.canalPedirReenganchar,
  EstadoCanal.tokenMuerto => Textos.canalPedirReabrir,
  EstadoCanal.permisoDenegado => Textos.canalPedirPermiso,
  EstadoCanal.soloEnPestana => Textos.canalPedirInstalar,
  EstadoCanal.sinActividadReciente => Textos.canalPedirAbrir,
  EstadoCanal.reenganchadoSinComprobar => Textos.canalPedirEsperar,
  EstadoCanal.alDia => '',
};

String _desdeCuando(DateTime? actividad) {
  if (actividad == null) {
    return Textos.canalSinActividadNunca;
  }
  return Textos.canalDesdeCuando(DateTime.now().difference(actividad).inDays);
}
