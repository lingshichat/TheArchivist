import 'package:flutter_test/flutter_test.dart';
import 'package:record_anywhere/features/sync/data/providers.dart';
import 'package:record_anywhere/shared/network/s3_api_client.dart';

void main() {
  test('sync target config round-trips webdav and s3 fields', () {
    final config = SyncTargetConfig(
      activeType: SyncTargetType.s3Compatible,
      webDav: WebDavSyncTargetConfig(
        baseUri: Uri.parse('https://dav.example.com/root'),
        username: 'alice',
        password: 'dav-secret',
        rootPath: 'record-anywhere',
      ),
      s3: S3SyncTargetConfig(
        endpoint: Uri.parse('https://s3.example.com'),
        region: 'us-east-1',
        bucket: 'archive',
        rootPrefix: 'record-anywhere',
        accessKey: 'access-key',
        secretKey: 'secret-key',
        sessionToken: 'session-token',
        addressingStyle: S3AddressingStyle.virtualHostedStyle,
      ),
    );

    final restored = SyncTargetConfig.fromJson(config.toJson());

    expect(restored.activeType, SyncTargetType.s3Compatible);
    expect(restored.webDav?.baseUri.toString(), 'https://dav.example.com/root');
    expect(restored.webDav?.username, 'alice');
    expect(restored.webDav?.password, 'dav-secret');
    expect(restored.webDav?.rootPath, 'record-anywhere');
    expect(restored.s3?.endpoint.toString(), 'https://s3.example.com');
    expect(restored.s3?.region, 'us-east-1');
    expect(restored.s3?.bucket, 'archive');
    expect(restored.s3?.rootPrefix, 'record-anywhere');
    expect(restored.s3?.accessKey, 'access-key');
    expect(restored.s3?.secretKey, 'secret-key');
    expect(restored.s3?.sessionToken, 'session-token');
    expect(
      restored.s3?.addressingStyle,
      S3AddressingStyle.virtualHostedStyle,
    );
  });

  test('in-memory sync target store writes reads and clears config', () async {
    final store = InMemorySyncTargetStore();
    final config = SyncTargetConfig(
      activeType: SyncTargetType.webDav,
      webDav: WebDavSyncTargetConfig(
        baseUri: Uri.parse('https://dav.example.com'),
        username: 'bob',
        password: 'password',
      ),
    );

    await store.write(config);
    final saved = await store.read();

    expect(saved.activeType, SyncTargetType.webDav);
    expect(saved.webDav?.username, 'bob');
    expect(saved.hasActiveTarget, isTrue);

    await store.clear();
    final cleared = await store.read();

    expect(cleared.activeType, isNull);
    expect(cleared.hasActiveTarget, isFalse);
  });

  test('adapter config conversion preserves normalized target fields', () {
    final webDav = WebDavSyncTargetConfig(
      baseUri: Uri.parse('https://dav.example.com'),
      username: 'carol',
      password: 'secret',
      rootPath: 'records',
    ).toAdapterConfig();
    final s3 = S3SyncTargetConfig(
      endpoint: Uri.parse('https://s3.example.com'),
      region: 'ap-east-1',
      bucket: 'records',
      accessKey: 'ak',
      secretKey: 'sk',
    ).toAdapterConfig();

    expect(webDav.baseUri.toString(), 'https://dav.example.com');
    expect(webDav.username, 'carol');
    expect(webDav.password, 'secret');
    expect(webDav.rootPath, 'records');
    expect(s3.endpoint.toString(), 'https://s3.example.com');
    expect(s3.region, 'ap-east-1');
    expect(s3.bucket, 'records');
    expect(s3.accessKey, 'ak');
    expect(s3.secretKey, 'sk');
    expect(s3.addressingStyle, S3AddressingStyle.pathStyle);
  });
}
