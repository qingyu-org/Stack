import 'package:flutter/services.dart';

/// 全局触感反馈开关。
///
/// Flutter 没有运行时关闭系统触感的 API，因此统一由这里转发；
/// [MyApp] 在设置变化时同步 [enabled]，各处的震动调用都走这里。
class AppHaptics {
  AppHaptics._();

  /// 默认关闭，避免部分用户不喜欢突然的震动。
  static bool enabled = false;

  static void lightImpact() {
    if (enabled) HapticFeedback.lightImpact();
  }

  static void mediumImpact() {
    if (enabled) HapticFeedback.mediumImpact();
  }

  static void selectionClick() {
    if (enabled) HapticFeedback.selectionClick();
  }
}
