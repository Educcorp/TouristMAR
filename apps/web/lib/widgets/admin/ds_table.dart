import 'package:flutter/material.dart';

import '../../theme/app_theme.dart';

/// Armazón mínimo de tabla para vistas de escritorio (Usuarios, Admins).
/// [columnFlex] define el peso relativo de cada columna; debe tener la misma
/// longitud que las listas de celdas de cada [DsTableRow].
class DsTable extends StatelessWidget {
  final List<String> headers;
  final List<int> columnFlex;
  final List<Widget> rows;

  const DsTable({
    super.key,
    required this.headers,
    required this.columnFlex,
    required this.rows,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadius.card),
        border: Border.all(color: AppColors.borderSubtle),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg, vertical: AppSpacing.md),
            color: AppColors.surfaceAlt,
            child: Row(
              children: List.generate(headers.length, (i) {
                return Expanded(
                  flex: columnFlex[i],
                  child: Text(headers[i], style: AppTypography.caption),
                );
              }),
            ),
          ),
          ...rows,
        ],
      ),
    );
  }
}

class DsTableRow extends StatefulWidget {
  final List<Widget> cells;
  final List<int> columnFlex;

  const DsTableRow({super.key, required this.cells, required this.columnFlex});

  @override
  State<DsTableRow> createState() => _DsTableRowState();
}

class _DsTableRowState extends State<DsTableRow> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 120),
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg, vertical: AppSpacing.md),
        decoration: BoxDecoration(
          color: _hovered ? AppColors.overlay(0.03) : Colors.transparent,
          border: Border(top: BorderSide(color: AppColors.borderSubtle)),
        ),
        child: Row(
          children: List.generate(widget.cells.length, (i) {
            return Expanded(
              flex: widget.columnFlex[i],
              // Align en vez de dejar que el hijo herede el ancho tight de
              // Expanded: así un botón/badge dentro de una celda conserva su
              // ancho intrínseco en vez de estirarse a todo el ancho de la
              // columna.
              child: Align(alignment: Alignment.centerLeft, child: widget.cells[i]),
            );
          }),
        ),
      ),
    );
  }
}
