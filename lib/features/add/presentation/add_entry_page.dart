import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/router/app_router.dart';
import '../../../shared/data/app_database.dart';
import '../../../shared/theme/app_theme.dart';
import '../../../shared/widgets/local_feedback.dart';
import '../data/add_entry_controller.dart';

class AddEntryPage extends ConsumerStatefulWidget {
  const AddEntryPage({super.key});

  @override
  ConsumerState<AddEntryPage> createState() => _AddEntryPageState();
}

class _AddEntryPageState extends ConsumerState<AddEntryPage> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _subtitleController = TextEditingController();
  final _yearController = TextEditingController();
  final _overviewController = TextEditingController();
  final _measureController = TextEditingController();
  final _tagsController = TextEditingController();
  final _shelvesController = TextEditingController();

  MediaType _mediaType = MediaType.movie;
  bool _isSaving = false;

  @override
  void dispose() {
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
    final theme = Theme.of(context);

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.xxxl,
        AppSpacing.xxxl,
        AppSpacing.xxxl,
        AppSpacing.xxxl,
      ),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 760),
          child: Container(
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
                  Text(
                    'Create Local Entry',
                    style: AppTextStyles.heroTitle(theme),
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  Text(
                    'Start with a minimal local record. Bangumi search can layer on later.',
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
          ),
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
          decoration: decoration('Tags', hintText: 'Comma separated'),
          enabled: !_isSaving,
        ),
        const SizedBox(height: AppSpacing.lg),
        TextFormField(
          controller: _shelvesController,
          style: fieldTextStyle,
          decoration: decoration('Lists', hintText: 'Comma separated'),
          enabled: !_isSaving,
        ),
      ],
    );
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    final controller = ref.read(addEntryControllerProvider);
    final releaseDate = _parseYear(_yearController.text);
    final measure = _parseMeasure(_measureController.text);

    setState(() => _isSaving = true);

    try {
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

      showLocalFeedback(context, 'Saved locally.');
      context.go(AppRoutes.detailFor(mediaId));
    } catch (error) {
      if (!mounted) {
        return;
      }
      showLocalFeedback(context, 'Could not save the entry.');
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
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
