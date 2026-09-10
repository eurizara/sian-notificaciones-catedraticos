/// SIAN — La banda que avisa cuando NO se está en producción (DT-20).
///
/// ────────────────────────────────────────────────────────────────────────────
/// Va sobre TODA la aplicación, no dentro de una pantalla.
/// ────────────────────────────────────────────────────────────────────────────
///
/// El error que previene se comete al redactar un aviso, no al entrar, así que
/// tiene que verse en todas partes y no solo al ingresar. Y tiene que verse
/// también en la pantalla de ingreso, porque entrar al ambiente equivocado es el
/// primer paso de equivocarse en todo lo demás.
///
/// Por eso se monta en `MaterialApp.builder` y no en `BarraSesion`: hay
/// pantallas sin barra —ingreso, registro, diagnóstico de arranque— y son justo
/// las que más conviene marcar.
///
/// ────────────────────────────────────────────────────────────────────────────
/// Empuja el contenido, no lo tapa
/// ────────────────────────────────────────────────────────────────────────────
///
/// Una banda flotante encima taparía algo, y lo que tape será distinto en cada
/// pantalla y en cada tamaño. Ocupar su propio espacio cuesta unos píxeles y no
/// esconde nada.
library;

import 'package:flutter/material.dart';

import '../../core/ambiente.dart';
import 'tema.dart';
import 'textos.dart';

/// Envuelve [hijo] con la banda, si el ambiente lo pide.
///
/// En producción devuelve [hijo] tal cual: ni un widget de más.
class BandaAmbiente extends StatelessWidget {
  const BandaAmbiente({required this.ambiente, required this.hijo, super.key});

  final Ambiente ambiente;
  final Widget hijo;

  @override
  Widget build(BuildContext context) {
    if (!ambienteNecesitaAviso(ambiente)) {
      return hijo;
    }

    return Column(
      children: <Widget>[
        _Banda(ambiente: ambiente),
        Expanded(child: hijo),
      ],
    );
  }
}

class _Banda extends StatelessWidget {
  const _Banda({required this.ambiente});

  final Ambiente ambiente;

  @override
  Widget build(BuildContext context) {
    return Material(
      // Dorado oscurecido: 5.03:1 con blanco encima, que cumple AA para texto
      // normal (RNF-13).
      //
      // No se usa el rojo, y no es por gusto: el rojo institucional está
      // reservado en exclusiva a las alertas urgentes. Si también significara
      // «ambiente de pruebas», dejaría de significar «urgente», y en una
      // emergencia real eso importa.
      color: ColoresSian.doradoTexto,
      child: SafeArea(
        bottom: false,
        child: Semantics(
          // Un lector de pantalla tiene que anunciarlo como aviso, no leerlo
          // como un texto suelto perdido arriba de todo.
          liveRegion: true,
          header: true,
          child: SizedBox(
            width: double.infinity,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              child: Text(
                _etiqueta(ambiente),
                textAlign: TextAlign.center,
                // El color NO viaja solo: el texto dice «NO ES PRODUCCIÓN» con
                // todas sus letras. Quien no distinga el dorado del azul de la
                // barra lee lo mismo que quien sí.
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                  fontSize: 13,
                  letterSpacing: 0.3,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

String _etiqueta(Ambiente ambiente) => switch (ambiente) {
  Ambiente.desarrollo => Textos.ambienteDesarrollo,
  Ambiente.calidad => Textos.ambienteCalidad,
  Ambiente.desconocido => Textos.ambienteDesconocido,
  // No se llega aquí: `ambienteNecesitaAviso` ya devolvió falso.
  Ambiente.produccion => '',
};
