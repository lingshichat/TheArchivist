import 'update_models.dart';

class AppVersion implements Comparable<AppVersion> {
  const AppVersion(this.parts);

  final List<int> parts;

  factory AppVersion.parse(String value) {
    final normalized = value.trim().replaceFirst(RegExp('^[vV]'), '');
    final withoutBuild = normalized.split('+').first.split('-').first;
    if (withoutBuild.trim().isEmpty) {
      throw UpdateVersionParseException('Version "$value" is empty.');
    }

    final parts = <int>[];
    for (final part in withoutBuild.split('.')) {
      final parsed = int.tryParse(part.trim());
      if (parsed == null) {
        throw UpdateVersionParseException('Version "$value" is invalid.');
      }
      parts.add(parsed);
    }

    return AppVersion(parts);
  }

  @override
  int compareTo(AppVersion other) {
    final length =
        parts.length > other.parts.length ? parts.length : other.parts.length;
    for (var index = 0; index < length; index += 1) {
      final current = index < parts.length ? parts[index] : 0;
      final remote = index < other.parts.length ? other.parts[index] : 0;
      if (current != remote) {
        return current.compareTo(remote);
      }
    }
    return 0;
  }
}

bool isRemoteVersionNewer({
  required String currentVersion,
  required String remoteTag,
}) {
  return AppVersion.parse(remoteTag)
          .compareTo(AppVersion.parse(currentVersion)) >
      0;
}
