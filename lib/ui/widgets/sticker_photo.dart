import 'dart:io';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:material_ui/material_ui.dart';

/// 贴纸式照片：白边 + 底部留白 + -2.2° 旋转 + 投影。
///
/// 数值对齐 `docs/UI-规格-M3.md` 第 6 节：
/// 外框 150 宽、白边 5、下留白 22（宝丽来式）、旋转 -2.2°、
/// 阴影 `0 8 18 -10 rgba(23,95,85,.5)`、图片区 140×98 cover。
class StickerPhoto extends StatelessWidget {
  const StickerPhoto({
    super.key,
    required this.file,
    this.width = 150,
    this.rotate = -2.2,
    this.decoded,
    this.cacheWidth,
  });

  final File file;
  final double width;
  final double rotate;

  /// 已解码的图像。headless golden 环境里 `Image.file` 的异步解码不完成
  /// （截图会是空白白边），用它兜底验证贴纸样式；真机不传这个参数。
  final ui.Image? decoded;

  /// 解码宽度。插图现在存的是原图（为了保住 EXIF，动辄几 MB），
  /// 直接 `Image.file` 会把整张原图解码进内存。这里按逻辑宽的 3 倍解码，
  /// 一屏几十张图也不会把内存吃穿。
  final int? cacheWidth;

  @override
  Widget build(BuildContext context) {
    const pad = 5.0;
    final imgWidth = width - pad * 2;

    return Transform.rotate(
      angle: rotate * math.pi / 180,
      child: Container(
        width: width,
        padding: const EdgeInsets.fromLTRB(pad, pad, pad, 22),
        decoration: BoxDecoration(
          color: Colors.white,
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF175F55).withValues(alpha: 0.5),
              offset: const Offset(0, 8),
              blurRadius: 18,
              spreadRadius: -10,
            ),
          ],
        ),
        child: decoded != null
            ? RawImage(
                image: decoded,
                width: imgWidth,
                height: 98,
                fit: BoxFit.cover,
              )
            : Image.file(
                file,
                width: imgWidth,
                height: 98,
                fit: BoxFit.cover,
                cacheWidth: cacheWidth ?? (imgWidth * 3).round(),
                errorBuilder: (context, error, stack) => Container(
                  width: imgWidth,
                  height: 98,
                  color: const Color(0xFFE4EFF8),
                  alignment: Alignment.center,
                  child: const Text(
                    '图片读取失败',
                    style: TextStyle(fontSize: 11, color: Color(0xFF8BA49C)),
                  ),
                ),
              ),
      ),
    );
  }
}
