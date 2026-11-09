"""
Pruebas del control de versión (corre en la integración continua).

El caso que lo motivó: la 2.0 llegó a desarrollo con el número 1.6.20.
"""
import importlib.util
import os
import unittest

_ruta = os.path.join(os.path.dirname(__file__), 'verificar-version.py')
_spec = importlib.util.spec_from_file_location('verificar_version', _ruta)
v = importlib.util.module_from_spec(_spec)
_spec.loader.exec_module(v)


def version(texto):
    return f"/// x\nconst String versionSian = '{texto}';\n"


class Control(unittest.TestCase):
    def test_el_caso_del_07_11_cambio_en_la_app_sin_subir_version(self):
        bien, mensaje = v.decidir(['app/lib/presentation/admin/seccion_catalogos.dart'],
                                  version('1.6.20'), version('1.6.20'))
        self.assertFalse(bien)
        self.assertIn('1.6.20', mensaje)

    def test_subir_la_version_lo_deja_pasar(self):
        self.assertTrue(v.decidir(['app/lib/x.dart'], version('1.6.20'), version('2.0.0'))[0])
        self.assertTrue(v.decidir(['app/web/firebase-messaging-sw.js'], version('1.6.20'), version('1.6.21'))[0])

    def test_bajar_la_version_no_vale(self):
        self.assertFalse(v.decidir(['app/lib/x.dart'], version('2.0.0'), version('1.9.9'))[0])

    def test_compara_por_numero_no_por_texto(self):
        self.assertTrue(v.decidir(['app/lib/x.dart'], version('1.6.9'), version('1.6.10'))[0])

    def test_lo_que_no_llega_a_quien_usa_sian_no_exige_version(self):
        for archivos in (['docs/13-cartera-de-incrementos.md'], ['functions/src/domain/sede.ts'],
                         ['app/test/widget/x_test.dart'], ['app/web/manuales/index.html'],
                         ['app/pubspec.lock'], ['.github/workflows/ci.yml'], []):
            self.assertTrue(v.decidir(archivos, version('1.6.20'), version('1.6.20'))[0], archivos)

    def test_sin_version_legible_falla(self):
        self.assertFalse(v.decidir(['app/lib/x.dart'], version('1.6.20'), 'nada')[0])

    def test_base_sin_version_no_bloquea(self):
        self.assertTrue(v.decidir(['app/lib/x.dart'], '', version('1.0.0'))[0])


if __name__ == '__main__':
    unittest.main()
