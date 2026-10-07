import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../models/lugar.dart';
import 'auth_service.dart' show apiUrl, crearClienteHttp;
import 'session_storage.dart';

/// "Mis favoritos" del visitante, guardados en el backend (`/api/favoritos`)
/// para que sean los mismos en web y móvil.
///
/// [ids] es la lista local de lugares ya marcados: los corazones de tarjetas
/// y fichas la escuchan para pintarse sin pedir nada al servidor cada vez.
/// Solo los negocios reales pueden ser favoritos (los lugares de ejemplo no
/// existen en la base de datos), ver [Lugar.esFavoritable].
class FavoritosService {
  FavoritosService._();

  static final FavoritosService instance = FavoritosService._();

  final ValueNotifier<Set<String>> ids = ValueNotifier(const {});

  late final http.Client _http = crearClienteHttp();

  bool esFavorito(String lugarId) => ids.value.contains(lugarId);

  Map<String, String> get _headers => {'Authorization': 'Bearer ${SessionStorage.token ?? ''}'};

  /// Trae los favoritos del servidor y deja [ids] al día.
  Future<List<Lugar>> listar() async {
    final res = await _http.get(Uri.parse('$apiUrl/favoritos'), headers: _headers);
    final data = _decode(res.body);
    if (res.statusCode < 200 || res.statusCode >= 300) {
      throw FavoritosError((data['error'] as String?) ?? 'No se pudieron cargar tus favoritos');
    }
    final lugares = (data['favoritos'] as List)
        .map((j) => Lugar.fromJson(j as Map<String, dynamic>))
        .toList();
    ids.value = {for (final l in lugares) l.id};
    return lugares;
  }

  /// Sincroniza [ids] sin que la interfaz tenga que manejar el error (los
  /// corazones simplemente se ven vacíos si no hay conexión o sesión).
  Future<void> cargarIds() async {
    try {
      await listar();
    } catch (_) {}
  }

  /// Marca o desmarca [lugarId]; devuelve el estado final. Actualiza [ids]
  /// de inmediato y lo revierte si el servidor rechaza el cambio.
  Future<bool> alternar(String lugarId) async {
    final marcar = !esFavorito(lugarId);
    final antes = ids.value;
    ids.value = marcar ? {...antes, lugarId} : ({...antes}..remove(lugarId));
    try {
      final uri = Uri.parse('$apiUrl/favoritos/$lugarId');
      final res = marcar ? await _http.put(uri, headers: _headers) : await _http.delete(uri, headers: _headers);
      if (res.statusCode < 200 || res.statusCode >= 300) {
        throw FavoritosError((_decode(res.body)['error'] as String?) ?? 'No se pudo actualizar tus favoritos');
      }
      return marcar;
    } catch (e) {
      ids.value = antes;
      if (e is FavoritosError) rethrow;
      throw const FavoritosError('No se pudo conectar con el servidor');
    }
  }

  Map<String, dynamic> _decode(String body) {
    try {
      return jsonDecode(body) as Map<String, dynamic>;
    } catch (_) {
      return {};
    }
  }
}

class FavoritosError implements Exception {
  final String message;
  const FavoritosError(this.message);

  @override
  String toString() => message;
}
