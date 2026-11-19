import 'package:material_ui/material_ui.dart';

import '../../data/schema.dart';
import '../theme.dart';

/// 编辑器草稿。取消返回 null。
class NoteDraft {
  const NoteDraft({required this.title, required this.body});

  final String title;
  final String body;
}

/// M2 最简文本编辑对话框：标题 + 正文两行字段，不做 M3 的信纸横线。
Future<NoteDraft?> showNoteEditor(
  BuildContext context, {
  Note? existing,
}) async {
  final titleController = TextEditingController(text: existing?.title ?? '');
  final bodyController = TextEditingController(text: existing?.body ?? '');
  final result = await showDialog<NoteDraft>(
    context: context,
    builder: (context) => AlertDialog(
      backgroundColor: EnvxColors.paper,
      title: Text(existing == null ? '写新的一封' : '编辑这封信'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: titleController,
            decoration: const InputDecoration(
              hintText: '标题',
              hintStyle: TextStyle(color: EnvxColors.ink3),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: bodyController,
            maxLines: 5,
            decoration: const InputDecoration(
              hintText: '正文',
              hintStyle: TextStyle(color: EnvxColors.ink3),
              alignLabelWithHint: true,
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('取消', style: TextStyle(color: EnvxColors.ink2)),
        ),
        TextButton(
          onPressed: () => Navigator.of(context).pop(
            NoteDraft(
              title: titleController.text.trim(),
              body: bodyController.text,
            ),
          ),
          child: const Text('完成', style: TextStyle(color: EnvxColors.mint700)),
        ),
      ],
    ),
  );
  titleController.dispose();
  bodyController.dispose();
  return result;
}
