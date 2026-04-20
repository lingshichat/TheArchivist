import 'package:flutter/material.dart';

import '../../../shared/theme/app_theme.dart';
import '../../../shared/widgets/empty_state.dart';

class AddEntryPage extends StatelessWidget {
  const AddEntryPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xxxl),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 520),
          child: const EmptyState(
            icon: Icons.construction_outlined,
            title: 'Coming soon',
            body:
                '添加条目流程将在阶段 2 与 Bangumi 搜索一起实现。'
                '当前阶段专注桌面骨架与本地数据模型。',
          ),
        ),
      ),
    );
  }
}
