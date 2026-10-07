import '../services/auth_service.dart';
import '../services/resenas_service.dart';

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

  /// Respuesta del negocio, si la hay.
  final String? reply;

  const UserReview({
    required this.placeName,
    required this.dateLabel,
    required this.rating,
    required this.text,
    this.reply,
  });

  factory UserReview.fromMiResena(MiResena r) => UserReview(
        placeName: r.lugarNombre,
        dateLabel: r.fecha,
        rating: r.estrellas,
        text: r.comentario ?? '',
        reply: r.respuesta,
      );
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

  /// Trae las reseñas reales del usuario (`GET /api/resenas/mias`). Si falla
  /// (sin conexión, sesión vencida) se conservan las que ya había.
  Future<void> cargarResenas([ResenasService? service]) async {
    try {
      final mias = await (service ?? ResenasService()).mias();
      reviews
        ..clear()
        ..addAll(mias.map(UserReview.fromMiResena));
    } on ResenasError {
      // Se queda con lo que había.
    }
  }

  /// Promedio de las estrellas que el usuario ha dado (null si no ha reseñado).
  double? get promedioDadas =>
      reviews.isEmpty ? null : reviews.fold<int>(0, (suma, r) => suma + r.rating) / reviews.length;

  factory VisitorProfile.fromAuthUser(AuthUser user) {
    return VisitorProfile(
      name: user.name,
      email: user.email,
      bio: user.bio ?? '',
      avatarUrl: user.avatarUrl,
      // TODO: "visitados" todavía no tiene backend — placeholder. Las reseñas
      // son reales: se cargan con [cargarResenas].
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
    );
  }
}
