/// SIAN — Texto de un aviso o una respuesta, con sus enlaces tocables (U-2).
///
/// ────────────────────────────────────────────────────────────────────────────
/// Qué se vuelve enlace, y qué no
/// ────────────────────────────────────────────────────────────────────────────
///
///   · **Web:** `http://…`, `https://…` y `www.…` (se abre como `https`).
///   · **Correo:** `nombre@dominio.algo` → la aplicación de correo.
///   · **Teléfono de Guatemala:** ocho dígitos que empiezan por 2 a 7, con o sin
///     `+502` y con un espacio o guion en medio (`5555 1234`, `+502 2222-3333`).
///     Solo ese formato: un número de carné o una fecha no deben ofrecer
///     «llamar».
///
/// Nada más. El texto lo escribió una persona y lo leen muchas: `javascript:`,
/// `data:` o cualquier otro esquema **nunca** se vuelve enlace. Y el signo de
/// puntuación que cierra una frase («visite www.umg.edu.gt.») no forma parte
/// del enlace.
///
/// Todo el texto sigue siendo **seleccionable** (U-1): tocar un enlace lo abre;
/// mantener pulsado selecciona, como en cualquier otro texto.
library;

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

import '../../core/plataforma/enlace.dart';
import 'tema.dart';

enum TipoDeTrozo { texto, web, correo, telefono }

@immutable
class TrozoDeTexto {
  const TrozoDeTexto(this.tipo, this.texto, [this.destino]);

  final TipoDeTrozo tipo;

  /// Lo que se ve, tal como lo escribieron.
  final String texto;

  /// A dónde lleva; nulo en el texto normal.
  final Uri? destino;

  @override
  bool operator ==(Object other) =>
      other is TrozoDeTexto &&
      other.tipo == tipo &&
      other.texto == texto &&
      other.destino == destino;

  @override
  int get hashCode => Object.hash(tipo, texto, destino);

  @override
  String toString() => 'TrozoDeTexto($tipo, "$texto", $destino)';
}

final RegExp _candidatos = RegExp(
  // Web con esquema, o que empieza por «www.».
  r'(?<web>\bhttps?://[^\s<>"]+|\bwww\.[^\s<>"]+)'
  // Correo.
  r'|(?<correo>\b[A-Za-z0-9._%+-]+@[A-Za-z0-9-]+(?:\.[A-Za-z0-9-]+)*\.[A-Za-z]{2,}\b)'
  // Teléfono de Guatemala, sin más dígitos pegados antes ni después.
  r'|(?<telefono>(?<![\d+])(?:\+502[\s-]?)?[2-7]\d{3}[\s-]?\d{4}(?!\d))',
  caseSensitive: false,
);

/// Puntuación que cierra una frase y no forma parte de la dirección.
final RegExp _colaDePuntuacion = RegExp(r'''[.,;:!?'"»”’\]]+$''');

/// Separa el texto en trozos normales y trozos tocables.
List<TrozoDeTexto> separarEnlaces(String texto) {
  final List<TrozoDeTexto> trozos = <TrozoDeTexto>[];
  int desde = 0;

  void normal(int hasta) {
    if (hasta > desde) {
      trozos.add(
        TrozoDeTexto(TipoDeTrozo.texto, texto.substring(desde, hasta)),
      );
    }
  }

  for (final RegExpMatch m in _candidatos.allMatches(texto)) {
    String visto = m[0]!;
    TipoDeTrozo tipo;
    Uri? destino;

    if (m.namedGroup('web') != null) {
      visto = _sinCola(visto);
      if (visto.length < 5) {
        continue;
      }
      final String conEsquema = visto.toLowerCase().startsWith('www.')
          ? 'https://$visto'
          : visto;
      destino = Uri.tryParse(conEsquema);
      tipo = TipoDeTrozo.web;
      if (destino == null ||
          !<String>{'http', 'https'}.contains(destino.scheme) ||
          destino.host.isEmpty) {
        continue;
      }
    } else if (m.namedGroup('correo') != null) {
      tipo = TipoDeTrozo.correo;
      destino = Uri(scheme: 'mailto', path: visto);
    } else {
      tipo = TipoDeTrozo.telefono;
      final String digitos = visto.replaceAll(RegExp(r'[^\d+]'), '');
      destino = Uri(
        scheme: 'tel',
        path: digitos.startsWith('+') ? digitos : '+502$digitos',
      );
    }

    normal(m.start);
    trozos.add(TrozoDeTexto(tipo, visto, destino));
    desde = m.start + visto.length;
  }
  normal(texto.length);
  return trozos;
}

/// Quita la puntuación final. Un paréntesis de cierre se queda solo si abre
/// otro dentro de la dirección, como en las de Wikipedia.
String _sinCola(String s) {
  String r = s.replaceFirst(_colaDePuntuacion, '');
  while (r.endsWith(')') &&
      ')'.allMatches(r).length > '('.allMatches(r).length) {
    r = r.substring(0, r.length - 1).replaceFirst(_colaDePuntuacion, '');
  }
  return r;
}

/// El texto, seleccionable, con sus enlaces tocables.
class TextoConEnlaces extends StatefulWidget {
  const TextoConEnlaces(this.texto, {this.estilo, super.key});

  final String texto;
  final TextStyle? estilo;

  @override
  State<TextoConEnlaces> createState() => _TextoConEnlacesState();
}

class _TextoConEnlacesState extends State<TextoConEnlaces> {
  final List<TapGestureRecognizer> _reconocedores = <TapGestureRecognizer>[];

  @override
  void dispose() {
    for (final TapGestureRecognizer r in _reconocedores) {
      r.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    for (final TapGestureRecognizer r in _reconocedores) {
      r.dispose();
    }
    _reconocedores.clear();

    final TextStyle base = widget.estilo ?? DefaultTextStyle.of(context).style;
    final TextStyle enlace = base.copyWith(
      color: PaletaSian.de(context).primarioTexto,
      decoration: TextDecoration.underline,
    );

    return SelectableText.rich(
      TextSpan(
        style: base,
        children: <InlineSpan>[
          for (final TrozoDeTexto t in separarEnlaces(widget.texto))
            if (t.destino == null)
              TextSpan(text: t.texto)
            else
              TextSpan(
                text: t.texto,
                style: enlace,
                recognizer:
                    (TapGestureRecognizer()
                        ..onTap = () => abrirEnlace(t.destino!))
                      .._registrarEn(_reconocedores),
                semanticsLabel: t.texto,
              ),
        ],
      ),
    );
  }
}

extension on TapGestureRecognizer {
  void _registrarEn(List<TapGestureRecognizer> lista) => lista.add(this);
}
