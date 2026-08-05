/// SIAN — Instructivo de instalación en iOS (RES-05, riesgo R-02).
///
/// ────────────────────────────────────────────────────────────────────────────
/// Sin este paso, en iPhone NO llega ninguna notificación. Ninguna.
/// ────────────────────────────────────────────────────────────────────────────
///
/// No es una recomendación ni una mejora de experiencia: Apple solo entrega
/// notificaciones web a una aplicación añadida a la pantalla de inicio. Un
/// catedrático con iPhone que use SIAN desde una pestaña de Safari **está
/// incomunicado y no lo sabe**, y en un simulacro eso importa.
///
/// El riesgo R-02 del documento 02 lo dice sin rodeos: es el mayor riesgo de
/// adopción del proyecto. Por eso el instructivo aparece solo, en el primer
/// acceso desde iOS sin instalar, y no escondido en una ayuda.
library;

import 'package:flutter/material.dart';

import '../../core/navegador.dart';
import '../shared/tema.dart';
import '../shared/textos.dart';

class InstructivoIos extends StatelessWidget {
  const InstructivoIos({required this.entorno, this.alOmitir, super.key});

  final EntornoNavegador entorno;

  /// Permite continuar sin instalar. Existe a propósito: bloquear la
  /// aplicación dejaría al catedrático sin poder ni siquiera leer sus
  /// mensajes, que es peor que dejarlo sin notificaciones.
  final VoidCallback? alOmitir;

  @override
  Widget build(BuildContext context) {
    final ThemeData tema = Theme.of(context);
    final bool navegadorEquivocado = entorno.navegador != 'Safari';

    return Scaffold(
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 460),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                const Center(child: EscudoUmg(tamano: 84)),
                const SizedBox(height: 20),
                Text(
                  Textos.instalarTitulo,
                  textAlign: TextAlign.center,
                  style: tema.textTheme.headlineSmall?.copyWith(
                    color: ColoresSian.primarioOscuro,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 12),

                Card(
                  color: ColoresSian.urgente.withValues(alpha: 0.1),
                  child: const Padding(
                    padding: EdgeInsets.all(16),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Icon(Icons.priority_high, color: ColoresSian.urgente),
                        SizedBox(width: 12),
                        Expanded(child: Text(Textos.instalarPorQue)),
                      ],
                    ),
                  ),
                ),

                if (entorno.iosDemasiadoAntiguo) ...<Widget>[
                  const SizedBox(height: 12),
                  Card(
                    color: ColoresSian.dorado.withValues(alpha: 0.12),
                    child: const Padding(
                      padding: EdgeInsets.all(16),
                      child: Text(Textos.instalarIosAntiguo),
                    ),
                  ),
                ],

                if (navegadorEquivocado) ...<Widget>[
                  const SizedBox(height: 12),
                  Card(
                    color: ColoresSian.dorado.withValues(alpha: 0.12),
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          const Icon(Icons.info_outline),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              Textos.instalarSoloSafari(entorno.navegador),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],

                const SizedBox(height: 24),
                for (final ({int numero, String texto, IconData icono}) paso
                    in Textos.pasosInstalacionIos)
                  _Paso(paso: paso),

                const SizedBox(height: 24),
                FilledButton.icon(
                  onPressed: () => Navigator.of(context).maybePop(),
                  icon: const Icon(Icons.check),
                  label: const Text(Textos.botonYaLoHice),
                ),
                if (alOmitir != null) ...<Widget>[
                  const SizedBox(height: 8),
                  TextButton(
                    onPressed: alOmitir,
                    child: const Text(Textos.botonSeguirSinInstalar),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    Textos.avisoSeguirSinInstalar,
                    textAlign: TextAlign.center,
                    style: tema.textTheme.bodySmall?.copyWith(
                      color: tema.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _Paso extends StatelessWidget {
  const _Paso({required this.paso});

  final ({int numero, String texto, IconData icono}) paso;

  @override
  Widget build(BuildContext context) {
    final ThemeData tema = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          CircleAvatar(
            radius: 16,
            backgroundColor: ColoresSian.primario,
            child: Text(
              '${paso.numero}',
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(paso.texto, style: tema.textTheme.bodyLarge),
            ),
          ),
          const SizedBox(width: 8),
          Icon(paso.icono, color: tema.colorScheme.onSurfaceVariant),
        ],
      ),
    );
  }
}
