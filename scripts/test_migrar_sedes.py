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
        self.assertEqual(ops, [('usuarios/u1', {'membresias': {'bdm': {'rol': 'COORDINADOR', 'facultades': []}},
                                                'sedesIds': ['bdm'], 'sedesCoordina': ['bdm']}, True)])
        self.assertEqual(r['usuarios'], 1)

    def test_rol_desconocido_no_da_privilegios(self):
        ops, _ = plan(usuarios=[('u1', {'rol': 'REY'})])
        self.assertEqual(ops[0][1]['membresias']['bdm']['rol'], 'CATEDRATICO')

    def test_no_pisa_membresias_existentes(self):
        ya = {'otra': {'rol': 'CATEDRATICO', 'facultades': []}}
        self.assertEqual(plan(usuarios=[('u1', {'rol': 'CATEDRATICO', 'membresias': ya,
                                                'sedesIds': ['otra'], 'sedesCoordina': []})])[0], [])

    def test_facultad_a_todos_es_idempotente(self):
        u = ('u1', {'rol': 'CATEDRATICO'})
        ops, r = plan(usuarios=[u], facultad_a_todos=True)
        self.assertEqual(ops[0][1]['membresias']['bdm']['facultades'], ['ing-sistemas'])
        ya = ('u1', {'rol': 'CATEDRATICO', **ops[0][1]})
        self.assertEqual(plan(usuarios=[ya], facultad_a_todos=True)[0], [])

    def test_facultad_a_todos_no_toca_a_quien_no_es_de_bdm(self):
        otra = ('u1', {'rol': 'CATEDRATICO', 'membresias': {'otra': {'rol': 'CATEDRATICO', 'facultades': []}},
                       'sedesIds': ['otra'], 'sedesCoordina': []})
        self.assertEqual(plan(usuarios=[otra], facultad_a_todos=True)[0], [])

    def test_mensajes_y_grupos_sin_sede(self):
        ops, r = plan(grupos=[('g1', {}), ('g2', {'sedeId': 'bdm'})],
                      mensajes=[('m1', {'titulo': 'x'}), ('m2', {'sedeId': 'otra'})])
        self.assertEqual(ops, [('grupos/g1', {'sedeId': 'bdm'}, True), ('mensajes/m1', {'sedeId': 'bdm'}, True)])
        self.assertTrue(all(o[2] is True for o in ops), 'solo actualizar lo que existe')

    def test_admin_general_por_correo(self):
        ops, r = plan(usuarios=[('u1', {'rol': 'COORDINADOR', 'correo': 'Coord@UMG.edu.gt',
                                         'membresias': {'bdm': {'rol': 'COORDINADOR', 'facultades': []}},
                                         'sedesIds': ['bdm'], 'sedesCoordina': ['bdm']})],
                      admin_general='coord@umg.edu.gt')
        self.assertEqual(ops, [('usuarios/u1', {'adminGeneral': True}, True)])
        ya = ('u1', {'correo': 'coord@umg.edu.gt', 'adminGeneral': True,
                     'membresias': {'bdm': {'rol': 'COORDINADOR', 'facultades': []}},
                     'sedesIds': ['bdm'], 'sedesCoordina': ['bdm']})
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



class Contraer(unittest.TestCase):
    """2.0-f: lo viejo que no dice sede se completa (decisiones F1 a F3 del 23/11/2026)."""

    def test_f3_listas_de_sedes_en_el_perfil(self):
        memb = {'villa-nueva': {'rol': 'COORDINADOR', 'facultades': []},
                'bdm': {'rol': 'CATEDRATICO', 'facultades': []}}
        ops, r = plan(usuarios=[('u1', {'rol': 'CATEDRATICO', 'membresias': memb})])
        self.assertEqual(ops, [('usuarios/u1', {'sedesIds': ['bdm', 'villa-nueva'],
                                                'sedesCoordina': ['villa-nueva']}, True)])
        self.assertEqual(r['listas_de_sedes'], 1)

    def test_f1_bitacora_vieja_a_bdm_con_su_asiento(self):
        cuando = m.datetime.datetime(2026, 11, 23, 12, 0, tzinfo=m.datetime.timezone.utc)
        ops, r = plan(bitacora=[('a1', {'tipo': 'X'}), ('a2', {'sedeId': 'villa-nueva'})], ahora=cuando)
        self.assertEqual(ops[0], ('bitacora/a1', {'sedeId': 'bdm'}, True))
        ruta, asiento, debe_existir = ops[1]
        self.assertEqual(ruta, 'bitacora/migracion-2-0-f-20261123120000')
        self.assertFalse(debe_existir, 'el asiento se crea, no pisa nada')
        self.assertEqual(asiento['tipo'], 'MIGRACION_SEDES')
        self.assertIn('1 asientos anteriores', asiento['resumen'])
        self.assertEqual(r['bitacora'], 1)

    def test_f1_sin_nada_que_clasificar_no_hay_asiento(self):
        self.assertEqual(plan(bitacora=[('a2', {'sedeId': 'bdm'})])[0], [])

    def test_f2_entregas_y_hilos_toman_la_sede_de_su_aviso(self):
        ops, r = plan(
            mensajes=[('m-vn', {'sedeId': 'villa-nueva'}), ('m-bdm', {'sedeId': 'bdm'})],
            entregas=[('mensajes/m-vn/ocurrencias/o/entregas/u1', {'mensajeId': 'm-vn'}),
                      ('mensajes/m-bdm/ocurrencias/o/entregas/u2', {}),
                      ('mensajes/m-vn/ocurrencias/o/entregas/u3', {'sedeId': 'villa-nueva'})],
            hilos=[('mensajes/m-vn/hilos/u1', {'mensajeId': 'm-vn'})],
        )
        self.assertEqual(ops, [
            ('mensajes/m-vn/ocurrencias/o/entregas/u1', {'sedeId': 'villa-nueva'}, True),
            ('mensajes/m-bdm/ocurrencias/o/entregas/u2', {'sedeId': 'bdm'}, True),
            ('mensajes/m-vn/hilos/u1', {'sedeId': 'villa-nueva'}, True),
        ])
        self.assertEqual((r['entregas'], r['hilos']), (2, 1))

    def test_invitaciones_sin_sede_a_bdm(self):
        ops, _ = plan(invitaciones=[('a@x', {}), ('b@x', {'sedeId': 'villa-nueva'})])
        self.assertEqual(ops, [('invitaciones/a@x', {'sedeId': 'bdm'}, True)])

    def test_es_idempotente_con_todo_completo(self):
        memb = {'bdm': {'rol': 'CATEDRATICO', 'facultades': []}}
        self.assertEqual(plan(
            usuarios=[('u1', {'rol': 'CATEDRATICO', 'membresias': memb, 'sedesIds': ['bdm'], 'sedesCoordina': []})],
            mensajes=[('m', {'sedeId': 'bdm'})], invitaciones=[('a@x', {'sedeId': 'bdm'})],
            bitacora=[('a', {'sedeId': 'bdm'})],
            entregas=[('mensajes/m/ocurrencias/o/entregas/u1', {'sedeId': 'bdm'})],
            hilos=[('mensajes/m/hilos/u1', {'sedeId': 'bdm'})],
        )[0], [])


class Escritura(unittest.TestCase):
    def test_tandas_de_500(self):
        self.assertEqual([len(t) for t in m.tandas(list(range(1201)))], [500, 500, 201])

    def test_escritura_con_precondicion_y_mascara(self):
        w = m.escritura('projects/p/databases/(default)/documents', ('bitacora/a1', {'sedeId': 'bdm'}, True))
        self.assertEqual(w['update']['name'], 'projects/p/databases/(default)/documents/bitacora/a1')
        self.assertEqual(w['updateMask'], {'fieldPaths': ['sedeId']})
        self.assertEqual(w['currentDocument'], {'exists': True})

    def test_fecha_como_timestamp(self):
        t = m.datetime.datetime(2026, 11, 23, 12, 0, tzinfo=m.datetime.timezone.utc)
        self.assertEqual(m.a_valor(t), {'timestampValue': '2026-11-23T12:00:00Z'})


if __name__ == '__main__':
    unittest.main()
