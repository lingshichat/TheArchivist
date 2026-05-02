import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Global mock data mode toggle.
///
/// When enabled, features that support mock mode should return preview/demo
/// data instead of making real network calls or reading real state.
///
/// Only available in debug builds. In release/profile, always reads `false`.
final mockModeProvider = StateProvider<bool>((ref) => false);

/// Convenience getter that returns `false` in non-debug builds.
bool watchMockMode(WidgetRef ref) {
  if (!kDebugMode) return false;
  return ref.watch(mockModeProvider);
}

/// Convenience getter for non-widget code (e.g. controllers).
bool readMockMode(Ref ref) {
  if (!kDebugMode) return false;
  return ref.read(mockModeProvider);
}
