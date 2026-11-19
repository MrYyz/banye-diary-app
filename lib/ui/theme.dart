import 'package:material_ui/material_ui.dart';

/// 薄荷雾色系，与界面稿保持同一套色板。
class EnvxColors {
  const EnvxColors._();

  static const mist = Color(0xFFEDF6F3);
  static const paper = Color(0xFFFBFDFC);

  static const mint700 = Color(0xFF1F7A6E);
  static const mint500 = Color(0xFF3AAFA0);
  static const mint100 = Color(0xFFDCF0EA);

  static const ink = Color(0xFF1E2E29);
  static const ink2 = Color(0xFF4E6760);
  static const ink3 = Color(0xFF8BA49C);

  static const sun = Color(0xFFFFE9B8);
  static const sky = Color(0xFFCFE6F7);
  static const blush = Color(0xFFFBD9E0);
}

class EnvxTheme {
  const EnvxTheme._();

  static ThemeData build() {
    final base = ThemeData(brightness: Brightness.light);
    return base.copyWith(
      scaffoldBackgroundColor: EnvxColors.mist,
      colorScheme: ColorScheme.fromSeed(
        seedColor: EnvxColors.mint700,
        primary: EnvxColors.mint700,
        surface: EnvxColors.paper,
      ),
      textTheme: base.textTheme.apply(
        bodyColor: EnvxColors.ink,
        displayColor: EnvxColors.ink,
      ),
    );
  }
}
