import 'dart:io';

import 'package:flutter/services.dart';

import 'update_models.dart';

abstract interface class UpdateInstaller {
  Future<void> install(
      {required String filePath, required UpdatePlatform platform});
}

class PlatformUpdateInstaller implements UpdateInstaller {
  const PlatformUpdateInstaller({
    MethodChannel channel = const MethodChannel('com.thearchivist.app/update'),
  }) : _channel = channel;

  final MethodChannel _channel;

  @override
  Future<void> install({
    required String filePath,
    required UpdatePlatform platform,
  }) async {
    switch (platform) {
      case UpdatePlatform.windows:
        await _installWindows(filePath);
        return;
      case UpdatePlatform.android:
        await _installAndroid(filePath);
        return;
      case UpdatePlatform.unsupported:
        throw const UpdateUnsupportedPlatformException(
          'Updates are currently available only on Windows and Android.',
        );
    }
  }

  Future<void> _installWindows(String filePath) async {
    final file = File(filePath);
    if (!await file.exists()) {
      throw const UpdateInstallException(
        'The downloaded installer could not be found.',
      );
    }

    try {
      await Process.start(
        filePath,
        const <String>[],
        mode: ProcessStartMode.detached,
      );
    } on ProcessException catch (error) {
      throw UpdateInstallException(
        error.message.isEmpty
            ? 'Unable to start the Windows installer.'
            : error.message,
      );
    }
  }

  Future<void> _installAndroid(String filePath) async {
    final file = File(filePath);
    if (!await file.exists()) {
      throw const UpdateInstallException(
        'The downloaded APK could not be found.',
      );
    }

    try {
      final started = await _channel.invokeMethod<bool>(
        'installApk',
        <String, Object?>{'path': filePath},
      );
      if (started != true) {
        throw const UpdateInstallException(
          'Android requires permission to install apps from this source.',
        );
      }
    } on PlatformException catch (error) {
      throw UpdateInstallException(
        error.message ?? 'Unable to open the Android package installer.',
      );
    } on MissingPluginException {
      throw const UpdateInstallException(
        'Android installer support is unavailable in this build.',
      );
    }
  }
}
