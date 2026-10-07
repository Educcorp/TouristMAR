import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../navegacion/rutas.dart';
import '../../services/auth_service.dart';
import '../../services/recorridos_service.dart';
import '../../services/session_storage.dart';
import '../../theme/app_theme.dart';
import '../../theme/breakpoints.dart';
import '../../utils/date_format_es.dart';
import '../../widgets/admin/ds_badge.dart';
import '../../widgets/admin/ds_button.dart';
import '../../widgets/admin/ds_card.dart';
import '../../widgets/admin/ds_icon_badge.dart';
import '../../widgets/admin/ds_states.dart';
import 'admin_negocio_detalle_page.dart';

/// Contenido de la sección "Solicitudes" embebido en [AdminShell] — sin
/// Scaffold/AppBar propio, ya que el sidebar/topbar los provee el shell.
///
/// Dos tipos de solicitud: registro de negocios (aprobar/rechazar) y
/// recorridos 360° que piden los negocios desde "Editar negocio".
class AdminRequestsPage extends StatefulWidget {
  final AuthService authService;
  final RecorridosService recorridosService;

  AdminRequestsPage({super.key, AuthService? authService, RecorridosService? recorridosService})
      : authService = authService ?? AuthService(),
        recorridosService = recorridosService ?? RecorridosService();

  @override
  State<AdminRequestsPage> createState() => _AdminRequestsPageState();
}

class _AdminRequestsPageState extends State<AdminRequestsPage> {
  List<NegocioSummary> _requests = [];
  bool _loading = true;
  String? _error;
  final Set<String> _deciding = {};

  List<SolicitudRecorrido360> _recorridos = [];
  String? _errorRecorridos;

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
    _errorRecorridos = null;
    // Cada lista falla por separado: si una no carga, la otra se sigue viendo.
    await Future.wait([
      () async {
        try {
          final requests = await widget.authService.adminListNegociosPendientes(token);
          if (mounted) setState(() => _requests = requests);
        } catch (err) {
          if (mounted) setState(() => _error = err is AuthError ? err.message : 'No se pudo conectar con el servidor');
        }
      }(),
      () async {
        try {
          final lista = await widget.recorridosService.listSolicitudes(token, estado: EstadoSolicitudRecorrido.pendiente);
          if (mounted) setState(() => _recorridos = lista);
        } catch (err) {
          if (mounted) {
            setState(() => _errorRecorridos = err is AuthError ? err.message : 'No se pudo conectar con el servidor');
          }
        }
      }(),
    ]);
    if (mounted) setState(() => _loading = false);
  }

  Future<void> _atenderRecorrido(SolicitudRecorrido360 solicitud, EstadoSolicitudRecorrido decision) async {
    final token = SessionStorage.token;
    if (token == null) return;
    var nota = '';
    if (decision == EstadoSolicitudRecorrido.rechazada) {
      final escrita = await _pedirNota(context, solicitud.negocio?.nombre ?? 'el negocio');
      if (escrita == null) return;
      nota = escrita;
    }
    setState(() => _deciding.add(solicitud.id));
    try {
      await widget.recorridosService.atenderSolicitud(token, solicitud.id, decision, nota: nota);
      if (!mounted) return;
      setState(() => _recorridos.removeWhere((s) => s.id == solicitud.id));
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(decision == EstadoSolicitudRecorrido.completada
            ? 'Solicitud marcada como atendida. Se le avisó al negocio.'
            : 'Solicitud rechazada. Se le avisó al negocio.'),
      ));
    } catch (err) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(err is AuthError ? err.message : 'No se pudo procesar la solicitud')),
      );
    } finally {
      if (mounted) setState(() => _deciding.remove(solicitud.id));
    }
  }

  Future<void> _decide(NegocioSummary negocio, bool approve) async {
    final token = SessionStorage.token;
    if (token == null) return;
    setState(() => _deciding.add(negocio.id));
    try {
      if (approve) {
        await widget.authService.adminApproveNegocio(token, negocio.id);
      } else {
        await widget.authService.adminRejectNegocio(token, negocio.id);
      }
      if (!mounted) return;
      setState(() => _requests.removeWhere((r) => r.id == negocio.id));
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(approve ? 'Solicitud aprobada. El negocio ya puede acceder a su panel.' : 'Solicitud rechazada.')),
      );
    } catch (err) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(err is AuthError ? err.message : 'No se pudo procesar la solicitud')),
      );
    } finally {
      if (mounted) setState(() => _deciding.remove(negocio.id));
    }
  }

  /// Detalle de la solicitud: lo que mandó la empresa (imagen, nombre,
  /// ubicación…), editable por el admin, con aprobar/rechazar.
  Future<void> _abrirDetalle(NegocioSummary negocio) async {
    final resultado = await abrirDetalleNegocio(context, negocioId: negocio.id, authService: widget.authService);
    if (!mounted || resultado == null) return;
    if (resultado.abrirContenido != null) {
      // El recorrido 360° y los marcadores de RA se agregan en la ficha del
      // lugar dentro de "Mapa y RA".
      context.go(rutaLugarAdmin(negocio.id));
      return;
    }
    if (resultado.aprobado != null) {
      setState(() => _requests.removeWhere((r) => r.id == negocio.id));
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(resultado.aprobado!
              ? 'Solicitud aprobada. El negocio ya puede acceder a su panel.'
              : 'Solicitud rechazada.'),
        ),
      );
    } else if (resultado.editado) {
      _load();
    }
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
            Row(
              children: [
                Text('Solicitudes', style: AppTypography.h1),
                if (_requests.length + _recorridos.length > 0) ...[
                  const SizedBox(width: AppSpacing.sm),
                  DsBadge(text: '${_requests.length + _recorridos.length}', tone: BadgeTone.warning),
                ],
              ],
            ),
            const SizedBox(height: 4),
            Text('Gestiona y da seguimiento a las solicitudes del sistema.', style: AppTypography.body),
            const SizedBox(height: AppSpacing.xl),
            if (_loading)
              DsLoadingState()
            else ...[
              _Encabezado(titulo: 'Registro de negocios', total: _requests.length),
              const SizedBox(height: AppSpacing.md),
              _buildContent(),
              const SizedBox(height: AppSpacing.xl),
              _Encabezado(titulo: 'Recorridos 360°', total: _recorridos.length),
              const SizedBox(height: 4),
              Text(
                'Negocios que pidieron su recorrido. Al crearle un recorrido desde su ficha, la solicitud se marca como atendida sola.',
                style: AppTypography.bodySmall,
              ),
              const SizedBox(height: AppSpacing.md),
              _buildRecorridos(),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildRecorridos() {
    if (_errorRecorridos != null) return DsErrorState(message: _errorRecorridos!, onRetry: _load);
    if (_recorridos.isEmpty) {
      return const DsEmptyState(
        icon: Icons.threesixty,
        title: 'No hay solicitudes de recorrido',
        subtitle: 'Cuando un negocio pida su recorrido 360°, aparecerá aquí.',
      );
    }
    return Column(
      children: _recorridos
          .map((s) => Padding(
                padding: const EdgeInsets.only(bottom: AppSpacing.md),
                child: _SolicitudRecorridoRow(
                  solicitud: s,
                  isDeciding: _deciding.contains(s.id),
                  onCrear: () => context.go(rutaLugarAdmin(s.negocioId)),
                  onAtendida: () => _atenderRecorrido(s, EstadoSolicitudRecorrido.completada),
                  onRechazar: () => _atenderRecorrido(s, EstadoSolicitudRecorrido.rechazada),
                ),
              ))
          .toList(),
    );
  }

  Widget _buildContent() {
    if (_error != null) return DsErrorState(message: _error!, onRetry: _load);
    if (_requests.isEmpty) {
      return const DsEmptyState(
        icon: Icons.mark_email_read_outlined,
        title: 'No hay solicitudes pendientes',
        subtitle: 'Cuando recibas nuevas solicitudes, aparecerán aquí.',
      );
    }
    return Column(
      children: _requests
          .map((r) => Padding(
                padding: const EdgeInsets.only(bottom: AppSpacing.md),
                child: _RequestRow(
                  negocio: r,
                  isDeciding: _deciding.contains(r.id),
                  onApprove: () => _decide(r, true),
                  onReject: () => _decide(r, false),
                  onOpen: () => _abrirDetalle(r),
                ),
              ))
          .toList(),
    );
  }
}

class _RequestRow extends StatelessWidget {
  final NegocioSummary negocio;
  final bool isDeciding;
  final VoidCallback onApprove;
  final VoidCallback onReject;
  final VoidCallback onOpen;

  const _RequestRow({
    required this.negocio,
    required this.isDeciding,
    required this.onApprove,
    required this.onReject,
    required this.onOpen,
  });

  @override
  Widget build(BuildContext context) {
    final date = formatDateEs(negocio.solicitadoEn);

    return DsCard(
      onTap: onOpen,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final compact = Breakpoints.isCompact(constraints.maxWidth);
          final badges = Wrap(
            spacing: AppSpacing.sm,
            runSpacing: 4,
            children: [
              if (negocio.esAdicional) const DsBadge(text: 'Negocio adicional', tone: BadgeTone.info),
              const DsBadge(text: 'Pendiente', tone: BadgeTone.warning),
            ],
          );
          // En pantallas angostas (celular) las insignias van debajo del
          // nombre; a lo ancho no caben junto a él y la fila se desborda.
          final identity = Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _Miniatura(url: negocio.portada),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      negocio.nombre,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.w700, fontSize: 14),
                    ),
                    const SizedBox(height: 2),
                    Text(negocio.categoria ?? 'Sin categoría', style: AppTypography.bodySmall),
                    if (compact) ...[
                      const SizedBox(height: 6),
                      badges,
                    ],
                  ],
                ),
              ),
              if (!compact) ...[
                const SizedBox(width: AppSpacing.sm),
                badges,
              ],
            ],
          );

          final meta = Padding(
            padding: EdgeInsets.only(top: AppSpacing.md, left: compact ? 0 : 56),
            child: Wrap(
              spacing: AppSpacing.lg,
              runSpacing: 6,
              children: [
                _InfoChip(icon: Icons.person_outline, text: negocio.contacto),
                _InfoChip(icon: Icons.mail_outline, text: negocio.email),
                _InfoChip(icon: Icons.event_outlined, text: date),
                _InfoChip(
                  icon: negocio.tieneUbicacion ? Icons.location_on_outlined : Icons.location_off_outlined,
                  text: negocio.tieneUbicacion ? 'Con ubicación' : 'Sin ubicación',
                ),
              ],
            ),
          );

          final actions = Padding(
            padding: EdgeInsets.only(top: AppSpacing.md, left: compact ? 0 : 56),
            child: isDeciding
                ? SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.slate400),
                  )
                : Wrap(
                    spacing: AppSpacing.sm,
                    runSpacing: AppSpacing.sm,
                    children: [
                      DsButton(
                        label: 'Ver y editar',
                        icon: Icons.open_in_new,
                        size: DsButtonSize.sm,
                        accent: AppColors.adminViolet,
                        onPressed: onOpen,
                      ),
                      DsButton(label: 'Rechazar', variant: DsButtonVariant.danger, size: DsButtonSize.sm, onPressed: onReject),
                      DsButton(
                        label: 'Aprobar',
                        variant: DsButtonVariant.secondary,
                        accent: AppColors.emerald,
                        size: DsButtonSize.sm,
                        onPressed: onApprove,
                      ),
                    ],
                  ),
          );

          return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [identity, meta, actions]);
        },
      ),
    );
  }
}

class _InfoChip extends StatelessWidget {
  final IconData icon;
  final String text;

  const _InfoChip({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 13, color: AppColors.slate500),
        const SizedBox(width: 6),
        Flexible(child: Text(text, style: AppTypography.bodySmall, overflow: TextOverflow.ellipsis)),
      ],
    );
  }
}

class _Encabezado extends StatelessWidget {
  final String titulo;
  final int total;

  const _Encabezado({required this.titulo, required this.total});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Text(titulo, style: AppTypography.h3),
        if (total > 0) ...[
          const SizedBox(width: AppSpacing.sm),
          DsBadge(text: '$total', tone: BadgeTone.warning),
        ],
      ],
    );
  }
}

/// Motivo del rechazo, que le llega al negocio en su notificación. null =
/// canceló.
Future<String?> _pedirNota(BuildContext context, String negocio) {
  final controller = TextEditingController();
  return showDialog<String>(
    context: context,
    builder: (context) => AlertDialog(
      backgroundColor: AppColors.panelNavySoft,
      title: Text('Rechazar recorrido de $negocio', style: AppTypography.h3),
      content: SizedBox(
        width: 380,
        child: TextField(
          controller: controller,
          maxLength: 500,
          maxLines: 3,
          autofocus: true,
          style: TextStyle(color: AppColors.textPrimary, fontSize: 14),
          decoration: InputDecoration(
            hintText: 'Motivo (opcional), p. ej. "Por ahora solo cubrimos la zona centro"',
            hintStyle: TextStyle(color: AppColors.slate500, fontSize: 13),
          ),
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Cancelar')),
        DsButton(
          label: 'Rechazar',
          variant: DsButtonVariant.danger,
          size: DsButtonSize.sm,
          onPressed: () => Navigator.of(context).pop(controller.text.trim()),
        ),
      ],
    ),
  ).whenComplete(controller.dispose);
}

class _SolicitudRecorridoRow extends StatelessWidget {
  final SolicitudRecorrido360 solicitud;
  final bool isDeciding;
  final VoidCallback onCrear;
  final VoidCallback onAtendida;
  final VoidCallback onRechazar;

  const _SolicitudRecorridoRow({
    required this.solicitud,
    required this.isDeciding,
    required this.onCrear,
    required this.onAtendida,
    required this.onRechazar,
  });

  @override
  Widget build(BuildContext context) {
    final n = solicitud.negocio;
    final pin = n?.ubicacion;

    return DsCard(
      child: LayoutBuilder(
        builder: (context, constraints) {
          final compact = Breakpoints.isCompact(constraints.maxWidth);
          final sangria = EdgeInsets.only(top: AppSpacing.md, left: compact ? 0 : 56);
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  DsIconBadgeCircle(icon: Icons.threesixty, color: AppColors.businessOrange),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(n?.nombre ?? 'Negocio',
                            style: TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.w700, fontSize: 14)),
                        const SizedBox(height: 2),
                        Text(
                          (n?.categoria.isNotEmpty ?? false) ? n!.categoria : 'Sin categoría',
                          style: AppTypography.bodySmall,
                        ),
                      ],
                    ),
                  ),
                  const DsBadge(text: 'Recorrido 360°', tone: BadgeTone.info),
                ],
              ),
              Padding(
                padding: sangria,
                child: Wrap(
                  spacing: AppSpacing.lg,
                  runSpacing: 6,
                  children: [
                    if (n != null && n.contacto.isNotEmpty) _InfoChip(icon: Icons.person_outline, text: n.contacto),
                    if (n != null && n.email.isNotEmpty) _InfoChip(icon: Icons.mail_outline, text: n.email),
                    if (n != null && n.telefono.isNotEmpty) _InfoChip(icon: Icons.phone_outlined, text: n.telefono),
                    _InfoChip(icon: Icons.event_outlined, text: formatDateEs(solicitud.creadaEn)),
                    if (n != null && n.direccion.isNotEmpty) _InfoChip(icon: Icons.place_outlined, text: n.direccion),
                    if (pin != null)
                      _InfoChip(icon: Icons.my_location, text: '${pin.lat.toStringAsFixed(6)}, ${pin.lng.toStringAsFixed(6)}'),
                  ],
                ),
              ),
              if (solicitud.mensaje.isNotEmpty)
                Padding(
                  padding: sangria,
                  child: Text('"${solicitud.mensaje}"', style: AppTypography.bodySmall.copyWith(fontStyle: FontStyle.italic)),
                ),
              Padding(
                padding: sangria,
                child: isDeciding
                    ? SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.slate400),
                      )
                    : Wrap(
                        spacing: AppSpacing.sm,
                        runSpacing: AppSpacing.sm,
                        children: [
                          DsButton(label: 'Rechazar', variant: DsButtonVariant.danger, size: DsButtonSize.sm, onPressed: onRechazar),
                          DsButton(
                            label: 'Marcar como atendida',
                            variant: DsButtonVariant.ghost,
                            size: DsButtonSize.sm,
                            onPressed: onAtendida,
                          ),
                          DsButton(
                            label: 'Crear recorrido',
                            icon: Icons.add,
                            variant: DsButtonVariant.secondary,
                            accent: AppColors.emerald,
                            size: DsButtonSize.sm,
                            onPressed: onCrear,
                          ),
                        ],
                      ),
              ),
            ],
          );
        },
      ),
    );
  }
}

/// Portada que mandó la empresa, en chico; si no mandó, el ícono de negocio.
class _Miniatura extends StatelessWidget {
  final String? url;

  // ignore: prefer_const_constructors_in_immutables
  _Miniatura({required this.url});

  @override
  Widget build(BuildContext context) {
    final u = url;
    if (u == null || u.isEmpty) {
      return DsIconBadgeCircle(icon: Icons.apartment, color: AppColors.businessOrange);
    }
    return ClipRRect(
      borderRadius: BorderRadius.circular(10),
      child: Image.network(
        u,
        width: 44,
        height: 44,
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) => DsIconBadgeCircle(icon: Icons.apartment, color: AppColors.businessOrange),
      ),
    );
  }
}
