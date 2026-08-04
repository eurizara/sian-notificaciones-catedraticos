/// SIAN — Política de contraseñas del cliente (RF-AUT-06).
///
/// Espejo de `functions/src/domain/politicaContrasena.ts`. Aquí sirve para dar
/// retroalimentación mientras se teclea; **la fuente de verdad es la del
/// servidor**, y esta duplicación es exactamente la deuda DT-06.
///
/// Ambas comprueban lo mismo y en el mismo orden de importancia:
///
///   1. Longitud — el único factor que crece exponencialmente
///   2. No delatar a quien la eligió
///   3. No estar en las listas de siempre
///   4. No ser secuencia ni repetición
///   5. Composición: mayúscula, minúscula, dígito y símbolo
library;

abstract final class PoliticaContrasena {
  /// RF-AUT-06. No baja de 10.
  static const int longitudMinima = 10;
  static const int longitudRecomendada = 14;
  static const int fragmentoPersonalMinimo = 4;
  static const int longitudSecuencia = 4;
}

enum IncumplimientoContrasena {
  longitudMinima,
  faltaMayuscula,
  faltaMinuscula,
  faltaDigito,
  faltaSimbolo,
  contieneDatosPersonales,
  demasiadoComun,
  secuenciaObvia,
  caracterRepetido,
}

enum FuerzaContrasena { insuficiente, aceptable, buena, excelente }

class ResultadoPolitica {
  const ResultadoPolitica({
    required this.valida,
    required this.incumplimientos,
    required this.fuerza,
  });

  final bool valida;
  final List<IncumplimientoContrasena> incumplimientos;
  final FuerzaContrasena fuerza;
}

const List<String> _comunes = <String>[
  'password', 'contrasena', 'contraseña', '123456', '12345678', '123456789',
  'qwerty', 'qwertyui', 'abc123', 'iloveyou', 'admin', 'administrador',
  'usuario', 'bienvenido', 'sian', 'umg', 'umgbdm', 'marianogalvez',
  'universidad', 'guatemala', 'catedratico', 'coordinacion', 'bocadelmonte',
  'simulacro', 'letmein', 'welcome',
];

String _normalizar(String texto) {
  const Map<String, String> tildes = <String, String>{
    'á': 'a', 'é': 'e', 'í': 'i', 'ó': 'o', 'ú': 'u', 'ü': 'u',
    'Á': 'a', 'É': 'e', 'Í': 'i', 'Ó': 'o', 'Ú': 'u', 'Ü': 'u',
  };
  final StringBuffer sb = StringBuffer();
  for (final String c in texto.toLowerCase().split('')) {
    sb.write(tildes[c] ?? c);
  }
  return sb.toString();
}

/// `P@ssw0rd` no es más segura que `password`, solo más incómoda de teclear.
String _deshacerSustituciones(String texto) => texto
    .replaceAll(RegExp('[@4]'), 'a')
    .replaceAll(RegExp('[3€]'), 'e')
    .replaceAll(RegExp(r'[1!|]'), 'i')
    .replaceAll('0', 'o')
    .replaceAll(RegExp(r'[5$]'), 's')
    .replaceAll('7', 't');

List<String> _fragmentosPersonales({String? correo, String? nombre}) {
  final List<String> crudos = <String>[];

  if (correo != null && correo.contains('@')) {
    final List<String> partes = correo.split('@');
    final String local = partes.first;
    crudos.add(local);
    crudos.addAll(local.split(RegExp(r'[._\-+\d]+')));
    crudos.addAll(partes.last.split('.'));
  }
  if (nombre != null) {
    crudos.addAll(nombre.split(RegExp(r'\s+')));
  }

  return crudos
      .map(_normalizar)
      .where((String f) => f.length >= PoliticaContrasena.fragmentoPersonalMinimo)
      .toList();
}

bool _tieneSecuencia(String texto) {
  const int n = PoliticaContrasena.longitudSecuencia;
  const List<String> teclado = <String>[
    'qwertyuiop',
    'asdfghjkl',
    'zxcvbnm',
    '1234567890',
  ];

  for (int i = 0; i + n <= texto.length; i += 1) {
    final String trozo = texto.substring(i, i + n);

    bool ascendente = true;
    bool descendente = true;
    for (int j = 1; j < trozo.length; j += 1) {
      final int paso = trozo.codeUnitAt(j) - trozo.codeUnitAt(j - 1);
      if (paso != 1) ascendente = false;
      if (paso != -1) descendente = false;
    }
    if (ascendente || descendente) {
      return true;
    }

    final String invertido = trozo.split('').reversed.join();
    if (teclado.any((String f) => f.contains(trozo) || f.contains(invertido))) {
      return true;
    }
  }
  return false;
}

bool _tieneRepeticion(String texto) {
  int racha = 1;
  for (int i = 1; i < texto.length; i += 1) {
    racha = texto[i] == texto[i - 1] ? racha + 1 : 1;
    if (racha >= PoliticaContrasena.longitudSecuencia) {
      return true;
    }
  }
  return false;
}

/// Evalúa una contraseña. Devuelve **todos** los incumplimientos, no el primero.
ResultadoPolitica evaluarContrasena(
  String bruto, {
  String? correo,
  String? nombre,
}) {
  final List<IncumplimientoContrasena> fallos = <IncumplimientoContrasena>[];
  final List<String> caracteres = bruto.characters();

  if (caracteres.length < PoliticaContrasena.longitudMinima) {
    fallos.add(IncumplimientoContrasena.longitudMinima);
  }
  if (!RegExp('[A-ZÁÉÍÓÚÑÜ]').hasMatch(bruto)) {
    fallos.add(IncumplimientoContrasena.faltaMayuscula);
  }
  if (!RegExp('[a-záéíóúñü]').hasMatch(bruto)) {
    fallos.add(IncumplimientoContrasena.faltaMinuscula);
  }
  if (!RegExp(r'\d').hasMatch(bruto)) {
    fallos.add(IncumplimientoContrasena.faltaDigito);
  }
  if (!RegExp(r'[^\p{L}\p{N}\s]', unicode: true).hasMatch(bruto)) {
    fallos.add(IncumplimientoContrasena.faltaSimbolo);
  }

  final String normalizada = _normalizar(bruto);
  final String desustituida = _deshacerSustituciones(normalizada);

  final List<String> personales = _fragmentosPersonales(
    correo: correo,
    nombre: nombre,
  );
  if (personales.any(
    (String f) => normalizada.contains(f) || desustituida.contains(f),
  )) {
    fallos.add(IncumplimientoContrasena.contieneDatosPersonales);
  }

  final String invertida = desustituida.split('').reversed.join();
  if (_comunes.any(
    (String c) =>
        desustituida.contains(c) || normalizada.contains(c) || invertida.contains(c),
  )) {
    fallos.add(IncumplimientoContrasena.demasiadoComun);
  }

  if (_tieneSecuencia(normalizada)) {
    fallos.add(IncumplimientoContrasena.secuenciaObvia);
  }
  if (_tieneRepeticion(bruto)) {
    fallos.add(IncumplimientoContrasena.caracterRepetido);
  }

  return ResultadoPolitica(
    valida: fallos.isEmpty,
    incumplimientos: fallos,
    fuerza: _calcularFuerza(bruto, fallos.isEmpty),
  );
}

FuerzaContrasena _calcularFuerza(String v, bool cumple) {
  if (!cumple) {
    return FuerzaContrasena.insuficiente;
  }
  final int largo = v.characters().length;
  final int variedad = <bool>[
    RegExp('[a-záéíóúñü]').hasMatch(v),
    RegExp('[A-ZÁÉÍÓÚÑÜ]').hasMatch(v),
    RegExp(r'\d').hasMatch(v),
    RegExp(r'[^\p{L}\p{N}\s]', unicode: true).hasMatch(v),
  ].where((bool b) => b).length;

  if (largo >= 16 && variedad == 4) {
    return FuerzaContrasena.excelente;
  }
  if (largo >= PoliticaContrasena.longitudRecomendada) {
    return FuerzaContrasena.buena;
  }
  return FuerzaContrasena.aceptable;
}

extension _Caracteres on String {
  /// Caracteres reales, no unidades de código: un acento no gasta doble.
  List<String> characters() => runes.map(String.fromCharCode).toList();
}
