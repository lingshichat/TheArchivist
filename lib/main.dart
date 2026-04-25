import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app/app.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  _setupErrorWidget();
  runApp(const ProviderScope(child: RecordAnywhereApp()));
}

void _setupErrorWidget() {
  ErrorWidget.builder = (details) {
    return Material(
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
                  color: Color(0xFFB0B8BF),
                ),
                const SizedBox(height: 16),
                const Text(
                  'Something went wrong',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF2D3338),
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  details.exception.toString(),
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 12,
                    color: Color(0xFF8A9299),
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
