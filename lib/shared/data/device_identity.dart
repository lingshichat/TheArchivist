import 'package:uuid/uuid.dart';

abstract final class DeviceIdentityService {
  static const _uuid = Uuid();

  static String generate() => _uuid.v4();
}
