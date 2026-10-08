import 'package:flutter/material.dart';

import '../models/visitor_profile.dart';
import '../models/lugar.dart';
import '../navegacion/rutas.dart';
import '../navegacion/sesion.dart';
import '../services/auth_service.dart';
import '../services/favoritos_service.dart';
import '../services/lugares_service.dart';
import '../theme/app_theme.dart';
import '../widgets/app_shell.dart';
import '../services/experiencias_launcher.dart';
import '../widgets/casco_lugar.dart';
import '../widgets/register_place_banner.dart';
import '../widgets/themed_builder.dart';
import '../utils/keyboard.dart';
import '../widgets/user_avatar.dart';

class HomePage extends StatefulWidget {
  final AuthUser user;

  const HomePage({super.key, required this.user});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  /// El mismo perfil que usan "Mi perfil" y "Editar perfil"
  /// ([Sesion.perfilVisitante]). Antes el inicio armaba su propia copia desde
  /// `widget.user` (lo que regresó el servidor al iniciar sesión), así que
  /// después de cambiar la foto seguía mostrando la anterior hasta recargar
  /// la página. Si el inicio se abre sin sesión registrada (p. ej. en
  /// pruebas), se arma desde `widget.user` como antes.
  late final VisitorProfile _profile = Sesion.usuario.value?.id == widget.user.id
      ? Sesion.perfilVisitante
      : VisitorProfile.fromAuthUser(widget.user);

  @override
  void initState() {
    super.initState();
    // Para que los corazones de tarjetas y fichas salgan ya marcados.
    FavoritosService.instance.cargarIds();
    // Y para que el contador de reseñas del menú lateral sea el real.
    _profile.cargarResenas().then((_) {
      if (mounted) setState(() {});
    });
    _cargarLugares();
  }

  /// Error 1: el banner "¿Te gustaría registrar un lugar nuevo?" (y la acción
  /// rápida "Proponer lugar") no hacían nada. El backend solo deja registrar
  /// lugares a cuentas de negocio, así que se le explica al visitante y, si
  /// acepta, se cierra su sesión y se abre directo el registro de negocio.
  Future<void> _proposePlace() async {
    final go = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: AppColors.panelNavySoft,
        title: Text('Registrar un lugar nuevo', style: TextStyle(color: AppColors.textPrimary)),
        content: Text(
          'Para proponer tu negocio o sitio turístico necesitas una cuenta de negocio. '
          'Al continuar se cerrará tu sesión de visitante y te llevaremos al registro de negocio. '
          'Un administrador revisará la solicitud antes de que aparezca en el mapa.',
          style: TextStyle(color: AppColors.textSecondary, height: 1.4),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: Text('Cancelar', style: TextStyle(color: AppColors.slate400)),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: Text('Continuar', style: TextStyle(color: AppColors.brandTeal, fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
    if (go != true || !mounted) return;

    cerrarSesion(context, registroNegocio: true);
  }

  /// Lugares públicos (reales y de ejemplo); `null` mientras cargan.
  List<Lugar>? _lugares;

  /// Ubicación del visitante, solo si la compartió (se pide con un botón,
  /// nunca al abrir la pantalla).
  Coordenadas? _yo;
  bool _pidiendoUbicacion = false;

  String _busqueda = '';
  CategoriaLugar? _filtro;
  final _buscador = TextEditingController();

  @override
  void dispose() {
    _buscador.dispose();
    super.dispose();
  }

  Future<void> _cargarLugares() async {
    final lugares = await const LugaresService().listarPublicos();
    if (mounted) setState(() => _lugares = lugares);
  }

  Future<void> _pedirUbicacion() async {
    setState(() => _pidiendoUbicacion = true);
    final yo = await UbicacionProvider.current.actual();
    if (!mounted) return;
    setState(() {
      _pidiendoUbicacion = false;
      _yo = yo;
    });
    if (yo == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No pudimos leer tu ubicación. Revisa el permiso del navegador o del teléfono.')),
      );
    }
  }

  double? _distancia(Lugar l) => (_yo == null || l.ubicacion == null) ? null : distanciaMetros(_yo!, l.ubicacion!);

  /// Filtrados por búsqueda y franja; con ubicación, del más cercano al más
  /// lejano (los que no tienen pin van al final).
  List<Lugar> get _visibles {
    final q = _busqueda.trim().toLowerCase();
    final lista = (_lugares ?? const <Lugar>[])
        .where((l) => _filtro == null || l.categoria == _filtro)
        .where((l) => q.isEmpty || l.nombre.toLowerCase().contains(q) || l.categoria.etiqueta.toLowerCase().contains(q))
        .toList();
    if (_yo != null) {
      lista.sort((a, b) => (_distancia(a) ?? double.infinity).compareTo(_distancia(b) ?? double.infinity));
    }
    return lista;
  }

  String get _greeting {
    final hour = DateTime.now().hour;
    if (hour < 12) return 'Buenos días';
    if (hour < 19) return 'Buenas tardes';
    return 'Buenas noches';
  }

  @override
  Widget build(BuildContext context) => ThemedBuilder(builder: _buildShell);

  Widget _buildShell(BuildContext context) {
    // También del perfil compartido: si cambió el nombre, el saludo ya sale nuevo.
    final firstName = _profile.name.trim().isEmpty ? _profile.name : _profile.name.trim().split(' ').first;

    return AppShell(
      accentColor: AppColors.brandTeal,
      // Se lee de `_profile` (el que edita "Editar perfil"), no de
      // `widget.user`, para que el inicio muestre la foto/nombre guardados.
      avatarIcon: UserAvatar(imageUrl: _profile.avatarUrl, fallbackLetter: _profile.name),
      drawerIdentity: VisitorIdentityCard(
        name: _profile.name,
        email: _profile.email,
        avatarUrl: _profile.avatarUrl,
        reviewsCount: _profile.reviews.length,
      ),
      navItems: visitorNavItems(context, profile: _profile, current: VisitorSection.home),
      body: CustomScrollView(
        slivers: [
          SliverToBoxAdapter(
            child: _Ancho(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('$_greeting, $firstName', style: AppTypography.h1),
                    const SizedBox(height: 4),
                    Text('¿A dónde vas hoy en Manzanillo?', style: AppTypography.body),
                    const SizedBox(height: 16),
                    _buildSearchBar(),
                    const SizedBox(height: 14),
                  ],
                ),
              ),
            ),
          ),
          SliverToBoxAdapter(child: _Ancho(child: _buildFranjas())),
          SliverToBoxAdapter(
            child: _Ancho(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 28, 20, 12),
                child: _buildEncabezadoLista(),
              ),
            ),
          ),
          SliverToBoxAdapter(child: _Ancho(child: _buildLista())),
          SliverToBoxAdapter(
            child: _Ancho(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 28, 20, 32),
                child: RegisterPlaceBanner(onTap: _proposePlace),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFranjas() {
    const categorias = [
      CategoriaLugar.playa,
      CategoriaLugar.restaurante,
      CategoriaLugar.mirador,
      CategoriaLugar.recreacion,
      CategoriaLugar.cultura,
      CategoriaLugar.hotel,
    ];
    return SizedBox(
      height: 48,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 20),
        itemCount: categorias.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (context, i) {
          final c = categorias[i];
          final activa = _filtro == c;
          // Sobre un esmalte oscuro (azul, rojo, tinta) el texto va en blanco.
          final sobreOscuro = c.esmalte.computeLuminance() < 0.3;
          final colorTexto = activa ? (sobreOscuro ? Colors.white : AppColors.riel) : AppColors.tinta;
          return Semantics(
            selected: activa,
            button: true,
            label: 'Filtrar por ${c.etiqueta}',
            excludeSemantics: true,
            child: Material(
              color: activa ? c.esmalte : AppColors.cubierta,
              shape: StadiumBorder(side: BorderSide(color: activa ? c.esmalte : AppColors.borderSubtle)),
              child: InkWell(
                customBorder: const StadiumBorder(),
                onTap: () => setState(() => _filtro = activa ? null : c),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Row(
                    children: [
                      Container(
                        width: 16,
                        height: kFranja,
                        decoration: BoxDecoration(
                          color: activa ? colorTexto : c.esmalte,
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(c.etiqueta, style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: colorTexto)),
                    ],
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildEncabezadoLista() {
    return Row(
      children: [
        Expanded(child: Text(_yo != null ? 'Cerca de ti' : 'Lugares en Manzanillo', style: AppTypography.h2)),
        if (_yo == null)
          TextButton.icon(
            onPressed: _pidiendoUbicacion ? null : _pedirUbicacion,
            icon: _pidiendoUbicacion
                ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                : const Icon(Icons.near_me_outlined, size: 20),
            label: const Text('Ordenar por cercanía'),
          ),
      ],
    );
  }

  Widget _buildLista() {
    final cargando = _lugares == null;
    final lugares = cargando ? const <Lugar>[] : _visibles;
    if (!cargando && lugares.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 32),
        child: Column(
          children: [
            Icon(Icons.travel_explore, size: 40, color: AppColors.slate400),
            const SizedBox(height: 12),
            Text('Nada coincide con tu búsqueda', style: AppTypography.h3),
            const SizedBox(height: 4),
            TextButton(
              onPressed: () => setState(() {
                _busqueda = '';
                _filtro = null;
                _buscador.clear();
              }),
              child: const Text('Ver todos los lugares'),
            ),
          ],
        ),
      );
    }
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final columnas = constraints.maxWidth >= 900 ? 3 : (constraints.maxWidth >= 560 ? 2 : 1);
          const espacio = 16.0;
          final ancho = (constraints.maxWidth - espacio * (columnas - 1)) / columnas;
          return Wrap(
            spacing: espacio,
            runSpacing: espacio,
            children: cargando
                ? [for (var i = 0; i < columnas * 2; i++) SizedBox(width: ancho, child: const CascoEsqueleto())]
                : [
                    for (final l in lugares)
                      SizedBox(
                        width: ancho,
                        child: CascoLugar(lugar: l, distanciaMetros: _distancia(l), onTap: () => abrirLugar(context, l)),
                      ),
                  ],
          );
        },
      ),
    );
  }

  Widget _buildSearchBar() {
    return TextField(
      controller: _buscador,
      // Tocar fuera de la barra cierra el teclado (en Android, por defecto,
      // un toque fuera no le quita el foco al campo).
      onTapOutside: (_) => hideKeyboard(),
      onChanged: (v) => setState(() => _busqueda = v),
      textInputAction: TextInputAction.search,
      style: TextStyle(color: AppColors.textPrimary, fontSize: 16),
      decoration: InputDecoration(
        hintText: 'Buscar playas, mariscos, miradores…',
        prefixIcon: Icon(Icons.search, color: AppColors.slate400),
        suffixIcon: _busqueda.isEmpty
            ? null
            : IconButton(
                tooltip: 'Borrar búsqueda',
                icon: const Icon(Icons.close),
                onPressed: () => setState(() {
                  _busqueda = '';
                  _buscador.clear();
                }),
              ),
      ),
    );
  }
}

/// Limita el contenido a una columna legible en pantallas anchas.
class _Ancho extends StatelessWidget {
  final Widget child;

  const _Ancho({required this.child});

  @override
  Widget build(BuildContext context) =>
      Center(child: ConstrainedBox(constraints: const BoxConstraints(maxWidth: 1080), child: child));
}
