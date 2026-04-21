import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

class PosterImage extends StatelessWidget {
  const PosterImage({
    super.key,
    required this.posterUrl,
    required this.fallback,
    this.borderRadius = BorderRadius.zero,
    this.fit = BoxFit.cover,
    this.muted = false,
  });

  final String? posterUrl;
  final Widget fallback;
  final BorderRadius borderRadius;
  final BoxFit fit;
  final bool muted;

  @override
  Widget build(BuildContext context) {
    final normalizedPosterUrl = posterUrl?.trim();

    return ClipRRect(
      borderRadius: borderRadius,
      child: Stack(
        fit: StackFit.expand,
        children: [
          _buildImageLayer(normalizedPosterUrl),
          if (muted)
            Positioned.fill(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.42),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildImageLayer(String? normalizedPosterUrl) {
    if (normalizedPosterUrl == null || normalizedPosterUrl.isEmpty) {
      return fallback;
    }

    return CachedNetworkImage(
      imageUrl: normalizedPosterUrl,
      fit: fit,
      fadeInDuration: const Duration(milliseconds: 180),
      placeholder: (context, url) => fallback,
      errorWidget: (context, url, error) => fallback,
    );
  }
}
