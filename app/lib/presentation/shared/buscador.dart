/// SIAN — Campo de búsqueda reutilizable.
///
/// ────────────────────────────────────────────────────────────────────────────
/// Se filtra sobre lo ya cargado, no consultando al servidor.
/// ────────────────────────────────────────────────────────────────────────────
///
/// Firestore no sabe buscar texto dentro de un campo: haría falta un índice
/// externo, con su costo y su servicio aparte, y ADR-008 descartó pagar
/// servicios adicionales. Filtrar en memoria es exacto sobre lo que hay
/// cargado y no cuesta nada.
///
/// El límite es honesto y hay que decirlo: si un mensaje está más atrás de lo
/// que se ha traído, la búsqueda no lo encuentra. Por eso el contador dice
/// siempre cuántos se están mirando del total.
library;

import 'package:flutter/material.dart';

import 'tema.dart';
import 'textos.dart';

/// Normaliza para comparar: sin acentos y en minúsculas.
///
/// Sin esto, buscar «simulacro» no encontraría «Simulacro» y buscar
/// «evacuacion» no encontraría «evacuación» — que es justo como la gente
/// escribe cuando tiene prisa.
String normalizar(String texto) {
  const String con = 'áàäâãéèëêíìïîóòöôõúùüûñçÁÀÄÂÃÉÈËÊÍÌÏÎÓÒÖÔÕÚÙÜÛÑÇ';
  const String sin = 'aaaaaeeeeiiiiooooouuuuncAAAAAEEEEIIIIOOOOOUUUUNC';

  final StringBuffer salida = StringBuffer();
  for (final int unidad in texto.toLowerCase().runes) {
    final String c = String.fromCharCode(unidad);
    final int i = con.indexOf(c);
    salida.write(i >= 0 ? sin[i] : c);
  }
  return salida.toString();
}

/// ¿Coincide el término con alguno de estos campos?
bool coincide(String termino, List<String> campos) {
  final String t = normalizar(termino.trim());
  if (t.isEmpty) {
    return true;
  }
  // Todas las palabras deben aparecer, en cualquier campo y en cualquier
  // orden: «simulacro norte» encuentra «Evacuación por la puerta norte —
  // simulacro».
  final List<String> palabras = t.split(RegExp(r'\s+'));
  final String todo = campos.map(normalizar).join(' ');
  return palabras.every(todo.contains);
}

class Buscador extends StatelessWidget {
  const Buscador({
    required this.controlador,
    required this.etiqueta,
    this.resultados,
    super.key,
  });

  final TextEditingController controlador;
  final String etiqueta;

  /// Cuántas coincidencias hay. Nulo mientras no se busca nada.
  final int? resultados;

  @override
  Widget build(BuildContext context) {
    final ThemeData tema = Theme.of(context);
    final bool buscando = controlador.text.trim().isNotEmpty;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        TextField(
          controller: controlador,
          decoration: InputDecoration(
            labelText: etiqueta,
            prefixIcon: const Icon(Icons.search),
            border: const OutlineInputBorder(),
            isDense: true,
            suffixIcon: buscando
                ? IconButton(
                    onPressed: controlador.clear,
                    icon: const Icon(Icons.close),
                    tooltip: Textos.buscarLimpiar,
                  )
                : null,
          ),
        ),
        if (buscando && resultados != null) ...<Widget>[
          const SizedBox(height: 4),
          Text(
            Textos.coincidencias(resultados!),
            style: tema.textTheme.bodySmall?.copyWith(
              color: resultados == 0
                  ? ColoresSian.doradoTexto
                  : tema.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ],
    );
  }
}

/// Botón de «ver más» con su contador.
///
/// Un contador sin número deja a la persona sin saber si quedan tres o
/// trescientos, que es la diferencia entre seguir pulsando y buscar.
class VerMas extends StatelessWidget {
  const VerMas({
    required this.mostrados,
    required this.total,
    required this.alPulsar,
    super.key,
  });

  final int mostrados;
  final int total;
  final VoidCallback alPulsar;

  @override
  Widget build(BuildContext context) {
    if (mostrados >= total) {
      return const SizedBox.shrink();
    }

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Column(
        children: <Widget>[
          OutlinedButton.icon(
            onPressed: alPulsar,
            icon: const Icon(Icons.expand_more),
            label: const Text(Textos.verMas),
          ),
          const SizedBox(height: 4),
          Text(
            Textos.mostrandoDe(mostrados, total),
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}
