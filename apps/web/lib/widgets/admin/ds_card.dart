import 'package:flutter/material.dart';

import '../../theme/app_theme.dart';

/// Superficie base de todas las tarjetas del panel admin: mismo color,
/// borde y radio en cualquier página. Si [onTap] se define, la tarjeta gana
/// un hover sutil (tinte claro + levantamiento + brillo de borde) pensado
/// para web/desktop.
class DsCard extends StatefulWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  final VoidCallback? onTap;
  final double radius;
  final Color? background;

  const DsCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(AppSpacing.lg),
    this.onTap,
    this.radius = AppRadius.card,
    this.background,
  });

  @override
  State<DsCard> createState() => _DsCardState();
}

class _DsCardState extends State<DsCard> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final interactive = widget.onTap != null;
    final borderColor = _hovered && interactive
        ? AppColors.overlay(0.16)
        : AppColors.borderSubtle;

    final card = AnimatedContainer(
      duration: const Duration(milliseconds: 180),
      curve: Curves.easeOut,
      transform: Matrix4.translationValues(0, _hovered && interactive ? -2 : 0, 0),
      padding: widget.padding,
      decoration: BoxDecoration(
        color: widget.background ?? AppColors.surface,
        borderRadius: BorderRadius.circular(widget.radius),
        border: Border.all(color: borderColor),
        // Sin BoxShadow a propósito: `surface` es casi transparente, así que
        // una sombra oscura se ve *a través* de la tarjeta y la oscurece
        // completa al pasar el cursor. El hover se marca solo con el tinte
        // claro del InkWell (hoverColor), el borde y el leve levantamiento.
      ),
      child: widget.child,
    );

    if (!interactive) return card;

    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      cursor: SystemMouseCursors.click,
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(widget.radius),
        child: InkWell(
          onTap: widget.onTap,
          borderRadius: BorderRadius.circular(widget.radius),
          // Sin esto, InkWell usa el gris fijo de Flutter para el estado
          // presionado (0x66BCBCBC en modo claro) — no es theme-aware y se ve
          // como una mancha gris fuerte cubriendo toda la tarjeta. Con
          // AppColors.overlay sí se adapta al tema y queda sutil.
          splashColor: AppColors.overlay(0.08),
          highlightColor: AppColors.overlay(0.06),
          hoverColor: AppColors.overlay(0.03),
          focusColor: AppColors.overlay(0.04),
          child: card,
        ),
      ),
    );
  }
}
