import 'package:flutter_test/flutter_test.dart';
import 'package:record_anywhere/features/bangumi/data/bangumi_type_mapper.dart';
import 'package:record_anywhere/shared/data/app_database.dart';

void main() {
  group('BangumiTypeMapper', () {
    test('maps Bangumi subject types to local media types', () {
      expect(BangumiTypeMapper.toMediaType(1), MediaType.book);
      expect(BangumiTypeMapper.toMediaType(2), MediaType.tv);
      expect(BangumiTypeMapper.toMediaType(4), MediaType.game);
      expect(BangumiTypeMapper.toMediaType(6), MediaType.movie);
      expect(BangumiTypeMapper.toMediaType(6, totalEpisodes: 12), MediaType.tv);
    });

    test('maps local media types back to Bangumi subject types', () {
      expect(BangumiTypeMapper.toSubjectType(MediaType.book), 1);
      expect(BangumiTypeMapper.toSubjectType(MediaType.tv), 2);
      expect(BangumiTypeMapper.toSubjectType(MediaType.game), 4);
      expect(BangumiTypeMapper.toSubjectType(MediaType.movie), 6);
    });

    test('maps Bangumi collection types to local unified status', () {
      expect(BangumiTypeMapper.toUnifiedStatus(1), UnifiedStatus.wishlist);
      expect(BangumiTypeMapper.toUnifiedStatus(2), UnifiedStatus.inProgress);
      expect(BangumiTypeMapper.toUnifiedStatus(3), UnifiedStatus.done);
      expect(BangumiTypeMapper.toUnifiedStatus(4), UnifiedStatus.onHold);
      expect(BangumiTypeMapper.toUnifiedStatus(5), UnifiedStatus.dropped);
    });

    test('maps local unified status back to Bangumi collection types', () {
      expect(BangumiTypeMapper.toCollectionType(UnifiedStatus.wishlist), 1);
      expect(BangumiTypeMapper.toCollectionType(UnifiedStatus.inProgress), 2);
      expect(BangumiTypeMapper.toCollectionType(UnifiedStatus.done), 3);
      expect(BangumiTypeMapper.toCollectionType(UnifiedStatus.onHold), 4);
      expect(BangumiTypeMapper.toCollectionType(UnifiedStatus.dropped), 5);
    });
  });
}
