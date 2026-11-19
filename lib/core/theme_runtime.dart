import 'package:material_ui/material_ui.dart';

/// 一套主题色。
///
/// 只换「强调色」—— 按钮、隐藏区入口条、开关开态这些地方。
/// 正文色与信纸底色一律不动：那两处一改，阅读对比就塌了，
/// 而日记最需要的是长时间阅读不累。
class ThemePreset {
  const ThemePreset({
    required this.key,
    required this.label,
    required this.accent,
    required this.soft,
  });

  final String key;
  final String label;

  /// 主强调色（原来 `EnvxColors.mint700` 的位置）。
  final Color accent;

  /// 浅强调色（原来 `EnvxColors.mint500` 的位置）。
  final Color soft;
}

const List<ThemePreset> kThemePresets = [
  ThemePreset(
    key: 'mist',
    label: '薄雾绿',
    accent: Color(0xFF1F7A6E),
    soft: Color(0xFF3AAFA0),
  ),
  ThemePreset(
    key: 'indigo',
    label: '靛蓝',
    accent: Color(0xFF2E4C7A),
    soft: Color(0xFF6C8FC7),
  ),
  ThemePreset(
    key: 'clay',
    label: '陶土',
    accent: Color(0xFF8A4E3C),
    soft: Color(0xFFC0836C),
  ),
  ThemePreset(
    key: 'plum',
    label: '莓紫',
    accent: Color(0xFF7A3B57),
    soft: Color(0xFFB87395),
  ),
];

/// 运行时主题快照。和 `SettingsRuntime` 一样是内存副本：
/// 设置页改完立刻写这里，其他页面下次构建就读到新色。
class ThemeRuntime {
  ThemeRuntime._();

  static ThemePreset value = kThemePresets.first;

  static void apply(String key) {
    for (final preset in kThemePresets) {
      if (preset.key == key) {
        value = preset;
        return;
      }
    }
    value = kThemePresets.first;
  }
}
