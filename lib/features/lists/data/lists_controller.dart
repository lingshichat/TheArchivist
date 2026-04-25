import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../shared/data/providers.dart';
import '../../../shared/data/repositories/shelf_repository.dart';

final listsControllerProvider = Provider<ListsController>((ref) {
  return ListsController(ref.watch(shelfRepositoryProvider));
});

class ListsController {
  ListsController(this._shelfRepository);

  final ShelfRepository _shelfRepository;

  Future<String> createShelf(String name) async {
    return _shelfRepository.createShelf(name: name);
  }

  Future<void> renameShelf(String id, String newName) async {
    await _shelfRepository.renameShelf(id, newName);
  }

  Future<void> deleteShelf(String id) async {
    await _shelfRepository.softDeleteShelf(id);
  }

  Future<void> batchAttach(String shelfId, List<String> mediaItemIds) async {
    await _shelfRepository.batchAttachToShelf(shelfId, mediaItemIds);
  }

  Future<void> batchDetach(String shelfId, List<String> mediaItemIds) async {
    await _shelfRepository.batchDetachFromShelf(shelfId, mediaItemIds);
  }

  Future<void> reorderItems(
    String shelfId,
    List<String> orderedItemIds,
  ) async {
    await _shelfRepository.reorderShelfItems(shelfId, orderedItemIds);
  }

  Future<bool> isNameTaken(String name) async {
    return _shelfRepository.isNameTaken(name);
  }
}
