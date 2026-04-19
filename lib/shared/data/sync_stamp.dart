/// Mixin for auto-stamping sync fields on write operations.
///
/// Concrete repositories will call [stampCompanion] before every write to
/// ensure updatedAt / syncVersion / deviceId are current.
abstract final class SyncStampDecorator {
  static DateTime now() => DateTime.now();
}
