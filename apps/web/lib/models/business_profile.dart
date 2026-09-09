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

  factory BusinessProfile.mock({
    String? businessName,
    String? email,
    String? category,
  }) {
    return BusinessProfile(
      businessName: (businessName == null || businessName.trim().isEmpty)
          ? 'Playa Audiencia Resort & Bar'
          : businessName,
      ownerName: 'Sofía Mendoza',
      email: (email == null || email.trim().isEmpty)
          ? 'contacto@playaaudiencia.mx'
          : email,
      category: (category == null || category.trim().isEmpty)
          ? 'Playa · Bar · Restaurante'
          : category,
      description: 'Un oasis frente al Pacífico. Ofrecemos snorkel, kayak, '
          'sillas de playa, bar de mariscos y acceso directo al mar más azul '
          'de Manzanillo. Reservaciones y eventos especiales disponibles '
          'todo el año.',
      coverImage: 'assets/images/place-playa-audiencia.jpg',
      gallery: const [
        'assets/images/place-playa-audiencia.jpg',
        'assets/images/place-cerro-vigia.jpg',
        'assets/images/place-laguna-cuyutlan.jpg',
      ],
      rating: 4.9,
      totalReviews: 124,
      monthlyVisits: 1243,
      newReviews: 23,
      favorites: 89,
      phone: '+52 314 123 4567',
      website: 'playaaudiencia.com.mx',
      address: 'Av. de los Cocoteros 42, Manzanillo, Col. 28219',
      hours: 'Lun – Dom: 8:00 am – 8:00 pm',
      verified: true,
    );
  }
}
