import 'dart:ui';

import 'package:flutter/widgets.dart';

/// 性能模式开关。
///
/// 打开后只关闭开销较大的“高级特效”——毛玻璃模糊、液态玻璃着色器、
/// 流光/脉冲等持续动画；页面转场、淡入淡出、颜色过渡等基础动画全部保留。
class PerformanceModeScope extends InheritedWidget {
  const PerformanceModeScope({
    super.key,
    required this.enabled,
    required super.child,
  });

  final bool enabled;

  static bool of(BuildContext context) {
    return context
            .dependOnInheritedWidgetOfExactType<PerformanceModeScope>()
            ?.enabled ??
        false;
  }

  @override
  bool updateShouldNotify(PerformanceModeScope oldWidget) {
    return oldWidget.enabled != enabled;
  }
}

/// 性能模式下直接跳过 [BackdropFilter]，保留普通内容。
///
/// 实时背景模糊需要每帧额外采样和合成，是低端设备掉帧的主要来源之一。
class PerformanceAwareBlur extends StatelessWidget {
  const PerformanceAwareBlur({
    super.key,
    required this.sigma,
    required this.child,
  });

  final double sigma;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    if (PerformanceModeScope.of(context)) return child;
    return BackdropFilter(
      filter: ImageFilter.blur(sigmaX: sigma, sigmaY: sigma),
      child: child,
    );
  }
}
