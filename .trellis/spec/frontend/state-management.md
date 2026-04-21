# State Management

> How state is managed in this project.

---

## Overview

This project uses `flutter_riverpod` as the application-level state solution.

Phase 1 now has a real local-first loop:

- App bootstrap still uses a root `ProviderScope`
- Router configuration is still exposed via a provider
- Home / Library / Detail now read from Drift-backed `StreamProvider`s
- Add / Detail write flows now go through feature controllers
- Page-local filters, dialog state, and text editing state stay local

The goal is to keep page widgets presentation-first while the data semantics
live in repositories and controllers.

---

## State Categories

- **Application state**
  - Router and future app-wide preferences
  - Lives in Riverpod providers
- **Feature-local UI state**
  - Selected tabs, filters, form text, dialog visibility
  - Stays local unless multiple routes need to share it
- **Domain/data state**
  - Local database, sync state, Bangumi integration
  - Read through repository-backed Riverpod providers
  - Written through feature-scoped controllers

---

## When to Use Global State

Promote state to Riverpod when:

- It is shared by multiple routes or shell-level widgets
- It survives page rebuilds and must stay coherent
- It represents app-level preference or data lifecycle
- It is a live read model backed by Drift streams

Keep state local when:

- It only affects a single widget subtree
- It is temporary visual interaction state
- It is form editing state that can be submitted in one action

---

## Local-First Read Pattern

Use `StreamProvider` / `StreamProvider.family` for live archive reads.

Rules:

- Providers read from repositories, not directly from page widgets
- Feature providers adapt DB entities into feature view data
- Shared widgets should still consume stable UI models such as
  `PosterViewData` and `CategoryViewData`
- Missing records should resolve to `null` or empty view data, not demo
  fallbacks

Current examples:

- `homeViewDataProvider`
- `libraryHeaderProvider`
- `libraryItemsProvider`
- `detailViewDataProvider`

---

## Local-First Write Pattern

Use controller classes for multi-step writes.

Rules:

- Pages trigger controller methods
- Controllers orchestrate repository writes
- Activity-log appends belong next to the mutation path
- Pages should only handle progress UI, dialogs, and success feedback

Current examples:

- `AddEntryController`
- `DetailActionsController`

---

## Server State

Phase 2 introduces external API integration (Bangumi). Server-state conventions:

### Network reads (search, fetch)

- External API calls go through `ApiService` methods, wrapped in Riverpod providers
- Providers return `AsyncValue<ResultDto>` — UI handles `when()` for loading/data/error
- Search is **not** streamed — `FutureProvider` or manual `AsyncNotifier` with debounce

## Scenario: paginated Bangumi search state on `/add`

### 1. Scope / Trigger

- Trigger: Add page Bangumi search now supports debounce, filter changes,
  infinite-scroll pagination, and load-more retry.
- This is cross-layer because the page owns text/scroll state, while Riverpod
  owns the server-state result pages.

### 2. Signatures

```dart
final bangumiSearchProvider = AsyncNotifierProvider.autoDispose
    .family<
      BangumiSearchController,
      BangumiPagedSearchState,
      BangumiSearchRequest
    >(BangumiSearchController.new);

class BangumiSearchController
    extends AutoDisposeFamilyAsyncNotifier<
      BangumiPagedSearchState,
      BangumiSearchRequest
    > {
  Future<void> loadMore();
}
```

### 3. Contracts

- Page-local state stays in `AddEntryPage`
  - `TextEditingController`
  - debounce timer
  - filter chip / popup state
  - `ScrollController`
- Riverpod state owns remote result pages
  - first-page failure uses provider `AsyncError`
  - later-page failure must stay inside `BangumiPagedSearchState.loadMoreError`
    so already rendered rows do not disappear
- `BangumiPagedSearchState` must include:
  - `total`
  - `items`
  - `pageSize`
  - `isLoadingMore`
  - `loadMoreError`
  - derived `hasMore`
- `loadMore()` must no-op when:
  - no current page exists
  - a page is already loading
  - `hasMore == false`
- page merge contract:
  - append new rows
  - keep earlier rows stable
  - dedupe by `subject.id`

### 4. Validation & Error Matrix

| State | Expected Behavior | UI Result |
|-------|-------------------|-----------|
| no committed keyword | provider not watched | empty guidance state |
| first-page loading | provider `AsyncLoading` | full loading empty-state |
| first-page error | provider `AsyncError` | retryable error empty-state |
| load-more in progress | keep rows + `isLoadingMore=true` | bottom loading footer |
| load-more error | keep rows + save error in state | bottom retry footer |
| `items.length >= total` | stop pagination | "all loaded" footer |

### 5. Good / Base / Bad Cases

- Good:
  - user searches `"eva"`, scrolls down, page 2 appends under page 1
- Base:
  - one-page result set; footer reports all loaded without extra requests
- Bad:
  - reassigning provider to `AsyncLoading` during `loadMore()`
  - page widget making direct `ApiService.searchSubjects(...)` calls in scroll listener
  - duplicate rows caused by appending without `subject.id` dedupe

### 6. Tests Required

- Provider tests:
  - first read loads page 1
  - `loadMore()` appends page 2 and page 3
  - `loadMore()` stops when `hasMore == false`
- Widget/manual assertions:
  - search results remain visible while later pages load
  - bottom footer switches among loading / retry / all-loaded states
  - changing keyword or filter resets to the new request family

### 7. Wrong vs Correct

#### Wrong

```dart
void onScroll() async {
  final result = await api.searchSubjects(keyword, offset: items.length);
  setState(() {
    items = result.data;
  });
}
```

- network logic leaks into the widget
- later pages replace earlier rows
- no shared pagination contract

#### Correct

```dart
Future<void> loadMore() async {
  final current = state.valueOrNull;
  if (current == null || current.isLoadingMore || !current.hasMore) {
    return;
  }

  state = AsyncData(
    current.copyWith(isLoadingMore: true, loadMoreError: null),
  );

  try {
    final result = await ref.read(bangumiApiServiceProvider).searchSubjects(
      arg.keyword.trim(),
      filter: <String, Object?>{'type': arg.filter.bangumiTypes},
      limit: current.pageSize,
      offset: current.items.length,
    );

    state = AsyncData(
      current.copyWith(
        total: result.total,
        items: <BangumiSubjectDto>[
          ...current.items,
          ...result.data.where(
            (item) => current.items.every((existing) => existing.id != item.id),
          ),
        ],
        isLoadingMore: false,
        loadMoreError: null,
      ),
    );
  } catch (error) {
    state = AsyncData(
      current.copyWith(isLoadingMore: false, loadMoreError: error),
    );
  }
}
```

### Sync writes (push to external)

- Sync is triggered by controllers after local write succeeds
- Controllers call an injected `SyncService.push(...)` — they do **not** know about tokens or HTTP
- Sync success/failure is surfaced as a light side-channel (snackbar, status chip), not as the primary action result
- Local state is always the source of truth; remote sync is best-effort

## Scenario: Bangumi auth + sync summary state on Settings

### 1. Scope / Trigger

- Trigger: Bangumi binding now includes post-connect import, startup restore
  reconciliation, and manual `Sync now`.
- This is cross-layer because settings-page UI depends on auth state,
  background sync state, and summary counts produced by Bangumi feature
  services.

### 2. Signatures

```dart
final bangumiAuthProvider =
    AsyncNotifierProvider<BangumiAuthController, BangumiAuth?>(
      BangumiAuthController.new,
    );

final bangumiSyncStatusProvider = NotifierProvider<
  BangumiSyncStatusController,
  BangumiSyncStatus
>(BangumiSyncStatusController.new);

enum BangumiSyncTrigger { postConnect, startupRestore, manual }

class BangumiSyncStatus {
  final bool isRunning;
  final BangumiSyncTrigger? activeTrigger;
  final DateTime? lastCompletedAt;
  final BangumiPullSummary? lastSummary;
}
```

### 3. Contracts

- `bangumiAuthProvider`
  - owns token restore / validation state
  - exposes only account summary needed by UI
  - does not expose raw token
- `bangumiSyncStatusProvider`
  - owns batch sync progress + last summary
  - must be feature-local in `features/bangumi/data/providers.dart`
  - must not live in `shared/data/providers.dart`
- settings-page local state keeps only:
  - text controller content
  - pending button state before provider settles
- provider state owns:
  - auth loading / error / connected data
  - currently running sync trigger
  - last sync summary counts
- trigger behavior:
  - `postConnect` may show one summary feedback after completion
  - `startupRestore` updates provider state silently by default
  - `manual` may show one summary feedback after completion
- batch pull summary is not streamed row-by-row to the page

### 4. Validation & Error Matrix

| State | Expected Behavior | UI Result |
|-------|-------------------|-----------|
| auth restore loading | `bangumiAuthProvider` is `AsyncLoading` | disable connect/disconnect actions |
| post-connect sync running | `bangumiSyncStatus.isRunning=true` | show "syncing" state in section |
| startup sync running | provider updates silently | no toast storm |
| manual sync success | save `lastSummary` + `lastCompletedAt` | one summary feedback + refreshed section |
| manual sync failure | keep last good summary, expose latest error state via controller/status | inline state or one light feedback |

### 5. Good / Base / Bad Cases

- Good:
  - settings page reads `bangumiAuthProvider` and `bangumiSyncStatusProvider`
    to render connected state + last summary
- Base:
  - startup restore kicks off background sync without blocking the whole app
- Bad:
  - page stores imported/updated counts in local `setState`
  - page loops over pull rows and emits one snackbar per item
  - API client is called directly from button handlers

### 6. Tests Required

- Provider tests:
  - auth restore reaches connected state without exposing raw token
  - manual sync updates `lastSummary` and `lastCompletedAt`
  - startup sync sets `activeTrigger=startupRestore`
- Widget/manual assertions:
  - connected settings section shows summary counts
  - `Sync now` disables while sync is running
  - startup restore does not spam per-item feedback

### 7. Wrong vs Correct

#### Wrong

```dart
class _SettingsState extends State<SettingsPage> {
  int importedCount = 0;

  Future<void> onSyncNow() async {
    final rows = await api.listCollections(username);
    setState(() => importedCount = rows.length);
  }
}
```

- page owns integration state directly
- no reusable sync-summary contract
- impossible to coordinate startup/manual triggers consistently

#### Correct

```dart
final status = ref.watch(bangumiSyncStatusProvider);

await ref.read(bangumiPullServiceProvider).pullCollections(
  username: auth.username!,
  trigger: BangumiSyncTrigger.manual,
);
```

- page stays presentation-first
- Bangumi feature providers own auth + sync state
- manual and background sync reuse one contract

### Provider placement

| Scope | Location | Examples |
|-------|----------|---------|
| Cross-feature (database, repos) | `lib/shared/data/providers.dart` | `appDatabaseProvider`, `mediaRepositoryProvider` |
| Feature-local (view models, page state) | next to the feature file | `homeViewDataProvider`, `libraryItemsProvider` |
| Integration module (API client, auth) | `lib/features/<name>/data/providers.dart` | `bangumiApiClientProvider`, `bangumiAuthProvider` |

Rules:

- Do not register integration-specific providers in `shared/data/providers.dart`
- Integration providers may depend on shared providers (e.g. `appDatabaseProvider`)
- Keep the dependency graph one-directional: `feature → shared`, never reverse

---

## Common Mistakes

- Creating global providers for one-off widget presentation state
- Letting page widgets call DAO methods directly
- Doing multi-step writes inside button callbacks
- Returning Drift row objects straight into shared presentation widgets
- Duplicating route-selection logic in both shell and feature layers
- Registering API/integration providers in `shared/data/providers.dart` (use feature-local file)
- Letting controllers import `dio` or handle HTTP details directly
