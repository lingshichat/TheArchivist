import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import 'poster_view_data.dart';

class PosterArt extends StatelessWidget {
  const PosterArt({super.key, required this.item, this.muted = false});

  final PosterViewData item;
  final bool muted;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(AppRadii.container),
      child: Stack(
        fit: StackFit.expand,
        children: [
          DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [item.posterColor, item.posterAccentColor],
              ),
            ),
          ),
          Positioned(
            left: -18,
            top: 18,
            child: Transform.rotate(
              angle: -0.28,
              child: Container(
                width: 120,
                height: 180,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(28),
                  color: Colors.white.withValues(alpha: 0.08),
                ),
              ),
            ),
          ),
          Positioned(
            right: -10,
            top: 26,
            child: Container(
              width: 76,
              height: 76,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withValues(alpha: 0.09),
              ),
            ),
          ),
          Positioned(
            left: 18,
            right: 18,
            bottom: 18,
            child: Container(
              height: 8,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(AppRadii.pill),
                color: Colors.white.withValues(alpha: 0.16),
              ),
            ),
          ),
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
}
