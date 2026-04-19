import 'package:flutter/material.dart';

enum DemoStatusTone { primary, secondary, tertiary, muted }

class DemoMediaItem {
  const DemoMediaItem({
    required this.title,
    required this.subtitle,
    required this.mediaLabel,
    required this.year,
    required this.statusLabel,
    required this.posterColor,
    this.posterAccentColor = const Color(0xFF111317),
    this.statusTone = DemoStatusTone.secondary,
  });

  final String title;
  final String subtitle;
  final String mediaLabel;
  final String year;
  final String statusLabel;
  final Color posterColor;
  final Color posterAccentColor;
  final DemoStatusTone statusTone;
}

class DemoMediaCategory {
  const DemoMediaCategory({
    required this.label,
    required this.description,
    required this.itemCount,
    required this.icon,
    required this.accentColor,
  });

  final String label;
  final String description;
  final String itemCount;
  final IconData icon;
  final Color accentColor;
}

abstract final class DemoData {
  static const List<DemoMediaItem> continuingItems = [
    DemoMediaItem(
      title: 'Neon Genesis: Revisited',
      subtitle: 'Episode 12',
      mediaLabel: 'Watching',
      year: '2024',
      statusLabel: 'Continue',
      posterColor: Color(0xFF36505B),
      posterAccentColor: Color(0xFF121417),
      statusTone: DemoStatusTone.primary,
    ),
    DemoMediaItem(
      title: 'The Midnight Library',
      subtitle: 'Page 184',
      mediaLabel: 'Reading',
      year: '2020',
      statusLabel: 'Continue',
      posterColor: Color(0xFF795746),
      posterAccentColor: Color(0xFF171312),
      statusTone: DemoStatusTone.primary,
    ),
  ];

  static const List<DemoMediaItem> recentlyAddedItems = [
    DemoMediaItem(
      title: 'Stille Nacht',
      subtitle: 'A winter chamber piece',
      mediaLabel: 'Movie',
      year: '2024',
      statusLabel: 'New',
      posterColor: Color(0xFF24272C),
      posterAccentColor: Color(0xFF08090A),
    ),
    DemoMediaItem(
      title: 'Circle of Being',
      subtitle: 'Collected essays',
      mediaLabel: 'Book',
      year: '2021',
      statusLabel: 'New',
      posterColor: Color(0xFF564743),
      posterAccentColor: Color(0xFF191516),
    ),
    DemoMediaItem(
      title: 'Wilderlands',
      subtitle: 'Third expedition build',
      mediaLabel: 'Game',
      year: '2024',
      statusLabel: 'New',
      posterColor: Color(0xFF7D7458),
      posterAccentColor: Color(0xFF171514),
    ),
    DemoMediaItem(
      title: 'Road to Nowhere',
      subtitle: 'Slow cinema archive',
      mediaLabel: 'Movie',
      year: '2023',
      statusLabel: 'New',
      posterColor: Color(0xFF3E404A),
      posterAccentColor: Color(0xFF101113),
    ),
    DemoMediaItem(
      title: 'Ink and Ocean',
      subtitle: 'Notebook anthology',
      mediaLabel: 'Book',
      year: '2022',
      statusLabel: 'New',
      posterColor: Color(0xFF695A6C),
      posterAccentColor: Color(0xFF181418),
    ),
    DemoMediaItem(
      title: 'Drakon Heir',
      subtitle: 'Campaign chapter six',
      mediaLabel: 'Game',
      year: '2024',
      statusLabel: 'New',
      posterColor: Color(0xFF4B6A63),
      posterAccentColor: Color(0xFF111414),
    ),
  ];

  static const List<DemoMediaItem> recentlyFinishedItems = [
    DemoMediaItem(
      title: 'Cinema Paradiso',
      subtitle: 'Finished June 12',
      mediaLabel: 'Movie',
      year: '1988',
      statusLabel: 'Finished',
      posterColor: Color(0xFF8C8F93),
      posterAccentColor: Color(0xFF2A2C2F),
      statusTone: DemoStatusTone.primary,
    ),
    DemoMediaItem(
      title: 'The Great Gatsby',
      subtitle: 'Finished June 08',
      mediaLabel: 'Book',
      year: '1925',
      statusLabel: 'Finished',
      posterColor: Color(0xFFA6A8AA),
      posterAccentColor: Color(0xFF383A3D),
      statusTone: DemoStatusTone.primary,
    ),
  ];

  static const List<DemoMediaItem> libraryItems = [
    DemoMediaItem(
      title: 'Neon Horizon: Part I',
      subtitle: 'Director cut edition',
      mediaLabel: 'Cinematography',
      year: '2023',
      statusLabel: 'Completed',
      posterColor: Color(0xFF17394A),
      posterAccentColor: Color(0xFF0A1116),
      statusTone: DemoStatusTone.secondary,
    ),
    DemoMediaItem(
      title: 'The Director’s Cut',
      subtitle: 'Monograph notes',
      mediaLabel: 'Photography',
      year: '2024',
      statusLabel: 'In Progress',
      posterColor: Color(0xFF343434),
      posterAccentColor: Color(0xFF0C0C0C),
      statusTone: DemoStatusTone.primary,
    ),
    DemoMediaItem(
      title: 'Silent Peaks',
      subtitle: 'Landscape survey',
      mediaLabel: 'Environment',
      year: '2021',
      statusLabel: 'Completed',
      posterColor: Color(0xFF8A6535),
      posterAccentColor: Color(0xFF12100F),
      statusTone: DemoStatusTone.secondary,
    ),
    DemoMediaItem(
      title: 'Structural Echoes',
      subtitle: 'Fold studies',
      mediaLabel: 'Research',
      year: '2022',
      statusLabel: 'Wishlist',
      posterColor: Color(0xFF7D7E80),
      posterAccentColor: Color(0xFF1A1B1C),
      statusTone: DemoStatusTone.tertiary,
    ),
    DemoMediaItem(
      title: 'The Sound of Stillness',
      subtitle: 'Listening notes',
      mediaLabel: 'Audio',
      year: '2020',
      statusLabel: 'Completed',
      posterColor: Color(0xFF111111),
      posterAccentColor: Color(0xFF040404),
      statusTone: DemoStatusTone.secondary,
    ),
    DemoMediaItem(
      title: 'Archivist’s Legacy',
      subtitle: 'Vault memo',
      mediaLabel: 'Archive',
      year: '2024',
      statusLabel: 'In Progress',
      posterColor: Color(0xFF6A4311),
      posterAccentColor: Color(0xFF140C06),
      statusTone: DemoStatusTone.primary,
    ),
    DemoMediaItem(
      title: 'Celluloid Dreams',
      subtitle: 'Projection diary',
      mediaLabel: 'Cinema',
      year: '2019',
      statusLabel: 'Completed',
      posterColor: Color(0xFF3E4953),
      posterAccentColor: Color(0xFF101317),
      statusTone: DemoStatusTone.secondary,
    ),
    DemoMediaItem(
      title: 'Mechanisms of Time',
      subtitle: 'Clockwork essays',
      mediaLabel: 'Book',
      year: '2024',
      statusLabel: 'Wishlist',
      posterColor: Color(0xFFCCB06C),
      posterAccentColor: Color(0xFF19140A),
      statusTone: DemoStatusTone.tertiary,
    ),
    DemoMediaItem(
      title: 'Fallen Leaves',
      subtitle: 'Northern lights',
      mediaLabel: 'Movie',
      year: '2022',
      statusLabel: 'Completed',
      posterColor: Color(0xFF6B6F3C),
      posterAccentColor: Color(0xFF111207),
      statusTone: DemoStatusTone.secondary,
    ),
    DemoMediaItem(
      title: 'The Wayfarer',
      subtitle: 'Signal watchlist',
      mediaLabel: 'Series',
      year: '2023',
      statusLabel: 'In Progress',
      posterColor: Color(0xFF204A61),
      posterAccentColor: Color(0xFF091117),
      statusTone: DemoStatusTone.primary,
    ),
    DemoMediaItem(
      title: 'Chaos Theory',
      subtitle: 'Field notes',
      mediaLabel: 'Science',
      year: '2021',
      statusLabel: 'Completed',
      posterColor: Color(0xFFE78300),
      posterAccentColor: Color(0xFF1B0E02),
      statusTone: DemoStatusTone.secondary,
    ),
    DemoMediaItem(
      title: 'Vessel of Light',
      subtitle: 'Architectural planes',
      mediaLabel: 'Design',
      year: '2024',
      statusLabel: 'Completed',
      posterColor: Color(0xFFB8C5CD),
      posterAccentColor: Color(0xFF181B1E),
      statusTone: DemoStatusTone.secondary,
    ),
    DemoMediaItem(
      title: 'Analog Soul',
      subtitle: 'Record collection',
      mediaLabel: 'Music',
      year: '2022',
      statusLabel: 'Wishlist',
      posterColor: Color(0xFF927D64),
      posterAccentColor: Color(0xFF13100D),
      statusTone: DemoStatusTone.tertiary,
    ),
    DemoMediaItem(
      title: 'Mirror Lake',
      subtitle: 'Still water studies',
      mediaLabel: 'Photography',
      year: '2023',
      statusLabel: 'Completed',
      posterColor: Color(0xFF6B8797),
      posterAccentColor: Color(0xFF0E1215),
      statusTone: DemoStatusTone.secondary,
    ),
  ];

  static const List<DemoMediaCategory> mediaCategories = [
    DemoMediaCategory(
      label: 'Movies & TV',
      description: '428 items in archive',
      itemCount: '428',
      icon: Icons.movie_outlined,
      accentColor: Color(0xFF426464),
    ),
    DemoMediaCategory(
      label: 'Books',
      description: '156 items in archive',
      itemCount: '156',
      icon: Icons.menu_book_rounded,
      accentColor: Color(0xFF4A6552),
    ),
    DemoMediaCategory(
      label: 'Games',
      description: '89 items in archive',
      itemCount: '89',
      icon: Icons.sports_esports_outlined,
      accentColor: Color(0xFF5C605F),
    ),
  ];

  static const DemoMediaItem detailItem = DemoMediaItem(
    title: 'The Monoliths of Silence',
    subtitle: 'Directed by Elena Valtari',
    mediaLabel: 'Cinematography',
    year: '2024',
    statusLabel: 'In Progress',
    posterColor: Color(0xFF2C333B),
    posterAccentColor: Color(0xFF090A0B),
    statusTone: DemoStatusTone.primary,
  );

  static const List<String> detailTags = [
    'Brutalism',
    'Noir',
    'Finland',
    'Monochrome',
  ];

  static const String detailSynopsis =
      'A precise, slow-burning meditation on concrete, weather, and memory. '
      'The record page keeps progress, notes, and lifecycle history visible in '
      'one desktop-first workspace so the archive feels more like a tool than a feed.';

  static const String detailNotes =
      'October 14, 2024\n\n'
      'Keep the detail page calm and editorial. The left column should stay action-led, '
      'while the right column carries synopsis, annotations, and the archive trail. '
      'Do not let the notes block turn into a generic form surface.';

  static const List<String> detailHistory = [
    'Status updated to In Progress — 14 Oct 2024, 09:42',
    'Added to collection — 10 Oct 2024, 14:15',
    'Catalog entry created — 10 Oct 2024, 14:10',
  ];
}
