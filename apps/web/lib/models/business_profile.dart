import '../services/auth_service.dart';

class BusinessReview {
  final String author;
  final String initials;
  final int rating;
  final String dateLabel;
  final String text;

  const BusinessReview({
    required this.author,
    required this.initials,
    required this.rating,
    required this.dateLabel,
    required this.text,
  });
}

const businessReviews = <BusinessReview>[
  BusinessReview(
    author: 'Carlos M.',
    initials: 'CM',
    rating: 5,
    dateLabel: '8 sep 2026',
    text: 'Un lugar increíble, el agua está perfecta y el servicio es de '
        'primera. Sin duda el mejor spot de la ciudad.',
  ),
  BusinessReview(
    author: 'Laura P.',
    initials: 'LP',
    rating: 4,
    dateLabel: '5 sep 2026',
    text: 'Las instalaciones están muy bien mantenidas. El ceviche del bar '
        'es delicioso, volvería solo por eso.',
  ),
  BusinessReview(
    author: 'Rodrigo T.',
    initials: 'RT',
    rating: 5,
    dateLabel: '1 sep 2026',
    text: 'Mejor playa de Manzanillo sin duda. Volveré con la familia el '
        'próximo puente.',
  ),
];

class BusinessProfile {
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

  BusinessProfile({
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
  });

  /// Perfil real de negocio devuelto por el backend. Las estadísticas
  /// (calificación, visitas, reseñas, favoritos) aún no existen como feature
  /// en el backend, así que se muestran en cero en vez de datos inventados.
  factory BusinessProfile.fromAuthUser(AuthUser user) {
    final negocio = user.negocio;
    return BusinessProfile(
      businessName: negocio?.nombre ?? user.name,
      ownerName: user.name,
      email: user.email,
      category: negocio?.categoria ?? '',
      description: negocio?.descripcion ?? '',
      coverImage: negocio?.portada ?? 'assets/images/place-playa-audiencia.jpg',
      gallery: const [],
      rating: 0,
      totalReviews: 0,
      monthlyVisits: 0,
      newReviews: 0,
      favorites: 0,
      phone: negocio?.telefono ?? '',
      website: negocio?.sitioWeb ?? '',
      address: negocio?.direccion ?? '',
      hours: negocio?.horario ?? '',
      verified: negocio?.aprobado ?? false,
    );
  }

}
