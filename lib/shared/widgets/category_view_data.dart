import 'package:flutter/material.dart';

class CategoryViewData {
  const CategoryViewData({
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
