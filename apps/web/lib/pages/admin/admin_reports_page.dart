import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import '../../services/auth_service.dart';
import '../../services/session_storage.dart';
import '../../theme/app_theme.dart';
import '../../theme/breakpoints.dart';
import '../../utils/date_format_es.dart';
import '../../widgets/admin/ds_card.dart';
import '../../widgets/admin/ds_states.dart';
import '../../widgets/admin/ds_stat_card.dart';

enum _DateRange { d30, d90, d365, all }

/// Dashboard analítico. Todas las cifras se calculan client-side a partir de
/// los listados reales que ya expone el backend (`adminListNegocios`,
/// `adminListUsers`) — no hay endpoint de series históricas todavía, así que
/// no se inventa ningún número.
class AdminReportsPage extends StatefulWidget {
  final AuthService authService;

  AdminReportsPage({super.key, AuthService? authService}) : authService = authService ?? AuthService();

  @override
  State<AdminReportsPage> createState() => _AdminReportsPageState();
}

class _AdminReportsPageState extends State<AdminReportsPage> {
  AdminStats? _stats;
  List<NegocioSummary> _negocios = [];
  List<AuthUser> _users = [];
  bool _loading = true;
  String? _error;
  _DateRange _range = _DateRange.d365;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final token = SessionStorage.token;
    if (token == null) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final results = await Future.wait([
        widget.authService.adminGetStats(token),
        widget.authService.adminListNegocios(token),
        widget.authService.adminListUsers(token),
      ]);
      if (!mounted) return;
      setState(() {
        _stats = results[0] as AdminStats;
        _negocios = results[1] as List<NegocioSummary>;
        _users = results[2] as List<AuthUser>;
      });
    } catch (err) {
      if (!mounted) return;
      setState(() => _error = err is AuthError ? err.message : 'No se pudo conectar con el servidor');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  List<NegocioSummary> get _negociosEnRango {
    if (_range == _DateRange.all) return _negocios;
    final days = switch (_range) { _DateRange.d30 => 30, _DateRange.d90 => 90, _DateRange.d365 => 365, _ => 365 };
    final cutoff = DateTime.now().subtract(Duration(days: days));
    return _negocios.where((n) => n.solicitadoEn.isAfter(cutoff)).toList();
  }

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: _load,
      color: AppColors.adminViolet,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Reportes', style: AppTypography.h1),
            const SizedBox(height: 4),
            Text('Métricas y distribución del sistema, calculadas en tiempo real.', style: AppTypography.body),
            SizedBox(height: AppSpacing.xl),
            if (_loading)
              DsLoadingState()
            else if (_error != null)
              DsErrorState(message: _error!, onRetry: _load)
            else
              _buildContent(),
          ],
        ),
      ),
    );
  }

  Widget _buildContent() {
    final stats = _stats!;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _StatsRow(stats: stats),
        const SizedBox(height: AppSpacing.xl),
        LayoutBuilder(
          builder: (context, constraints) {
            // Ancho del área de contenido (ya sin el sidebar), no de la
            // ventana completa — un umbral más bajo que `Breakpoints.expanded`.
            final twoColumns = constraints.maxWidth >= 760;
            final categoria = _CategoryDonutCard(negocios: _negocios);
            final estado = _EstadoDonutCard(negocios: _negocios);
            if (!twoColumns) {
              return Column(children: [categoria, const SizedBox(height: AppSpacing.lg), estado]);
            }
            return Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(child: categoria),
                const SizedBox(width: AppSpacing.lg),
                Expanded(child: estado),
              ],
            );
          },
        ),
        const SizedBox(height: AppSpacing.lg),
        _SolicitudesPorMesCard(
          negocios: _negociosEnRango,
          range: _range,
          onRangeChanged: (r) => setState(() => _range = r),
        ),
        const SizedBox(height: AppSpacing.lg),
        _UsuariosActivosCard(users: _users),
      ],
    );
  }
}

class _StatsRow extends StatelessWidget {
  final AdminStats stats;
  const _StatsRow({required this.stats});

  @override
  Widget build(BuildContext context) {
    final items = [
      (Icons.groups_outlined, stats.turistas, 'Visitantes registrados', AppColors.brandTeal),
      (Icons.apartment, stats.negociosActivos, 'Negocios activos', AppColors.businessOrange),
      (Icons.report_gmailerrorred_outlined, stats.negociosPendientes, 'Solicitudes pendientes', AppColors.amber),
      (Icons.store_outlined, stats.negociosTotal, 'Negocios totales', AppColors.emerald),
    ];
    return LayoutBuilder(
      builder: (context, constraints) {
        final compact = Breakpoints.isCompact(constraints.maxWidth);
        return GridView.count(
          crossAxisCount: compact ? 2 : 4,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          mainAxisSpacing: AppSpacing.md,
          crossAxisSpacing: AppSpacing.md,
          childAspectRatio: compact ? 1.05 : 1.5,
          children: items.map((s) {
            final (icon, value, label, color) = s;
            return DsStatCard(icon: icon, value: value, label: label, accent: color);
          }).toList(),
        );
      },
    );
  }
}

class _ChartShell extends StatelessWidget {
  final String title;
  final Widget child;

  _ChartShell({required this.title, required this.child});

  @override
  Widget build(BuildContext context) {
    return DsCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: AppTypography.h3),
          SizedBox(height: AppSpacing.lg),
          SizedBox(height: 200, child: child),
        ],
      ),
    );
  }
}

final _chartPalette = [
  AppColors.adminViolet,
  AppColors.brandTeal,
  AppColors.businessOrange,
  AppColors.emerald,
  AppColors.amber,
  AppColors.oceanBlue,
];

class _CategoryDonutCard extends StatelessWidget {
  final List<NegocioSummary> negocios;
  const _CategoryDonutCard({required this.negocios});

  @override
  Widget build(BuildContext context) {
    final counts = <String, int>{};
    for (final n in negocios) {
      final key = n.categoria ?? 'Sin categoría';
      counts[key] = (counts[key] ?? 0) + 1;
    }
    if (counts.isEmpty) {
      return _ChartShell(
        title: 'Negocios por categoría',
        child: Center(child: Text('Sin datos todavía', style: TextStyle(color: AppColors.slate400, fontSize: 12))),
      );
    }
    final entries = counts.entries.toList();
    return _ChartShell(
      title: 'Negocios por categoría',
      child: Row(
        children: [
          Expanded(
            child: PieChart(
              PieChartData(
                sectionsSpace: 2,
                centerSpaceRadius: 36,
                sections: [
                  for (var i = 0; i < entries.length; i++)
                    PieChartSectionData(
                      value: entries[i].value.toDouble(),
                      color: _chartPalette[i % _chartPalette.length],
                      radius: 46,
                      showTitle: false,
                    ),
                ],
              ),
            ),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(child: _Legend(entries: entries)),
        ],
      ),
    );
  }
}

class _EstadoDonutCard extends StatelessWidget {
  final List<NegocioSummary> negocios;
  const _EstadoDonutCard({required this.negocios});

  @override
  Widget build(BuildContext context) {
    final labels = {'aprobado': 'Activos', 'pendiente': 'Pendientes', 'rechazado': 'Rechazados'};
    final colors = {'aprobado': AppColors.emerald, 'pendiente': AppColors.amber, 'rechazado': AppColors.errorRed};
    final counts = <String, int>{};
    for (final n in negocios) {
      counts[n.estado] = (counts[n.estado] ?? 0) + 1;
    }
    if (counts.isEmpty) {
      return _ChartShell(
        title: 'Negocios por estado',
        child: Center(child: Text('Sin datos todavía', style: TextStyle(color: AppColors.slate400, fontSize: 12))),
      );
    }
    final entries = counts.entries.toList();
    return _ChartShell(
      title: 'Negocios por estado',
      child: Row(
        children: [
          Expanded(
            child: PieChart(
              PieChartData(
                sectionsSpace: 2,
                centerSpaceRadius: 36,
                sections: [
                  for (final e in entries)
                    PieChartSectionData(
                      value: e.value.toDouble(),
                      color: colors[e.key] ?? AppColors.slate400,
                      radius: 46,
                      showTitle: false,
                    ),
                ],
              ),
            ),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: _Legend(entries: entries.map((e) => MapEntry(labels[e.key] ?? e.key, e.value)).toList(),
                colorOf: (label) {
                  final key = labels.entries.firstWhere((x) => x.value == label, orElse: () => const MapEntry('', '')).key;
                  return colors[key] ?? AppColors.slate400;
                }),
          ),
        ],
      ),
    );
  }
}

class _Legend extends StatelessWidget {
  final List<MapEntry<String, int>> entries;
  final Color Function(String label)? colorOf;

  const _Legend({required this.entries, this.colorOf});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        for (var i = 0; i < entries.length; i++)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 3),
            child: Row(
              children: [
                Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: colorOf != null ? colorOf!(entries[i].key) : _chartPalette[i % _chartPalette.length],
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    '${entries[i].key} (${entries[i].value})',
                    style: AppTypography.bodySmall,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

class _SolicitudesPorMesCard extends StatelessWidget {
  final List<NegocioSummary> negocios;
  final _DateRange range;
  final ValueChanged<_DateRange> onRangeChanged;

  const _SolicitudesPorMesCard({required this.negocios, required this.range, required this.onRangeChanged});

  @override
  Widget build(BuildContext context) {
    final counts = <String, int>{};
    final sortedNegocios = [...negocios]..sort((a, b) => a.solicitadoEn.compareTo(b.solicitadoEn));
    for (final n in sortedNegocios) {
      final key = monthLabelEs(n.solicitadoEn);
      counts[key] = (counts[key] ?? 0) + 1;
    }
    final entries = counts.entries.toList();
    final maxY = entries.isEmpty ? 1.0 : entries.map((e) => e.value).reduce((a, b) => a > b ? a : b).toDouble();

    return DsCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Solicitudes por mes', style: AppTypography.h3),
              _RangeSelector(value: range, onChanged: onRangeChanged),
            ],
          ),
          const SizedBox(height: AppSpacing.lg),
          SizedBox(
            height: 200,
            child: entries.isEmpty
                ? Center(child: Text('Sin solicitudes en este rango', style: TextStyle(color: AppColors.slate400, fontSize: 12)))
                : BarChart(
                    BarChartData(
                      maxY: maxY + 1,
                      gridData: const FlGridData(show: false),
                      borderData: FlBorderData(show: false),
                      titlesData: FlTitlesData(
                        leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                        rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                        topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                        bottomTitles: AxisTitles(
                          sideTitles: SideTitles(
                            showTitles: true,
                            getTitlesWidget: (value, meta) {
                              final i = value.toInt();
                              if (i < 0 || i >= entries.length) return const SizedBox.shrink();
                              return Padding(
                                padding: const EdgeInsets.only(top: 6),
                                child: Text(entries[i].key, style: AppTypography.caption),
                              );
                            },
                          ),
                        ),
                      ),
                      barGroups: [
                        for (var i = 0; i < entries.length; i++)
                          BarChartGroupData(x: i, barRods: [
                            BarChartRodData(
                              toY: entries[i].value.toDouble(),
                              color: AppColors.adminViolet,
                              width: 18,
                              borderRadius: BorderRadius.circular(4),
                            ),
                          ]),
                      ],
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}

class _RangeSelector extends StatelessWidget {
  final _DateRange value;
  final ValueChanged<_DateRange> onChanged;

  const _RangeSelector({required this.value, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    const labels = {_DateRange.d30: '30d', _DateRange.d90: '90d', _DateRange.d365: '1a', _DateRange.all: 'Todo'};
    return Wrap(
      spacing: 6,
      children: labels.entries.map((e) {
        final selected = e.key == value;
        return GestureDetector(
          onTap: () => onChanged(e.key),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: selected ? AppColors.adminViolet.withOpacity(0.16) : Colors.transparent,
              borderRadius: BorderRadius.circular(999),
              border: Border.all(color: selected ? AppColors.adminViolet.withOpacity(0.4) : AppColors.borderSubtle),
            ),
            child: Text(
              e.value,
              style: TextStyle(
                color: selected ? AppColors.adminViolet : AppColors.slate400,
                fontSize: 11,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        );
      }).toList(),
    );
  }
}

class _UsuariosActivosCard extends StatelessWidget {
  final List<AuthUser> users;
  const _UsuariosActivosCard({required this.users});

  @override
  Widget build(BuildContext context) {
    final active = users.where((u) => u.activo).length;
    final blocked = users.length - active;
    final maxY = [active, blocked].reduce((a, b) => a > b ? a : b).toDouble();

    return DsCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Usuarios: activos vs. bloqueados', style: AppTypography.h3),
          const SizedBox(height: AppSpacing.lg),
          SizedBox(
            height: 160,
            child: users.isEmpty
                ? Center(child: Text('Sin usuarios todavía', style: TextStyle(color: AppColors.slate400, fontSize: 12)))
                : BarChart(
                    BarChartData(
                      maxY: maxY == 0 ? 1 : maxY + 1,
                      gridData: const FlGridData(show: false),
                      borderData: FlBorderData(show: false),
                      titlesData: FlTitlesData(
                        leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                        rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                        topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                        bottomTitles: AxisTitles(
                          sideTitles: SideTitles(
                            showTitles: true,
                            getTitlesWidget: (value, meta) {
                              final label = value.toInt() == 0 ? 'Activos' : 'Bloqueados';
                              return Padding(
                                padding: const EdgeInsets.only(top: 6),
                                child: Text(label, style: AppTypography.caption),
                              );
                            },
                          ),
                        ),
                      ),
                      barGroups: [
                        BarChartGroupData(x: 0, barRods: [
                          BarChartRodData(toY: active.toDouble(), color: AppColors.emerald, width: 32, borderRadius: BorderRadius.circular(4)),
                        ]),
                        BarChartGroupData(x: 1, barRods: [
                          BarChartRodData(toY: blocked.toDouble(), color: AppColors.errorRed, width: 32, borderRadius: BorderRadius.circular(4)),
                        ]),
                      ],
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}
