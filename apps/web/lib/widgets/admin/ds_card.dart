import 'package:flutter/material.dart';

import '../../theme/app_theme.dart';

/// Superficie base de todas las tarjetas del panel admin: mismo color,
/// borde y radio en cualquier página. Si [onTap] se define, la tarjeta gana
/// un hover sutil (elevación + brillo de borde) pensado para web/desktop.
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
        boxShadow: _hovered && interactive
            ? [
                BoxShadow(
                  color: Colors.black.withOpacity(0.25),
                  blurRadius: 20,
                  offset: const Offset(0, 8),
                ),
              ]
            : null,
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
          child: card,
        ),
      ),
    );
  }
}
