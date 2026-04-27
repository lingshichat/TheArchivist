import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app/app.dart';
import 'shared/theme/app_theme.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  _setupErrorWidget();
  runApp(const ProviderScope(child: RecordAnywhereApp()));
}

void _setupErrorWidget() {
  ErrorWidget.builder = (details) {
    return Material(
      color: AppColors.background,
      child: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.broken_image_outlined,
                  size: 48,
                  color: AppColors.subtleText,
                ),
                const SizedBox(height: 16),
                const Text(
                  'Something went wrong',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: AppColors.onSurface,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  details.exception.toString(),
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppColors.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  };
}
