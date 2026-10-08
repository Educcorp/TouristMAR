import '../services/auth_service.dart';
import '../services/resenas_service.dart';
import 'horario.dart';

class BusinessProfile {
  final String id;
  String businessName;
  String ownerName;
  String email;
  String category;
  String description;
  String coverImage;
  List<String> gallery;
  double rating;
  int totalReviews;
  int monthlyVisits;
  int newReviews;
  int favorites;
  String phone;
  String website;
  String address;
  String hours;
  bool verified;
  String estado;
  String? archivo360;
  String? arMarcador;
  String? arGeo;
  /// Pin del negocio en el mapa público (null = todavía sin ubicar).
  double? latitud;
  double? longitud;

  BusinessProfile({
    required this.id,
    required this.businessName,
    required this.ownerName,
    required this.email,
    required this.category,
    required this.description,
    required this.coverImage,
    required this.gallery,
    required this.rating,
    required this.totalReviews,
    required this.monthlyVisits,
    required this.newReviews,
    required this.favorites,
    required this.phone,
    required this.website,
    required this.address,
    required this.hours,
    required this.verified,
    required this.estado,
    this.archivo360,
    this.arMarcador,
    this.arGeo,
    this.latitud,
    this.longitud,
  });

  /// Portada que se pone cuando el negocio todavía no sube la suya.
  /// Sin portada: [CoverImage] pinta el casco vacío en lugar de una foto ajena.
  static const portadaPredeterminada = '';

  /// Lo que le falta a la ficha del negocio para estar completa (lo que ve
  /// el visitante). Mientras falte algo, al entrar al panel de empresa sale
  /// el aviso obligatorio "Completa la información de tu negocio".
  List<String> get datosFaltantes => [
        if (businessName.trim().isEmpty) 'Nombre del negocio',
        if (category.trim().isEmpty) 'Categoría',
        if (description.trim().isEmpty) 'Descripción',
        if (coverImage.trim().isEmpty || coverImage.startsWith('assets/')) 'Foto de portada',
        if (address.trim().isEmpty) 'Dirección',
        if (latitud == null || longitud == null) 'Ubicación en el mapa',
        if (phone.replaceAll(RegExp(r'[^0-9]'), '').length < 7) 'Teléfono',
        // Un horario escrito a mano antes del selector de días y horas
        // también cuenta como pendiente: se tiene que volver a elegir.
        if (!(HorarioSemanal.parse(hours)?.algunDiaAbierto ?? false)) 'Horario (días y horas)',
      ];

  bool get informacionCompleta => datosFaltantes.isEmpty;

  /// Trae las reseñas reales de este negocio y deja al día la calificación
  /// promedio, el total y las reseñas del último mes. Devuelve null si no se
  /// pudo (sin conexión): se conserva lo que ya había.
  Future<ResenasLugar?> cargarResenas([ResenasService? service]) async {
    try {
      final datos = await (service ?? ResenasService()).listarDeLugar(id);
      rating = datos.resumen.promedio;
      totalReviews = datos.resumen.total;
      final hace30Dias = DateTime.now().subtract(const Duration(days: 30));
      newReviews = datos.resenas.where((r) => r.createdAt.isAfter(hace30Dias)).length;
      return datos;
    } on ResenasError {
      return null;
    }
  }

  /// Un negocio puntual de una cuenta (una cuenta puede tener varios). Las
  /// estadísticas de visitas y favoritos aún no existen como feature en el
  /// backend (se muestran en cero en vez de datos inventados); la calificación
  /// y las reseñas se completan con [cargarResenas].
  factory BusinessProfile.fromNegocioInfo(AuthUser user, NegocioInfo negocio) {
    return BusinessProfile(
      id: negocio.id,
      businessName: negocio.nombre,
      ownerName: user.name,
      email: user.email,
      category: negocio.categoria ?? '',
      description: negocio.descripcion ?? '',
      coverImage: negocio.portada ?? portadaPredeterminada,
      gallery: negocio.galeria,
      rating: 0,
      totalReviews: 0,
      monthlyVisits: 0,
      newReviews: 0,
      favorites: 0,
      phone: negocio.telefono ?? '',
      website: negocio.sitioWeb ?? '',
      address: negocio.direccion ?? '',
      hours: negocio.horario ?? '',
      verified: negocio.aprobado,
      estado: negocio.estado,
      archivo360: negocio.archivo360,
      arMarcador: negocio.arMarcador,
      arGeo: negocio.arGeo,
      latitud: negocio.latitud,
      longitud: negocio.longitud,
    );
  }
}
