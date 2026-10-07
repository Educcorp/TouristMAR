import 'package:flutter/material.dart';

import '../services/auth_service.dart';
import '../theme/app_theme.dart';

/// Las tres experiencias inmersivas que puede ofrecer un lugar. El orden del
/// enum es el orden en que se muestran en la ficha.
enum ExperienciaTipo { arMarcador, arGeo, recorrido360 }

/// Estado de una experiencia vista desde el visitante.
enum ExperienciaEstado {
  /// El negocio todavía no subió el recurso — la tarjeta se muestra apagada.
  noDisponible,

  /// Existe pero requiere algo del visitante (estar en el lugar físico).
  bloqueada,

  /// Lista para abrirse.
  disponible,
}

/// Estado del recurso visto desde el negocio/admin (quién lo subió y si ya
/// se revisó). Todavía no existe en el backend: hoy solo se sabe si la URL
/// está o no (ver [Lugar.fromNegocioInfo]).
enum RecursoEstado { sinArchivo, enRevision, publicado, rechazado }

class ExperienciaInfo {
  final ExperienciaTipo tipo;
  final String titulo;
  final String tituloCorto;
  final String descripcion;
  final IconData icon;

  const ExperienciaInfo._(this.tipo, this.titulo, this.tituloCorto, this.descripcion, this.icon);

  /// Color de acento por tipo — getter porque [AppColors] depende del tema.
  Color get color => switch (tipo) {
        ExperienciaTipo.arMarcador => AppColors.brandTeal,
        ExperienciaTipo.arGeo => AppColors.emerald,
        ExperienciaTipo.recorrido360 => AppColors.oceanBlue,
      };

  static ExperienciaInfo of(ExperienciaTipo tipo) => switch (tipo) {
        ExperienciaTipo.arMarcador => const ExperienciaInfo._(
            ExperienciaTipo.arMarcador,
            'Realidad aumentada con marcador',
            'RA marcador',
            'Apunta la cámara al marcador del lugar y mira el contenido 3D sobre él.',
            Icons.qr_code_scanner,
          ),
        ExperienciaTipo.arGeo => const ExperienciaInfo._(
            ExperienciaTipo.arGeo,
            'RA por geolocalización',
            'RA geo',
            'Acércate al lugar: verás su información flotando en la cámara y, al llegar, la guía completa.',
            Icons.explore_outlined,
          ),
        ExperienciaTipo.recorrido360 => const ExperienciaInfo._(
            ExperienciaTipo.recorrido360,
            'Recorrido 3D / 360°',
            'Recorrido 360°',
            'Explora el lugar desde donde estés, en 360 grados.',
            Icons.threesixty,
          ),
      };
}

class Coordenadas {
  final double lat;
  final double lng;

  const Coordenadas(this.lat, this.lng);

  @override
  String toString() => '${lat.toStringAsFixed(5)}, ${lng.toStringAsFixed(5)}';
}

/// Centro de referencia del mapa (bahía de Manzanillo).
const centroManzanillo = Coordenadas(19.0800, -104.3150);

/// Categorías conocidas para el mapa. En el backend `categoria` es texto
/// libre, así que [CategoriaLugar.detectar] lo normaliza por palabra clave.
enum CategoriaLugar { playa, mirador, restaurante, hotel, recreacion, cultura, otro }

extension CategoriaLugarX on CategoriaLugar {
  String get etiqueta => switch (this) {
        CategoriaLugar.playa => 'Playas',
        CategoriaLugar.mirador => 'Miradores',
        CategoriaLugar.restaurante => 'Restaurantes',
        CategoriaLugar.hotel => 'Hospedaje',
        CategoriaLugar.recreacion => 'Recreación',
        CategoriaLugar.cultura => 'Cultura',
        CategoriaLugar.otro => 'Otros',
      };

  IconData get icon => switch (this) {
        CategoriaLugar.playa => Icons.beach_access_outlined,
        CategoriaLugar.mirador => Icons.landscape_outlined,
        CategoriaLugar.restaurante => Icons.restaurant_outlined,
        CategoriaLugar.hotel => Icons.hotel_outlined,
        CategoriaLugar.recreacion => Icons.kayaking_outlined,
        CategoriaLugar.cultura => Icons.museum_outlined,
        CategoriaLugar.otro => Icons.place_outlined,
      };

  Color get color => switch (this) {
        CategoriaLugar.playa => AppColors.brandTeal,
        CategoriaLugar.mirador => AppColors.emerald,
        CategoriaLugar.restaurante => AppColors.orange,
        CategoriaLugar.hotel => AppColors.adminViolet,
        CategoriaLugar.recreacion => AppColors.oceanBlue,
        CategoriaLugar.cultura => AppColors.amber,
        CategoriaLugar.otro => AppColors.slate400,
      };
}

class CategoriaLugarDetector {
  CategoriaLugarDetector._();

  static const _claves = {
    CategoriaLugar.playa: ['playa', 'beach'],
    CategoriaLugar.mirador: ['mirador', 'cerro', 'vista'],
    CategoriaLugar.restaurante: ['restaur', 'comida', 'mariscos', 'bar', 'café', 'cafe', 'cocina'],
    CategoriaLugar.hotel: ['hotel', 'hosped', 'hostal', 'posada', 'resort'],
    CategoriaLugar.recreacion: ['recrea', 'laguna', 'buceo', 'tour', 'parque', 'aventura', 'nocturno', 'antro'],
    CategoriaLugar.cultura: ['cultur', 'museo', 'monumento', 'histór', 'histor', 'arte'],
  };

  static CategoriaLugar detectar(String? texto) {
    final t = (texto ?? '').toLowerCase();
    for (final entry in _claves.entries) {
      if (entry.value.any(t.contains)) return entry.key;
    }
    return CategoriaLugar.otro;
  }
}

/// Un punto del mapa público: un negocio aprobado (o un atractivo general
/// del destino) con su ubicación y sus experiencias inmersivas.
class Lugar {
  final String id;
  final String nombre;
  final String categoriaTexto;
  final String descripcion;
  final String? direccion;
  final String? horario;
  final String? telefono;
  final String portada;
  final List<String> galeria;
  final double rating;
  final int totalResenas;

  /// `null` mientras el negocio no haya fijado su punto en el mapa (el
  /// backend todavía no tiene columnas de latitud/longitud).
  final Coordenadas? ubicacion;

  /// URLs de los recursos tal como las guarda `negocio_profiles`.
  final String? archivo360;
  final String? arMarcador;
  final String? arGeo;

  /// Radio visible (metros) de la RA por geolocalización: dentro de él la
  /// cámara ya muestra el marcador flotante. Cada punto de interés trae el
  /// suyo (ver [PuntoRaGeo]); este es el del pin del lugar.
  final double radioDesbloqueo;

  const Lugar({
    required this.id,
    required this.nombre,
    required this.categoriaTexto,
    this.descripcion = '',
    this.direccion,
    this.horario,
    this.telefono,
    required this.portada,
    this.galeria = const [],
    this.rating = 0,
    this.totalResenas = 0,
    this.ubicacion,
    this.archivo360,
    this.arMarcador,
    this.arGeo,
    this.radioDesbloqueo = 100,
  });

  static final _uuid = RegExp(r'^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$', caseSensitive: false);

  /// Solo los negocios reales (id UUID) existen en la base de datos; los
  /// lugares de ejemplo (`demo-…`) no se pueden guardar como favoritos.
  bool get esFavoritable => idEsReal(id);

  static bool idEsReal(String id) => _uuid.hasMatch(id);

  CategoriaLugar get categoria => CategoriaLugarDetector.detectar(categoriaTexto);

  bool tiene(ExperienciaTipo tipo) => switch (tipo) {
        ExperienciaTipo.arMarcador => arMarcador != null,
        ExperienciaTipo.arGeo => arGeo != null,
        ExperienciaTipo.recorrido360 => archivo360 != null,
      };

  bool get tieneExperiencias => ExperienciaTipo.values.any(tiene);

  int get totalExperiencias => ExperienciaTipo.values.where(tiene).length;

  /// Un lugar tal como lo devuelven `GET /api/lugares` y `GET /api/favoritos`:
  /// los datos del negocio más su calificación real (`rating`, `totalResenas`).
  factory Lugar.fromJson(Map<String, dynamic> json) => Lugar.fromNegocioInfo(
        NegocioInfo.fromJson(json),
        rating: (json['rating'] as num?)?.toDouble() ?? 0,
        totalResenas: (json['totalResenas'] as num?)?.toInt() ?? 0,
      );

  factory Lugar.fromNegocioInfo(NegocioInfo negocio, {Coordenadas? ubicacion, double rating = 0, int totalResenas = 0}) => Lugar(
        rating: rating,
        totalResenas: totalResenas,
        id: negocio.id,
        nombre: negocio.nombre,
        categoriaTexto: negocio.categoria ?? '',
        descripcion: negocio.descripcion ?? '',
        direccion: negocio.direccion,
        horario: negocio.horario,
        telefono: negocio.telefono,
        portada: negocio.portada ?? 'assets/images/place-playa-audiencia.jpg',
        galeria: negocio.galeria,
        ubicacion: ubicacion ??
            (negocio.latitud != null && negocio.longitud != null
                ? Coordenadas(negocio.latitud!, negocio.longitud!)
                : null),
        archivo360: negocio.archivo360,
        arMarcador: negocio.arMarcador,
        arGeo: negocio.arGeo,
      );
}
