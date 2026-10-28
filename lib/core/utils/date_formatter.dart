/// 日期/时间格式化。
///
/// 所有时间字符串都来自 API，且已按 `timezone=auto` 返回**地点本地时间**。
/// 这里仅做「墙上时钟」格式化，**不**把 DateTime 转换为设备时区，
/// 否则跨时区查询会出现日期偏移。
class AppDateFormatter {
  const AppDateFormatter._();

  /// 例：14:00
  static String hour(DateTime time) =>
      '${time.hour.toString().padLeft(2, '0')}:00';

  /// 例：14:05
  static String hourMinute(DateTime time) =>
      '${time.hour.toString().padLeft(2, '0')}:'
      '${time.minute.toString().padLeft(2, '0')}';

  /// 温度：保留 1 位小数，整数则不显示小数位。
  static String temperature(double value) {
    final rounded = value.roundToDouble();
    if ((value - rounded).abs() < 0.05) return rounded.toInt().toString();
    return value.toStringAsFixed(1);
  }

  /// 温度区间：`18° / 26°`
  static String temperatureRange(double min, double max) =>
      '${temperature(min)}° / ${temperature(max)}°';
}
