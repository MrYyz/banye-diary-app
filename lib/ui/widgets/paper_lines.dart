import 'package:material_ui/material_ui.dart';

/// 信纸横线。
///
/// 铁律：线周期 28 必须等于正文行盒（fontSize 14 × height 2.0 = 28）。
/// 设计稿的 `repeating-linear-gradient` 从 **padding box** 顶部起算，
/// 所以第 n 条线落在 `contentTop + 27 + 28*(n-1)`，正好压在第 n 行文字的底部 1px。
///
/// 不要在 Flutter 里用 `Container` 背景图代替：`DecorationImage` 的起点是
/// border box，会整体偏 contentTop（这里是 24px），文字就会浮在线的中间。
class PaperLinesPainter extends CustomPainter {
  const PaperLinesPainter({
    required this.contentTop,
    required this.horizontalInset,
    this.lineColor = const Color(0xFFF3F9F6),
    this.period = 28.0,
    this.lineWidth = 1.0,
  });

  /// 内容区顶部（= 信纸 padding-top）。
  final double contentTop;

  /// 左右内缩（= 信纸 padding-left/right），线不画到圆角里。
  final double horizontalInset;

  final Color lineColor;
  final double period;
  final double lineWidth;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = lineColor;
    final width = size.width - horizontalInset * 2;
    if (width <= 0) return;

    var y = contentTop + period - lineWidth;
    while (y < size.height) {
      canvas.drawRect(
        Rect.fromLTWH(horizontalInset, y, width, lineWidth),
        paint,
      );
      y += period;
    }
  }

  @override
  bool shouldRepaint(covariant PaperLinesPainter old) =>
      old.contentTop != contentTop ||
      old.horizontalInset != horizontalInset ||
      old.lineColor != lineColor ||
      old.period != period ||
      old.lineWidth != lineWidth;
}
