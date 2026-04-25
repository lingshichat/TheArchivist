import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../sync/data/providers.dart';
import '../../../shared/network/s3_api_client.dart';
import '../../../shared/theme/app_theme.dart';
import '../../../shared/widgets/local_feedback.dart';
import '../../../shared/widgets/section_card.dart';

class SyncTargetSection extends ConsumerStatefulWidget {
  const SyncTargetSection({super.key});

  @override
  ConsumerState<SyncTargetSection> createState() =>
      _SyncTargetSectionState();
}

enum _SyncTargetAction {
  none,
  saving,
  testing,
  disconnecting,
  syncing,
}

class _SyncTargetSectionState extends ConsumerState<SyncTargetSection> {
  SyncTargetType _selectedType = SyncTargetType.webDav;

  late final TextEditingController _webDavBaseUriController;
  late final TextEditingController _webDavUsernameController;
  late final TextEditingController _webDavPasswordController;
  late final TextEditingController _webDavRootPathController;

  late final TextEditingController _s3EndpointController;
  late final TextEditingController _s3RegionController;
  late final TextEditingController _s3BucketController;
  late final TextEditingController _s3AccessKeyController;
  late final TextEditingController _s3SecretKeyController;
  late final TextEditingController _s3SessionTokenController;
  late final TextEditingController _s3RootPrefixController;

  bool _obscureWebDavPassword = true;
  bool _obscureS3SecretKey = true;
  bool _obscureS3SessionToken = true;
  S3AddressingStyle _s3AddressingStyle = S3AddressingStyle.pathStyle;

  _SyncTargetAction _pendingAction = _SyncTargetAction.none;
  SyncConnectionTestResult? _testResult;
  bool _showPendingQueue = false;
  bool _showConflicts = false;

  @override
  void initState() {
    super.initState();
    _webDavBaseUriController = TextEditingController();
    _webDavUsernameController = TextEditingController();
    _webDavPasswordController = TextEditingController();
    _webDavRootPathController = TextEditingController();

    _s3EndpointController = TextEditingController();
    _s3RegionController = TextEditingController();
    _s3BucketController = TextEditingController();
    _s3AccessKeyController = TextEditingController();
    _s3SecretKeyController = TextEditingController();
    _s3SessionTokenController = TextEditingController();
    _s3RootPrefixController = TextEditingController();
  }

  @override
  void dispose() {
    _webDavBaseUriController.dispose();
    _webDavUsernameController.dispose();
    _webDavPasswordController.dispose();
    _webDavRootPathController.dispose();

    _s3EndpointController.dispose();
    _s3RegionController.dispose();
    _s3BucketController.dispose();
    _s3AccessKeyController.dispose();
    _s3SecretKeyController.dispose();
    _s3SessionTokenController.dispose();
    _s3RootPrefixController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final configAsync = ref.watch(syncTargetConfigProvider);
    final hasActive = configAsync.valueOrNull?.hasActiveTarget ?? false;

    return SectionCard(
      title: 'Cloud Sync',
      leading: Icon(
        Icons.cloud_sync_outlined,
        size: 18,
        color: hasActive ? AppColors.accent : AppColors.subtleText,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Configure a WebDAV or S3-compatible target for cross-device sync.',
            style: theme.textTheme.bodySmall?.copyWith(height: 1.7),
          ),
          const SizedBox(height: AppSpacing.xl),
          if (hasActive)
            _buildConnectedState(context, configAsync.valueOrNull!)
          else
            _buildConfigForm(context),
        ],
      ),
    );
  }

  bool get isBusy => _pendingAction != _SyncTargetAction.none;

  // ─── Connected state ─────────────────────────────────────

  Widget _buildConnectedState(
    BuildContext context,
    SyncTargetConfig config,
  ) {
    final theme = Theme.of(context);
    final syncStatus = ref.watch(syncStatusProvider);
    final isWebDav = config.activeType == SyncTargetType.webDav;
    final typeLabel = isWebDav ? 'WebDAV' : 'S3-Compatible';
    final statusColor = _statusColor(syncStatus);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Target info
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(AppSpacing.lg),
          decoration: BoxDecoration(
            color: AppColors.surfaceContainerLowest,
            borderRadius: BorderRadius.circular(AppRadii.container),
            border: Border.all(
              color: AppColors.outlineVariant.withValues(alpha: 0.1),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Text('ACTIVE TARGET', style: theme.textTheme.labelSmall),
                  const Spacer(),
                  _statusBadge(theme, _statusLabel(syncStatus), statusColor),
                ],
              ),
              const SizedBox(height: AppSpacing.xs),
              Text(
                typeLabel,
                style: theme.textTheme.titleMedium?.copyWith(
                  color: AppColors.onSurface,
                ),
              ),
              const SizedBox(height: AppSpacing.sm),
              if (isWebDav) ...[
                _maskedFact(theme, 'Base URI', _maskUri(config.webDav!.baseUri)),
                _maskedFact(theme, 'Username', config.webDav!.username),
                _maskedFact(theme, 'Root Path', config.webDav!.rootPath),
              ] else ...[
                _maskedFact(theme, 'Endpoint', _maskUri(config.s3!.endpoint)),
                _maskedFact(theme, 'Bucket', config.s3!.bucket),
                _maskedFact(theme, 'Region', config.s3!.region),
                _maskedFact(theme, 'Access Key', _maskSecret(config.s3!.accessKey)),
              ],
            ],
          ),
        ),

        // Sync status facts
        const SizedBox(height: AppSpacing.md),
        _factRow(theme, 'LAST SYNC', _formatTimestamp(syncStatus.lastCompletedAt)),
        if (syncStatus.lastErrorSummary != null) ...[
          const SizedBox(height: AppSpacing.md),
          _factRow(
            theme,
            'LAST FAILURE',
            syncStatus.lastErrorSummary!,
            isWarning: true,
          ),
        ],

        // Action buttons
        const SizedBox(height: AppSpacing.lg),
        Row(
          children: [
            Expanded(
              flex: 3,
              child: FilledButton.icon(
                onPressed: isBusy ? null : _handleSyncNow,
                icon: _pendingAction == _SyncTargetAction.syncing
                    ? SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: AppColors.accentForeground,
                        ),
                      )
                    : const Icon(Icons.sync_rounded, size: 16),
                label: Text(
                  _pendingAction == _SyncTargetAction.syncing
                      ? 'Syncing...'
                      : 'Sync Now',
                ),
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: OutlinedButton(
                onPressed: isBusy ? null : _handleTestConnection,
                child: _pendingAction == _SyncTargetAction.testing
                    ? SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: AppColors.accent,
                        ),
                      )
                    : const Icon(Icons.network_check_rounded, size: 16),
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: OutlinedButton(
                onPressed: isBusy ? null : _handleDisconnect,
                child: const Text('Disconnect'),
              ),
            ),
          ],
        ),

        // Test result
        if (_testResult != null) ...[
          const SizedBox(height: AppSpacing.lg),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(AppSpacing.md),
            decoration: BoxDecoration(
              color: _testResult!.success
                  ? AppColors.accent.withValues(alpha: 0.08)
                  : AppColors.error.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(AppRadii.container),
            ),
            child: Text(
              _testResult!.message,
              style: theme.textTheme.bodySmall?.copyWith(
                color: _testResult!.success ? AppColors.accent : AppColors.error,
                height: 1.6,
              ),
            ),
          ),
        ],

        // Pending queue
        if (syncStatus.pendingCount > 0 ||
            syncStatus.lastErrorSummary != null) ...[
          const SizedBox(height: AppSpacing.lg),
          _expandToggle(
            theme,
            label: 'Pending Queue (${syncStatus.pendingCount})',
            expanded: _showPendingQueue,
            onTap: () => setState(() => _showPendingQueue = !_showPendingQueue),
          ),
          if (_showPendingQueue) ...[
            const SizedBox(height: AppSpacing.md),
            _buildPendingQueueList(theme),
            const SizedBox(height: AppSpacing.md),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: isBusy ? null : _handleRetryAll,
                icon: const Icon(Icons.refresh_rounded, size: 16),
                label: const Text('Retry All Pending'),
              ),
            ),
          ],
        ],

        // Conflict copies
        if (syncStatus.hasConflicts) ...[
          const SizedBox(height: AppSpacing.lg),
          _expandToggle(
            theme,
            label: 'Conflict Copies',
            expanded: _showConflicts,
            color: AppColors.error,
            onTap: () => setState(() => _showConflicts = !_showConflicts),
          ),
          if (_showConflicts) ...[
            const SizedBox(height: AppSpacing.md),
            _buildConflictList(theme),
          ],
        ],
      ],
    );
  }

  Widget _statusBadge(ThemeData theme, String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.sm,
        vertical: AppSpacing.xs,
      ),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(AppRadii.card),
      ),
      child: Text(
        label.toUpperCase(),
        style: theme.textTheme.labelMedium?.copyWith(color: color),
      ),
    );
  }

  Widget _factRow(
    ThemeData theme,
    String label,
    String value, {
    bool isWarning = false,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerLow,
        borderRadius: BorderRadius.circular(AppRadii.container),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: theme.textTheme.labelSmall),
          const SizedBox(height: AppSpacing.xs),
          Text(
            value,
            style: theme.textTheme.bodySmall?.copyWith(
              color: isWarning ? AppColors.error : AppColors.onSurface,
              height: 1.55,
            ),
          ),
        ],
      ),
    );
  }

  Widget _expandToggle(
    ThemeData theme, {
    required String label,
    required bool expanded,
    required VoidCallback onTap,
    Color? color,
  }) {
    final effectiveColor = color ?? AppColors.onSurfaceVariant;
    return GestureDetector(
      onTap: onTap,
      child: Row(
        children: [
          Icon(
            expanded
                ? Icons.expand_less_rounded
                : Icons.expand_more_rounded,
            size: 16,
            color: effectiveColor,
          ),
          const SizedBox(width: AppSpacing.sm),
          Text(
            label,
            style: theme.textTheme.labelMedium?.copyWith(
              color: effectiveColor,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPendingQueueList(ThemeData theme) {
    final pendingAsync = ref.watch(syncPendingItemsProvider);
    return pendingAsync.when(
      data: (items) {
        if (items.isEmpty) {
          return _infoBox(theme, 'No pending items.');
        }
        return Column(
          children: items
              .map((item) => _pendingQueueItem(theme, item))
              .toList(),
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, stackTrace) =>
          _infoBox(theme, 'Could not load pending items.'),
    );
  }

  Widget _pendingQueueItem(ThemeData theme, SyncQueueItem item) {
    final hasError = item.errorSummary != null;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.md),
      margin: const EdgeInsets.only(bottom: AppSpacing.sm),
      decoration: BoxDecoration(
        color: hasError
            ? AppColors.error.withValues(alpha: 0.04)
            : AppColors.surfaceContainerLow,
        borderRadius: BorderRadius.circular(AppRadii.container),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                '${item.entityType.name} · ${item.operation.name}',
                style: theme.textTheme.labelMedium,
              ),
              const Spacer(),
              if (item.retryCount > 0)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.sm,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.error.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(AppRadii.card),
                  ),
                  child: Text(
                    '${item.retryCount} retries',
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: AppColors.error,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            _truncateId(item.entityId),
            style: theme.textTheme.bodySmall,
          ),
          if (item.errorSummary != null) ...[
            const SizedBox(height: AppSpacing.xs),
            Text(
              item.errorSummary!,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.bodySmall?.copyWith(
                color: AppColors.error,
              ),
            ),
          ],
          if (item.lastAttemptedAt != null) ...[
            const SizedBox(height: AppSpacing.xs),
            Text(
              'Last attempt: ${_formatTimestamp(item.lastAttemptedAt)}',
              style: theme.textTheme.bodySmall?.copyWith(
                color: AppColors.onSurfaceVariant,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildConflictList(ThemeData theme) {
    return FutureBuilder<List<SyncConflictCopy>>(
      future: ref.read(syncConflictRepositoryProvider).listPending(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        final conflicts = snapshot.data ?? [];
        if (conflicts.isEmpty) {
          return _infoBox(theme, 'No pending conflicts.');
        }
        return Column(
          children: conflicts.map((c) => _conflictItem(theme, c)).toList(),
        );
      },
    );
  }

  Widget _conflictItem(ThemeData theme, SyncConflictCopy conflict) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.md),
      margin: const EdgeInsets.only(bottom: AppSpacing.sm),
      decoration: BoxDecoration(
        color: AppColors.error.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(AppRadii.container),
        border: Border.all(
          color: AppColors.error.withValues(alpha: 0.12),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '${conflict.entityType.name} · ${conflict.fieldName}',
            style: theme.textTheme.labelMedium?.copyWith(
              color: AppColors.error,
            ),
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            _truncateId(conflict.entityId),
            style: theme.textTheme.bodySmall,
          ),
          const SizedBox(height: AppSpacing.sm),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('LOCAL', style: theme.textTheme.labelSmall),
                    const SizedBox(height: 2),
                    Text(
                      conflict.localValue ?? '(empty)',
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('REMOTE', style: theme.textTheme.labelSmall),
                    const SizedBox(height: 2),
                    Text(
                      conflict.remoteValue ?? '(empty)',
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            'Detected: ${_formatTimestamp(conflict.detectedAt)}',
            style: theme.textTheme.bodySmall?.copyWith(
              color: AppColors.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            'This conflict requires manual resolution.',
            style: theme.textTheme.bodySmall?.copyWith(
              color: AppColors.onSurfaceVariant,
              fontStyle: FontStyle.italic,
            ),
          ),
        ],
      ),
    );
  }

  Widget _infoBox(ThemeData theme, String text) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerLow,
        borderRadius: BorderRadius.circular(AppRadii.container),
      ),
      child: Text(text, style: theme.textTheme.bodySmall),
    );
  }

  // ─── Config form ─────────────────────────────────────────

  Widget _buildConfigForm(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('TARGET TYPE', style: theme.textTheme.labelSmall),
        const SizedBox(height: AppSpacing.sm),
        _buildTypeSelector(theme),
        const SizedBox(height: AppSpacing.xl),
        if (_selectedType == SyncTargetType.webDav)
          _buildWebDavForm(theme)
        else
          _buildS3Form(theme),
      ],
    );
  }

  Widget _buildTypeSelector(ThemeData theme) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.xs),
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(AppRadii.container),
        border: Border.all(
          color: AppColors.outlineVariant.withValues(alpha: 0.1),
        ),
      ),
      child: Row(
        children: [
          _typeOption(theme, 'WebDAV', SyncTargetType.webDav),
          const SizedBox(width: AppSpacing.xs),
          _typeOption(theme, 'S3-Compatible', SyncTargetType.s3Compatible),
        ],
      ),
    );
  }

  Widget _typeOption(ThemeData theme, String label, SyncTargetType type) {
    final active = _selectedType == type;
    return Expanded(
      child: GestureDetector(
        onTap: isBusy ? null : () => setState(() => _selectedType = type),
        child: Container(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.md,
            vertical: AppSpacing.sm,
          ),
          decoration: BoxDecoration(
            color: active
                ? AppColors.surfaceContainerLow
                : Colors.transparent,
            borderRadius: BorderRadius.circular(AppRadii.container),
            boxShadow: active
                ? [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.04),
                      blurRadius: 6,
                      offset: const Offset(0, 1),
                    ),
                  ]
                : null,
          ),
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: theme.textTheme.bodySmall?.copyWith(
              color: active ? AppColors.accent : AppColors.onSurfaceVariant,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildWebDavForm(ThemeData theme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _textField(
          controller: _webDavBaseUriController,
          label: 'Base URI',
          hint: 'https://dav.example.com/',
        ),
        const SizedBox(height: AppSpacing.md),
        _textField(
          controller: _webDavUsernameController,
          label: 'Username',
        ),
        const SizedBox(height: AppSpacing.md),
        _obscuredField(
          controller: _webDavPasswordController,
          label: 'Password',
          obscure: _obscureWebDavPassword,
          onToggle: () =>
              setState(() => _obscureWebDavPassword = !_obscureWebDavPassword),
        ),
        const SizedBox(height: AppSpacing.md),
        _textField(
          controller: _webDavRootPathController,
          label: 'Root Path',
          hint: '/record-anywhere/',
        ),
        const SizedBox(height: AppSpacing.xl),
        _buildConfigActionButtons(),
      ],
    );
  }

  Widget _buildS3Form(ThemeData theme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _textField(
          controller: _s3EndpointController,
          label: 'Endpoint',
          hint: 'https://s3.example.com',
        ),
        const SizedBox(height: AppSpacing.md),
        Row(
          children: [
            Expanded(
              child: _textField(
                controller: _s3RegionController,
                label: 'Region',
                hint: 'us-east-1',
              ),
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: _textField(
                controller: _s3BucketController,
                label: 'Bucket',
              ),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.md),
        _textField(
          controller: _s3AccessKeyController,
          label: 'Access Key',
        ),
        const SizedBox(height: AppSpacing.md),
        _obscuredField(
          controller: _s3SecretKeyController,
          label: 'Secret Key',
          obscure: _obscureS3SecretKey,
          onToggle: () =>
              setState(() => _obscureS3SecretKey = !_obscureS3SecretKey),
        ),
        const SizedBox(height: AppSpacing.md),
        _obscuredField(
          controller: _s3SessionTokenController,
          label: 'Session Token',
          hint: 'Optional',
          obscure: _obscureS3SessionToken,
          onToggle: () => setState(
            () => _obscureS3SessionToken = !_obscureS3SessionToken,
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        _textField(
          controller: _s3RootPrefixController,
          label: 'Root Prefix',
          hint: 'record-anywhere/',
        ),
        const SizedBox(height: AppSpacing.md),
        _addressingStyleSelector(theme),
        const SizedBox(height: AppSpacing.xl),
        _buildConfigActionButtons(),
      ],
    );
  }

  Widget _addressingStyleSelector(ThemeData theme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Addressing Style', style: theme.textTheme.labelSmall),
        const SizedBox(height: AppSpacing.sm),
        Container(
          padding: const EdgeInsets.all(AppSpacing.xs),
          decoration: BoxDecoration(
            color: AppColors.surfaceContainerLowest,
            borderRadius: BorderRadius.circular(AppRadii.container),
            border: Border.all(
              color: AppColors.outlineVariant.withValues(alpha: 0.1),
            ),
          ),
          child: Row(
            children: [
              _styleOption(theme, 'Path-Style', S3AddressingStyle.pathStyle),
              const SizedBox(width: AppSpacing.xs),
              _styleOption(
                theme,
                'Virtual-Hosted',
                S3AddressingStyle.virtualHostedStyle,
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _styleOption(
    ThemeData theme,
    String label,
    S3AddressingStyle style,
  ) {
    final active = _s3AddressingStyle == style;
    return Expanded(
      child: GestureDetector(
        onTap: isBusy ? null : () => setState(() => _s3AddressingStyle = style),
        child: Container(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.md,
            vertical: AppSpacing.sm,
          ),
          decoration: BoxDecoration(
            color:
                active ? AppColors.surfaceContainerLow : Colors.transparent,
            borderRadius: BorderRadius.circular(AppRadii.container),
          ),
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: theme.textTheme.bodySmall?.copyWith(
              color: active ? AppColors.accent : AppColors.onSurfaceVariant,
            ),
          ),
        ),
      ),
    );
  }

  Widget _textField({
    required TextEditingController controller,
    required String label,
    String? hint,
  }) {
    final theme = Theme.of(context);
    return TextField(
      controller: controller,
      enabled: !isBusy,
      style: AppFormStyles.fieldText(theme),
      decoration: AppFormStyles.fieldDecoration(
        theme,
        label: label,
        hintText: hint,
        surface: AppFormSurface.lowest,
      ),
    );
  }

  Widget _obscuredField({
    required TextEditingController controller,
    required String label,
    String? hint,
    required bool obscure,
    required VoidCallback onToggle,
  }) {
    final theme = Theme.of(context);
    return TextField(
      controller: controller,
      obscureText: obscure,
      enabled: !isBusy,
      style: AppFormStyles.fieldText(theme),
      decoration: AppFormStyles.fieldDecoration(
        theme,
        label: label,
        hintText: hint,
        surface: AppFormSurface.lowest,
      ).copyWith(
        suffixIcon: IconButton(
          onPressed: isBusy ? null : onToggle,
          icon: Icon(
            obscure ? Icons.visibility_off_outlined : Icons.visibility_outlined,
            size: 18,
          ),
        ),
      ),
    );
  }

  Widget _buildConfigActionButtons() {
    final saving = _pendingAction == _SyncTargetAction.saving;
    final testing = _pendingAction == _SyncTargetAction.testing;

    return Row(
      children: [
        Expanded(
          child: FilledButton(
            onPressed: isBusy ? null : _handleSave,
            child: saving
                ? Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: AppColors.accentForeground,
                        ),
                      ),
                      const SizedBox(width: AppSpacing.sm),
                      const Text('Saving...'),
                    ],
                  )
                : const Text('Save Configuration'),
          ),
        ),
        const SizedBox(width: AppSpacing.md),
        Expanded(
          child: FilledButton.icon(
            onPressed: isBusy ? null : _handleTestConnection,
            icon: testing
                ? SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: AppColors.accentForeground,
                    ),
                  )
                : const Icon(Icons.network_check_rounded, size: 16),
            label: Text(testing ? 'Testing...' : 'Test Connection'),
          ),
        ),
      ],
    );
  }

  // ─── Helpers ─────────────────────────────────────────────

  Widget _maskedFact(ThemeData theme, String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(top: AppSpacing.xs),
      child: Row(
        children: [
          SizedBox(
            width: 100,
            child: Text(label, style: theme.textTheme.labelSmall),
          ),
          Expanded(
            child: Text(
              value,
              style: theme.textTheme.bodySmall?.copyWith(
                color: AppColors.onSurfaceVariant,
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _maskUri(Uri uri) {
    final host = uri.host;
    if (host.length <= 6) return host;
    return '${host.substring(0, 3)}...${host.substring(host.length - 3)}';
  }

  String _maskSecret(String value) {
    if (value.length <= 4) return '****';
    return '${value.substring(0, 2)}${'*' * (value.length - 4)}${value.substring(value.length - 2)}';
  }

  String _truncateId(String id) {
    if (id.length <= 16) return id;
    return '${id.substring(0, 16)}...';
  }

  Uri? _ensureScheme(String raw) {
    final text = raw.trim();
    if (text.isEmpty) return null;
    try {
      if (text.startsWith('http://') || text.startsWith('https://')) {
        return Uri.parse(text);
      }
      return Uri.parse('https://$text');
    } catch (_) {
      return null;
    }
  }

  String _formatTimestamp(DateTime? value) {
    if (value == null) return 'Never synced';
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    final local = value.toLocal();
    final date =
        '${local.year}-${twoDigits(local.month)}-${twoDigits(local.day)}';
    final time = '${twoDigits(local.hour)}:${twoDigits(local.minute)}';
    return '$date $time';
  }

  String _statusLabel(SyncStatusState state) {
    if (state.isRunning) return 'Syncing';
    if (state.hasConflicts) return 'Conflict';
    if (state.lastErrorSummary != null) return 'Failed';
    if (state.lastCompletedAt != null) return 'Synced';
    return 'Ready';
  }

  Color _statusColor(SyncStatusState state) {
    if (state.hasConflicts || state.lastErrorSummary != null) {
      return AppColors.error;
    }
    if (state.isRunning) return AppColors.accent;
    return AppColors.subtleText;
  }

  SyncTargetConfig? _buildConfigFromForm() {
    if (_selectedType == SyncTargetType.webDav) {
      final baseUri = _webDavBaseUriController.text.trim();
      final username = _webDavUsernameController.text.trim();
      final password = _webDavPasswordController.text.trim();
      if (baseUri.isEmpty || username.isEmpty || password.isEmpty) return null;

      final parsedUri = _ensureScheme(baseUri);
      if (parsedUri == null) return null;

      return SyncTargetConfig(
        activeType: SyncTargetType.webDav,
        webDav: WebDavSyncTargetConfig(
          baseUri: parsedUri,
          username: username,
          password: password,
          rootPath: _webDavRootPathController.text.trim(),
        ),
      );
    }

    final endpoint = _s3EndpointController.text.trim();
    final region = _s3RegionController.text.trim();
    final bucket = _s3BucketController.text.trim();
    final accessKey = _s3AccessKeyController.text.trim();
    final secretKey = _s3SecretKeyController.text.trim();
    if (endpoint.isEmpty || region.isEmpty || bucket.isEmpty ||
        accessKey.isEmpty || secretKey.isEmpty) {
      return null;
    }

    final parsedEndpoint = _ensureScheme(endpoint);
    if (parsedEndpoint == null) return null;

    return SyncTargetConfig(
      activeType: SyncTargetType.s3Compatible,
      s3: S3SyncTargetConfig(
        endpoint: parsedEndpoint,
        region: region,
        bucket: bucket,
        accessKey: accessKey,
        secretKey: secretKey,
        sessionToken: _s3SessionTokenController.text.trim().isNotEmpty
            ? _s3SessionTokenController.text.trim()
            : null,
        rootPrefix: _s3RootPrefixController.text.trim(),
        addressingStyle: _s3AddressingStyle,
      ),
    );
  }

  SyncStorageAdapter _createAdapterFromConfig(SyncTargetConfig config) {
    if (config.activeType == SyncTargetType.webDav) {
      final webDavConfig = config.webDav!.toAdapterConfig();
      return ref.read(webDavStorageAdapterProvider(webDavConfig));
    }
    final s3Config = config.s3!.toAdapterConfig();
    return ref.read(s3StorageAdapterProvider(s3Config));
  }

  // ─── Actions ─────────────────────────────────────────────

  Future<void> _handleSave() async {
    final config = _buildConfigFromForm();
    if (config == null) {
      showLocalFeedback(
        context,
        'Please fill in all required fields.',
        tone: LocalFeedbackTone.error,
      );
      return;
    }

    setState(() => _pendingAction = _SyncTargetAction.saving);
    try {
      final store = ref.read(syncTargetStoreProvider);
      await store.write(config);
      ref.invalidate(syncTargetConfigProvider);
      if (mounted) {
        showLocalFeedback(context, 'Sync target saved.');
      }
    } catch (error) {
      if (mounted) {
        showLocalFeedback(
          context,
          'Failed to save: $error',
          tone: LocalFeedbackTone.error,
        );
      }
    } finally {
      if (mounted) {
        setState(() => _pendingAction = _SyncTargetAction.none);
      }
    }
  }

  Future<void> _handleTestConnection() async {
    SyncTargetConfig? config;

    final savedConfig = ref.read(syncTargetConfigProvider).valueOrNull;
    if (savedConfig != null && savedConfig.hasActiveTarget) {
      config = savedConfig;
    } else {
      config = _buildConfigFromForm();
    }

    if (config == null) {
      showLocalFeedback(
        context,
        'Please save a configuration before testing.',
        tone: LocalFeedbackTone.error,
      );
      return;
    }

    setState(() {
      _pendingAction = _SyncTargetAction.testing;
      _testResult = null;
    });

    try {
      final adapter = _createAdapterFromConfig(config);
      final testService = ref.read(syncConnectionTestServiceProvider);
      final result = await testService.testAdapter(adapter);

      if (mounted) {
        setState(() => _testResult = result);
        showLocalFeedback(
          context,
          result.message,
          tone: result.success
              ? LocalFeedbackTone.success
              : LocalFeedbackTone.error,
        );
      }
    } catch (error) {
      if (mounted) {
        setState(() {
          _testResult = const SyncConnectionTestResult(
            success: false,
            message: 'Connection test failed unexpectedly.',
          );
        });
        showLocalFeedback(
          context,
          'Connection test failed unexpectedly.',
          tone: LocalFeedbackTone.error,
        );
      }
    } finally {
      if (mounted) {
        setState(() => _pendingAction = _SyncTargetAction.none);
      }
    }
  }

  Future<void> _handleDisconnect() async {
    setState(() => _pendingAction = _SyncTargetAction.disconnecting);
    try {
      final store = ref.read(syncTargetStoreProvider);
      await store.clear();
      ref.invalidate(syncTargetConfigProvider);
      if (mounted) {
        setState(() => _testResult = null);
        showLocalFeedback(context, 'Sync target disconnected.');
      }
    } catch (error) {
      if (mounted) {
        showLocalFeedback(
          context,
          'Failed to disconnect: $error',
          tone: LocalFeedbackTone.error,
        );
      }
    } finally {
      if (mounted) {
        setState(() => _pendingAction = _SyncTargetAction.none);
      }
    }
  }

  Future<void> _handleSyncNow() async {
    final config = ref.read(syncTargetConfigProvider).valueOrNull;
    if (config == null || !config.hasActiveTarget) return;

    setState(() => _pendingAction = _SyncTargetAction.syncing);
    try {
      final adapter = _createAdapterFromConfig(config);
      final ops = ref.read(syncOperationsServiceProvider);
      await ops.runSyncWithConfig(adapter);
      ref.invalidate(syncPendingItemsProvider);
      if (mounted) {
        showLocalFeedback(context, 'Sync completed.');
      }
    } catch (error) {
      if (mounted) {
        showLocalFeedback(
          context,
          'Sync failed: $error',
          tone: LocalFeedbackTone.error,
        );
      }
    } finally {
      if (mounted) {
        setState(() => _pendingAction = _SyncTargetAction.none);
      }
    }
  }

  Future<void> _handleRetryAll() async {
    final config = ref.read(syncTargetConfigProvider).valueOrNull;
    if (config == null || !config.hasActiveTarget) return;

    setState(() => _pendingAction = _SyncTargetAction.syncing);
    try {
      final adapter = _createAdapterFromConfig(config);
      final ops = ref.read(syncOperationsServiceProvider);
      await ops.retryAllPending(adapter);
      ref.invalidate(syncPendingItemsProvider);
      if (mounted) {
        showLocalFeedback(context, 'Retry completed.');
      }
    } catch (error) {
      if (mounted) {
        showLocalFeedback(
          context,
          'Retry failed: $error',
          tone: LocalFeedbackTone.error,
        );
      }
    } finally {
      if (mounted) {
        setState(() => _pendingAction = _SyncTargetAction.none);
      }
    }
  }
}
