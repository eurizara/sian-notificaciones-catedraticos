/// SIAN — Elegir y guardar plantillas de avisos (RF-MSG-14).
///
/// Las **predefinidas** vienen con SIAN y cubren lo que coordinación escribe
/// una y otra vez; las **propias** las guarda cualquiera que emita avisos y las
/// ven todos los que emiten. Lo que va entre corchetes —`[día]`, `[hora]`— hay
/// que completarlo: el formulario no deja enviar mientras quede alguno de los
/// que traía la plantilla.
library;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../infrastructure/firebase/repositorio_plantillas.dart';
import '../shared/tema.dart';
import '../shared/textos.dart';

final Provider<RepositorioPlantillas> repositorioPlantillasProvider =
    Provider<RepositorioPlantillas>(
      (Ref ref) => RepositorioPlantillasFirebase(),
    );

final StreamProvider<List<Plantilla>> plantillasPropiasProvider =
    StreamProvider<List<Plantilla>>(
      (Ref ref) => ref.watch(repositorioPlantillasProvider).observar(),
    );

const List<Plantilla> plantillasPredefinidas = <Plantilla>[
  Plantilla(
    nombre: 'Recordatorio de actualizar SIAN',
    titulo: 'Actualice SIAN',
    cuerpo:
        'Hay una versión nueva de SIAN. Ábrala y, si arriba aparece el botón '
        '«Actualizar», tóquelo; tarda unos segundos y no se pierde nada. '
        'Después responda a este mensaje con «Listo». Gracias.',
    requiereConfirmacion: true,
    predefinida: true,
  ),
  Plantilla(
    nombre: 'Recordatorio de responder',
    titulo: 'Pendiente de su respuesta',
    cuerpo:
        'Le recordamos responder el aviso «[título del aviso]». Puede hacerlo '
        'desde el mismo aviso, con el botón Responder. Gracias.',
    predefinida: true,
  ),
  Plantilla(
    nombre: 'Simulacro de evacuación',
    titulo: 'Simulacro de evacuación: [día]',
    cuerpo:
        'El [día] a las [hora] se realizará un simulacro de evacuación en la '
        'sede. Al sonar la alarma, suspenda la clase y guíe a sus estudiantes '
        'por la ruta señalizada hasta el punto de reunión. Confirme de enterado.',
    requiereConfirmacion: true,
    predefinida: true,
  ),
  Plantilla(
    nombre: 'Suspensión de clases',
    titulo: 'Suspensión de clases: [día]',
    cuerpo:
        'Se suspenden las clases del [día] por [motivo]. Las actividades se '
        'reprogramarán y se informará por este medio. Confirme de enterado.',
    requiereConfirmacion: true,
    predefinida: true,
  ),
  Plantilla(
    nombre: 'Reunión de catedráticos',
    titulo: 'Reunión de catedráticos: [día]',
    cuerpo:
        'Se convoca a reunión el [día] a las [hora] en [lugar]. Tema: [tema]. '
        'Confirme su asistencia respondiendo a este mensaje.',
    predefinida: true,
  ),
  Plantilla(
    nombre: 'Evacuación inmediata',
    titulo: 'EVACUACIÓN INMEDIATA',
    cuerpo:
        'Evacúe ahora el edificio con sus estudiantes por la ruta señalizada '
        'hasta el punto de reunión. No use elevadores. Espere instrucciones.',
    urgente: true,
    requiereConfirmacion: true,
    predefinida: true,
  ),
];

/// Por nombre o título, sin tildes ni mayúsculas. Sin búsqueda, todas.
List<Plantilla> filtrarPlantillas(List<Plantilla> todas, String busqueda) {
  final String q = _plano(busqueda.trim());
  if (q.isEmpty) {
    return todas;
  }
  return <Plantilla>[
    for (final Plantilla p in todas)
      if (_plano(p.nombre).contains(q) || _plano(p.titulo).contains(q)) p,
  ];
}

/// Lo que va entre corchetes: lo que hay que completar antes de enviar.
Set<String> marcadoresDe(String texto) => <String>{
  for (final RegExpMatch m in RegExp(r'\[[^\[\]\n]{1,40}\]').allMatches(texto))
    m[0]!,
};

String _plano(String s) => s
    .toLowerCase()
    .replaceAll(RegExp('[áàä]'), 'a')
    .replaceAll(RegExp('[éèë]'), 'e')
    .replaceAll(RegExp('[íìï]'), 'i')
    .replaceAll(RegExp('[óòö]'), 'o')
    .replaceAll(RegExp('[úùü]'), 'u');

/// Abre la lista y devuelve la elegida, o nula si se cerró sin elegir.
///
/// Sin permiso de urgentes no se ofrecen las urgentes: el servidor las
/// rechazaría igual, y ofrecer algo que no se puede enviar solo confunde.
Future<Plantilla?> elegirPlantilla(
  BuildContext context, {
  required bool puedeUrgentes,
}) => showDialog<Plantilla>(
  context: context,
  builder: (BuildContext _) => _Selector(puedeUrgentes: puedeUrgentes),
);

/// Pide el nombre con que se guarda. Nulo si se canceló.
Future<String?> pedirNombreDePlantilla(BuildContext context) async {
  final String? r = await showDialog<String>(
    context: context,
    builder: (BuildContext _) => const _DialogoNombre(),
  );
  final String limpio = (r ?? '').trim();
  return limpio.isEmpty ? null : limpio;
}

/// Dueño de su controlador: liberarlo al volver de `showDialog` lo soltaba
/// mientras el diálogo todavía se estaba cerrando.
class _DialogoNombre extends StatefulWidget {
  const _DialogoNombre();

  @override
  State<_DialogoNombre> createState() => _DialogoNombreState();
}

class _DialogoNombreState extends State<_DialogoNombre> {
  final TextEditingController _nombre = TextEditingController();

  @override
  void dispose() {
    _nombre.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text(Textos.plantillaGuardar),
    content: TextField(
      controller: _nombre,
      autofocus: true,
      inputFormatters: <TextInputFormatter>[
        LengthLimitingTextInputFormatter(60),
      ],
      decoration: const InputDecoration(
        labelText: Textos.plantillaNombre,
        helperText: Textos.plantillaNombreAyuda,
        helperMaxLines: 2,
        border: OutlineInputBorder(),
      ),
      onSubmitted: (String v) => Navigator.of(context).pop(v),
    ),
    actions: <Widget>[
      TextButton(
        onPressed: () => Navigator.of(context).pop(),
        child: const Text(Textos.botonCancelar),
      ),
      FilledButton(
        onPressed: () => Navigator.of(context).pop(_nombre.text),
        child: const Text(Textos.plantillaGuardarConfirmar),
      ),
    ],
  );
}

class _Selector extends ConsumerStatefulWidget {
  const _Selector({required this.puedeUrgentes});

  final bool puedeUrgentes;

  @override
  ConsumerState<_Selector> createState() => _SelectorState();
}

class _SelectorState extends ConsumerState<_Selector> {
  final TextEditingController _busqueda = TextEditingController();

  @override
  void initState() {
    super.initState();
    _busqueda.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _busqueda.dispose();
    super.dispose();
  }

  Future<void> _borrar(Plantilla p) async {
    final bool? si = await showDialog<bool>(
      context: context,
      builder: (BuildContext contexto) => AlertDialog(
        title: const Text(Textos.plantillaBorrarTitulo),
        content: Text(Textos.plantillaBorrarDetalle(p.nombre)),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(contexto).pop(false),
            child: const Text(Textos.botonCancelar),
          ),
          FilledButton(
            onPressed: () => Navigator.of(contexto).pop(true),
            child: const Text(Textos.plantillaBorrarConfirmar),
          ),
        ],
      ),
    );
    if (si ?? false) {
      await ref.read(repositorioPlantillasProvider).borrar(p.id!);
    }
  }

  @override
  Widget build(BuildContext context) {
    // Si las propias no cargan (sin red, reglas sin desplegar), las
    // predefinidas siguen sirviendo: no se bloquea nada por eso.
    final List<Plantilla> propias =
        ref.watch(plantillasPropiasProvider).value ?? const <Plantilla>[];
    bool ofrecible(Plantilla p) => widget.puedeUrgentes || !p.urgente;

    final List<Plantilla> predefinidas = filtrarPlantillas(
      plantillasPredefinidas.where(ofrecible).toList(),
      _busqueda.text,
    );
    final List<Plantilla> suyas = filtrarPlantillas(
      propias.where(ofrecible).toList(),
      _busqueda.text,
    );

    return AlertDialog(
      title: const Text(Textos.plantillaElegirTitulo),
      contentPadding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      content: SizedBox(
        width: 520,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            TextField(
              controller: _busqueda,
              decoration: const InputDecoration(
                labelText: Textos.plantillaBuscar,
                prefixIcon: Icon(Icons.search),
                border: OutlineInputBorder(),
                isDense: true,
              ),
            ),
            const SizedBox(height: 8),
            Flexible(
              child: ListView(
                shrinkWrap: true,
                children: <Widget>[
                  if (suyas.isNotEmpty) ...<Widget>[
                    const _Encabezado(Textos.plantillaPropias),
                    for (final Plantilla p in suyas)
                      _Fila(plantilla: p, alBorrar: () => _borrar(p)),
                  ],
                  if (predefinidas.isNotEmpty) ...<Widget>[
                    const _Encabezado(Textos.plantillaPredefinidas),
                    for (final Plantilla p in predefinidas) _Fila(plantilla: p),
                  ],
                  if (suyas.isEmpty && predefinidas.isEmpty)
                    const Padding(
                      padding: EdgeInsets.all(16),
                      child: Text(Textos.plantillaSinResultados),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
      actions: <Widget>[
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text(Textos.botonCancelar),
        ),
      ],
    );
  }
}

class _Encabezado extends StatelessWidget {
  const _Encabezado(this.texto);

  final String texto;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(4, 12, 4, 4),
    child: Text(texto, style: Theme.of(context).textTheme.labelLarge),
  );
}

class _Fila extends StatelessWidget {
  const _Fila({required this.plantilla, this.alBorrar});

  final Plantilla plantilla;
  final VoidCallback? alBorrar;

  @override
  Widget build(BuildContext context) => ListTile(
    contentPadding: const EdgeInsets.symmetric(horizontal: 4),
    leading: Icon(
      plantilla.urgente
          ? Icons.warning_amber_rounded
          : Icons.description_outlined,
      color: plantilla.urgente ? PaletaSian.de(context).urgente : null,
    ),
    title: Text(plantilla.nombre),
    subtitle: Text(
      plantilla.titulo,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
    ),
    trailing: alBorrar == null
        ? null
        : IconButton(
            icon: const Icon(Icons.delete_outline),
            tooltip: Textos.plantillaBorrar,
            onPressed: alBorrar,
          ),
    onTap: () => Navigator.of(context).pop(plantilla),
  );
}
