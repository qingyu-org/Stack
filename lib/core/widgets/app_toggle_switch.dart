import 'package:flutter/cupertino.dart';
import 'package:liquid_glass_widgets/liquid_glass_widgets.dart';

import '../performance/performance_mode.dart';

class AppToggleSwitch extends StatelessWidget {
  const AppToggleSwitch({
    super.key,
    required this.value,
    required this.onChanged,
  });

  final bool value;
  final ValueChanged<bool>? onChanged;

  @override
  Widget build(BuildContext context) {
    // 性能模式下去掉液态玻璃开关，改用系统开关。
    final Widget toggle = PerformanceModeScope.of(context)
        ? CupertinoSwitch(
            value: value,
            activeTrackColor: CupertinoColors.systemBlue.resolveFrom(context),
            onChanged: onChanged,
          )
        : GlassSwitch(
            value: value,
            onChanged: onChanged ?? (_) {},
            activeColor: CupertinoColors.systemBlue.resolveFrom(context),
            useOwnLayer: true,
            quality: GlassQuality.premium,
          );
    if (onChanged != null) return toggle;

    return Semantics(
      toggled: value,
      enabled: false,
      child: ExcludeSemantics(
        child: IgnorePointer(child: Opacity(opacity: 0.5, child: toggle)),
      ),
    );
  }
}
