import 'package:url_launcher/url_launcher.dart';

/// Abre los datos de contacto de un negocio (teléfono, sitio web, dirección)
/// en la app/pestaña correspondiente del sistema. Cada función falla en
/// silencio si el dato viene vacío o el dispositivo no puede abrir el enlace
/// (no hay ningún flujo que dependa de que esto tenga éxito).

Future<void> abrirTelefono(String telefono) async {
  final numero = telefono.trim();
  if (numero.isEmpty) return;
  // tel: tolera espacios/paréntesis tal cual los capturó el negocio.
  await _lanzar(Uri(scheme: 'tel', path: numero));
}

Future<void> abrirSitioWeb(String sitio) async {
  final texto = sitio.trim();
  if (texto.isEmpty) return;
  // El negocio suele guardarlo sin esquema (p. ej. "miweb.com.mx"); sin uno,
  // Uri.parse lo interpreta como ruta relativa y no abre nada.
  final conEsquema = RegExp(r'^https?://', caseSensitive: false).hasMatch(texto) ? texto : 'https://$texto';
  final uri = Uri.tryParse(conEsquema);
  if (uri != null) await _lanzar(uri, nuevaPestana: true);
}

Future<void> abrirDireccionEnMapa(String direccion, {double? latitud, double? longitud}) async {
  final uri = latitud != null && longitud != null
      ? Uri.parse('https://www.google.com/maps/search/?api=1&query=$latitud,$longitud')
      : direccion.trim().isEmpty
          ? null
          : Uri.parse('https://www.google.com/maps/search/?api=1&query=${Uri.encodeComponent(direccion.trim())}');
  if (uri != null) await _lanzar(uri, nuevaPestana: true);
}

Future<void> _lanzar(Uri uri, {bool nuevaPestana = false}) async {
  try {
    await launchUrl(uri, webOnlyWindowName: nuevaPestana ? '_blank' : null);
  } catch (_) {
    // Sin conexión a un manejador (tel:/sitio bloqueado, etc.) — no hay nada
    // más que hacer desde aquí.
  }
}
