import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../shared/demo/demo_data.dart';
import '../../../shared/widgets/poster_view_data.dart';

class DetailNotesEntry {
  const DetailNotesEntry({required this.date, required this.body});

  final String date;
  final String body;
}

class DetailLifecycleEntry {
  const DetailLifecycleEntry({
    required this.title,
    required this.time,
    this.current = false,
  });

  final String title;
  final String time;
  final bool current;
}

class DetailViewData {
  const DetailViewData({
    required this.poster,
    this.synopsis,
    this.tags,
    this.notes,
    this.lifecycle,
  });

  final PosterViewData poster;
  final String? synopsis;
  final List<String>? tags;
  final DetailNotesEntry? notes;
  final List<DetailLifecycleEntry>? lifecycle;

  bool get hasSynopsis => synopsis != null && synopsis!.isNotEmpty;
  bool get hasTags => tags != null && tags!.isNotEmpty;
  bool get hasNotes => notes != null;
  bool get hasLifecycle => lifecycle != null && lifecycle!.isNotEmpty;
}

abstract class DetailViewDataSource {
  DetailViewData fetchById(String id);
}

class DemoDetailViewDataSource implements DetailViewDataSource {
  const DemoDetailViewDataSource();

  @override
  DetailViewData fetchById(String id) {
    final DemoMediaItem? item = DemoData.lookupById(id);
    if (item == null) {
      return _fullView(DemoData.detailItem);
    }
    if (item.id == DemoData.detailItem.id) {
      return _fullView(item);
    }
    return DetailViewData(poster: item.toPosterView());
  }

  DetailViewData _fullView(DemoMediaItem item) {
    final parts = DemoData.detailNotes.split('\n\n');
    final notesDate = parts.isNotEmpty ? parts.first : '';
    final notesBody = parts.length > 1 ? parts.sublist(1).join('\n\n') : '';

    return DetailViewData(
      poster: item.toPosterView(),
      synopsis: DemoData.detailSynopsis,
      tags: DemoData.detailTags,
      notes: DetailNotesEntry(date: notesDate, body: notesBody),
      lifecycle: const [
        DetailLifecycleEntry(
          title: 'STATUS UPDATED: IN PROGRESS',
          time: '14 OCT 2024 — 09:42 AM',
          current: true,
        ),
        DetailLifecycleEntry(
          title: 'ADDED TO COLLECTION',
          time: '10 OCT 2024 — 02:15 PM',
        ),
        DetailLifecycleEntry(
          title: 'CATALOG ENTRY CREATED',
          time: '10 OCT 2024 — 02:10 PM',
        ),
      ],
    );
  }
}

final detailViewDataSourceProvider = Provider<DetailViewDataSource>((ref) {
  return const DemoDetailViewDataSource();
});

final detailViewDataProvider =
    Provider.family<DetailViewData, String>((ref, id) {
      return ref.watch(detailViewDataSourceProvider).fetchById(id);
    });
