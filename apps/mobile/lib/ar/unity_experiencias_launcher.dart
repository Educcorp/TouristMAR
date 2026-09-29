import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:touristmar_web/models/lugar.dart';
import 'package:touristmar_web/services/auth_service.dart' show apiUrl;
import 'package:touristmar_web/services/experiencias_launcher.dart';

import 'selector_experiencia.dart';

/// Abre las experiencias del módulo de Unity (una pantalla nativa aparte, ver
/// android/app/src/main/kotlin/.../MainActivity.kt). El módulo trae las tres
/// como escenas y la escena "Arranque" abre la que se le pida:
///
/// - RA con marcador: Unity baja todos los marcadores de GET /api/marcadores y
///   reconoce cualquiera, así que no necesita saber de qué lugar se abrió.
/// - Recorrido 360°: se le pasa el nombre del recorrido (GET /api/recorridos).
/// - RA por ubicación: se le pasa el nombre de la playa (lista fija en Unity,
///   ControladorPlayas.cs; el propio visor mide la distancia).
class UnityExperienciasLauncher implements ExperienciasLauncher {
  static const _canal = MethodChannel('touristmar/ar');

  final bool _unityIncluido;

  UnityExperienciasLauncher._(this._unityIncluido);

  /// Pregunta a Android si este build trae el módulo de Unity.
  static Future<UnityExperienciasLauncher> crear() async {
    bool incluido;
    try {
      incluido = await _canal.invokeMethod<bool>('disponible') ?? false;
    } on MissingPluginException {
      incluido = false; // iOS / escritorio: todavía sin módulo de Unity
    }
    return UnityExperienciasLauncher._(incluido);
  }

  @override
  bool soporta(ExperienciaTipo tipo) => _unityIncluido;

  @override
  bool mideDistancia(ExperienciaTipo tipo) => _unityIncluido && tipo == ExperienciaTipo.arGeo;

  @override
  Future<void> abrir(BuildContext context, Lugar lugar, ExperienciaTipo tipo) async {
    if (!soporta(tipo)) throw ExperienciaNoConfigurada(tipo);
    switch (tipo) {
      case ExperienciaTipo.arMarcador:
        await _abrirUnity('marcadores');
      case ExperienciaTipo.recorrido360:
        final recorrido = await _elegirRecorrido(context, lugar);
        if (recorrido != null) await _abrirUnity('recorrido', recorrido);
      case ExperienciaTipo.arGeo:
        final playa = await _elegirPlaya(context, lugar);
        if (playa != null) await _abrirUnity('geo', playa);
    }
  }

  Future<void> _abrirUnity(String escena, [String parametro = '']) async {
    try {
      await _canal.invokeMethod<void>('abrir', {'escena': escena, 'parametro': parametro});
    } on PlatformException catch (e) {
      throw ExperienciaError(e.message ?? 'No se pudo abrir la experiencia.');
    }
  }

  /// El recorrido asignado al lugar (por negocioId o por nombre); si no hay
  /// uno, el visitante elige de la lista de recorridos publicados.
  Future<String?> _elegirRecorrido(BuildContext context, Lugar lugar) async {
    final List<Map<String, dynamic>> recorridos;
    try {
      final res = await http.get(Uri.parse('$apiUrl/recorridos'));
      if (res.statusCode != 200) throw const FormatException();
      recorridos = ((jsonDecode(res.body) as Map<String, dynamic>)['recorridos'] as List).cast<Map<String, dynamic>>();
    } catch (_) {
      throw const ExperienciaError('No se pudieron cargar los recorridos 360°. Revisa tu conexión.');
    }
    if (recorridos.isEmpty) throw const ExperienciaError('Todavía no hay recorridos 360° publicados.');

    final propio = recorridos.where((r) =>
        (r['negocioId'] as String? ?? '') == lugar.id || normalizarNombre(r['nombre'] as String? ?? '') == normalizarNombre(lugar.nombre));
    if (propio.isNotEmpty) return propio.first['nombre'] as String;

    if (!context.mounted) return null;
    return mostrarSelectorExperiencia(
      context,
      titulo: 'Elige un recorrido 360°',
      subtitulo: '${lugar.nombre} todavía no tiene un recorrido propio. Puedes ver cualquiera de estos:',
      icono: Icons.threesixty,
      opciones: [
        for (final r in recorridos)
          OpcionExperiencia(
            valor: r['nombre'] as String,
            titulo: _primeraLinea(r['textoParaMostrar'] as String?) ?? r['nombre'] as String,
            detalle: '${(r['escenas'] as List?)?.length ?? 0} fotos 360°',
            imagenUrl: r['urlPortada'] as String?,
          ),
      ],
    );
  }

  /// La playa del lugar si está en la lista del módulo; si no, se elige.
  Future<String?> _elegirPlaya(BuildContext context, Lugar lugar) async {
    final propia = playaParaLugar(lugar.nombre);
    if (propia != null) return propia;
    if (!context.mounted) return null;
    return mostrarSelectorExperiencia(
      context,
      titulo: '¿Qué playa quieres explorar?',
      subtitulo: 'La realidad aumentada por ubicación está disponible en estas playas de Manzanillo:',
      icono: Icons.beach_access_outlined,
      opciones: [for (final p in playasConRA) OpcionExperiencia(valor: p, titulo: p)],
    );
  }

  static String? _primeraLinea(String? texto) {
    final linea = texto?.split('\n').first.trim();
    return (linea == null || linea.isEmpty) ? null : linea;
  }
}

/// Las playas que conoce la RA por ubicación. Espejo de `listaPlayas` en
/// ar-module ControladorPlayas.cs: los nombres tienen que coincidir EXACTO.
const playasConRA = [
  'Playa El Paraíso',
  'Cuyutlán',
  'Playa Miramar',
  'Playa los Arcos',
  'Playa Las Palmitas',
  'Playa La Boquita',
  'Playa Olas Altas',
  'Playa La Audiencia',
  'Playa Salagua',
  'Playa Las Brisas',
  'Playa Perla',
  'Playa Club de Yates',
  'Playa Azul',
  'Playa de las Quinceañeras',
  'Playa San Pedrito',
  'Playa Vida del Mar',
  'Estrecho Peña Blanca',
];

/// "Laguna de Cuyutlán" → "Cuyutlán", "Playa La Audiencia" → igual.
String? playaParaLugar(String nombreLugar) {
  final lugar = normalizarNombre(nombreLugar);
  for (final p in playasConRA) {
    final playa = normalizarNombre(p);
    if (playa == lugar || lugar.contains(playa) || playa.contains(lugar)) return p;
  }
  return null;
}

String normalizarNombre(String texto) {
  const acentos = {'á': 'a', 'é': 'e', 'í': 'i', 'ó': 'o', 'ú': 'u', 'ü': 'u', 'ñ': 'n'};
  final minusculas = texto.toLowerCase().split('').map((c) => acentos[c] ?? c).join();
  return minusculas.replaceAll(RegExp(r'^playa\s+'), '').replaceAll(RegExp(r'\s+'), ' ').trim();
}
