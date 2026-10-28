import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/lugar.dart';
import 'auth_service.dart' show apiUrl, AuthError, crearClienteHttp;
import 'session_storage.dart';

/// Fuente de los puntos del mapa: los negocios aprobados con pin
/// (`GET /api/lugares`). Ya no se mezclan lugares de ejemplo: si el backend
/// no responde, la lista llega vacía y la pantalla lo dice.
class LugaresService {
  const LugaresService();

  Future<List<Lugar>> listarPublicos() async {
    final cliente = crearClienteHttp();
    try {
      final res = await cliente.get(Uri.parse('$apiUrl/lugares'));
      if (res.statusCode >= 200 && res.statusCode < 300) {
        final data = jsonDecode(res.body) as Map<String, dynamic>;
        return (data['lugares'] as List)
            .map((j) => Lugar.fromJson(j as Map<String, dynamic>))
            .toList();
      }
    } catch (_) {
      // Sin conexión con el backend: el mapa queda vacío.
    } finally {
      cliente.close();
    }
    return const [];
  }

  /// Cuenta una visita a la ficha del lugar ("Visitas este mes" del panel de
  /// empresa). Si falla no pasa nada: es solo una estadística.
  Future<void> registrarVisita(String lugarId) async {
    if (!Lugar.idEsReal(lugarId)) return;
    final token = SessionStorage.token;
    final cliente = crearClienteHttp();
    try {
      await cliente.post(
        Uri.parse('$apiUrl/lugares/$lugarId/visita'),
        headers: {if (token != null) 'Authorization': 'Bearer $token'},
      );
    } catch (_) {
      // Sin conexión: la visita simplemente no se cuenta.
    } finally {
      cliente.close();
    }
  }

  /// El dueño fija el pin de su negocio.
  Future<void> guardarUbicacion(String negocioId, Coordenadas ubicacion) async {
    final token = SessionStorage.token;
    if (token == null) throw const AuthError('Tu sesión expiró. Vuelve a iniciar sesión.');
    final cliente = crearClienteHttp();
    final http.Response res;
    try {
      res = await cliente.patch(
        Uri.parse('$apiUrl/auth/profile/negocios/$negocioId'),
        headers: {'Content-Type': 'application/json', 'Authorization': 'Bearer $token'},
        body: jsonEncode({'latitud': ubicacion.lat, 'longitud': ubicacion.lng}),
      );
    } finally {
      cliente.close();
    }
    if (res.statusCode < 200 || res.statusCode >= 300) {
      String? motivo;
      try {
        motivo = (jsonDecode(res.body) as Map<String, dynamic>)['error'] as String?;
      } catch (_) {}
      throw AuthError(motivo == null ? 'No se pudo guardar la ubicación' : 'No se pudo guardar la ubicación: $motivo');
    }
  }

}
