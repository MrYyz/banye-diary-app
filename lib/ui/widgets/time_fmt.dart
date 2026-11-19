/// 时间分组与展示文案，UI 层共用。
class TimeFmt {
  const TimeFmt._();

  static const _weekdays = ['周一', '周二', '周三', '周四', '周五', '周六', '周日'];

  /// 测试用：把"现在"钉在某一刻，golden 才不会因为跨天/跨小时漂移。
  /// 生产环境保持 null，一律走真实时钟。
  static DateTime? overrideNow;

  /// 全局"现在"。UI 里所有取当前时间的地方都走这里。
  static DateTime now() => overrideNow ?? DateTime.now();

  /// 顶部日期：`11月16日 周一`。
  static String dateLine(DateTime now) {
    return '${now.month}月${now.day}日 ${_weekdays[now.weekday - 1]}';
  }

  static bool _sameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  /// 卡片元信息里的相对时间：今天写过 / 昨天 / 本周 / 上周 / 更早。
  static String relative(int ms) {
    if (ms == 0) return '';
    final t = DateTime.fromMillisecondsSinceEpoch(ms);
    final now = TimeFmt.now();
    if (_sameDay(t, now)) return '今天写过';
    final diff = now.difference(t).inDays;
    if (diff == 1) return '昨天';
    if (diff < 7) return '本周';
    if (diff < 14) return '上周';
    return '更早';
  }

  /// 列表右侧时间：今天显示 HH:MM，更早显示 MM/DD。
  static String rowTime(int ms) {
    if (ms == 0) return '';
    final t = DateTime.fromMillisecondsSinceEpoch(ms);
    final now = TimeFmt.now();
    if (_sameDay(t, now)) {
      final hh = t.hour.toString().padLeft(2, '0');
      final mm = t.minute.toString().padLeft(2, '0');
      return '$hh:$mm';
    }
    final m = t.month.toString().padLeft(2, '0');
    final d = t.day.toString().padLeft(2, '0');
    return '$m/$d';
  }

  /// 分组：今天 / 上周 / 更早。
  static String groupOf(int ms) {
    if (ms == 0) return '更早';
    final t = DateTime.fromMillisecondsSinceEpoch(ms);
    final now = TimeFmt.now();
    if (_sameDay(t, now)) return '今天';
    final diff = now.difference(t).inDays;
    if (diff < 7) return '上周';
    return '更早';
  }
}
