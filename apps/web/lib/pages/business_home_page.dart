import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../models/business_profile.dart';
import '../navegacion/rutas.dart';
import '../navegacion/sesion.dart';
import '../services/auth_service.dart';
import '../widgets/business/business_shell.dart';
import '../widgets/themed_builder.dart';
import 'business_dashboard_page.dart';
import 'business_experiencias_page.dart';
import 'business_profile_page.dart';
import 'business_reviews_page.dart';

/// Host del panel de empresa: aloja [BusinessShell] y decide qué contenido
/// mostrar en el área central según la sección elegida y el negocio
/// seleccionado en el switcher. El sidebar/topbar nunca se remonta al
/// cambiar de sección ni al cambiar de negocio — solo el contenido central.
class BusinessHomePage extends StatefulWidget {
  final AuthUser user;

  /// Sección visible y negocio elegido (vienen de la URL:
  /// `/empresa/<seccion>?negocio=<id>`).
  final BusinessSection seccion;
  final String? negocioId;

  const BusinessHomePage({super.key, required this.user, this.seccion = BusinessSection.dashboard, this.negocioId});

  @override
  State<BusinessHomePage> createState() => _BusinessHomePageState();
}

class _BusinessHomePageState extends State<BusinessHomePage> {
  /// La misma lista para todas las pantallas de la empresa (ver [Sesion.negocios]).
  List<BusinessProfile> get _negocios => Sesion.negocios;

  String get _selectedId {
    final pedido = widget.negocioId;
    if (pedido != null && _negocios.any((n) => n.id == pedido)) return pedido;
    return _negocios.firstWhere((n) => n.verified, orElse: () => _negocios.first).id;
  }

  BusinessSection get _section => widget.seccion;

  BusinessProfile get _selected => _negocios.firstWhere((n) => n.id == _selectedId);

  void _ir(BusinessSection section, {String? negocioId}) =>
      context.go(rutaEmpresa(section, negocioId: negocioId ?? _selectedId));

  void _selectNegocio(String id) => _ir(BusinessSection.dashboard, negocioId: id);

  void _selectSection(BusinessSection section) => _ir(section);

  void _refreshSelected() => setState(() {});

  Future<void> _openSuggestForm() async {
    final created = await context.push<BusinessProfile>('/empresa/sugerir');
    if (created != null && mounted) {
      if (!_negocios.any((n) => n.id == created.id)) _negocios.add(created);
      _ir(BusinessSection.dashboard, negocioId: created.id);
    }
  }

  @override
  Widget build(BuildContext context) => ThemedBuilder(builder: _buildShell);

  Widget _buildShell(BuildContext context) {
    return BusinessShell(
      negocios: _negocios,
      selected: _selected,
      onSelectNegocio: _selectNegocio,
      onAddNegocio: _openSuggestForm,
      section: _section,
      onSelectSection: _selectSection,
      onNotificationTap: _handleNotificationTap,
      body: _buildBody(),
    );
  }

  /// Una notificación de aprobado/rechazado trae el negocioId al que se
  /// refiere — si todavía está en la lista (siempre debería estarlo), se
  /// selecciona y se manda a "Mi negocio" para que se vea el resultado.
  void _handleNotificationTap(AppNotification notification) {
    final negocioId = notification.negocioId;
    if (negocioId == null) return;
    if (!_negocios.any((n) => n.id == negocioId)) return;
    _ir(BusinessSection.perfil, negocioId: negocioId);
  }

  Widget _buildBody() {
    switch (_section) {
      case BusinessSection.dashboard:
        return BusinessDashboardContent(
          key: ValueKey(_selectedId),
          business: _selected,
          onNegocioUpdated: _refreshSelected,
          onOpenReviews: () => _selectSection(BusinessSection.resenas),
          onOpenExperiencias: () => _selectSection(BusinessSection.experiencias),
        );
      case BusinessSection.perfil:
        return BusinessProfileContent(
          key: ValueKey(_selectedId),
          business: _selected,
          onNegocioUpdated: _refreshSelected,
          onOpenReviews: () => _selectSection(BusinessSection.resenas),
        );
      case BusinessSection.experiencias:
        return BusinessExperienciasContent(key: ValueKey(_selectedId), business: _selected);
      case BusinessSection.resenas:
        return BusinessReviewsContent(key: ValueKey(_selectedId), business: _selected);
    }
  }
}
