import 'package:flutter/material.dart';

enum PosterStatusTone { primary, secondary, tertiary, muted }

class PosterViewData {
  const PosterViewData({
    required this.id,
    required this.title,
    required this.mediaLabel,
    required this.posterColor,
    required this.posterAccentColor,
    this.subtitle,
    this.year,
    this.statusLabel,
    this.statusTone = PosterStatusTone.secondary,
  });

  final String id;
  final String title;
  final String mediaLabel;
  final Color posterColor;
  final Color posterAccentColor;
  final String? subtitle;
  final String? year;
  final String? statusLabel;
  final PosterStatusTone statusTone;
}
