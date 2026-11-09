"""
Pruebas del guion de migración a sedes (2.0-c). Corren en la integración
continua: `python3 -m unittest discover -s scripts -p 'test_*.py'`.

Lo que se vigila es lo que haría daño en producción: que correrlo dos veces no
escriba nada la segunda, que no pise lo que ya tiene dato, y que no pueda crear
documentos a medias.
"""
import importlib.util
import os
import unittest

_ruta = os.path.join(os.path.dirname(__file__), 'migrar-sedes.py')
_spec = importlib.util.spec_from_file_location('migrar_sedes', _ruta)
m = importlib.util.module_from_spec(_spec)
_spec.loader.exec_module(m)


def plan(**kw):
    base = dict(usuarios=[], grupos=[], mensajes=[], existe_sede=True, existe_facultad=True)
    base.update(kw)
    return m.planificar(**base)


class Valores(unittest.TestCase):
    def test_ida_y_vuelta(self):
        dato = {'bdm': {'rol': 'CATEDRATICO', 'facultades': ['ing-sistemas'], 'activa': True, 'n': 3}}
        self.assertEqual(m.de_valor(m.a_valor(dato)), dato)

    def test_bool_no_se_confunde_con_entero(self):
        self.assertEqual(m.a_valor(True), {'booleanValue': True})
        self.assertEqual(m.a_valor(1), {'integerValue': '1'})

    def test_tipo_no_soportado(self):
        with self.assertRaises(ValueError):
            m.a_valor(1.5)


class Plan(unittest.TestCase):
    def test_crea_la_sede_y_la_facultad_solo_si_faltan(self):
        ops, r = plan(existe_sede=False, existe_facultad=False)
        self.assertEqual([o[0] for o in ops],
                         ['sedes/bdm', 'sedes/bdm/facultades/ing-sistemas', 'facultades/ing-sistemas'])
        self.assertTrue(all(o[2] is False for o in ops), 'crear solo si no existe')
        self.assertEqual(plan()[0], [])

    def test_perfil_sin_membresias_recibe_la_de_omision(self):
        ops, r = plan(usuarios=[('u1', {'rol': 'COORDINADOR', 'correo': 'a@x'})])
        self.assertEqual(ops, [('usuarios/u1', {'membresias': {'bdm': {'rol': 'COORDINADOR', 'facultades': []}}}, True)])
        self.assertEqual(r['usuarios'], 1)

    def test_rol_desconocido_no_da_privilegios(self):
        ops, _ = plan(usuarios=[('u1', {'rol': 'REY'})])
        self.assertEqual(ops[0][1]['membresias']['bdm']['rol'], 'CATEDRATICO')

    def test_no_pisa_membresias_existentes(self):
        ya = {'otra': {'rol': 'CATEDRATICO', 'facultades': []}}
        self.assertEqual(plan(usuarios=[('u1', {'rol': 'CATEDRATICO', 'membresias': ya})])[0], [])

    def test_facultad_a_todos_es_idempotente(self):
        u = ('u1', {'rol': 'CATEDRATICO'})
        ops, r = plan(usuarios=[u], facultad_a_todos=True)
        self.assertEqual(ops[0][1]['membresias']['bdm']['facultades'], ['ing-sistemas'])
        ya = ('u1', {'rol': 'CATEDRATICO', 'membresias': ops[0][1]['membresias']})
        self.assertEqual(plan(usuarios=[ya], facultad_a_todos=True)[0], [])

    def test_facultad_a_todos_no_toca_a_quien_no_es_de_bdm(self):
        otra = ('u1', {'rol': 'CATEDRATICO', 'membresias': {'otra': {'rol': 'CATEDRATICO', 'facultades': []}}})
        self.assertEqual(plan(usuarios=[otra], facultad_a_todos=True)[0], [])

    def test_mensajes_y_grupos_sin_sede(self):
        ops, r = plan(grupos=[('g1', {}), ('g2', {'sedeId': 'bdm'})],
                      mensajes=[('m1', {'titulo': 'x'}), ('m2', {'sedeId': 'otra'})])
        self.assertEqual(ops, [('grupos/g1', {'sedeId': 'bdm'}, True), ('mensajes/m1', {'sedeId': 'bdm'}, True)])
        self.assertTrue(all(o[2] is True for o in ops), 'solo actualizar lo que existe')

    def test_admin_general_por_correo(self):
        ops, r = plan(usuarios=[('u1', {'rol': 'COORDINADOR', 'correo': 'Coord@UMG.edu.gt',
                                         'membresias': {'bdm': {'rol': 'COORDINADOR', 'facultades': []}}})],
                      admin_general='coord@umg.edu.gt')
        self.assertEqual(ops, [('usuarios/u1', {'adminGeneral': True}, True)])
        ya = ('u1', {'correo': 'coord@umg.edu.gt', 'adminGeneral': True,
                     'membresias': {'bdm': {'rol': 'COORDINADOR', 'facultades': []}}})
        self.assertEqual(plan(usuarios=[ya], admin_general='coord@umg.edu.gt')[0], [])

    def test_admin_general_con_correo_inexistente_no_escribe_nada(self):
        with self.assertRaises(ValueError):
            plan(usuarios=[('u1', {'correo': 'a@x'})], admin_general='nadie@x')

    def test_la_bitacora_no_se_toca(self):
        ops, _ = plan(usuarios=[('u1', {'rol': 'CATEDRATICO'})], grupos=[('g', {})], mensajes=[('m', {})])
        self.assertFalse(any(o[0].startswith('bitacora/') for o in ops))



class CatalogoUnico(unittest.TestCase):
    """2.0.6: las facultades que ya tienen las sedes pasan al catálogo único."""

    def test_adopta_cada_facultad_una_vez_con_su_mismo_identificador(self):
        ops, r = plan(facultades_por_sede=[
            ('bdm', 'ing-sistemas', {'nombre': 'Ingeniería en Sistemas', 'activa': True}),
            ('bdm', 'psicologia', {'nombre': 'Psicología', 'activa': False}),
            ('villa-nueva', 'ing-sistemas', {'nombre': 'Ingeniería en Sistemas', 'activa': True}),
        ], catalogo={})
        self.assertEqual(ops, [
            ('facultades/ing-sistemas', {'nombre': 'Ingeniería en Sistemas', 'activa': True}, False),
            ('facultades/psicologia', {'nombre': 'Psicología', 'activa': True}, False),
        ])
        self.assertEqual(r['catalogo_facultades'], 2)

    def test_es_idempotente(self):
        sedes = [('bdm', 'ing-sistemas', {'nombre': 'Ingeniería en Sistemas'})]
        self.assertEqual(plan(facultades_por_sede=sedes,
                              catalogo={'ing-sistemas': {'nombre': 'Ingeniería en Sistemas', 'activa': True}})[0], [])

    def test_mismo_nombre_con_otro_identificador_no_se_adivina(self):
        ops, r = plan(facultades_por_sede=[
            ('bdm', 'ing-sistemas', {'nombre': 'Ingeniería en Sistemas'}),
            ('villa-nueva', 'ingenieria-en-sistemas', {'nombre': 'ingenieria en  sistemas'}),
        ], catalogo={})
        self.assertEqual([o[0] for o in ops], ['facultades/ing-sistemas'])
        self.assertEqual(len(r['conflictos']), 1)
        self.assertIn('villa-nueva', r['conflictos'][0])

    def test_clave_de_nombre_como_el_servidor(self):
        self.assertEqual(m.clave_de_nombre('  Ingeniería   en SISTEMAS '), 'ingenieria en sistemas')


if __name__ == '__main__':
    unittest.main()
