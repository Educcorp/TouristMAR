import '../services/auth_service.dart';

class VisitedPlace {
  final String image;
  final String category;
  final String name;
  final double rating;
  final String dateLabel;

  const VisitedPlace({
    required this.image,
    required this.category,
    required this.name,
    required this.rating,
    required this.dateLabel,
  });
}

class UserReview {
  final String placeName;
  final String dateLabel;
  final int rating;
  final String text;

  const UserReview({
    required this.placeName,
    required this.dateLabel,
    required this.rating,
    required this.text,
  });
}

class VisitorProfile {
  String name;
  String email;
  String bio;
  String? avatarUrl;
  final List<VisitedPlace> visited;
  final List<UserReview> reviews;

  VisitorProfile({
    required this.name,
    required this.email,
    this.bio = '',
    this.avatarUrl,
    List<VisitedPlace>? visited,
    List<UserReview>? reviews,
  })  : visited = visited ?? [],
        reviews = reviews ?? [];

  factory VisitorProfile.fromAuthUser(AuthUser user) {
    return VisitorProfile(
      name: user.name,
      email: user.email,
      bio: user.bio ?? '',
      avatarUrl: user.avatarUrl,
      // TODO: "visitados" y "reseñas" todavía no tienen backend — placeholder
      // hasta que exista el sistema de lugares/reseñas.
      visited: const [
        VisitedPlace(
          image: 'assets/images/place-playa-audiencia.jpg',
          category: 'Playas',
          name: 'Playa de Santiago',
          rating: 4.8,
          dateLabel: '12 ago 2026',
        ),
        VisitedPlace(
          image: 'assets/images/place-laguna-cuyutlan.jpg',
          category: 'Recreación',
          name: 'Laguna de Cuyutlán',
          rating: 4.6,
          dateLabel: '3 jul 2026',
        ),
        VisitedPlace(
          image: 'assets/images/place-cerro-vigia.jpg',
          category: 'Miradores',
          name: 'Cerro del Vigía',
          rating: 4.7,
          dateLabel: '18 jun 2026',
        ),
      ],
      reviews: const [
        UserReview(
          placeName: 'Playa de Santiago',
          dateLabel: '12 ago 2026',
          rating: 5,
          text: 'Agua cristalina y arena perfecta. Sin duda uno de los mejores '
              'rincones de Manzanillo para descansar y desconectarse.',
        ),
        UserReview(
          placeName: 'El Bigotes – Mariscos',
          dateLabel: '28 jul 2026',
          rating: 4,
          text: 'El ceviche estaba delicioso y la vista al mar es '
              'espectacular. Ambiente relajado y precios accesibles.',
        ),
      ],
    );
  }
}
