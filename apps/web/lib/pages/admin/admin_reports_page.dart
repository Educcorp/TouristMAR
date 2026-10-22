import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import '../../models/lugar.dart';
import '../../services/auth_service.dart';
import '../../services/session_storage.dart';
import '../../theme/app_theme.dart';
import '../../theme/breakpoints.dart';
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
            const SizedBox(height: AppSpacing.xl),
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
            final categoria = _CategoriaBarrasCard(negocios: _negocios);
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
  final String? subtitle;
  final Widget? trailing;
  final Widget child;

  // Sin `const` a propósito: build() lee AppColors (depende de
  // ThemeController); una instancia const no se reconstruiría al cambiar el
  // tema y se quedaría con los colores viejos.
  // ignore: prefer_const_constructors_in_immutables
  _ChartShell({required this.title, this.subtitle, this.trailing, required this.child});

  @override
  Widget build(BuildContext context) {
    return DsCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: AppTypography.h3),
                    if (subtitle != null) ...[
                      const SizedBox(height: 2),
                      Text(subtitle!, style: AppTypography.caption.copyWith(color: AppColors.slate400)),
                    ],
                  ],
                ),
              ),
              if (trailing != null) trailing!,
            ],
          ),
          const SizedBox(height: AppSpacing.lg),
          child,
        ],
      ),
    );
  }
}

class _SinDatos extends StatelessWidget {
  final String texto;
  const _SinDatos(this.texto);

  @override
  Widget build(BuildContext context) => SizedBox(
        height: 120,
        child: Center(child: Text(texto, style: TextStyle(color: AppColors.slate400, fontSize: 13))),
      );
}

String _porcentaje(int parte, int total) => total == 0 ? '0%' : '${(parte * 100 / total).round()}%';

/// Negocios por categoría, agrupados en las mismas categorías del mapa (la
/// categoría que escribe cada negocio es texto libre: "Club de playa",
/// "club de Playa"… se juntan en "Playas"). Barras horizontales: se leen
/// mejor que una dona con muchas rebanadas.
class _CategoriaBarrasCard extends StatelessWidget {
  final List<NegocioSummary> negocios;
  const _CategoriaBarrasCard({required this.negocios});

  @override
  Widget build(BuildContext context) {
    final counts = <CategoriaLugar, int>{};
    for (final n in negocios) {
      final c = CategoriaLugarDetector.detectar(n.categoria);
      counts[c] = (counts[c] ?? 0) + 1;
    }
    final entries = counts.entries.toList()..sort((a, b) => b.value.compareTo(a.value));
    final total = negocios.length;
    final maximo = entries.isEmpty ? 1 : entries.first.value;

    return _ChartShell(
      title: 'Negocios por categoría',
      subtitle: '$total negocios registrados',
      child: entries.isEmpty
          ? const _SinDatos('Sin datos todavía')
          : Column(
              children: [
                for (final e in entries)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 6),
                    child: Row(
                      children: [
                        Icon(e.key.icon, size: 18, color: e.key.color),
                        const SizedBox(width: 8),
                        SizedBox(
                          width: 104,
                          child: Text(e.key.etiqueta, style: AppTypography.bodySmall.copyWith(color: AppColors.tinta)),
                        ),
                        Expanded(
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(4),
                            child: SizedBox(
                              height: 12,
                              child: Stack(
                                children: [
                                  Container(color: AppColors.surfaceAlt),
                                  FractionallySizedBox(
                                    widthFactor: e.value / maximo,
                                    child: Container(color: e.key.esmalte),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        SizedBox(
                          width: 64,
                          child: Text(
                            '${e.value} · ${_porcentaje(e.value, total)}',
                            textAlign: TextAlign.right,
                            style: AppTypography.bodySmall.copyWith(color: AppColors.tinta, fontWeight: FontWeight.w600),
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
    );
  }
}

/// Dona de estados con el total al centro y porcentaje en la leyenda.
class _EstadoDonutCard extends StatelessWidget {
  final List<NegocioSummary> negocios;
  const _EstadoDonutCard({required this.negocios});

  @override
  Widget build(BuildContext context) {
    final estados = [
      ('aprobado', 'Activos', AppColors.emerald),
      ('pendiente', 'Pendientes', AppColors.amber),
      ('rechazado', 'Rechazados', AppColors.errorRed),
    ];
    final counts = {for (final (clave, _, _) in estados) clave: negocios.where((n) => n.estado == clave).length};
    final total = negocios.length;

    return _ChartShell(
      title: 'Negocios por estado',
      subtitle: 'Solicitudes revisadas y por revisar',
      child: total == 0
          ? const _SinDatos('Sin datos todavía')
          : Row(
              children: [
                SizedBox(
                  width: 150,
                  height: 150,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      PieChart(
                        PieChartData(
                          sectionsSpace: 2,
                          centerSpaceRadius: 46,
                          startDegreeOffset: -90,
                          sections: [
                            for (final (clave, _, color) in estados)
                              if (counts[clave]! > 0)
                                PieChartSectionData(value: counts[clave]!.toDouble(), color: color, radius: 22, showTitle: false),
                          ],
                        ),
                      ),
                      Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text('$total', style: AppTypography.cifra(size: 26)),
                          Text('total', style: AppTypography.caption.copyWith(color: AppColors.slate400)),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: AppSpacing.lg),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      for (final (clave, etiqueta, color) in estados)
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 6),
                          child: Row(
                            children: [
                              Container(
                                width: 10,
                                height: 10,
                                decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(3)),
                              ),
                              const SizedBox(width: 8),
                              Expanded(child: Text(etiqueta, style: AppTypography.bodySmall.copyWith(color: AppColors.tinta))),
                              Text(
                                '${counts[clave]} · ${_porcentaje(counts[clave]!, total)}',
                                style: AppTypography.bodySmall.copyWith(color: AppColors.tinta, fontWeight: FontWeight.w600),
                              ),
                            ],
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
    );
  }
}

/// Solicitudes de negocio en el tiempo: por semana en los rangos cortos y por
/// mes en los largos, sin huecos (los periodos sin solicitudes salen en 0) y
/// con la cifra encima de cada barra.
class _SolicitudesPorMesCard extends StatelessWidget {
  final List<NegocioSummary> negocios;
  final _DateRange range;
  final ValueChanged<_DateRange> onRangeChanged;

  const _SolicitudesPorMesCard({required this.negocios, required this.range, required this.onRangeChanged});

  static const _mesesCortos = ['ene', 'feb', 'mar', 'abr', 'may', 'jun', 'jul', 'ago', 'sep', 'oct', 'nov', 'dic'];

  bool get _porSemana => range == _DateRange.d30 || range == _DateRange.d90;

  /// Inicio del periodo (lunes de la semana o día 1 del mes) de [fecha].
  DateTime _inicioPeriodo(DateTime fecha) {
    final dia = DateTime(fecha.year, fecha.month, fecha.day);
    return _porSemana ? dia.subtract(Duration(days: dia.weekday - 1)) : DateTime(fecha.year, fecha.month);
  }

  DateTime _siguiente(DateTime p) => _porSemana ? p.add(const Duration(days: 7)) : DateTime(p.year, p.month + 1);

  String _etiqueta(DateTime p, bool conAnio) {
    if (_porSemana) return '${p.day} ${_mesesCortos[p.month - 1]}';
    final mes = _mesesCortos[p.month - 1];
    return conAnio ? "$mes '${p.year % 100}" : mes;
  }

  @override
  Widget build(BuildContext context) {
    final ahora = DateTime.now();
    final desde = switch (range) {
      _DateRange.d30 => ahora.subtract(const Duration(days: 30)),
      _DateRange.d90 => ahora.subtract(const Duration(days: 90)),
      _DateRange.d365 => DateTime(ahora.year - 1, ahora.month + 1),
      _DateRange.all => negocios.isEmpty
          ? DateTime(ahora.year, ahora.month)
          : negocios.map((n) => n.solicitadoEn).reduce((a, b) => a.isBefore(b) ? a : b),
    };

    final periodos = <DateTime>[];
    for (var p = _inicioPeriodo(desde); !p.isAfter(ahora); p = _siguiente(p)) {
      periodos.add(p);
    }
    final conteo = List.filled(periodos.length, 0);
    for (final n in negocios) {
      final i = periodos.indexOf(_inicioPeriodo(n.solicitadoEn));
      if (i != -1) conteo[i]++;
    }
    final total = conteo.fold(0, (a, b) => a + b);
    final maximo = conteo.isEmpty ? 0 : conteo.reduce((a, b) => a > b ? a : b);
    final intervalo = maximo <= 5 ? 1.0 : (maximo / 4).ceilToDouble();
    final conAnio = periodos.isNotEmpty && periodos.first.year != periodos.last.year;
    // Con muchas barras se etiqueta una de cada N para que no se encimen.
    final cadaN = (periodos.length / 8).ceil().clamp(1, 99);
    final estiloCifra = TextStyle(color: AppColors.tinta, fontSize: 12, fontWeight: FontWeight.w700);

    return _ChartShell(
      title: _porSemana ? 'Solicitudes por semana' : 'Solicitudes por mes',
      subtitle: '$total en el periodo',
      trailing: _RangeSelector(value: range, onChanged: onRangeChanged),
      child: SizedBox(
        height: 220,
        child: total == 0
            ? const _SinDatos('Sin solicitudes en este rango')
            : BarChart(
                BarChartData(
                  maxY: (maximo + intervalo).toDouble(),
                  alignment: BarChartAlignment.spaceAround,
                  gridData: FlGridData(
                    drawVerticalLine: false,
                    horizontalInterval: intervalo,
                    getDrawingHorizontalLine: (_) => FlLine(color: AppColors.borderSubtle, strokeWidth: 1),
                  ),
                  borderData: FlBorderData(show: false),
                  barTouchData: BarTouchData(
                    enabled: false,
                    touchTooltipData: BarTouchTooltipData(
                      getTooltipColor: (_) => Colors.transparent,
                      tooltipPadding: EdgeInsets.zero,
                      tooltipMargin: 2,
                      getTooltipItem: (group, _, rod, __) => BarTooltipItem('${rod.toY.toInt()}', estiloCifra),
                    ),
                  ),
                  titlesData: FlTitlesData(
                    rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                    topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                    leftTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 28,
                        interval: intervalo,
                        getTitlesWidget: (value, meta) => Text(
                          value.toInt().toString(),
                          style: AppTypography.caption.copyWith(color: AppColors.slate400),
                        ),
                      ),
                    ),
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 26,
                        getTitlesWidget: (value, meta) {
                          final i = value.toInt();
                          if (i < 0 || i >= periodos.length || i % cadaN != 0) return const SizedBox.shrink();
                          return Padding(
                            padding: const EdgeInsets.only(top: 6),
                            child: Text(_etiqueta(periodos[i], conAnio), style: AppTypography.caption),
                          );
                        },
                      ),
                    ),
                  ),
                  barGroups: [
                    for (var i = 0; i < periodos.length; i++)
                      BarChartGroupData(
                        x: i,
                        showingTooltipIndicators: conteo[i] > 0 ? const [0] : const [],
                        barRods: [
                          BarChartRodData(
                            toY: conteo[i].toDouble(),
                            color: AppColors.turquesa,
                            width: periodos.length > 20 ? 8 : 18,
                            borderRadius: const BorderRadius.vertical(top: Radius.circular(4)),
                          ),
                        ],
                      ),
                  ],
                ),
              ),
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
    const labels = {_DateRange.d30: '30 días', _DateRange.d90: '90 días', _DateRange.d365: '1 año', _DateRange.all: 'Todo'};
    return Wrap(
      spacing: 6,
      runSpacing: 6,
      children: labels.entries.map((e) {
        final selected = e.key == value;
        return Material(
          color: selected ? AppColors.tinta : Colors.transparent,
          shape: StadiumBorder(side: BorderSide(color: selected ? AppColors.tinta : AppColors.borderSubtle)),
          child: InkWell(
            customBorder: const StadiumBorder(),
            onTap: () => onChanged(e.key),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              child: Text(
                e.value,
                style: TextStyle(
                  color: selected ? AppColors.casco : AppColors.slate300,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
        );
      }).toList(),
    );
  }
}

/// Cuentas por tipo y por estado, como barras de proporción con su leyenda.
class _UsuariosActivosCard extends StatelessWidget {
  final List<AuthUser> users;
  const _UsuariosActivosCard({required this.users});

  @override
  Widget build(BuildContext context) {
    final total = users.length;
    final empresas = users.where((u) => u.isNegocio).length;
    final activos = users.where((u) => u.activo).length;

    return _ChartShell(
      title: 'Cuentas de usuario',
      subtitle: '$total cuentas (sin contar administradores)',
      child: total == 0
          ? const _SinDatos('Sin usuarios todavía')
          : Column(
              children: [
                _BarraProporcion(
                  titulo: 'Tipo de cuenta',
                  partes: [
                    ('Visitantes', total - empresas, AppColors.turquesa),
                    ('Empresas', empresas, AppColors.amarillo),
                  ],
                ),
                const SizedBox(height: AppSpacing.lg),
                _BarraProporcion(
                  titulo: 'Estado',
                  partes: [
                    ('Activas', activos, AppColors.emerald),
                    ('Bloqueadas', total - activos, AppColors.errorRed),
                  ],
                ),
              ],
            ),
    );
  }
}

class _BarraProporcion extends StatelessWidget {
  final String titulo;
  final List<(String, int, Color)> partes;

  const _BarraProporcion({required this.titulo, required this.partes});

  @override
  Widget build(BuildContext context) {
    final total = partes.fold(0, (a, p) => a + p.$2);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(titulo, style: AppTypography.bodySmall.copyWith(color: AppColors.slate300)),
        const SizedBox(height: 6),
        ClipRRect(
          borderRadius: BorderRadius.circular(6),
          child: SizedBox(
            height: 14,
            child: Row(
              children: [
                for (final (_, n, color) in partes)
                  if (n > 0) Expanded(flex: n, child: Container(color: color)),
              ],
            ),
          ),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: AppSpacing.lg,
          runSpacing: 4,
          children: [
            for (final (etiqueta, n, color) in partes)
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(width: 10, height: 10, decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(3))),
                  const SizedBox(width: 6),
                  Text('$etiqueta: $n (${_porcentaje(n, total)})',
                      style: AppTypography.bodySmall.copyWith(color: AppColors.tinta, fontWeight: FontWeight.w600)),
                ],
              ),
          ],
        ),
      ],
    );
  }
}
