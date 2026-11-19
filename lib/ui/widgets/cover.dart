import 'package:material_ui/material_ui.dart';

import '../../core/settings.dart';
import '../theme.dart';

/// 一套信封配色方案：三个槽位（sun / sky / blush）各自一对「底色 + 加深描边」。
///
/// `Notebook.color` 里存的是槽位名，不是颜色值 —— 所以换方案时，
/// 已有的笔记本会一起换色，不需要改库。
class CoverScheme {
  const CoverScheme({
    required this.key,
    required this.label,
    required this.colors,
    required this.accents,
  });

  final String key;
  final String label;
  final Map<String, Color> colors;
  final Map<String, Color> accents;
}

/// 封面三色色板与 key 的映射。`Notebook.color` 存 key（sun/sky/blush），
/// null 或未知 key 时按 index 轮换。
class CoverPalette {
  const CoverPalette._();

  static const List<String> keys = ['sun', 'sky', 'blush'];

  /// 自定义方案的 key：色值不在 `schemes` 里，运行时从设置读。
  static const String kCustomKey = 'custom';

  /// 自定义配色的候选色。都偏浅 —— 信封底色要压得住正文，
  /// 太深的话封面上那行字就读不清了。
  static const List<int> swatches = [
    0xFFF7E4C2,
    0xFFF2D9CE,
    0xFFF8D3D9,
    0xFFEBD8E6,
    0xFFCFDFE8,
    0xFFDDEAE4,
    0xFFE2E2EC,
    0xFFEFEFE7,
    0xFFD3E8D4,
    0xFFF4E9CF,
    0xFFE4DDF3,
    0xFFDCE5F5,
  ];

  /// 四套可选方案。顺序即设置页展示顺序，第一套为默认。
  static const List<CoverScheme> schemes = [
    CoverScheme(
      key: 'mist',
      label: '薄雾绿',
      colors: {
        'sun': EnvxColors.sun,
        'sky': EnvxColors.sky,
        'blush': EnvxColors.blush,
      },
      accents: {
        'sun': Color(0xFFE0C077),
        'sky': Color(0xFFA6CBE6),
        'blush': Color(0xFFEDB1C0),
      },
    ),
    CoverScheme(
      key: 'sand',
      label: '暖沙',
      colors: {
        'sun': Color(0xFFF7E4C2),
        'sky': Color(0xFFE6DAC6),
        'blush': Color(0xFFF2D9CE),
      },
      accents: {
        'sun': Color(0xFFE2C28D),
        'sky': Color(0xFFCBB59A),
        'blush': Color(0xFFDDB2A2),
      },
    ),
    CoverScheme(
      key: 'berry',
      label: '莓果',
      colors: {
        'sun': Color(0xFFFAD9C8),
        'sky': Color(0xFFEBD8E6),
        'blush': Color(0xFFF8D3D9),
      },
      accents: {
        'sun': Color(0xFFE5AE93),
        'sky': Color(0xFFCDAED0),
        'blush': Color(0xFFE8A8B4),
      },
    ),
    CoverScheme(
      key: 'ink',
      label: '墨青',
      colors: {
        'sun': Color(0xFFDDEAE4),
        'sky': Color(0xFFCFDFE8),
        'blush': Color(0xFFE2E2EC),
      },
      accents: {
        'sun': Color(0xFFAEC9BE),
        'sky': Color(0xFFA3C0D2),
        'blush': Color(0xFFB9B9CC),
      },
    ),
  ];

  /// 当前生效方案：读运行时设置；未知 key 回落到第一套。
  static CoverScheme get current {
    final key = SettingsRuntime.value.coverScheme;
    if (key == kCustomKey) return custom;
    for (final scheme in schemes) {
      if (scheme.key == key) return scheme;
    }
    return schemes.first;
  }

  /// 自定义方案：三色取自设置，描边由底色压暗推出来 ——
  /// 用户只挑三个底色，不用再把三遍描边也挑一遍。
  static CoverScheme get custom {
    final raw = SettingsRuntime.value.customCover;
    final colors = <String, Color>{};
    final accents = <String, Color>{};
    for (var i = 0; i < keys.length; i++) {
      final color = Color(i < raw.length ? raw[i] : kDefaultCustomCover[i]);
      colors[keys[i]] = color;
      accents[keys[i]] = accentOf(color);
    }
    return CoverScheme(
      key: kCustomKey,
      label: '自定义',
      colors: colors,
      accents: accents,
    );
  }

  /// 由底色推描边色：同色相、明度压 14%。自定义方案的描边靠它，
  /// 设置页的小色样也用它，两边看起来才是一套。
  static Color accentOf(Color color) {
    final hsl = HSLColor.fromColor(color);
    return hsl.withLightness((hsl.lightness - 0.14).clamp(0.0, 1.0)).toColor();
  }

  static Color resolve(String? key, int index) {
    final colors = current.colors;
    if (key != null && colors.containsKey(key)) return colors[key]!;
    return colors[keys[index % keys.length]]!;
  }

  static Color accent(String? key, int index) {
    final accents = current.accents;
    if (key != null && accents.containsKey(key)) return accents[key]!;
    return accents[keys[index % keys.length]]!;
  }

  /// 下一个封面色 key（换封面色循环用）。
  static String nextKey(String? current) {
    var i = keys.indexOf(current ?? '');
    i = (i + 1) % keys.length;
    return keys[i];
  }
}

/// 信封封面：底色 + 封口三角线 + 蜡封圆。首页卡片封面与列表小图标共用。
class EnvelopeCover extends StatelessWidget {
  const EnvelopeCover({
    super.key,
    required this.colorKey,
    required this.index,
    this.radius = 16,
    this.sealRadius = 6.5,
  });

  final String? colorKey;
  final int index;
  final double radius;
  final double sealRadius;

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: _CoverPainter(
        bg: CoverPalette.resolve(colorKey, index),
        accent: CoverPalette.accent(colorKey, index),
        radius: radius,
        sealRadius: sealRadius,
      ),
      size: Size.infinite,
    );
  }
}

class _CoverPainter extends CustomPainter {
  const _CoverPainter({
    required this.bg,
    required this.accent,
    required this.radius,
    required this.sealRadius,
  });

  final Color bg;
  final Color accent;
  final double radius;
  final double sealRadius;

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;

    canvas.drawRRect(
      RRect.fromRectAndRadius(Offset.zero & size, Radius.circular(radius)),
      Paint()..color = bg,
    );

    final flap = Path()
      ..moveTo(0, 0)
      ..lineTo(w / 2, h * 0.54)
      ..lineTo(w, 0);
    canvas.drawPath(
      flap,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.6
        ..strokeCap = StrokeCap.round
        ..color = accent,
    );

    canvas.drawCircle(
      Offset(w / 2, h * 0.54),
      sealRadius,
      Paint()..color = accent,
    );
  }

  @override
  bool shouldRepaint(covariant _CoverPainter oldDelegate) =>
      oldDelegate.bg != bg ||
      oldDelegate.accent != accent ||
      oldDelegate.radius != radius ||
      oldDelegate.sealRadius != sealRadius;
}
