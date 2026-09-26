/// SIAN — Copiar el título o el mensaje de un aviso (U-1).
///
/// Un botón, y no solo texto seleccionable: seleccionar dentro de una
/// aplicación instalada en un iPhone es incómodo —hay que acertar con los
/// tiradores—, y lo que se quiere casi siempre es el aviso entero para
/// reenviarlo o pegarlo en otro sitio. El texto sigue siendo seleccionable
/// para quien quiera solo un trozo.
library;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../shared/textos.dart';

enum QueCopiar { todo, titulo, mensaje }

/// Lo que va al portapapeles para cada opción.
String textoACopiar(
  QueCopiar que, {
  required String titulo,
  required String cuerpo,
}) => switch (que) {
  QueCopiar.todo => '$titulo\n\n$cuerpo',
  QueCopiar.titulo => titulo,
  QueCopiar.mensaje => cuerpo,
};

class BotonCopiarAviso extends StatelessWidget {
  const BotonCopiarAviso({
    required this.titulo,
    required this.cuerpo,
    super.key,
  });

  final String titulo;
  final String cuerpo;

  Future<void> _copiar(BuildContext context, QueCopiar que) async {
    await Clipboard.setData(
      ClipboardData(
        text: textoACopiar(que, titulo: titulo, cuerpo: cuerpo),
      ),
    );
    if (context.mounted) {
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          const SnackBar(
            content: Text(Textos.copiado),
            duration: Duration(seconds: 2),
          ),
        );
    }
  }

  @override
  Widget build(BuildContext context) => PopupMenuButton<QueCopiar>(
    tooltip: Textos.botonCopiar,
    onSelected: (QueCopiar que) => _copiar(context, que),
    itemBuilder: (BuildContext _) => const <PopupMenuEntry<QueCopiar>>[
      PopupMenuItem<QueCopiar>(
        value: QueCopiar.todo,
        child: Text(Textos.copiarTodo),
      ),
      PopupMenuItem<QueCopiar>(
        value: QueCopiar.titulo,
        child: Text(Textos.copiarTitulo),
      ),
      PopupMenuItem<QueCopiar>(
        value: QueCopiar.mensaje,
        child: Text(Textos.copiarMensaje),
      ),
    ],
    child: const Padding(
      padding: EdgeInsets.symmetric(vertical: 8),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Icon(Icons.content_copy, size: 18),
          SizedBox(width: 6),
          Text(Textos.botonCopiar),
        ],
      ),
    ),
  );
}
