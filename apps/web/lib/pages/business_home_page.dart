import 'package:flutter/material.dart';

import '../models/business_profile.dart';
import '../services/auth_service.dart';
import '../widgets/business/business_shell.dart';
import 'business_dashboard_page.dart';
import 'business_profile_page.dart';
import 'business_reviews_page.dart';
import 'business_suggest_page.dart';

/// Host del panel de empresa: aloja [BusinessShell] y decide qué contenido
/// mostrar en el área central según la sección elegida y el negocio
/// seleccionado en el switcher. El sidebar/topbar nunca se remonta al
/// cambiar de sección ni al cambiar de negocio — solo el contenido central.
class BusinessHomePage extends StatefulWidget {
  final AuthUser user;

  const BusinessHomePage({super.key, required this.user});

  @override
  State<BusinessHomePage> createState() => _BusinessHomePageState();
}

class _BusinessHomePageState extends State<BusinessHomePage> {
  late List<BusinessProfile> _negocios = widget.user.negocios
      .map((n) => BusinessProfile.fromNegocioInfo(widget.user, n))
      .toList();
  late String _selectedId = (_negocios.firstWhere(
    (n) => n.verified,
    orElse: () => _negocios.first,
  )).id;
  BusinessSection _section = BusinessSection.dashboard;

  BusinessProfile get _selected => _negocios.firstWhere((n) => n.id == _selectedId);

  void _selectNegocio(String id) {
    setState(() {
      _selectedId = id;
      _section = BusinessSection.dashboard;
    });
  }

  void _selectSection(BusinessSection section) => setState(() => _section = section);

  void _refreshSelected() => setState(() {});

  Future<void> _openSuggestForm() async {
    final created = await Navigator.of(context).push<BusinessProfile>(
      MaterialPageRoute(builder: (_) => const BusinessSuggestPage()),
    );
    if (created != null && mounted) {
      setState(() {
        _negocios.add(created);
        _selectedId = created.id;
        _section = BusinessSection.dashboard;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return BusinessShell(
      negocios: _negocios,
      selected: _selected,
      onSelectNegocio: _selectNegocio,
      onAddNegocio: _openSuggestForm,
      section: _section,
      onSelectSection: _selectSection,
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    switch (_section) {
      case BusinessSection.dashboard:
        return BusinessDashboardContent(
          key: ValueKey(_selectedId),
          business: _selected,
          onNegocioUpdated: _refreshSelected,
          onOpenReviews: () => _selectSection(BusinessSection.resenas),
        );
      case BusinessSection.perfil:
        return BusinessProfileContent(
          key: ValueKey(_selectedId),
          business: _selected,
          onNegocioUpdated: _refreshSelected,
          onOpenReviews: () => _selectSection(BusinessSection.resenas),
        );
      case BusinessSection.resenas:
        return BusinessReviewsContent(key: ValueKey(_selectedId), business: _selected);
    }
  }
}
