import 'package:flutter/material.dart';

/// Muestra una foto de portada que puede ser un asset local (mock/default)
/// o una URL real subida a Supabase Storage.
class CoverImage extends StatelessWidget {
  final String source;
  final BoxFit fit;

  const CoverImage({super.key, required this.source, this.fit = BoxFit.cover});

  @override
  Widget build(BuildContext context) {
    if (source.startsWith('http')) {
      return Image.network(source, fit: fit);
    }
    return Image.asset(source, fit: fit);
  }
}
