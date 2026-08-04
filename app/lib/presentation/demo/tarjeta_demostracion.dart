/// SIAN — Modo demostración.
///
/// ────────────────────────────────────────────────────────────────────────────
/// SOLO EXISTE CONTRA EMULADORES.
/// ────────────────────────────────────────────────────────────────────────────
///
/// Permite entrar con un clic como cualquiera de los roles sembrados por
/// `npm run seed:dev`, para recorrer los casos de uso del documento 01,
/// sección 8, sin teclear credenciales cada vez.
///
/// **No es una cuenta de invitado.** RF-AUT-03 no admite excepciones: solo
/// entra quien está en la lista blanca institucional. Esto se limita a
/// rellenar el formulario con credenciales que ya existen en el emulador —las
/// mismas que cualquiera puede ver en `scripts/seed-dev.ts`— y a pulsar el
/// mismo botón de siempre. No hay una puerta paralela: el inicio de sesión que
/// se ejecuta es exactamente el de producción.
///
/// Quien la use pasa por las mismas reglas de seguridad y los mismos custom
/// claims que cualquier usuario real.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../application/proveedores_sesion.dart';
import '../../core/entorno.dart';
import '../../domain/rol.dart';
import '../shared/textos.dart';

/// Cuenta sembrada por `scripts/seed-dev.ts`.
@immutable
class CuentaDemostracion {
  const CuentaDemostracion({
    required this.correo,
    required this.rol,
    required this.descripcion,
  });

  final String correo;
  final Rol rol;

  /// Qué se puede probar entrando con esta cuenta.
  final String descripcion;

  /// Contraseña común de las cuentas sembradas. Está a la vista en
  /// `scripts/seed-dev.ts`, y solo existe dentro del emulador.
  static const String contrasena = 'Aula#Magna2047';

  static const List<CuentaDemostracion> todas = <CuentaDemostracion>[
    CuentaDemostracion(
      correo: 'coordinacion@umg.edu.gt',
      rol: Rol.coordinador,
      descripcion: Textos.demoCoordinador,
    ),
    CuentaDemostracion(
      correo: 'admin1@umg.edu.gt',
      rol: Rol.administradora,
      descripcion: Textos.demoAdministradora1,
    ),
    CuentaDemostracion(
      correo: 'admin2@umg.edu.gt',
      rol: Rol.administradora,
      descripcion: Textos.demoAdministradora2,
    ),
    CuentaDemostracion(
      correo: 'catedratico1@umg.edu.gt',
      rol: Rol.catedratico,
      descripcion: Textos.demoCatedratico,
    ),
    CuentaDemostracion(
      correo: 'auditoria@umg.edu.gt',
      rol: Rol.auditor,
      descripcion: Textos.demoAuditor,
    ),
  ];
}

class TarjetaDemostracion extends ConsumerStatefulWidget {
  const TarjetaDemostracion({super.key});

  @override
  ConsumerState<TarjetaDemostracion> createState() =>
      _TarjetaDemostracionState();
}

class _TarjetaDemostracionState extends ConsumerState<TarjetaDemostracion> {
  String? _entrando;
  String? _error;

  Future<void> _entrarComo(CuentaDemostracion cuenta) async {
    setState(() {
      _entrando = cuenta.correo;
      _error = null;
    });

    try {
      await ref
          .read(repositorioSesionProvider)
          .entrarConCorreo(
            correo: cuenta.correo,
            contrasena: CuentaDemostracion.contrasena,
          );
    } on Object catch (_) {
      if (mounted) {
        setState(() => _error = Textos.demoErrorSinSemilla);
      }
    } finally {
      if (mounted) {
        setState(() => _entrando = null);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    // Cinturón y tirantes: aunque el llamador ya comprueba el entorno, esta
    // pantalla se niega a dibujarse fuera del emulador.
    if (!Entorno.usaEmulador) {
      return const SizedBox.shrink();
    }

    final ThemeData tema = Theme.of(context);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Row(
              children: <Widget>[
                Icon(Icons.science_outlined, color: tema.colorScheme.tertiary),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    Textos.demoTitulo,
                    style: tema.textTheme.titleMedium,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              Textos.demoSubtitulo,
              style: tema.textTheme.bodySmall?.copyWith(
                color: tema.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 12),

            for (final CuentaDemostracion cuenta in CuentaDemostracion.todas)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: OutlinedButton(
                  onPressed: _entrando == null
                      ? () => _entrarComo(cuenta)
                      : null,
                  style: OutlinedButton.styleFrom(
                    alignment: Alignment.centerLeft,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 12,
                    ),
                  ),
                  child: Row(
                    children: <Widget>[
                      if (_entrando == cuenta.correo)
                        const SizedBox(
                          height: 16,
                          width: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      else
                        Icon(_iconoDe(cuenta.rol), size: 20),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: <Widget>[
                            Text(
                              cuenta.rol.etiqueta,
                              style: tema.textTheme.labelLarge,
                            ),
                            Text(
                              cuenta.descripcion,
                              style: tema.textTheme.bodySmall?.copyWith(
                                color: tema.colorScheme.onSurfaceVariant,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),

            if (_error != null)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(
                  _error!,
                  style: TextStyle(color: tema.colorScheme.error),
                ),
              ),
          ],
        ),
      ),
    );
  }

  IconData _iconoDe(Rol rol) => switch (rol) {
    Rol.coordinador => Icons.shield_outlined,
    Rol.administradora => Icons.badge_outlined,
    Rol.catedratico => Icons.school_outlined,
    Rol.auditor => Icons.fact_check_outlined,
  };
}
