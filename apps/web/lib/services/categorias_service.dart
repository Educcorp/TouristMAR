import 'dart:convert';

import 'package:http/http.dart' as http;

import 'auth_service.dart' show apiUrl, AuthError, crearClienteHttp;

/// Una categoría de negocio administrable (panel admin → Categorías).
class CategoriaNegocio {
  final String id;
  final String nombre;
  /// Cuántos negocios la usan (solo lo llena el panel admin).
  final int negocios;

  const CategoriaNegocio({required this.id, required this.nombre, this.negocios = 0});

  factory CategoriaNegocio.fromJson(Map<String, dynamic> json) => CategoriaNegocio(
        id: json['id'] as String,
        nombre: json['nombre'] as String,
        negocios: (json['negocios'] as num?)?.toInt() ?? 0,
      );
}

/// Categorías de negocio. La lista pública llena los desplegables de registro
/// y de "Editar negocio"; el admin las crea, renombra y borra.
class CategoriasService {
  CategoriasService({http.Client? client}) : _client = client ?? crearClienteHttp();

  final http.Client _client;

  /// Las que había fijas antes de que fueran administrables: se usan si el
  /// backend no responde, para que el formulario nunca quede sin opciones.
  static const respaldo = ['Playa', 'Restaurante', 'Club de playa', 'Club nocturno', 'Hotel', 'Mirador', 'Cultura', 'Recreación'];

  static List<String>? _cache;

  /// Nombres de las categorías (con caché por sesión de la app).
  Future<List<String>> nombres({bool refrescar = false}) async {
    if (_cache != null && !refrescar) return _cache!;
    try {
      final res = await _client.get(Uri.parse('$apiUrl/categorias'));
      if (res.statusCode >= 200 && res.statusCode < 300) {
        final lista = (jsonDecode(res.body)['categorias'] as List)
            .map((c) => CategoriaNegocio.fromJson(c as Map<String, dynamic>).nombre)
            .toList();
        if (lista.isNotEmpty) return _cache = lista;
      }
    } catch (_) {
      // Sin conexión: se usa el respaldo.
    }
    return respaldo;
  }

  static void olvidarCache() => _cache = null;

  Future<List<CategoriaNegocio>> listarAdmin(String token) async {
    final res = await _client.get(Uri.parse('$apiUrl/admin/categorias'), headers: _auth(token));
    final data = _decode(res, 'No se pudieron cargar las categorías');
    return (data['categorias'] as List).map((c) => CategoriaNegocio.fromJson(c as Map<String, dynamic>)).toList();
  }

  Future<void> crear(String token, String nombre) async {
    final res = await _client.post(
      Uri.parse('$apiUrl/admin/categorias'),
      headers: {..._auth(token), 'Content-Type': 'application/json'},
      body: jsonEncode({'nombre': nombre}),
    );
    _decode(res, 'No se pudo crear la categoría');
    olvidarCache();
  }

  Future<void> renombrar(String token, String id, String nombre) async {
    final res = await _client.patch(
      Uri.parse('$apiUrl/admin/categorias/$id'),
      headers: {..._auth(token), 'Content-Type': 'application/json'},
      body: jsonEncode({'nombre': nombre}),
    );
    _decode(res, 'No se pudo renombrar la categoría');
    olvidarCache();
  }

  Future<void> borrar(String token, String id) async {
    final res = await _client.delete(Uri.parse('$apiUrl/admin/categorias/$id'), headers: _auth(token));
    _decode(res, 'No se pudo borrar la categoría');
    olvidarCache();
  }

  Map<String, String> _auth(String token) => {'Authorization': 'Bearer $token'};

  Map<String, dynamic> _decode(http.Response res, String porDefecto) {
    Map<String, dynamic> data = const {};
    try {
      if (res.body.isNotEmpty) data = jsonDecode(res.body) as Map<String, dynamic>;
    } catch (_) {}
    if (res.statusCode < 200 || res.statusCode >= 300) {
      throw AuthError((data['error'] as String?) ?? porDefecto);
    }
    return data;
  }
}
