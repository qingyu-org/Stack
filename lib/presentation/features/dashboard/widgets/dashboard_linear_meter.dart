import 'package:flutter/cupertino.dart';

import '../../../../core/performance/performance_mode.dart';

class DashboardLinearMeter extends StatelessWidget {
  const DashboardLinearMeter({
    super.key,
    required this.percent,
    required this.color,
  });

  final double percent;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final value = percent.clamp(0.0, 100.0) / 100;
    final bar = Container(
      height: 6,
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(3),
      ),
    );

    // 性能模式下不做进度条补间，直接跟随数据刷新。
    if (PerformanceModeScope.of(context)) {
      return FractionallySizedBox(
        alignment: Alignment.centerLeft,
        widthFactor: value,
        child: bar,
      );
    }

    return TweenAnimationBuilder<double>(
      duration: const Duration(milliseconds: 600),
      curve: Curves.easeOutCubic,
      tween: Tween<double>(begin: 0, end: value),
      builder: (context, value, _) {
        return FractionallySizedBox(
          alignment: Alignment.centerLeft,
          widthFactor: value,
          child: bar,
        );
      },
    );
  }
}
