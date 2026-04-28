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
    this.memCacheWidth = 300,
    this.memCacheHeight = 450,
  });

  final String? posterUrl;
  final Widget fallback;
  final BorderRadius borderRadius;
  final BoxFit fit;
  final bool muted;
  final int? memCacheWidth;
  final int? memCacheHeight;

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
                  color: Colors.black.withValues(alpha: 0.45),
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
      fadeInDuration: const Duration(milliseconds: 80),
      memCacheWidth: memCacheWidth,
      memCacheHeight: memCacheHeight,
      maxWidthDiskCache: 600,
      maxHeightDiskCache: 900,
      placeholder: (context, url) => fallback,
      errorWidget: (context, url, error) => fallback,
    );
  }
}
