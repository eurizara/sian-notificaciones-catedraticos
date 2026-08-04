/// SIAN — Pantalla de inicio de sesión (RF-AUT-02, RF-AUT-05, RF-AUT-06).
library;

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../application/proveedores_sesion.dart';
import '../../core/entorno.dart';
import '../demo/tarjeta_demostracion.dart';
import 'tema.dart';
import 'textos.dart';

class PantallaIngreso extends ConsumerStatefulWidget {
  const PantallaIngreso({this.alRegistrarse, super.key});

  /// Lleva a la pantalla de registro (RF-AUT-02).
  final VoidCallback? alRegistrarse;

  @override
  ConsumerState<PantallaIngreso> createState() => _PantallaIngresoState();
}

class _PantallaIngresoState extends ConsumerState<PantallaIngreso> {
  final GlobalKey<FormState> _formulario = GlobalKey<FormState>();
  final TextEditingController _correo = TextEditingController();
  final TextEditingController _contrasena = TextEditingController();

  bool _enviando = false;
  bool _contrasenaVisible = false;
  String? _error;

  @override
  void dispose() {
    _correo.dispose();
    _contrasena.dispose();
    super.dispose();
  }

  /// Traduce el código de Firebase a algo que una persona pueda leer.
  ///
  /// Deliberadamente **no** se distingue «correo inexistente» de «contraseña
  /// incorrecta»: hacerlo permitiría averiguar qué correos tienen cuenta en el
  /// sistema probando uno por uno.
  String _mensajeDeError(FirebaseAuthException e) => switch (e.code) {
    'invalid-email' => Textos.errorCorreoInvalido,
    'user-disabled' => Textos.errorCuentaDesactivada,
    'too-many-requests' => Textos.errorDemasiadosIntentos,
    'network-request-failed' => Textos.errorSinRed,
    _ => Textos.errorCredenciales,
  };

  Future<void> _entrar() async {
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
          .entrarConCorreo(
            correo: _correo.text,
            contrasena: _contrasena.text,
          );
      // No se navega aquí: el cambio de sesión lo observa el enrutador, que es
      // el único que decide qué pantalla toca (RN-01 aplicado a la interfaz).
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

  Future<void> _recuperar() async {
    final String correo = _correo.text.trim();
    if (correo.isEmpty) {
      setState(() => _error = Textos.errorCorreoParaRecuperar);
      return;
    }

    try {
      await ref.read(repositorioSesionProvider).recuperarContrasena(correo);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text(Textos.recuperacionEnviada)),
        );
      }
    } on Object catch (_) {
      // Se responde igual exista o no la cuenta: lo contrario delataría qué
      // correos están registrados.
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text(Textos.recuperacionEnviada)),
        );
      }
    }
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

  String? _validarContrasena(String? valor) {
    if ((valor ?? '').isEmpty) {
      return Textos.validacionContrasenaObligatoria;
    }
    return null;
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
                const Center(child: EscudoUmg(tamano: 132)),
                const SizedBox(height: 20),
                Text(
                  Textos.nombreApp,
                  textAlign: TextAlign.center,
                  style: tema.textTheme.headlineMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: ColoresSian.primarioOscuro,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  Textos.nombreCompleto,
                  textAlign: TextAlign.center,
                  style: tema.textTheme.bodyMedium?.copyWith(
                    color: tema.colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  Textos.institucion,
                  textAlign: TextAlign.center,
                  style: tema.textTheme.labelLarge?.copyWith(
                    color: ColoresSian.doradoTexto,
                  ),
                ),
                Text(
                  Textos.sede,
                  textAlign: TextAlign.center,
                  style: tema.textTheme.bodySmall?.copyWith(
                    color: tema.colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 32),

                Form(
                  key: _formulario,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: <Widget>[
                      TextFormField(
                        controller: _correo,
                        autofillHints: const <String>[AutofillHints.email],
                        keyboardType: TextInputType.emailAddress,
                        textInputAction: TextInputAction.next,
                        decoration: const InputDecoration(
                          labelText: Textos.etiquetaCorreo,
                          prefixIcon: Icon(Icons.alternate_email),
                          border: OutlineInputBorder(),
                        ),
                        validator: _validarCorreo,
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: _contrasena,
                        obscureText: !_contrasenaVisible,
                        autofillHints: const <String>[AutofillHints.password],
                        textInputAction: TextInputAction.done,
                        onFieldSubmitted: (_) => _entrar(),
                        decoration: InputDecoration(
                          labelText: Textos.etiquetaContrasena,
                          prefixIcon: const Icon(Icons.lock_outline),
                          border: const OutlineInputBorder(),
                          suffixIcon: IconButton(
                            onPressed: () => setState(
                              () => _contrasenaVisible = !_contrasenaVisible,
                            ),
                            icon: Icon(
                              _contrasenaVisible
                                  ? Icons.visibility_off
                                  : Icons.visibility,
                            ),
                            tooltip: _contrasenaVisible
                                ? Textos.ocultarContrasena
                                : Textos.mostrarContrasena,
                          ),
                        ),
                        validator: _validarContrasena,
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
                  onPressed: _enviando ? null : _entrar,
                  child: _enviando
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text(Textos.botonEntrar),
                ),
                const SizedBox(height: 8),
                TextButton(
                  onPressed: _enviando ? null : _recuperar,
                  child: const Text(Textos.botonOlvideContrasena),
                ),
                if (widget.alRegistrarse != null)
                  TextButton(
                    onPressed: _enviando ? null : widget.alRegistrarse,
                    child: const Text(Textos.botonNoTengoCuenta),
                  ),

                // Solo con emuladores. Cuando USE_EMULATOR es false esta rama
                // no se compila: el modo demostración no puede llegar a
                // producción ni por descuido (RF-AUT-03).
                if (Entorno.usaEmulador) ...<Widget>[
                  const SizedBox(height: 32),
                  const TarjetaDemostracion(),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
