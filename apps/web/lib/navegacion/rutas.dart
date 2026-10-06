import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../models/business_profile.dart';
import '../models/lugar.dart';
import '../pages/admin/admin_dashboard_page.dart';
import '../pages/business_edit_page.dart';
import '../pages/business_gallery_page.dart';
import '../pages/business_home_page.dart';
import '../pages/business_suggest_page.dart';
import '../pages/edit_profile_page.dart';
import '../pages/explorar_mapa_page.dart';
import '../pages/favoritos_page.dart';
import '../pages/home_page.dart';
import '../pages/login_page.dart';
import '../pages/lugar_detalle_page.dart';
import '../pages/profile_page.dart';
import '../pages/recorrido_360_page.dart';
import '../services/auth_service.dart';
import '../services/lugares_service.dart';
import '../services/recorridos_service.dart';
import '../widgets/admin/admin_shell.dart';
import '../widgets/business/business_shell.dart';
import '../widgets/session_guard.dart';
import 'sesion.dart';

// Rutas de la app (web y móvil). Cada pantalla tiene su dirección, así la
// flecha de atrás del navegador (o del teléfono) regresa a la pantalla
// anterior y recargar deja al usuario donde estaba:
//
//   /login                         inicio de sesión y registro (?registro=negocio)
//   /inicio  /mapa  /favoritos  /perfil   visitante (/perfil/editar)
//   /lugar/:id                     ficha de un lugar (?vista=previa para admin/negocio)
//   /recorrido/:nombre             recorrido 360° a pantalla completa
//   /empresa/:seccion              panel de empresa (?negocio=<id>)
//   /empresa/editar|galeria|sugerir
//   /admin/:seccion                panel admin
//   /admin/mapa/lugar/:id          un lugar dentro de "Mapa y RA"
//
// Las secciones de un panel se cambian con `go` (reemplazan la pantalla);
// las pantallas de detalle se abren con `push` (se apilan y "atrás" las
// cierra). Con sesión abierta, /login manda a la pantalla de inicio del rol,
// así que "atrás" ya no saca al usuario hasta el login.

/// Secciones del panel de empresa en la URL.
const _seccionesEmpresa = {
  'inicio': BusinessSection.dashboard,
  'perfil': BusinessSection.perfil,
  'experiencias': BusinessSection.experiencias,
  'resenas': BusinessSection.resenas,
};

String rutaEmpresa(BusinessSection seccion, {String? negocioId}) {
  final slug = _seccionesEmpresa.entries.firstWhere((e) => e.value == seccion).key;
  return Uri(path: '/empresa/$slug', queryParameters: negocioId == null ? null : {'negocio': negocioId}).toString();
}

String rutaAdmin(AdminSection seccion) => '/admin/${seccion.slug}';

String rutaLugarAdmin(String lugarId) => '/admin/mapa/lugar/${Uri.encodeComponent(lugarId)}';

/// Abre la ficha de un lugar encima de la pantalla actual.
Future<void> abrirLugar(BuildContext context, Lugar lugar, {bool vistaPrevia = false}) {
  return context.push(
    Uri(path: '/lugar/${Uri.encodeComponent(lugar.id)}', queryParameters: vistaPrevia ? {'vista': 'previa'} : null)
        .toString(),
    extra: lugar,
  );
}

/// Abre un recorrido 360° a pantalla completa.
Future<void> abrirRecorrido(BuildContext context, RecorridoPublico recorrido, {String? lugarNombre}) {
  return context.push(
    Uri(
      path: '/recorrido/${Uri.encodeComponent(recorrido.nombre)}',
      queryParameters: lugarNombre == null ? null : {'lugar': lugarNombre},
    ).toString(),
    extra: recorrido,
  );
}

/// Cierra la sesión y lleva al login (opcionalmente con un aviso o directo
/// al registro de negocio).
void cerrarSesion(BuildContext context, {String? mensaje, bool registroNegocio = false}) {
  Sesion.cerrar(mensaje: mensaje);
  context.go(registroNegocio ? '/login?registro=negocio' : '/login');
}

/// Pantalla sin animación: cambiar de sección se siente como cambiar de
/// pestaña, no como abrir otra pantalla encima.
Page<void> _sinAnimacion(GoRouterState state, Widget child, {LocalKey? key}) =>
    NoTransitionPage<void>(key: key ?? state.pageKey, child: child);

GoRouter crearRouter({AuthService? authService, String? inicial}) {
  // Con `push` también cambia la URL del navegador (por defecto go_router
  // solo la cambia con `go`).
  GoRouter.optionURLReflectsImperativeAPIs = true;

  return GoRouter(
    initialLocation: inicial ?? '/',
    refreshListenable: Sesion.usuario,
    redirect: (context, state) => _redirigir(state.matchedLocation),
    errorBuilder: (context, state) => const _RutaInvalida(),
    routes: [
      GoRoute(path: '/', redirect: (_, __) {
        final user = Sesion.usuario.value;
        return user == null ? '/login' : (rutaInicio(user) ?? '/login');
      }),
      GoRoute(
        path: '/login',
        pageBuilder: (context, state) => _sinAnimacion(
          state,
          LoginPage(
            authService: authService,
            initialError: Sesion.tomarMensaje(),
            startInBusinessRegister: state.uri.queryParameters['registro'] == 'negocio',
          ),
        ),
      ),

      // --- Visitante --------------------------------------------------------
      GoRoute(
        path: '/inicio',
        pageBuilder: (context, state) => _sinAnimacion(state, SessionGuard(child: HomePage(user: Sesion.usuario.value!))),
      ),
      GoRoute(
        path: '/mapa',
        pageBuilder: (context, state) =>
            _sinAnimacion(state, SessionGuard(child: ExplorarMapaPage(profile: Sesion.perfilVisitante))),
      ),
      GoRoute(
        path: '/favoritos',
        pageBuilder: (context, state) =>
            _sinAnimacion(state, SessionGuard(child: FavoritosPage(profile: Sesion.perfilVisitante))),
      ),
      GoRoute(
        path: '/perfil',
        pageBuilder: (context, state) =>
            _sinAnimacion(state, SessionGuard(child: ProfilePage(profile: Sesion.perfilVisitante))),
        routes: [
          GoRoute(
            path: 'editar',
            builder: (context, state) => EditProfilePage(profile: Sesion.perfilVisitante, authService: authService),
          ),
        ],
      ),
      GoRoute(
        path: '/lugar/:id',
        builder: (context, state) => _LugarPorId(
          id: state.pathParameters['id']!,
          lugar: state.extra is Lugar ? state.extra as Lugar : null,
          vistaPrevia: state.uri.queryParameters['vista'] == 'previa',
        ),
      ),
      GoRoute(
        path: '/recorrido/:nombre',
        builder: (context, state) => _RecorridoPorNombre(
          nombre: state.pathParameters['nombre']!,
          recorrido: state.extra is RecorridoPublico ? state.extra as RecorridoPublico : null,
          lugarNombre: state.uri.queryParameters['lugar'],
        ),
      ),

      // --- Empresa ----------------------------------------------------------
      GoRoute(
        path: '/empresa/editar',
        builder: (context, state) => _conNegocio(state, (n) => BusinessEditPage(business: n, authService: authService)),
      ),
      GoRoute(
        path: '/empresa/galeria',
        builder: (context, state) => _conNegocio(state, (n) => BusinessGalleryPage(business: n, authService: authService)),
      ),
      GoRoute(path: '/empresa/sugerir', builder: (context, state) => const BusinessSuggestPage()),
      GoRoute(
        path: '/empresa/:seccion',
        pageBuilder: (context, state) => _sinAnimacion(
          state,
          // Misma llave para todas las secciones: el panel (menú y negocio
          // elegido) no se vuelve a crear al cambiar de sección.
          key: const ValueKey('empresa'),
          SessionGuard(
            child: BusinessHomePage(
              user: Sesion.usuario.value!,
              seccion: _seccionesEmpresa[state.pathParameters['seccion']] ?? BusinessSection.dashboard,
              negocioId: state.uri.queryParameters['negocio'],
            ),
          ),
        ),
      ),

      // --- Admin ------------------------------------------------------------
      GoRoute(
        path: '/admin/mapa/lugar/:id',
        pageBuilder: (context, state) => _sinAnimacion(
          state,
          key: const ValueKey('admin'),
          SessionGuard(
            child: AdminDashboardPage(
              admin: Sesion.usuario.value!,
              authService: authService,
              seccion: AdminSection.mapa,
              lugarId: state.pathParameters['id'],
            ),
          ),
        ),
      ),
      GoRoute(
        path: '/admin/:seccion',
        pageBuilder: (context, state) => _sinAnimacion(
          state,
          key: const ValueKey('admin'),
          SessionGuard(
            child: AdminDashboardPage(
              admin: Sesion.usuario.value!,
              authService: authService,
              seccion: AdminSectionSlug.desdeSlug(state.pathParameters['seccion']) ?? AdminSection.inicio,
            ),
          ),
        ),
      ),
    ],
  );
}

/// Quién puede ver cada ruta. Sin sesión: solo /login. Con sesión: /login
/// lleva a su inicio, y cada panel es solo de su rol (la ficha de un lugar y
/// los recorridos los pueden abrir todos, el admin y el negocio en vista
/// previa).
String? _redirigir(String ruta) {
  final user = Sesion.usuario.value;
  if (ruta == '/') return null;
  if (user == null) return ruta == '/login' ? null : '/login';

  final inicio = rutaInicio(user);
  if (ruta == '/login') return inicio; // null = negocio en revisión: se queda viendo su estado.
  if (inicio == null) return '/login';

  if (ruta.startsWith('/lugar/') || ruta.startsWith('/recorrido/')) return null;
  if (ruta.startsWith('/admin')) return user.isAdmin ? null : inicio;
  if (ruta.startsWith('/empresa')) return user.isNegocio ? null : inicio;
  // /inicio, /mapa, /perfil: solo visitantes.
  return user.isAdmin || user.isNegocio ? inicio : null;
}

Widget _conNegocio(GoRouterState state, Widget Function(BusinessProfile negocio) pagina) {
  final negocio = Sesion.negocio(state.uri.queryParameters['negocio']) ?? Sesion.negocios.first;
  return pagina(negocio);
}

class _RutaInvalida extends StatelessWidget {
  const _RutaInvalida();

  @override
  Widget build(BuildContext context) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (context.mounted) context.go('/');
    });
    return const Scaffold(body: Center(child: CircularProgressIndicator()));
  }
}

/// Ficha de un lugar por su id. Al navegar desde la app el lugar ya viene
/// cargado; al recargar la página (o entrar con el enlace) se busca.
class _LugarPorId extends StatefulWidget {
  final String id;
  final Lugar? lugar;
  final bool vistaPrevia;

  const _LugarPorId({required this.id, this.lugar, required this.vistaPrevia});

  @override
  State<_LugarPorId> createState() => _LugarPorIdState();
}

class _LugarPorIdState extends State<_LugarPorId> {
  late Lugar? _lugar = widget.lugar;
  bool _noExiste = false;

  @override
  void initState() {
    super.initState();
    if (_lugar == null) _buscar();
  }

  Future<void> _buscar() async {
    var lugares = await const LugaresService().listarPublicos();
    try {
      lugares = [...lugares, ...lugaresDeRecorridos(await RecorridosService().listPublicos(), lugares)];
    } catch (_) {
      // Sin recorridos: solo se buscan los lugares.
    }
    if (!mounted) return;
    setState(() {
      _lugar = lugares.where((l) => l.id == widget.id).firstOrNull;
      _noExiste = _lugar == null;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_lugar != null) return LugarDetallePage(lugar: _lugar!, vistaPrevia: widget.vistaPrevia);
    return Scaffold(
      appBar: AppBar(),
      body: Center(child: _noExiste ? const Text('Este lugar ya no está disponible.') : const CircularProgressIndicator()),
    );
  }
}

/// Recorrido 360° por su nombre (mismo criterio que [_LugarPorId]).
class _RecorridoPorNombre extends StatefulWidget {
  final String nombre;
  final RecorridoPublico? recorrido;
  final String? lugarNombre;

  const _RecorridoPorNombre({required this.nombre, this.recorrido, this.lugarNombre});

  @override
  State<_RecorridoPorNombre> createState() => _RecorridoPorNombreState();
}

class _RecorridoPorNombreState extends State<_RecorridoPorNombre> {
  late RecorridoPublico? _recorrido = widget.recorrido;
  bool _noExiste = false;

  @override
  void initState() {
    super.initState();
    if (_recorrido == null) _buscar();
  }

  Future<void> _buscar() async {
    RecorridoPublico? encontrado;
    try {
      encontrado = (await RecorridosService().listPublicos()).where((r) => r.nombre == widget.nombre).firstOrNull;
    } catch (_) {}
    if (!mounted) return;
    setState(() {
      _recorrido = encontrado;
      _noExiste = encontrado == null;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_recorrido != null) return Recorrido360Page(recorrido: _recorrido!, lugarNombre: widget.lugarNombre);
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(backgroundColor: Colors.black, foregroundColor: Colors.white),
      body: Center(
        child: _noExiste
            ? const Text('Este recorrido ya no está disponible.', style: TextStyle(color: Colors.white70))
            : const CircularProgressIndicator(),
      ),
    );
  }
}
