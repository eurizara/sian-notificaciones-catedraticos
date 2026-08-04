/// SIAN — Registro con correo y contraseña (RF-AUT-02, RF-AUT-06).
///
/// Crear la credencial **no** concede acceso. El alta solo se completa si ese
/// correo ya está en la lista blanca institucional; si no lo está, el servidor
/// borra la credencial recién creada y deja asiento en bitácora (RF-AUT-03).
///
/// Se dice en pantalla, antes de que la persona teclee nada. Descubrirlo
/// después de elegir contraseña y aceptar sería una pérdida de tiempo y una
/// mala primera impresión del sistema.
library;

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../application/proveedores_sesion.dart';
import '../../domain/politica_contrasena.dart';
import 'tema.dart';
import 'textos.dart';

class PantallaRegistro extends ConsumerStatefulWidget {
  const PantallaRegistro({required this.alVolver, super.key});

  /// Vuelve al inicio de sesión.
  final VoidCallback alVolver;

  @override
  ConsumerState<PantallaRegistro> createState() => _PantallaRegistroState();
}

class _PantallaRegistroState extends ConsumerState<PantallaRegistro> {
  final GlobalKey<FormState> _formulario = GlobalKey<FormState>();
  final TextEditingController _correo = TextEditingController();
  final TextEditingController _contrasena = TextEditingController();
  final TextEditingController _repetir = TextEditingController();

  bool _enviando = false;
  bool _visible = false;
  String? _error;

  @override
  void dispose() {
    _correo.dispose();
    _contrasena.dispose();
    _repetir.dispose();
    super.dispose();
  }

  /// RF-AUT-06 — la política completa, no solo contar tipos de carácter.
  ///
  /// Es el espejo de la del servidor. Comprobarla aquí es cortesía —evita un
  /// viaje de ida y vuelta—, no seguridad.
  String? _validarContrasena(String? valor) {
    final String v = valor ?? '';
    if (v.isEmpty) {
      return Textos.validacionContrasenaObligatoria;
    }

    final ResultadoPolitica r = evaluarContrasena(
      v,
      correo: _correo.text,
      nombre: null,
    );
    if (r.valida) {
      return null;
    }

    // Se enumeran TODOS los incumplimientos: soltar una regla cada vez es la
    // forma más segura de que la persona acabe eligiendo algo malo.
    return r.incumplimientos.map(Textos.explicarIncumplimiento).join(' ');
  }

  String? _validarCorreo(String? valor) {
    final String v = (valor ?? '').trim();
    if (v.isEmpty) {
      return Textos.validacionCorreoObligatorio;
    }
    if (!RegExp(r'^[^\s@]+@[^\s@.]+(\.[^\s@.]+)+$').hasMatch(v)) {
      return Textos.validacionCorreoInvalido;
    }
    return null;
  }

  String _mensajeDeError(FirebaseAuthException e) => switch (e.code) {
    'email-already-in-use' => Textos.errorCorreoYaRegistrado,
    'weak-password' => Textos.errorContrasenaDebil,
    'invalid-email' => Textos.validacionCorreoInvalido,
    'operation-not-allowed' => Textos.errorRegistroDeshabilitado,
    'network-request-failed' => Textos.errorSinRed,
    _ => Textos.errorInesperado,
  };

  Future<void> _registrar() async {
    if (!(_formulario.currentState?.validate() ?? false)) {
      return;
    }

    setState(() {
      _enviando = true;
      _error = null;
    });

    try {
      await ref
          .read(repositorioSesionProvider)
          .registrarConCorreo(correo: _correo.text, contrasena: _contrasena.text);
      // No se navega desde aquí: el enrutador observa la sesión y decide. Si
      // el correo no estaba invitado, aterrizará en la pantalla de rechazo.
    } on FirebaseAuthException catch (e) {
      if (mounted) {
        setState(() => _error = _mensajeDeError(e));
      }
    } on Object catch (_) {
      if (mounted) {
        setState(() => _error = Textos.errorInesperado);
      }
    } finally {
      if (mounted) {
        setState(() => _enviando = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData tema = Theme.of(context);

    return Scaffold(
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                const Center(child: EscudoUmg(tamano: 96)),
                const SizedBox(height: 16),
                Text(
                  Textos.registroTitulo,
                  textAlign: TextAlign.center,
                  style: tema.textTheme.headlineSmall?.copyWith(
                    color: ColoresSian.primarioOscuro,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 16),

                // El aviso va ANTES del formulario, no después de fallar.
                Card(
                  color: tema.colorScheme.surfaceContainerHighest,
                  child: const Padding(
                    padding: EdgeInsets.all(16),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Icon(
                          Icons.verified_user_outlined,
                          color: ColoresSian.primario,
                        ),
                        SizedBox(width: 12),
                        Expanded(child: Text(Textos.registroAvisoListaBlanca)),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 24),

                Form(
                  key: _formulario,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: <Widget>[
                      TextFormField(
                        controller: _correo,
                        keyboardType: TextInputType.emailAddress,
                        textInputAction: TextInputAction.next,
                        decoration: const InputDecoration(
                          labelText: Textos.etiquetaCorreo,
                          prefixIcon: Icon(Icons.alternate_email),
                          border: OutlineInputBorder(),
                          helperText: Textos.registroAyudaCorreo,
                        ),
                        validator: _validarCorreo,
                      ),
                      const SizedBox(height: 20),
                      TextFormField(
                        controller: _contrasena,
                        obscureText: !_visible,
                        textInputAction: TextInputAction.next,
                        decoration: InputDecoration(
                          labelText: Textos.etiquetaContrasena,
                          prefixIcon: const Icon(Icons.lock_outline),
                          border: const OutlineInputBorder(),
                          helperText: Textos.registroAyudaContrasenaLarga,
                          helperMaxLines: 2,
                          suffixIcon: IconButton(
                            onPressed: () => setState(() => _visible = !_visible),
                            icon: Icon(
                              _visible ? Icons.visibility_off : Icons.visibility,
                            ),
                            tooltip: _visible
                                ? Textos.ocultarContrasena
                                : Textos.mostrarContrasena,
                          ),
                        ),
                        validator: _validarContrasena,
                        onChanged: (String _) => setState(() {}),
                      ),
                      const SizedBox(height: 8),
                      _MedidorFuerza(
                        resultado: evaluarContrasena(
                          _contrasena.text,
                          correo: _correo.text,
                        ),
                        vacia: _contrasena.text.isEmpty,
                      ),
                      const SizedBox(height: 20),
                      TextFormField(
                        controller: _repetir,
                        obscureText: !_visible,
                        textInputAction: TextInputAction.done,
                        onFieldSubmitted: (_) => _registrar(),
                        decoration: const InputDecoration(
                          labelText: Textos.etiquetaRepetirContrasena,
                          prefixIcon: Icon(Icons.lock_reset_outlined),
                          border: OutlineInputBorder(),
                        ),
                        validator: (String? v) => v == _contrasena.text
                            ? null
                            : Textos.validacionContrasenasNoCoinciden,
                      ),
                    ],
                  ),
                ),

                if (_error != null) ...<Widget>[
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: tema.colorScheme.errorContainer,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      children: <Widget>[
                        Icon(
                          Icons.error_outline,
                          color: tema.colorScheme.onErrorContainer,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            _error!,
                            style: TextStyle(
                              color: tema.colorScheme.onErrorContainer,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],

                const SizedBox(height: 24),
                FilledButton(
                  onPressed: _enviando ? null : _registrar,
                  child: _enviando
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text(Textos.botonCrearCuenta),
                ),
                const SizedBox(height: 8),
                TextButton(
                  onPressed: _enviando ? null : widget.alVolver,
                  child: const Text(Textos.botonYaTengoCuenta),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Barra de fuerza orientativa.
///
/// No mide entropía real: es una señal para que se vea que **alargar la
/// contraseña ayuda mucho más que añadirle otro signo de admiración**.
class _MedidorFuerza extends StatelessWidget {
  const _MedidorFuerza({required this.resultado, required this.vacia});

  final ResultadoPolitica resultado;
  final bool vacia;

  @override
  Widget build(BuildContext context) {
    if (vacia) {
      return const SizedBox(height: 24);
    }

    final ThemeData tema = Theme.of(context);
    final ({double valor, Color color, String etiqueta}) v = switch (resultado.fuerza) {
      FuerzaContrasena.insuficiente => (
        valor: 0.2,
        color: ColoresSian.urgente,
        etiqueta: Textos.fuerzaInsuficiente,
      ),
      FuerzaContrasena.aceptable => (
        valor: 0.5,
        color: ColoresSian.dorado,
        etiqueta: Textos.fuerzaAceptable,
      ),
      FuerzaContrasena.buena => (
        valor: 0.8,
        color: ColoresSian.primario,
        etiqueta: Textos.fuerzaBuena,
      ),
      FuerzaContrasena.excelente => (
        valor: 1,
        color: ColoresSian.confirmado,
        etiqueta: Textos.fuerzaExcelente,
      ),
    };

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: v.valor,
            minHeight: 6,
            color: v.color,
            backgroundColor: tema.colorScheme.surfaceContainerHighest,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          v.etiqueta,
          // La etiqueta acompaña al color: quien no distingue el verde del
          // rojo no debería quedarse sin la información (RNF-13).
          style: tema.textTheme.bodySmall?.copyWith(color: v.color),
        ),
      ],
    );
  }
}
