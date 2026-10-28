import 'package:flutter/material.dart';

/// 设计 token 集中定义。组件优先引用这里的值，避免散落的魔法数字；
/// 固定渐变背景上的文字色属于视觉例外，不进入全局 token。
class AppTokens {
  const AppTokens._();

  // 8pt 栅格
  static const double spacingXs = 4;
  static const double spacingSm = 8;
  static const double spacingMd = 16;
  static const double spacingLg = 24;
  static const double spacingXl = 32;

  static const double radiusSm = 8;
  static const double radiusMd = 16;
  static const double radiusLg = 24;

  static const double minTouchTarget = 44;

  // 品牌色（天空蓝）
  static const Color seed = Color(0xFF2D7FF9);

  /// 白天/夜间背景渐变，按天气分组取用。
  static const List<Color> dayGradient = <Color>[
    Color(0xFF4A90D9),
    Color(0xFF7FB5E8),
  ];

  static const List<Color> nightGradient = <Color>[
    Color(0xFF1B2942),
    Color(0xFF2E4468),
  ];

  static const List<Color> rainGradient = <Color>[
    Color(0xFF4B5B6E),
    Color(0xFF76889B),
  ];
}
