import 'package:material_ui/material_ui.dart';

import '../theme.dart';

/// 空态：信封轮廓 + 主文案 + 副文案。首页 / 笔记列表 / 搜索无结果共用。
class EmptyState extends StatelessWidget {
  const EmptyState({
    super.key,
    required this.title,
    required this.subtitle,
    this.icon = Icons.mail_outline,
  });

  final String title;
  final String subtitle;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 44, color: EnvxColors.ink3),
          const SizedBox(height: 14),
          Text(
            title,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: EnvxColors.ink,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            subtitle,
            style: const TextStyle(fontSize: 11.5, color: EnvxColors.ink3),
          ),
        ],
      ),
    );
  }
}
