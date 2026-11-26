import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';
import 'package:liquid_glass_widgets/liquid_glass_widgets.dart';

import '../../../../core/performance/performance_mode.dart';
import '../../../../core/theme/app_theme.dart';
import 'package:mono_dash/core/utils/app_haptics.dart';

/// 过滤器项数据模型
class FilterItem {
  final String label;
  final String value;
  final IconData? icon;

  const FilterItem({required this.label, required this.value, this.icon});
}

/// 磨砂玻璃风格的横向过滤器栏
///
/// 常用于列表顶部的分类筛选，支持粘性固定（结合 Stack 或 Sliver 使用）。
class FrostedFilterBar extends StatelessWidget {
  const FrostedFilterBar({
    super.key,
    required this.items,
    required this.selectedValue,
    required this.onSelected,
    this.overlaps = false,
  });

  /// 过滤器选项列表
  final List<FilterItem> items;

  /// 当前选中的值
  final String selectedValue;

  /// 选中回调
  final ValueChanged<String> onSelected;

  /// 是否有内容经过下方（控制透明度和阴影）
  final bool overlaps;

  @override
  Widget build(BuildContext context) {
    final isDark = CupertinoTheme.brightnessOf(context) == Brightness.dark;
    final reduceEffects = PerformanceModeScope.of(context);
    final glassSettings = LiquidGlassSettings.figma(
      refraction: 42,
      depth: 35,
      dispersion: 5,
      frost: 1,
      glassColor: isDark
          ? const Color(0xFF2C2C2E).withValues(alpha: 0.42)
          : const Color(0xFFE5E5EA).withValues(alpha: 0.55),
      lightIntensity: 76,
    );
    // 性能模式下去掉液态玻璃着色器，改用接近不透明的实色表面。
    final surfaceColor = reduceEffects
        ? (isDark
              ? const Color(0xFF2C2C2E).withValues(alpha: 0.95)
              : const Color(0xFFFFFFFF).withValues(alpha: 0.95))
        : (isDark
              ? const Color(0xFF3A3A3C).withValues(alpha: 0.78)
              : const Color(0xFFFFFFFF).withValues(alpha: 0.65));

    final content = ClipRRect(
      borderRadius: BorderRadius.circular(18),
      child: Stack(
        children: [
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: surfaceColor,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(
                  color: isDark
                      ? CupertinoColors.white.withValues(alpha: 0.08)
                      : const Color(0xFFE8E8E8),
                  width: 0.5,
                ),
              ),
            ),
          ),
          ListView.builder(
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(),
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 7),
            itemCount: items.length,
            itemBuilder: (context, index) {
              final item = items[index];
              final selected = item.value == selectedValue;
              return _FilterButton(
                label: item.label,
                icon: item.icon,
                selected: selected,
                onPressed: () => onSelected(item.value),
              );
            },
          ),
        ],
      ),
    );

    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 4, 14, 8),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        height: 46,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(18),
          boxShadow: overlaps
              ? [
                  BoxShadow(
                    color: CupertinoColors.black.withValues(alpha: 0.05),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ]
              : null,
        ),
        child: reduceEffects
            ? content
            : LiquidGlassLayer(
                settings: glassSettings,
                child: AdaptiveGlass.grouped(
                  quality: GlassQuality.premium,
                  shape: const LiquidRoundedRectangle(borderRadius: 18),
                  child: content,
                ),
              ),
      ),
    );
  }
}

class _FilterButton extends StatelessWidget {
  const _FilterButton({
    required this.label,
    this.icon,
    required this.selected,
    required this.onPressed,
  });

  final String label;
  final IconData? icon;
  final bool selected;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final color = selected
        ? CupertinoColors.activeBlue.resolveFrom(context)
        : AppColors.secondaryLabel(context);
    return Padding(
      padding: const EdgeInsets.only(right: 7),
      child: CupertinoButton(
        padding: EdgeInsets.zero,
        minimumSize: Size.zero,
        onPressed: () {
          AppHaptics.selectionClick();
          onPressed();
        },
        child: Container(
          height: 32,
          padding: EdgeInsets.only(left: icon == null ? 12 : 10, right: 12),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: selected
                ? color.withValues(alpha: 0.13)
                : AppColors.tertiaryBackground(context).withValues(alpha: 0.5),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (icon != null) ...[
                Icon(icon, size: 16, color: color),
                const SizedBox(width: 5),
              ],
              Text(
                label,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: selected ? FontWeight.w700 : FontWeight.w600,
                  color: color,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
