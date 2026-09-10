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

import '../../infrastructure/firebase/repositorio_canal.dart';
import '../shared/tema.dart';
import '../shared/textos.dart';

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
        const Icon(Icons.error_outline, size: 40, color: ColoresSian.urgente),
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
  const _Contenido({required this.revision, required this.alReintentar});

  final RevisionDeCanal revision;
  final VoidCallback alReintentar;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
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
          Expanded(
            child: ListView.separated(
              itemCount: revision.personas.length,
              separatorBuilder: (_, _) => const Divider(height: 1),
              itemBuilder: (BuildContext context, int i) =>
                  _Fila(persona: revision.personas[i]),
            ),
          ),
      ],
    );
  }
}

class _TodoEnOrden extends StatelessWidget {
  const _TodoEnOrden();

  @override
  Widget build(BuildContext context) => const Padding(
    padding: EdgeInsets.symmetric(vertical: 32),
    child: Row(
      children: <Widget>[
        Icon(Icons.check_circle_outline, color: ColoresSian.confirmado),
        SizedBox(width: 8),
        Text(Textos.canalTodoEnOrden),
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
      leading: Icon(_icono(persona.estado), color: _color(persona.estado)),
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
      trailing: Text(
        _desdeCuando(persona.ultimaActividad),
        style: tema.textTheme.bodySmall,
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
  EstadoCanal.alDia => ColoresSian.confirmado,
};

String _queLePasa(EstadoCanal estado) => switch (estado) {
  EstadoCanal.sinDispositivo => Textos.canalSinDispositivo,
  EstadoCanal.ultimoEnvioFallo => Textos.canalUltimoEnvioFallo,
  EstadoCanal.tokenMuerto => Textos.canalTokenMuerto,
  EstadoCanal.permisoDenegado => Textos.canalPermisoDenegado,
  EstadoCanal.soloEnPestana => Textos.canalSoloEnPestana,
  EstadoCanal.sinActividadReciente => Textos.canalSinActividad,
  EstadoCanal.alDia => '',
};

String _quePedirle(EstadoCanal estado) => switch (estado) {
  EstadoCanal.sinDispositivo => Textos.canalPedirRegistrar,
  EstadoCanal.ultimoEnvioFallo => Textos.canalPedirReenganchar,
  EstadoCanal.tokenMuerto => Textos.canalPedirReabrir,
  EstadoCanal.permisoDenegado => Textos.canalPedirPermiso,
  EstadoCanal.soloEnPestana => Textos.canalPedirInstalar,
  EstadoCanal.sinActividadReciente => Textos.canalPedirAbrir,
  EstadoCanal.alDia => '',
};

String _desdeCuando(DateTime? actividad) {
  if (actividad == null) {
    return Textos.canalSinActividadNunca;
  }
  return Textos.canalDesdeCuando(DateTime.now().difference(actividad).inDays);
}
