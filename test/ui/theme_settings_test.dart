import 'package:envx/core/settings.dart';
import 'package:envx/core/theme_runtime.dart';
import 'package:envx/ui/widgets/cover.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

void main() {
  test('主题色：切到靛蓝生效，未知 key 回落薄雾绿', () {
    ThemeRuntime.apply('indigo');
    expect(ThemeRuntime.value.key, 'indigo');
    expect(ThemeRuntime.value.label, '靛蓝');
    expect(ThemeRuntime.value.accent, const Color(0xFF2E4C7A));

    ThemeRuntime.apply('不存在的主题');
    expect(ThemeRuntime.value.key, 'mist');
    expect(ThemeRuntime.value.accent, const Color(0xFF1F7A6E));
  });

  test('自定义信封三色：槽位色取设置，描边由底色压暗', () {
    SettingsRuntime.value = const AppSettings(
      coverScheme: CoverPalette.kCustomKey,
      customCover: [0xFFEEDDCC, 0xFFDDEEFF, 0xFFFFEEDD],
    );

    expect(CoverPalette.current.key, CoverPalette.kCustomKey);
    expect(CoverPalette.current.label, '自定义');
    expect(CoverPalette.current.colors['sun'], const Color(0xFFEEDDCC));
    expect(CoverPalette.current.colors['sky'], const Color(0xFFDDEEFF));
    expect(CoverPalette.current.colors['blush'], const Color(0xFFFFEEDD));

    const base = Color(0xFFEEDDCC);
    final accent = CoverPalette.accentOf(base);
    expect(accent, isNot(base));
    expect(
      HSLColor.fromColor(accent).lightness,
      lessThan(HSLColor.fromColor(base).lightness),
      reason: '描边要比底色深，否则封口线看不出来',
    );
  });

  test('切回固定方案：自定义的三色不再顶替槽位', () {
    SettingsRuntime.value = const AppSettings(coverScheme: 'sand');
    expect(CoverPalette.current.key, 'sand');
    expect(CoverPalette.current.colors['sun'], const Color(0xFFF7E4C2));
  });
}
