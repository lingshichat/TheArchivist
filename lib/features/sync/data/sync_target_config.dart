import '../../../shared/network/s3_api_client.dart';
import 's3_storage_adapter.dart';
import 'webdav_storage_adapter.dart';

enum SyncTargetType { webDav, s3Compatible }

class SyncTargetConfig {
  const SyncTargetConfig({this.activeType, this.webDav, this.s3});

  final SyncTargetType? activeType;
  final WebDavSyncTargetConfig? webDav;
  final S3SyncTargetConfig? s3;

  bool get hasActiveTarget {
    return activeConfig != null;
  }

  Object? get activeConfig {
    return switch (activeType) {
      SyncTargetType.webDav => webDav,
      SyncTargetType.s3Compatible => s3,
      null => null,
    };
  }

  SyncTargetConfig copyWith({
    Object? activeType = _noOverride,
    Object? webDav = _noOverride,
    Object? s3 = _noOverride,
  }) {
    return SyncTargetConfig(
      activeType: identical(activeType, _noOverride)
          ? this.activeType
          : activeType as SyncTargetType?,
      webDav: identical(webDav, _noOverride)
          ? this.webDav
          : webDav as WebDavSyncTargetConfig?,
      s3: identical(s3, _noOverride) ? this.s3 : s3 as S3SyncTargetConfig?,
    );
  }

  Map<String, Object?> toJson() {
    return <String, Object?>{
      'activeType': activeType?.name,
      'webDav': webDav?.toJson(),
      's3': s3?.toJson(),
    };
  }

  factory SyncTargetConfig.fromJson(Map<String, Object?> json) {
    return SyncTargetConfig(
      activeType: _parseTargetType(json['activeType']),
      webDav: _parseNested(
        json['webDav'],
        WebDavSyncTargetConfig.fromJson,
      ),
      s3: _parseNested(json['s3'], S3SyncTargetConfig.fromJson),
    );
  }

  static SyncTargetType? _parseTargetType(Object? value) {
    if (value is! String || value.trim().isEmpty) {
      return null;
    }
    return SyncTargetType.values.byName(value);
  }

  static T? _parseNested<T>(
    Object? value,
    T Function(Map<String, Object?> json) parser,
  ) {
    if (value is! Map) {
      return null;
    }
    return parser(Map<String, Object?>.from(value));
  }
}

class WebDavSyncTargetConfig {
  const WebDavSyncTargetConfig({
    required this.baseUri,
    required this.username,
    required this.password,
    this.rootPath = '',
  });

  final Uri baseUri;
  final String username;
  final String password;
  final String rootPath;

  WebDavStorageAdapterConfig toAdapterConfig() {
    return WebDavStorageAdapterConfig(
      baseUri: baseUri,
      username: username,
      password: password,
      rootPath: rootPath,
    );
  }

  Map<String, Object?> toJson() {
    return <String, Object?>{
      'baseUri': baseUri.toString(),
      'username': username,
      'password': password,
      'rootPath': rootPath,
    };
  }

  factory WebDavSyncTargetConfig.fromJson(Map<String, Object?> json) {
    return WebDavSyncTargetConfig(
      baseUri: Uri.parse(_requireString(json, 'baseUri')),
      username: _requireString(json, 'username'),
      password: _requireString(json, 'password'),
      rootPath: _optionalString(json, 'rootPath') ?? '',
    );
  }
}

class S3SyncTargetConfig {
  const S3SyncTargetConfig({
    required this.endpoint,
    required this.region,
    required this.bucket,
    required this.accessKey,
    required this.secretKey,
    this.rootPrefix = '',
    this.sessionToken,
    this.addressingStyle = S3AddressingStyle.pathStyle,
  });

  final Uri endpoint;
  final String region;
  final String bucket;
  final String rootPrefix;
  final String accessKey;
  final String secretKey;
  final String? sessionToken;
  final S3AddressingStyle addressingStyle;

  S3StorageAdapterConfig toAdapterConfig() {
    return S3StorageAdapterConfig(
      endpoint: endpoint,
      region: region,
      bucket: bucket,
      rootPrefix: rootPrefix,
      accessKey: accessKey,
      secretKey: secretKey,
      sessionToken: sessionToken,
      addressingStyle: addressingStyle,
    );
  }

  Map<String, Object?> toJson() {
    return <String, Object?>{
      'endpoint': endpoint.toString(),
      'region': region,
      'bucket': bucket,
      'rootPrefix': rootPrefix,
      'accessKey': accessKey,
      'secretKey': secretKey,
      'sessionToken': sessionToken,
      'addressingStyle': addressingStyle.name,
    };
  }

  factory S3SyncTargetConfig.fromJson(Map<String, Object?> json) {
    return S3SyncTargetConfig(
      endpoint: Uri.parse(_requireString(json, 'endpoint')),
      region: _requireString(json, 'region'),
      bucket: _requireString(json, 'bucket'),
      rootPrefix: _optionalString(json, 'rootPrefix') ?? '',
      accessKey: _requireString(json, 'accessKey'),
      secretKey: _requireString(json, 'secretKey'),
      sessionToken: _optionalString(json, 'sessionToken'),
      addressingStyle: _parseAddressingStyle(json['addressingStyle']),
    );
  }

  static S3AddressingStyle _parseAddressingStyle(Object? value) {
    if (value is! String || value.trim().isEmpty) {
      return S3AddressingStyle.pathStyle;
    }
    return S3AddressingStyle.values.byName(value);
  }
}

String _requireString(Map<String, Object?> json, String key) {
  final value = _optionalString(json, key);
  if (value == null) {
    throw ArgumentError.value(json[key], key, 'Value cannot be empty.');
  }
  return value;
}

String? _optionalString(Map<String, Object?> json, String key) {
  final value = json[key];
  if (value is! String) {
    return null;
  }
  final normalized = value.trim();
  if (normalized.isEmpty) {
    return null;
  }
  return normalized;
}

const Object _noOverride = Object();
