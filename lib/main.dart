import 'package:material_ui/material_ui.dart';

import 'ui/theme.dart';
import 'ui/bootstrap_page.dart';
import 'ui/widgets/lock_gate.dart';

void main() => runApp(const EnvxApp());

class EnvxApp extends StatelessWidget {
  const EnvxApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: '信封日记',
      debugShowCheckedModeBanner: false,
      theme: EnvxTheme.build(),
      // 锁门放在 builder 里，才能盖住所有 push 出来的页面
      // （笔记列表、编辑器、隐藏区），而不只是首页。
      builder: (context, child) =>
          LockGate(child: child ?? const SizedBox.shrink()),
      home: const BootstrapPage(),
    );
  }
}
