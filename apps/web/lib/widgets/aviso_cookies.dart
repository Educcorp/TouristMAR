import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../platform/platform_services.dart';
import '../theme/app_theme.dart';

const _clave = 'touristmar_aviso_cookies';

/// Barra inferior (solo en la web) que avisa qué guarda el navegador y liga al
/// aviso de privacidad. Se muestra hasta que se toca "Entendido".
class AvisoCookies extends StatefulWidget {
  final Widget child;
  final VoidCallback onVerAviso;

  const AvisoCookies({super.key, required this.child, required this.onVerAviso});

  @override
  State<AvisoCookies> createState() => _AvisoCookiesState();
}

class _AvisoCookiesState extends State<AvisoCookies> {
  late bool _visible = kIsWeb && PlatformServices.store.read(_clave) == null;

  void _aceptar() {
    PlatformServices.store.write(_clave, '1');
    setState(() => _visible = false);
  }

  @override
  Widget build(BuildContext context) {
    if (!_visible) return widget.child;
    return Stack(
      children: [
        widget.child,
        // En escritorio va en la esquina, compacto (centrado tapaba la foto
        // del login y su leyenda); en el celular, de lado a lado.
        Positioned(
          left: MediaQuery.sizeOf(context).width >= 900 ? null : 12,
          right: 12,
          bottom: 12,
          child: SafeArea(
            child: Align(
              alignment: Alignment.bottomRight,
              child: ConstrainedBox(
                constraints: BoxConstraints(maxWidth: MediaQuery.sizeOf(context).width >= 900 ? 420 : 760),
                child: Material(
                  color: AppColors.cubierta,
                  elevation: 8,
                  borderRadius: BorderRadius.circular(16),
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 12, 12, 12),
                    child: Wrap(
                      alignment: WrapAlignment.end,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 480),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.cookie_outlined, color: AppColors.brandTeal),
                              const SizedBox(width: 10),
                              Flexible(
                                child: Text(
                                  'No usamos cookies de rastreo ni de publicidad. Solo guardamos en tu navegador tu sesión '
                                  'y tus preferencias.',
                                  style: TextStyle(color: AppColors.tinta, fontSize: 14, height: 1.35),
                                ),
                              ),
                            ],
                          ),
                        ),
                        TextButton(onPressed: widget.onVerAviso, child: const Text('Aviso de privacidad')),
                        FilledButton(
                          key: const ValueKey('cookies-entendido'),
                          onPressed: _aceptar,
                          child: const Text('Entendido'),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
