import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

class UserAvatar extends StatelessWidget {
  final String? imageUrl;
  final String fallbackLetter;
  final double radius;
  final Color color;

  const UserAvatar({
    super.key,
    required this.imageUrl,
    required this.fallbackLetter,
    this.radius = 16,
    this.color = AppColors.brandTeal,
  });

  @override
  Widget build(BuildContext context) {
    if (imageUrl != null && imageUrl!.isNotEmpty) {
      return CircleAvatar(
        radius: radius,
        backgroundColor: color.withOpacity(0.2),
        backgroundImage: NetworkImage(imageUrl!),
      );
    }
    return CircleAvatar(
      radius: radius,
      backgroundColor: color.withOpacity(0.2),
      child: Text(
        fallbackLetter.isNotEmpty ? fallbackLetter[0].toUpperCase() : '?',
        style: TextStyle(color: color, fontWeight: FontWeight.w700, fontSize: radius * 0.6),
      ),
    );
  }
}
