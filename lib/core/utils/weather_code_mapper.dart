import 'package:flutter/material.dart';

/// 天气分组，用于挑选背景渐变与图标动画。
enum WeatherGroup { clear, cloudy, rain, snow, thunder, fog }

/// 视觉描述：图标 + 分组。
///
/// 文案不在这里：同一份天气代码要按当前语言显示（见
/// `AppStrings.weatherLabel`），把中文写在映射表里会让英文界面露出中文。
typedef WeatherVisual = ({IconData icon, WeatherGroup group});

/// WMO 天气代码（0-99）→ 图标与分组。
///
/// 映射表集中在此文件，便于单元测试与扩展；界面组件不感知代码含义。
/// 参考：Open-Meteo `weather_code` 文档的 WMO Weather interpretation codes。
WeatherVisual describeWeatherCode(int code, {bool isDay = true}) {
  switch (code) {
    case 0:
    case 1:
      return (
        icon: isDay ? Icons.wb_sunny_outlined : Icons.nightlight_round,
        group: WeatherGroup.clear,
      );
    case 2:
      return (icon: Icons.cloud_queue, group: WeatherGroup.cloudy);
    case 3:
      return (icon: Icons.cloud_outlined, group: WeatherGroup.cloudy);
    case 45:
    case 48:
      return (icon: Icons.blur_on, group: WeatherGroup.fog);
    case 51:
    case 53:
    case 55:
      return (icon: Icons.grain, group: WeatherGroup.rain);
    case 56:
    case 57:
      return (icon: Icons.ac_unit, group: WeatherGroup.rain);
    case 61:
    case 63:
    case 65:
      return (icon: Icons.water_drop_outlined, group: WeatherGroup.rain);
    case 66:
    case 67:
      return (icon: Icons.ac_unit, group: WeatherGroup.rain);
    case 71:
    case 73:
    case 75:
    case 77:
      return (icon: Icons.ac_unit, group: WeatherGroup.snow);
    case 80:
    case 81:
    case 82:
      return (icon: Icons.grain, group: WeatherGroup.rain);
    case 85:
    case 86:
      return (icon: Icons.ac_unit, group: WeatherGroup.snow);
    case 95:
      return (icon: Icons.bolt, group: WeatherGroup.thunder);
    case 96:
    case 99:
      return (icon: Icons.bolt, group: WeatherGroup.thunder);
    default:
      return (icon: Icons.help_outline, group: WeatherGroup.cloudy);
  }
}
