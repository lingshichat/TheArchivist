import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/router/app_router.dart';
import '../../../shared/data/app_database.dart';
import '../../../shared/data/local_view_adapters.dart';
import '../../../shared/network/bangumi_api_client.dart';
import '../../../shared/theme/app_theme.dart';
import '../../../shared/utils/step_logger.dart';
import '../../../shared/widgets/empty_state.dart';
import '../../../shared/widgets/local_feedback.dart';
import '../data/add_entry_controller.dart';
import '../data/bangumi_quick_add_controller.dart';
import '../data/bangumi_search_providers.dart';
import '../../bangumi/data/bangumi_models.dart';
import 'bangumi_search_result_card.dart';
import 'bangumi_subject_preview_dialog.dart';

class AddEntryPage extends ConsumerStatefulWidget {
  const AddEntryPage({super.key});

  @override
  ConsumerState<AddEntryPage> createState() => _AddEntryPageState();
}

class _AddEntryPageState extends ConsumerState<AddEntryPage> {
  static const StepLogger logger = StepLogger('AddEntryPage');

  final _pageScrollController = ScrollController();
  final _searchController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _subtitleController = TextEditingController();
  final _yearController = TextEditingController();
  final _overviewController = TextEditingController();
  final _measureController = TextEditingController();
  final _tagsController = TextEditingController();
  final _shelvesController = TextEditingController();

  Timer? _searchDebounce;
  MediaType _mediaType = MediaType.movie;
  BangumiSearchFilter _searchFilter = BangumiSearchFilter.all;
  String _committedKeyword = '';
  bool _manualFormExpanded = false;
  bool _isSaving = false;
  int? _quickAddingSubjectId;

  @override
  void initState() {
    super.initState();
    _pageScrollController.addListener(_handlePageScroll);
    _searchController.addListener(_handleSearchChanged);
  }

  @override
  void dispose() {
    _searchDebounce?.cancel();
    _pageScrollController
      ..removeListener(_handlePageScroll)
      ..dispose();
    _searchController
      ..removeListener(_handleSearchChanged)
      ..dispose();
    _titleController.dispose();
    _subtitleController.dispose();
    _yearController.dispose();
    _overviewController.dispose();
    _measureController.dispose();
    _tagsController.dispose();
    _shelvesController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final localIndexAsync = ref.watch(bangumiLocalIndexProvider);
    final searchRequest = _activeSearchRequest;
    final searchAsync = searchRequest == null
        ? null
        : ref.watch(bangumiSearchProvider(searchRequest));

    return SingleChildScrollView(
      controller: _pageScrollController,
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.xxxl,
        AppSpacing.xxxl,
        AppSpacing.xxxl,
        AppSpacing.xxxl,
      ),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1080),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildSearchPanel(
                context,
                searchAsync: searchAsync,
                localIndexAsync: localIndexAsync,
              ),
              const SizedBox(height: AppSpacing.xxxl),
              _buildManualCreateSection(context),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSearchPanel(
    BuildContext context, {
    required AsyncValue<Map<int, BangumiLocalMatch>> localIndexAsync,
    required AsyncValue<BangumiPagedSearchState>? searchAsync,
  }) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.all(AppSpacing.xxxl),
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerLow,
        borderRadius: BorderRadius.circular(AppRadii.container),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Add From Bangumi', style: AppTextStyles.heroTitle(theme)),
          const SizedBox(height: AppSpacing.xs),
          Text(
            'Search Bangumi first, choose a starting status, then keep refining your archive locally.',
            style: theme.textTheme.bodyMedium,
          ),
          const SizedBox(height: AppSpacing.xxl),
          _buildSearchControls(context),
          const SizedBox(height: AppSpacing.xxl),
          _buildSearchResults(
            context,
            searchAsync: searchAsync,
            localIndexAsync: localIndexAsync,
          ),
        ],
      ),
    );
  }

  Widget _buildSearchControls(BuildContext context) {
    final theme = Theme.of(context);

    return LayoutBuilder(
      builder: (context, constraints) {
        final searchField = TextField(
          controller: _searchController,
          style: AppFormStyles.fieldText(theme),
          decoration:
              AppFormStyles.fieldDecoration(
                theme,
                label: 'Search Bangumi',
                hintText: 'Type a title, series, book, or game',
                surface: AppFormSurface.lowest,
              ).copyWith(
                prefixIcon: const Icon(Icons.search_rounded, size: 18),
                suffixIcon: _searchController.text.trim().isEmpty
                    ? null
                    : IconButton(
                        onPressed: _clearSearch,
                        icon: const Icon(Icons.close_rounded, size: 18),
                      ),
              ),
          textInputAction: TextInputAction.search,
          onSubmitted: (_) => _commitSearchNow(),
        );

        final filterButton = _BangumiFilterButton(
          value: _searchFilter,
          onSelected: _applySearchFilter,
        );

        if (constraints.maxWidth < 760) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              searchField,
              const SizedBox(height: AppSpacing.md),
              Align(alignment: Alignment.centerLeft, child: filterButton),
            ],
          );
        }

        return Row(
          children: [
            Expanded(child: searchField),
            const SizedBox(width: AppSpacing.md),
            filterButton,
          ],
        );
      },
    );
  }

  Widget _buildSearchResults(
    BuildContext context, {
    required AsyncValue<Map<int, BangumiLocalMatch>> localIndexAsync,
    required AsyncValue<BangumiPagedSearchState>? searchAsync,
  }) {
    final localIndex =
        localIndexAsync.valueOrNull ?? const <int, BangumiLocalMatch>{};

    if (searchAsync == null) {
      return const EmptyState(
        compact: true,
        icon: Icons.travel_explore_rounded,
        title: 'Search Bangumi first',
        body:
            'Find a title, pick a starting status, then keep searching or expand the manual form below.',
      );
    }

    return searchAsync.when(
      loading: () => const EmptyState(
        compact: true,
        icon: Icons.hourglass_bottom_rounded,
        title: 'Searching Bangumi',
        body: 'Looking up matching titles from the current filter.',
      ),
      error: (error, stackTrace) {
        final (title, body) = _searchErrorCopy(error);
        return EmptyState(
          compact: true,
          icon: Icons.wifi_off_rounded,
          title: title,
          body: body,
          actionLabel: 'Try Again',
          onActionTap: _commitSearchNow,
        );
      },
      data: (result) {
        if (result.items.isEmpty) {
          return const EmptyState(
            compact: true,
            icon: Icons.search_off_rounded,
            title: 'No matches found',
            body: 'Try another keyword or switch the Bangumi type filter.',
          );
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'RESULTS · ${result.total}',
              style: Theme.of(
                context,
              ).textTheme.labelLarge?.copyWith(color: AppColors.subtleText),
            ),
            const SizedBox(height: AppSpacing.md),
            ...result.items.map((subject) {
              final localMatch = localIndex[subject.id];
              return Padding(
                padding: const EdgeInsets.only(bottom: AppSpacing.md),
                child: BangumiSearchResultCard(
                  subject: subject,
                  localMatch: localMatch,
                  isBusy: _quickAddingSubjectId == subject.id,
                  onViewTap: () => _handlePreview(subject, localMatch),
                  onAddTap: () => _handleQuickAdd(subject),
                ),
              );
            }),
            _BangumiSearchPaginationFooter(
              result: result,
              onRetryTap: _loadMoreSearchResults,
            ),
          ],
        );
      },
    );
  }

  Widget _buildManualCreateSection(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'OR CREATE MANUALLY',
          style: theme.textTheme.labelLarge?.copyWith(
            color: AppColors.subtleText,
          ),
        ),
        const SizedBox(height: AppSpacing.sm),
        Row(
          children: [
            Expanded(
              child: Text(
                _manualFormExpanded
                    ? 'Use the local form when Bangumi cannot find the title you want.'
                    : 'Keep the local form as a fallback for titles Bangumi does not cover.',
                style: theme.textTheme.bodyMedium,
              ),
            ),
            const SizedBox(width: AppSpacing.md),
            TextButton.icon(
              onPressed: () {
                setState(() {
                  _manualFormExpanded = !_manualFormExpanded;
                });
              },
              icon: Icon(
                _manualFormExpanded
                    ? Icons.keyboard_arrow_up_rounded
                    : Icons.keyboard_arrow_down_rounded,
              ),
              label: Text(_manualFormExpanded ? 'Collapse' : 'Expand'),
            ),
          ],
        ),
        if (_manualFormExpanded) ...[
          const SizedBox(height: AppSpacing.xl),
          _buildManualCreatePanel(context),
        ],
      ],
    );
  }

  Widget _buildManualCreatePanel(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.all(AppSpacing.xxxl),
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerLow,
        borderRadius: BorderRadius.circular(AppRadii.container),
      ),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Create Local Entry', style: AppTextStyles.panelTitle(theme)),
            const SizedBox(height: AppSpacing.xs),
            Text(
              'Start with a minimal local record when you need a manual fallback.',
              style: theme.textTheme.bodyMedium,
            ),
            const SizedBox(height: AppSpacing.xxxl),
            LayoutBuilder(
              builder: (context, constraints) {
                final useSplit = constraints.maxWidth >= 620;
                final left = _buildPrimaryFields(context);
                final right = _buildSecondaryFields(context);

                if (!useSplit) {
                  return Column(
                    children: [
                      left,
                      const SizedBox(height: AppSpacing.xl),
                      right,
                    ],
                  );
                }

                return Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(child: left),
                    const SizedBox(width: AppSpacing.xl),
                    Expanded(child: right),
                  ],
                );
              },
            ),
            const SizedBox(height: AppSpacing.xxxl),
            Row(
              children: [
                OutlinedButton(
                  style: AppFormStyles.secondaryButton(
                    theme,
                    surface: AppFormSurface.low,
                  ),
                  onPressed: _isSaving
                      ? null
                      : () => context.go(AppRoutes.library),
                  child: const Text('Back to Library'),
                ),
                const Spacer(),
                FilledButton.icon(
                  onPressed: _isSaving ? null : _submit,
                  icon: _isSaving
                      ? const SizedBox(
                          width: 14,
                          height: 14,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: AppColors.accentForeground,
                          ),
                        )
                      : const Icon(Icons.add_rounded, size: 18),
                  label: Text(_isSaving ? 'Saving...' : 'Create Entry'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPrimaryFields(BuildContext context) {
    final theme = Theme.of(context);
    final fieldTextStyle = AppFormStyles.fieldText(theme);
    const surface = AppFormSurface.low;

    InputDecoration decoration(String label, {String? hintText}) {
      return AppFormStyles.fieldDecoration(
        theme,
        label: label,
        hintText: hintText,
        surface: surface,
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        DropdownButtonFormField<MediaType>(
          initialValue: _mediaType,
          style: fieldTextStyle,
          iconEnabledColor: AppFormStyles.fieldIconColor,
          dropdownColor: AppFormStyles.dropdownColor(surface),
          decoration: decoration('Media type'),
          items: MediaType.values
              .map(
                (value) => DropdownMenuItem<MediaType>(
                  value: value,
                  child: Text(_mediaTypeLabel(value)),
                ),
              )
              .toList(),
          onChanged: _isSaving
              ? null
              : (value) {
                  if (value == null) {
                    return;
                  }
                  setState(() {
                    _mediaType = value;
                    _measureController.clear();
                  });
                },
        ),
        const SizedBox(height: AppSpacing.lg),
        TextFormField(
          controller: _titleController,
          style: fieldTextStyle,
          decoration: decoration('Title'),
          enabled: !_isSaving,
          validator: (value) {
            if (value == null || value.trim().isEmpty) {
              return 'Title is required.';
            }
            return null;
          },
        ),
        const SizedBox(height: AppSpacing.lg),
        TextFormField(
          controller: _subtitleController,
          style: fieldTextStyle,
          decoration: decoration('Subtitle'),
          enabled: !_isSaving,
        ),
        const SizedBox(height: AppSpacing.lg),
        TextFormField(
          controller: _yearController,
          style: fieldTextStyle,
          decoration: decoration('Release year'),
          keyboardType: TextInputType.number,
          enabled: !_isSaving,
          validator: (value) {
            final trimmed = value?.trim();
            if (trimmed == null || trimmed.isEmpty) {
              return null;
            }

            final year = int.tryParse(trimmed);
            if (year == null || year < 1 || year > 9999) {
              return 'Use a valid year.';
            }
            return null;
          },
        ),
        const SizedBox(height: AppSpacing.lg),
        TextFormField(
          controller: _measureController,
          style: fieldTextStyle,
          decoration: decoration(_measureFieldLabel(_mediaType)),
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          enabled: !_isSaving,
          validator: (value) => _validateMeasure(value, _mediaType),
        ),
      ],
    );
  }

  Widget _buildSecondaryFields(BuildContext context) {
    final theme = Theme.of(context);
    final fieldTextStyle = AppFormStyles.fieldText(theme);
    const surface = AppFormSurface.low;

    InputDecoration decoration(String label, {String? hintText}) {
      return AppFormStyles.fieldDecoration(
        theme,
        label: label,
        hintText: hintText,
        surface: surface,
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextFormField(
          controller: _overviewController,
          style: fieldTextStyle,
          decoration: decoration('Synopsis'),
          enabled: !_isSaving,
          maxLines: 6,
        ),
        const SizedBox(height: AppSpacing.lg),
        TextFormField(
          controller: _tagsController,
          style: fieldTextStyle,
          decoration: decoration('Tags', hintText: 'Keywords, comma separated'),
          enabled: !_isSaving,
        ),
        const SizedBox(height: AppSpacing.lg),
        TextFormField(
          controller: _shelvesController,
          style: fieldTextStyle,
          decoration: decoration(
            'Shelves',
            hintText: 'Custom collections, comma separated',
          ),
          enabled: !_isSaving,
        ),
      ],
    );
  }

  void _handleSearchChanged() {
    /*
     * ========================================================================
     * 步骤1：处理搜索框输入变化
     * ========================================================================
     * 目标：
     *   1) 维持 300ms debounce 的搜索节奏
     *   2) 让清空按钮和搜索结果只跟提交后的关键词联动
     */
    logger.info('开始处理 Bangumi 搜索输入变化...');

    // 1.1 取消上一个 debounce 计时器，并更新当前输入态
    _searchDebounce?.cancel();
    if (mounted) {
      setState(() {});
    }

    // 1.2 重新安排新的查询提交时间点
    final nextKeyword = _searchController.text.trim();
    _searchDebounce = Timer(const Duration(milliseconds: 300), () {
      if (!mounted) {
        return;
      }

      setState(() {
        _committedKeyword = nextKeyword;
      });
    });

    logger.info('Bangumi 搜索输入变化处理完成。');
  }

  void _applySearchFilter(BangumiSearchFilter value) {
    /*
     * ========================================================================
     * 步骤2：切换 Bangumi 类型筛选
     * ========================================================================
     * 目标：
     *   1) 立即刷新当前关键词对应的搜索结果
     *   2) 让 Add 页的筛选状态保持本地 UI 责任
     */
    logger.info('开始切换 Bangumi 类型筛选...');

    // 2.1 更新筛选器状态
    setState(() {
      _searchFilter = value;
      _committedKeyword = _searchController.text.trim();
    });

    logger.info('Bangumi 类型筛选切换完成。');
  }

  void _commitSearchNow() {
    /*
     * ========================================================================
     * 步骤3：立即提交当前搜索词
     * ========================================================================
     * 目标：
     *   1) 支持回车和“重试”动作绕过 debounce
     *   2) 保持搜索结果和当前文本框内容同步
     */
    logger.info('开始立即提交 Bangumi 搜索词...');

    // 3.1 清理未触发的 debounce
    _searchDebounce?.cancel();

    // 3.2 立刻刷新当前关键词
    setState(() {
      _committedKeyword = _searchController.text.trim();
    });

    logger.info('Bangumi 搜索词立即提交完成。');
  }

  void _clearSearch() {
    /*
     * ========================================================================
     * 步骤4：清空当前搜索状态
     * ========================================================================
     * 目标：
     *   1) 清理文本框和已提交关键词
     *   2) 回到 Add 页的初始引导态
     */
    logger.info('开始清空 Bangumi 搜索状态...');

    // 4.1 停掉现有 debounce，并清空文本框
    _searchDebounce?.cancel();
    _searchController.clear();

    // 4.2 重置已提交关键词
    setState(() {
      _committedKeyword = '';
    });

    logger.info('Bangumi 搜索状态清空完成。');
  }

  BangumiSearchRequest? get _activeSearchRequest {
    final normalizedKeyword = _committedKeyword.trim();
    if (normalizedKeyword.isEmpty) {
      return null;
    }

    return BangumiSearchRequest(
      keyword: normalizedKeyword,
      filter: _searchFilter,
    );
  }

  void _handlePageScroll() {
    if (!_pageScrollController.hasClients) {
      return;
    }

    if (_pageScrollController.position.extentAfter > 480) {
      return;
    }

    unawaited(_loadMoreSearchResults());
  }

  Future<void> _loadMoreSearchResults() async {
    /*
     * ========================================================================
     * 步骤5：按滚动触发 Bangumi 搜索懒加载
     * ========================================================================
     * 目标：
     *   1) 当用户滚动到结果区底部时继续请求下一页
     *   2) 避免 Add 页一次性渲染全部搜索结果
     */
    logger.info('开始按滚动触发 Bangumi 搜索懒加载...');

    // 5.1 检查当前搜索请求和分页状态
    final request = _activeSearchRequest;
    if (request == null) {
      logger.info('Bangumi 搜索懒加载跳过，当前没有激活搜索。');
      return;
    }

    final current = ref.read(bangumiSearchProvider(request)).valueOrNull;
    if (current == null || current.isLoadingMore || !current.hasMore) {
      logger.info('Bangumi 搜索懒加载跳过，当前无需继续加载。');
      return;
    }

    // 5.2 调用分页 controller 追加下一页
    await ref.read(bangumiSearchProvider(request).notifier).loadMore();

    logger.info('Bangumi 搜索懒加载触发完成。');
  }

  Future<void> _handleQuickAdd(BangumiSubjectDto subject) async {
    /*
     * ========================================================================
     * 步骤6：执行 Bangumi 快捷添加
     * ========================================================================
     * 目标：
     *   1) 先收集用户要写入的 UnifiedStatus
     *   2) 调用 controller 完成本地写入和同步 hook
     */
    logger.info('开始执行 Bangumi 快捷添加...');

    // 5.1 弹出状态选择层，未选择则直接退出
    final selectedStatus = await showDialog<UnifiedStatus>(
      context: context,
      builder: (context) => _BangumiStatusDialog(subject: subject),
    );
    if (selectedStatus == null || !mounted) {
      logger.info('Bangumi 快捷添加取消。');
      return;
    }

    setState(() {
      _quickAddingSubjectId = subject.id;
    });

    try {
      // 5.2 调用 quick add controller 执行本地写入
      final result = await ref
          .read(bangumiQuickAddControllerProvider)
          .createFromSubject(subject: subject, status: selectedStatus);

      if (!mounted) {
        return;
      }

      final message = result.alreadyExists
          ? 'This title is already in your local archive.'
          : 'Saved locally.';
      showLocalFeedback(
        context,
        message,
        actionLabel: 'View details',
        onActionTap: () {
          ScaffoldMessenger.of(context).hideCurrentSnackBar();
          context.go(AppRoutes.detailFor(result.mediaId));
        },
      );
    } catch (error) {
      if (!mounted) {
        return;
      }

      // 5.3 用统一轻反馈兜底错误，不打断当前搜索流
      showLocalFeedback(
        context,
        'Could not add this Bangumi title.',
        tone: LocalFeedbackTone.error,
      );
    } finally {
      if (mounted) {
        setState(() {
          _quickAddingSubjectId = null;
        });
      }
    }

    logger.info('Bangumi 快捷添加完成。');
  }

  Future<void> _handlePreview(
    BangumiSubjectDto subject,
    BangumiLocalMatch? localMatch,
  ) async {
    /*
     * ========================================================================
     * 步骤7：打开 Bangumi 搜索结果预览
     * ========================================================================
     * 目标：
     *   1) 让用户在添加前先浏览远程详情
     *   2) 已在库条目仍可从预览层进入本地详情
     */
    logger.info('开始打开 Bangumi 搜索结果预览...');

    // 6.1 弹出远程详情预览层
    await showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return BangumiSubjectPreviewDialog(
          subjectId: subject.id,
          localMatch: localMatch,
          onOpenLocalTap: localMatch == null
              ? null
              : () {
                  Navigator.of(dialogContext).pop();
                  context.go(AppRoutes.detailFor(localMatch.mediaId));
                },
        );
      },
    );

    logger.info('Bangumi 搜索结果预览已关闭。');
  }

  Future<void> _submit() async {
    /*
     * ========================================================================
     * 步骤8：提交手动创建表单
     * ========================================================================
     * 目标：
     *   1) 继续保留 WP4 的本地手动创建能力
     *   2) 与 Bangumi 搜索流并存，不互相覆盖
     */
    logger.info('开始提交手动创建表单...');

    // 6.1 表单校验失败时直接返回
    if (!_formKey.currentState!.validate()) {
      logger.info('手动创建表单校验失败。');
      return;
    }

    final controller = ref.read(addEntryControllerProvider);
    final releaseDate = _parseYear(_yearController.text);
    final measure = _parseMeasure(_measureController.text);

    setState(() => _isSaving = true);

    try {
      // 6.2 调用本地 add controller 写入记录
      final mediaId = await controller.create(
        AddEntryInput(
          mediaType: _mediaType,
          title: _titleController.text,
          subtitle: _subtitleController.text,
          releaseDate: releaseDate,
          overview: _overviewController.text,
          runtimeMinutes: _mediaType == MediaType.movie
              ? measure?.round()
              : null,
          totalEpisodes: _mediaType == MediaType.tv ? measure?.round() : null,
          totalPages: _mediaType == MediaType.book ? measure?.round() : null,
          estimatedPlayHours: _mediaType == MediaType.game ? measure : null,
          tags: _splitComma(_tagsController.text),
          shelves: _splitComma(_shelvesController.text),
        ),
      );

      if (!mounted) {
        return;
      }

      // 6.3 手动创建沿用原来的成功反馈和详情跳转
      showLocalFeedback(context, 'Saved locally.');
      context.go(AppRoutes.detailFor(mediaId));
    } catch (error) {
      if (!mounted) {
        return;
      }
      showLocalFeedback(
        context,
        'Could not save the entry.',
        tone: LocalFeedbackTone.error,
      );
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }

    logger.info('手动创建表单提交完成。');
  }

  (String, String) _searchErrorCopy(Object error) {
    if (error is BangumiNetworkError) {
      return (
        'Could not reach Bangumi',
        'Check the network connection, then retry the current search.',
      );
    }

    if (error is BangumiBadRequestError) {
      return (
        'Bangumi rejected the search',
        'The current search request was not accepted. Try a different keyword.',
      );
    }

    return (
      'Could not search Bangumi',
      'The current query could not be resolved right now. Try again in a moment.',
    );
  }

  String? _validateMeasure(String? value, MediaType mediaType) {
    final trimmed = value?.trim();
    if (trimmed == null || trimmed.isEmpty) {
      return null;
    }

    final parsed = num.tryParse(trimmed);
    if (parsed == null || parsed <= 0) {
      return 'Use a positive number.';
    }

    if ((mediaType == MediaType.tv || mediaType == MediaType.book) &&
        parsed is! int &&
        parsed.toInt() != parsed) {
      return 'Use a whole number.';
    }

    return null;
  }

  DateTime? _parseYear(String value) {
    final year = int.tryParse(value.trim());
    if (year == null) {
      return null;
    }
    return DateTime(year);
  }

  double? _parseMeasure(String value) {
    final trimmed = value.trim();
    if (trimmed.isEmpty) {
      return null;
    }
    return double.tryParse(trimmed);
  }

  List<String> _splitComma(String rawValue) {
    return rawValue
        .split(',')
        .map((value) => value.trim())
        .where((value) => value.isNotEmpty)
        .toList();
  }
}

class _BangumiSearchPaginationFooter extends StatelessWidget {
  const _BangumiSearchPaginationFooter({
    required this.result,
    required this.onRetryTap,
  });

  final BangumiPagedSearchState result;
  final Future<void> Function() onRetryTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    if (result.isLoadingMore) {
      return Padding(
        padding: const EdgeInsets.only(top: AppSpacing.md),
        child: Center(
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
              const SizedBox(width: AppSpacing.md),
              Text(
                'Loading more results...',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: AppColors.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      );
    }

    if (result.loadMoreError != null) {
      return Padding(
        padding: const EdgeInsets.only(top: AppSpacing.md),
        child: Container(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.lg,
            vertical: AppSpacing.md,
          ),
          decoration: BoxDecoration(
            color: AppColors.surfaceContainerLowest,
            borderRadius: BorderRadius.circular(AppRadii.card),
            border: Border.all(
              color: AppColors.outlineVariant.withValues(alpha: 0.18),
            ),
          ),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  'Could not load more results right now.',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: AppColors.onSurfaceVariant,
                  ),
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              TextButton(onPressed: onRetryTap, child: const Text('Retry')),
            ],
          ),
        ),
      );
    }

    if (result.hasMore) {
      return Padding(
        padding: const EdgeInsets.only(top: AppSpacing.md),
        child: Center(
          child: Text(
            'Scroll down to load more',
            style: theme.textTheme.labelMedium?.copyWith(
              color: AppColors.subtleText,
            ),
          ),
        ),
      );
    }

    if (result.total > result.pageSize) {
      return Padding(
        padding: const EdgeInsets.only(top: AppSpacing.md),
        child: Center(
          child: Text(
            'All matching results are loaded.',
            style: theme.textTheme.labelMedium?.copyWith(
              color: AppColors.subtleText,
            ),
          ),
        ),
      );
    }

    return const SizedBox.shrink();
  }
}

class _BangumiFilterButton extends StatelessWidget {
  const _BangumiFilterButton({required this.value, required this.onSelected});

  final BangumiSearchFilter value;
  final ValueChanged<BangumiSearchFilter> onSelected;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return PopupMenuButton<BangumiSearchFilter>(
      initialValue: value,
      onSelected: onSelected,
      tooltip: 'Bangumi type filter',
      position: PopupMenuPosition.under,
      color: AppColors.surfaceContainerLowest,
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadii.container),
        side: BorderSide(
          color: AppColors.outlineVariant.withValues(alpha: 0.15),
        ),
      ),
      itemBuilder: (context) {
        return BangumiSearchFilter.values
            .map(
              (option) => PopupMenuItem<BangumiSearchFilter>(
                value: option,
                child: Text(
                  option.label,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: option == value
                        ? AppColors.accent
                        : AppColors.onSurface,
                    fontWeight: option == value
                        ? FontWeight.w700
                        : FontWeight.w500,
                  ),
                ),
              ),
            )
            .toList();
      },
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.lg,
          vertical: AppSpacing.md,
        ),
        decoration: BoxDecoration(
          color: AppColors.surfaceContainerLowest,
          borderRadius: BorderRadius.circular(AppRadii.container),
          border: Border.all(
            color: AppColors.outlineVariant.withValues(alpha: 0.24),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              value.label.toUpperCase(),
              style: theme.textTheme.labelLarge?.copyWith(
                color: AppColors.onSurface,
              ),
            ),
            const SizedBox(width: AppSpacing.xs),
            const Icon(
              Icons.expand_more_rounded,
              size: 16,
              color: AppColors.subtleText,
            ),
          ],
        ),
      ),
    );
  }
}

class _BangumiStatusDialog extends StatelessWidget {
  const _BangumiStatusDialog({required this.subject});

  final BangumiSubjectDto subject;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final title = subject.nameCn?.trim().isNotEmpty == true
        ? subject.nameCn!.trim()
        : subject.name.trim().isNotEmpty
        ? subject.name.trim()
        : 'Bangumi #${subject.id}';

    return Dialog(
      backgroundColor: AppColors.surfaceContainerLowest,
      insetPadding: const EdgeInsets.all(AppSpacing.xxl),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 520),
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.xxxl),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Choose Starting Status',
                style: AppTextStyles.panelTitle(theme),
              ),
              const SizedBox(height: AppSpacing.xs),
              Text(
                'Add "$title" to the local archive with one of the unified status states below.',
                style: theme.textTheme.bodyMedium,
              ),
              const SizedBox(height: AppSpacing.xxl),
              Wrap(
                spacing: AppSpacing.md,
                runSpacing: AppSpacing.md,
                children: UnifiedStatus.values.map((value) {
                  return _StatusChoiceChip(
                    label: LocalViewAdapters.statusLabel(value),
                    onTap: () => Navigator.of(context).pop(value),
                  );
                }).toList(),
              ),
              const SizedBox(height: AppSpacing.xxl),
              Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('Cancel'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _StatusChoiceChip extends StatelessWidget {
  const _StatusChoiceChip({required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadii.card),
        child: Ink(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.lg,
            vertical: AppSpacing.md,
          ),
          decoration: BoxDecoration(
            color: AppColors.surfaceContainerLow,
            borderRadius: BorderRadius.circular(AppRadii.card),
            border: Border.all(
              color: AppColors.outlineVariant.withValues(alpha: 0.18),
            ),
          ),
          child: Text(
            label.toUpperCase(),
            style: Theme.of(
              context,
            ).textTheme.labelLarge?.copyWith(color: AppColors.onSurface),
          ),
        ),
      ),
    );
  }
}

String _mediaTypeLabel(MediaType value) {
  switch (value) {
    case MediaType.movie:
      return 'Movie';
    case MediaType.tv:
      return 'TV Series';
    case MediaType.book:
      return 'Book';
    case MediaType.game:
      return 'Game';
  }
}

String _measureFieldLabel(MediaType value) {
  switch (value) {
    case MediaType.movie:
      return 'Runtime minutes';
    case MediaType.tv:
      return 'Total episodes';
    case MediaType.book:
      return 'Total pages';
    case MediaType.game:
      return 'Estimated play hours';
  }
}
