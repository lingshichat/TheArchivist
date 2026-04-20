import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../widgets/category_view_data.dart';
import '../widgets/poster_view_data.dart';
import 'app_database.dart';
import 'daos/media_dao.dart';

abstract final class LocalViewAdapters {
  static PosterViewData toPosterView(
    MediaItemWithUserEntry item, {
    String? mediaLabelOverride,
    String? subtitleOverride,
    String? statusLabelOverride,
    String? yearOverride,
  }) {
    final palette = _paletteFor(item.mediaItem.mediaType, item.mediaItem.title);

    return PosterViewData(
      id: item.mediaItem.id,
      title: item.mediaItem.title,
      mediaLabel:
          mediaLabelOverride ?? mediaTypeLabel(item.mediaItem.mediaType),
      posterColor: palette.background,
      posterAccentColor: palette.foreground,
      subtitle: subtitleOverride ?? item.mediaItem.subtitle,
      year: yearOverride ?? yearLabel(item.mediaItem.releaseDate),
      statusLabel: statusLabelOverride ?? statusLabel(item.userEntry?.status),
      statusTone: statusTone(item.userEntry?.status),
    );
  }

  static String mediaTypeLabel(MediaType type) {
    switch (type) {
      case MediaType.movie:
        return 'Movie';
      case MediaType.tv:
        return 'TV';
      case MediaType.book:
        return 'Book';
      case MediaType.game:
        return 'Game';
    }
  }

  static String statusLabel(UnifiedStatus? status) {
    switch (status ?? UnifiedStatus.wishlist) {
      case UnifiedStatus.wishlist:
        return 'Wishlist';
      case UnifiedStatus.inProgress:
        return 'In Progress';
      case UnifiedStatus.done:
        return 'Completed';
      case UnifiedStatus.onHold:
        return 'On Hold';
      case UnifiedStatus.dropped:
        return 'Dropped';
    }
  }

  static PosterStatusTone statusTone(UnifiedStatus? status) {
    switch (status ?? UnifiedStatus.wishlist) {
      case UnifiedStatus.inProgress:
        return PosterStatusTone.primary;
      case UnifiedStatus.done:
        return PosterStatusTone.secondary;
      case UnifiedStatus.wishlist:
        return PosterStatusTone.tertiary;
      case UnifiedStatus.onHold:
      case UnifiedStatus.dropped:
        return PosterStatusTone.muted;
    }
  }

  static String? yearLabel(DateTime? releaseDate) {
    if (releaseDate == null) {
      return null;
    }

    return releaseDate.year.toString();
  }

  static String buildProgressSummary(MediaItem item, ProgressEntry? progress) {
    switch (item.mediaType) {
      case MediaType.tv:
        final current = progress?.currentEpisode;
        if (current == null) {
          return 'Episode progress not set';
        }

        if (item.totalEpisodes != null) {
          return 'Episode $current / ${item.totalEpisodes}';
        }

        return 'Episode $current';
      case MediaType.book:
        final current = progress?.currentPage;
        if (current == null) {
          return 'Page progress not set';
        }

        if (item.totalPages != null) {
          return 'Page $current / ${item.totalPages}';
        }

        return 'Page $current';
      case MediaType.movie:
        final current = progress?.currentMinutes;
        if (current == null) {
          return 'Runtime progress not set';
        }

        if (item.runtimeMinutes != null) {
          return '${current.round()} / ${item.runtimeMinutes} min';
        }

        return '${current.round()} min';
      case MediaType.game:
        final current = progress?.currentMinutes;
        if (current == null) {
          return 'Playtime not set';
        }

        final currentHours = current / 60;
        if (item.estimatedPlayHours != null) {
          return '${currentHours.toStringAsFixed(1)} / ${item.estimatedPlayHours!.toStringAsFixed(1)} h';
        }

        return '${currentHours.toStringAsFixed(1)} h';
    }
  }

  static double buildProgressRatio(MediaItem item, ProgressEntry? progress) {
    if (progress?.completionRatio != null) {
      return (progress!.completionRatio!).clamp(0, 1);
    }

    switch (item.mediaType) {
      case MediaType.tv:
        if (progress?.currentEpisode == null ||
            item.totalEpisodes == null ||
            item.totalEpisodes == 0) {
          return 0;
        }

        return (progress!.currentEpisode! / item.totalEpisodes!).clamp(0, 1);
      case MediaType.book:
        if (progress?.currentPage == null ||
            item.totalPages == null ||
            item.totalPages == 0) {
          return 0;
        }

        return (progress!.currentPage! / item.totalPages!).clamp(0, 1);
      case MediaType.movie:
        if (progress?.currentMinutes == null ||
            item.runtimeMinutes == null ||
            item.runtimeMinutes == 0) {
          return 0;
        }

        return (progress!.currentMinutes! / item.runtimeMinutes!).clamp(0, 1);
      case MediaType.game:
        if (progress?.currentMinutes == null ||
            item.estimatedPlayHours == null ||
            item.estimatedPlayHours == 0) {
          return 0;
        }

        return ((progress!.currentMinutes! / 60) / item.estimatedPlayHours!)
            .clamp(0, 1);
    }
  }

  static String formatDateTime(DateTime value) {
    const months = <String>[
      'JAN',
      'FEB',
      'MAR',
      'APR',
      'MAY',
      'JUN',
      'JUL',
      'AUG',
      'SEP',
      'OCT',
      'NOV',
      'DEC',
    ];

    final hour = value.hour == 0
        ? 12
        : (value.hour > 12 ? value.hour - 12 : value.hour);
    final minute = value.minute.toString().padLeft(2, '0');
    final suffix = value.hour >= 12 ? 'PM' : 'AM';

    return '${value.day.toString().padLeft(2, '0')} ${months[value.month - 1]} ${value.year} — ${hour.toString().padLeft(2, '0')}:$minute $suffix';
  }

  static CategoryViewData buildCategory({
    required String label,
    required int count,
    required IconData icon,
    required Color accentColor,
  }) {
    return CategoryViewData(
      label: label,
      description: '$count items in archive',
      itemCount: '$count',
      icon: icon,
      accentColor: accentColor,
    );
  }

  static String archiveIdLabel(String id) {
    final shortId = id.length <= 8 ? id : id.substring(0, 8);
    return 'ID: ${shortId.toUpperCase()}';
  }

  static _PosterPalette _paletteFor(MediaType type, String title) {
    const palettes = <_PosterPalette>[
      _PosterPalette(
        background: Color(0xFF36505B),
        foreground: Color(0xFF121417),
      ),
      _PosterPalette(
        background: Color(0xFF795746),
        foreground: Color(0xFF171312),
      ),
      _PosterPalette(
        background: Color(0xFF4B6A63),
        foreground: Color(0xFF111414),
      ),
      _PosterPalette(
        background: Color(0xFF6B8797),
        foreground: Color(0xFF0E1215),
      ),
      _PosterPalette(
        background: Color(0xFF6A4311),
        foreground: Color(0xFF140C06),
      ),
      _PosterPalette(
        background: Color(0xFF6B6F3C),
        foreground: Color(0xFF111207),
      ),
    ];

    final typeBias = switch (type) {
      MediaType.movie => 0,
      MediaType.tv => 1,
      MediaType.book => 2,
      MediaType.game => 3,
    };
    final seed = title.codeUnits.fold<int>(typeBias, (sum, unit) => sum + unit);
    return palettes[math.max(0, seed % palettes.length)];
  }
}

class _PosterPalette {
  const _PosterPalette({required this.background, required this.foreground});

  final Color background;
  final Color foreground;
}
