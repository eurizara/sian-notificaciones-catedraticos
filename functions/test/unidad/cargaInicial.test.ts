/**
 * Lo que descarga el aparato cada vez que se abre SIAN (S-7).
 *
 * ─────────────────────────────────────────────────────────────────────────────
 * Medido el 25/09/2026 en desarrollo
 * ─────────────────────────────────────────────────────────────────────────────
 *
 * `main.dart.js` son 820 KB comprimidos y se servía con `no-store`: se volvía a
 * descargar entero en CADA apertura. Hosting no contesta 304 a lo que se sirve
 * sin caché, así que el escudo y las cuatro tipografías (unos 350 KB que no
 * cambian nunca) también. Cargar el panel de coordinación aparte solo ahorraba
 * 81 KB (~10 %): lo que pesaba no era el tamaño, sino repetir la descarga.
 *
 * La solución es la de siempre: huella de contenido en el nombre y caché larga.
 * El nombre cambia cuando cambia el contenido, así que nunca se sirve algo viejo.
 * Estas pruebas vigilan las tres piezas: el guion que pone la huella, las
 * cabeceras de Hosting y que el despliegue lo use en los tres ambientes.
 */

import { execFileSync } from 'node:child_process';
import { createHash } from 'node:crypto';
import { mkdtempSync, readdirSync, readFileSync, statSync, writeFileSync } from 'node:fs';
import { tmpdir } from 'node:os';
import { join, relative } from 'node:path';

import { minimatch } from 'minimatch';

const raiz = join(__dirname, '../../..');
const leer = (ruta: string) => readFileSync(join(raiz, ruta), 'utf8');
const guion = join(raiz, 'scripts/huella-paquete.sh');

const BOOTSTRAP =
  '_flutter.buildConfig = {"engineRevision":"x","builds":[{"compileTarget":"dart2js",' +
  '"renderer":"canvaskit","mainJsPath":"main.dart.js"},{}]};\n' +
  'let{entrypointUrl:n=c("main.dart.js")}=e||{};';

function carpetaDePrueba(bootstrap = BOOTSTRAP): string {
  const dir = mkdtempSync(join(tmpdir(), 'huella-'));
  writeFileSync(join(dir, 'main.dart.js'), 'console.log("sian");');
  writeFileSync(join(dir, 'flutter_bootstrap.js'), bootstrap);
  return dir;
}

function correr(dir: string): { codigo: number; salida: string } {
  try {
    const salida = execFileSync('bash', [guion, dir], { encoding: 'utf8', stdio: 'pipe' });
    return { codigo: 0, salida };
  } catch (e) {
    const err = e as { status: number; stderr: string };
    return { codigo: err.status, salida: err.stderr };
  }
}

describe('huella-paquete.sh', () => {
  it('renombra main.dart.js con la huella de su contenido y apunta el arranque a él', () => {
    const dir = carpetaDePrueba();
    const huella = createHash('sha256')
      .update('console.log("sian");')
      .digest('hex')
      .slice(0, 12);

    expect(correr(dir).codigo).toBe(0);

    const archivos = readdirSync(dir).sort();
    expect(archivos).toEqual(['flutter_bootstrap.js', `main.${huella}.dart.js`]);
    const arranque = readFileSync(join(dir, 'flutter_bootstrap.js'), 'utf8');
    expect(arranque).toContain(`"mainJsPath":"main.${huella}.dart.js"`);
    expect(arranque).not.toContain('"mainJsPath":"main.dart.js"');
  });

  it('si el arranque no tiene la forma esperada, falla y no toca nada', () => {
    // Una versión nueva de Flutter puede cambiar el formato. Publicar entonces
    // un arranque que apunta a un archivo que no existe dejaría la app en
    // blanco: mejor que el despliegue se detenga.
    const dir = carpetaDePrueba('_flutter.buildConfig = {"builds":[]};');
    const r = correr(dir);
    expect(r.codigo).not.toBe(0);
    expect(r.salida).toContain('mainJsPath');
    expect(readdirSync(dir).sort()).toEqual(['flutter_bootstrap.js', 'main.dart.js']);
  });

  it('sin main.dart.js, falla', () => {
    const dir = mkdtempSync(join(tmpdir(), 'huella-'));
    writeFileSync(join(dir, 'flutter_bootstrap.js'), BOOTSTRAP);
    expect(correr(dir).codigo).not.toBe(0);
  });
});

interface Regla {
  source?: string;
  headers: { key: string; value: string }[];
}

function reglas(): Regla[] {
  const config = JSON.parse(leer('firebase.json')) as { hosting: { headers?: Regla[] } };
  return config.hosting.headers ?? [];
}

function cachePara(ruta: string): string[] {
  return reglas()
    .filter((r) => r.source !== undefined && minimatch(ruta, r.source, { dot: true }))
    .flatMap((r) => r.headers.filter((h) => h.key === 'Cache-Control').map((h) => h.value));
}

describe('cabeceras de Hosting', () => {
  it('el paquete con huella se guarda un año, y ninguna otra regla lo contradice', () => {
    expect(cachePara('/main.0123456789ab.dart.js')).toEqual([
      'public, max-age=31536000, immutable',
    ]);
  });

  it('lo que no lleva huella sigue sin caché: el arranque, index y version.json', () => {
    for (const ruta of ['/flutter_bootstrap.js', '/index.html', '/version.json', '/main.dart.js']) {
      expect(cachePara(ruta)).toEqual(['no-cache, no-store, must-revalidate']);
    }
  });

  it('el escudo y las tipografías propias se guardan una semana', () => {
    for (const ruta of [
      '/assets/assets/escudo-umg.png',
      '/assets/assets/fuentes/Urbanist-400.ttf',
    ]) {
      expect(cachePara(ruta)).toEqual(['public, max-age=604800']);
    }
  });

  it('lo que genera Flutter en cada compilación sigue revalidándose', () => {
    // La fuente de iconos se recorta en cada compilación con el mismo nombre:
    // es la que dejó botones sin icono una semana (ver firebase.json).
    for (const ruta of [
      '/assets/fonts/MaterialIcons-Regular.otf',
      '/assets/AssetManifest.bin',
      '/assets/FontManifest.json',
      '/assets/NOTICES',
      '/assets/shaders/ink_sparkle.frag',
      '/assets/packages/cupertino_icons/assets/CupertinoIcons.ttf',
    ]) {
      expect(cachePara(ruta)).toEqual(['no-cache']);
    }
  });
});

describe('el despliegue pone la huella en los tres ambientes', () => {
  it('después de sellar la versión, y antes de publicar', () => {
    const flujo = leer('.github/workflows/deploy.yml');
    const sellar = [...flujo.matchAll(/bash scripts\/sellar-version\.sh app\/build\/web/g)];
    const huella = [...flujo.matchAll(/bash scripts\/huella-paquete\.sh app\/build\/web/g)];
    expect(sellar).toHaveLength(3);
    expect(huella).toHaveLength(3);
    for (let i = 0; i < 3; i += 1) {
      expect(huella[i]!.index!).toBeGreaterThan(sellar[i]!.index!);
    }
  });
});

describe('el escudo y las tipografías: si cambian, cambian de nombre', () => {
  // Con una semana de caché, un archivo que cambia de contenido y conserva el
  // nombre se seguiría viendo viejo en los aparatos durante días. Si esta
  // prueba falla porque cambiaste uno: dale un nombre nuevo (escudo-umg-2.png),
  // actualiza pubspec.yaml y el código que lo usa, y anota aquí su huella.
  const HUELLAS: Record<string, string> = {
    'escudo-umg.png': 'ffe0b54206b47a51',
    'fuentes/Urbanist-400.ttf': '599ec73b0a0388ba',
    'fuentes/Urbanist-500.ttf': '7b9e538738641d42',
    'fuentes/Urbanist-600.ttf': 'beb886f39281fdb7',
    'fuentes/Urbanist-700.ttf': 'e166b470f65b6c2a',
  };

  it('cada archivo conserva el contenido con el que se publicó', () => {
    const base = join(raiz, 'app/assets');
    const actuales: Record<string, string> = {};
    const recorrer = (dir: string) => {
      for (const nombre of readdirSync(dir)) {
        const ruta = join(dir, nombre);
        if (statSync(ruta).isDirectory()) {
          recorrer(ruta);
        } else if (!nombre.endsWith('.txt')) {
          actuales[relative(base, ruta)] = createHash('sha256')
            .update(readFileSync(ruta))
            .digest('hex')
            .slice(0, 16);
        }
      }
    };
    recorrer(base);
    expect(actuales).toEqual(HUELLAS);
  });
});
