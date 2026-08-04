/**
 * Pruebas de la política de contraseñas — RF-AUT-06.
 *
 * El objetivo de estas pruebas no es que «cumpla las cuatro reglas», sino que
 * **rechace lo que un atacante probaría primero**: el nombre de la persona, el
 * de la institución, y las listas de siempre.
 */

import {
  POLITICA_CONTRASENA,
  evaluarContrasena,
} from '../../src/domain/politicaContrasena';

/** Una contraseña que cumple todo, para partir de algo válido. */
const BUENA = 'Trueno#Violeta47';

describe('composición mínima', () => {
  it('acepta una contraseña que cumple la política completa', () => {
    const r = evaluarContrasena(BUENA);
    expect(r.valida).toBe(true);
    expect(r.incumplimientos).toEqual([]);
  });

  it('exige 10 caracteres y no menos', () => {
    // La longitud es el único factor que crece exponencialmente: rebajarla
    // para añadir un símbolo sería cambiar entropía por apariencia de rigor.
    expect(POLITICA_CONTRASENA.longitudMinima).toBe(10);
    expect(evaluarContrasena('Corto#1a').incumplimientos).toContain('LONGITUD_MINIMA');
    expect(evaluarContrasena('Trueno#47x').incumplimientos).not.toContain('LONGITUD_MINIMA');
  });

  it('exige mayúscula, minúscula, dígito y símbolo', () => {
    expect(evaluarContrasena('trueno#violeta47').incumplimientos).toContain('FALTA_MAYUSCULA');
    expect(evaluarContrasena('TRUENO#VIOLETA47').incumplimientos).toContain('FALTA_MINUSCULA');
    expect(evaluarContrasena('Trueno#Violeta').incumplimientos).toContain('FALTA_DIGITO');
    expect(evaluarContrasena('TruenoVioleta47').incumplimientos).toContain('FALTA_SIMBOLO');
  });

  it('cuenta caracteres, no bytes: los acentos no gastan doble', () => {
    expect(evaluarContrasena('Ñandú#Café47').valida).toBe(true);
  });

  it('informa TODOS los incumplimientos de una vez', () => {
    // Soltar una regla cada vez es la forma más segura de que la persona
    // acabe eligiendo algo malo por agotamiento.
    const r = evaluarContrasena('abc');
    expect(r.incumplimientos.length).toBeGreaterThanOrEqual(4);
    expect(r.incumplimientos).toEqual(
      expect.arrayContaining([
        'LONGITUD_MINIMA',
        'FALTA_MAYUSCULA',
        'FALTA_DIGITO',
        'FALTA_SIMBOLO',
      ]),
    );
  });
});

describe('no puede delatar a quien la eligió', () => {
  const contexto = {
    correo: 'ana.perez@umg.edu.gt',
    nombre: 'Ana Pérez López',
  };

  it('rechaza la que contiene el usuario del correo', () => {
    expect(evaluarContrasena('Perez#Segura47', contexto).incumplimientos).toContain(
      'CONTIENE_DATOS_PERSONALES',
    );
  });

  it('rechaza la que contiene el apellido, aunque cambie la caja', () => {
    expect(evaluarContrasena('XYZ#LOPEZ2047', contexto).incumplimientos).toContain(
      'CONTIENE_DATOS_PERSONALES',
    );
  });

  it('rechaza aunque se disfrace con sustituciones', () => {
    // `P3r3z` no es más segura que `Perez`, solo más incómoda de teclear.
    expect(evaluarContrasena('XY#P3r3z2047', contexto).incumplimientos).toContain(
      'CONTIENE_DATOS_PERSONALES',
    );
  });

  it('rechaza la que contiene la unidad académica del correo', () => {
    expect(
      evaluarContrasena('Cielo#Ingenieria47', {
        correo: 'ana.perez@ingenieria.umg.edu.gt',
      }).incumplimientos,
    ).toContain('CONTIENE_DATOS_PERSONALES');
  });

  it('«umg» se rechaza igual, aunque por la lista y no por el contexto', () => {
    // Tiene tres caracteres, por debajo del mínimo para considerarlo
    // fragmento personal. Lo que importa es que NO pase, no por qué regla.
    expect(evaluarContrasena('Cielo#umg2047', contexto).valida).toBe(false);
  });

  it('no se confunde con fragmentos demasiado cortos', () => {
    // «de», «la» y similares aparecerían en media contraseña del mundo.
    const r = evaluarContrasena('Trueno#Violeta47', {
      nombre: 'Ana de la Cruz',
      correo: 'a.cruz@umg.edu.gt',
    });
    expect(r.incumplimientos).not.toContain('CONTIENE_DATOS_PERSONALES');
  });

  it('sin contexto, no inventa coincidencias', () => {
    expect(evaluarContrasena(BUENA).valida).toBe(true);
  });
});

describe('listas de siempre', () => {
  it('rechaza las contraseñas más probadas del mundo', () => {
    for (const mala of ['Password#2047', 'Qwerty#12047', 'Admin#204711']) {
      expect(evaluarContrasena(mala).incumplimientos).toContain('DEMASIADO_COMUN');
    }
  });

  it('rechaza el nombre del sistema y el de la universidad', () => {
    // Es lo primero que probaría cualquiera que sepa qué sistema es.
    for (const mala of ['Sian#Segura47', 'Umg#Guatemala47', 'Simulacro#2047']) {
      expect(evaluarContrasena(mala).incumplimientos).toContain('DEMASIADO_COMUN');
    }
  });

  it('las reconoce aunque vengan disfrazadas', () => {
    expect(evaluarContrasena('P@ssw0rd#47X').incumplimientos).toContain('DEMASIADO_COMUN');
  });
});

describe('secuencias y repeticiones', () => {
  it('rechaza secuencias del abecedario y de los dígitos', () => {
    // `Abcdefgh` tiene ocho caracteres y ninguna resistencia.
    expect(evaluarContrasena('Xk#Abcdefgh9').incumplimientos).toContain('SECUENCIA_OBVIA');
    expect(evaluarContrasena('Xk#Trueno1234').incumplimientos).toContain('SECUENCIA_OBVIA');
  });

  it('rechaza secuencias de teclado', () => {
    expect(evaluarContrasena('Xk#Truenoasdf9').incumplimientos).toContain('SECUENCIA_OBVIA');
  });

  it('rechaza secuencias descendentes', () => {
    expect(evaluarContrasena('Xk#Trueno4321').incumplimientos).toContain('SECUENCIA_OBVIA');
  });

  it('rechaza un carácter repetido cuatro veces', () => {
    expect(evaluarContrasena('Trueno#aaaa47').incumplimientos).toContain('CARACTER_REPETIDO');
  });

  it('tolera una repetición corta, que es normal en palabras reales', () => {
    // «Ll» y «rr» aparecen en castellano constantemente.
    expect(evaluarContrasena('Caballo#Verde47').valida).toBe(true);
  });
});

describe('fuerza orientativa', () => {
  it('lo que no cumple es insuficiente, sin matices', () => {
    expect(evaluarContrasena('abc').fuerza).toBe('INSUFICIENTE');
  });

  it('premia la longitud por encima de la variedad', () => {
    // Es la señal que se quiere dar: alargar ayuda más que añadir otro signo
    // de admiración.
    expect(evaluarContrasena('Trueno#47x').fuerza).toBe('ACEPTABLE'); // 10
    expect(evaluarContrasena('Trueno#Vio47x').fuerza).toBe('ACEPTABLE'); // 13
    expect(evaluarContrasena('Trueno#Violet47').fuerza).toBe('BUENA'); // 15
    expect(evaluarContrasena('Trueno#Violeta47Nube').fuerza).toBe('EXCELENTE'); // 20
  });
});
