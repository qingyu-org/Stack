import 'dart:math' as math;

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_tabler_icons/flutter_tabler_icons.dart';

import '../../../../core/localization/l10n_x.dart';
import '../../../../core/theme/app_theme.dart';
import '../utils/pro_data_utils.dart';

class ProCard extends StatelessWidget {
  const ProCard({
    super.key,
    this.title,
    this.trailing,
    required this.child,
    this.padding = const EdgeInsets.fromLTRB(14, 12, 14, 14),
    this.margin = const EdgeInsets.only(bottom: 12),
  });

  final String? title;
  final Widget? trailing;
  final Widget child;
  final EdgeInsets padding;
  final EdgeInsets margin;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: margin,
      padding: padding,
      decoration: BoxDecoration(
        color: AppColors.secondaryBackground(context).withValues(alpha: 0.68),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: AppColors.separator(context).withValues(alpha: 0.14),
          width: 0.6,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (title != null || trailing != null) ...[
            Row(
              children: [
                if (title != null)
                  Expanded(
                    child: Text(
                      title!,
                      style: TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 0.1,
                        color: AppColors.secondaryLabel(context),
                      ),
                    ),
                  )
                else
                  const Spacer(),
                if (trailing != null) trailing!,
              ],
            ),
            const SizedBox(height: 10),
          ],
          child,
        ],
      ),
    );
  }
}

class ProMetricData {
  const ProMetricData({
    required this.label,
    required this.value,
    this.icon,
    this.color,
  });

  final String label;
  final String value;
  final IconData? icon;
  final Color? color;
}

class ProMetricGrid extends StatelessWidget {
  const ProMetricGrid({
    super.key,
    required this.metrics,
    this.columns = 2,
    this.spacing = 8,
  });

  final List<ProMetricData> metrics;
  final int columns;
  final double spacing;

  @override
  Widget build(BuildContext context) {
    if (metrics.isEmpty) return const SizedBox.shrink();
    return LayoutBuilder(
      builder: (context, constraints) {
        final width =
            (constraints.maxWidth - spacing * (columns - 1)) / columns;
        return Wrap(
          spacing: spacing,
          runSpacing: spacing,
          children: [
            for (final metric in metrics)
              SizedBox(
                width: width,
                child: _ProMetricTile(metric: metric),
              ),
          ],
        );
      },
    );
  }
}

class _ProMetricTile extends StatelessWidget {
  const _ProMetricTile({required this.metric});

  final ProMetricData metric;

  @override
  Widget build(BuildContext context) {
    final color =
        metric.color ?? CupertinoColors.activeBlue.resolveFrom(context);
    return Container(
      padding: const EdgeInsets.fromLTRB(10, 9, 10, 10),
      decoration: BoxDecoration(
        color: AppColors.tertiaryBackground(context).withValues(alpha: 0.55),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (metric.icon != null) ...[
            Icon(metric.icon, size: 14, color: color.withValues(alpha: 0.9)),
            const SizedBox(width: 6),
          ],
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  metric.label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 10.5,
                    height: 1.1,
                    color: AppColors.secondaryLabel(context),
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  metric.value,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 19,
                    fontWeight: FontWeight.w700,
                    letterSpacing: -0.5,
                    height: 1.05,
                    color: AppColors.label(context),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class ProSegmented<T> extends StatelessWidget {
  const ProSegmented({
    super.key,
    required this.values,
    required this.labels,
    required this.selected,
    required this.onChanged,
  });

  final List<T> values;
  final List<String> labels;
  final T selected;
  final ValueChanged<T> onChanged;

  @override
  Widget build(BuildContext context) {
    final index = values.indexOf(selected);
    return CupertinoSlidingSegmentedControl<int>(
      groupValue: index < 0 ? 0 : index,
      thumbColor: AppColors.secondaryBackground(context),
      backgroundColor: AppColors.tertiaryBackground(
        context,
      ).withValues(alpha: 0.7),
      padding: const EdgeInsets.all(2),
      children: {
        for (var i = 0; i < values.length; i++)
          i: Padding(
            padding: const EdgeInsets.symmetric(vertical: 5, horizontal: 4),
            child: Text(
              labels[i],
              maxLines: 1,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: AppColors.label(context),
              ),
            ),
          ),
      },
      onValueChanged: (value) {
        if (value != null) onChanged(values[value]);
      },
    );
  }
}

class ProChartSeries {
  const ProChartSeries({
    required this.spots,
    required this.color,
    required this.label,
    this.showArea = true,
  });

  final List<FlSpot> spots;
  final Color color;
  final String label;
  final bool showArea;
}

class ProLineChart extends StatelessWidget {
  const ProLineChart({
    super.key,
    required this.labels,
    required this.series,
    this.height = 150,
    this.showLegend = true,
  });

  final List<String> labels;
  final List<ProChartSeries> series;
  final double height;
  final bool showLegend;

  @override
  Widget build(BuildContext context) {
    final allSpots = [for (final item in series) ...item.spots];
    if (allSpots.isEmpty) {
      return ProEmpty(
        message: proText(context, zh: '暂无趋势数据', en: 'No trend data yet'),
        compact: true,
      );
    }
    var maxY = allSpots.map((spot) => spot.y).reduce(math.max);
    if (maxY <= 0) maxY = 1;
    maxY *= 1.2;
    final maxX = math.max(1, labels.length - 1).toDouble();
    final interval = math.max(1, (labels.length / 4).floor()).toDouble();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (showLegend && series.length > 1) ...[
          Wrap(
            spacing: 14,
            children: [
              for (final item in series)
                _LegendDot(label: item.label, color: item.color),
            ],
          ),
          const SizedBox(height: 8),
        ],
        SizedBox(
          height: height,
          child: LineChart(
            LineChartData(
              minX: 0,
              maxX: maxX,
              minY: 0,
              maxY: maxY,
              clipData: const FlClipData.all(),
              gridData: const FlGridData(show: false),
              borderData: FlBorderData(show: false),
              titlesData: FlTitlesData(
                topTitles: const AxisTitles(
                  sideTitles: SideTitles(showTitles: false),
                ),
                rightTitles: const AxisTitles(
                  sideTitles: SideTitles(showTitles: false),
                ),
                leftTitles: const AxisTitles(
                  sideTitles: SideTitles(showTitles: false),
                ),
                bottomTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    reservedSize: 22,
                    interval: interval,
                    getTitlesWidget: (value, meta) {
                      final index = value.round();
                      if (index < 0 || index >= labels.length) {
                        return const SizedBox.shrink();
                      }
                      return Padding(
                        padding: const EdgeInsets.only(top: 7),
                        child: Text(
                          labels[index],
                          style: TextStyle(
                            fontSize: 9.5,
                            color: AppColors.tertiaryLabel(context),
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ),
              lineTouchData: LineTouchData(
                touchTooltipData: LineTouchTooltipData(
                  getTooltipColor: (_) => AppColors.secondaryBackground(
                    context,
                  ).withValues(alpha: 0.98),
                  getTooltipItems: (spots) => [
                    for (final spot in spots)
                      LineTooltipItem(
                        '${series.length > 1 ? '${series[spot.barIndex].label} ' : ''}'
                        '${formatProValue(spot.y, context: context)}',
                        TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: series[spot.barIndex].color,
                        ),
                      ),
                  ],
                ),
              ),
              lineBarsData: [
                for (final item in series)
                  LineChartBarData(
                    spots: item.spots,
                    isCurved: item.spots.length > 2,
                    curveSmoothness: 0.25,
                    color: item.color,
                    barWidth: 2.2,
                    isStrokeCapRound: true,
                    dotData: const FlDotData(show: false),
                    belowBarData: BarAreaData(
                      show: item.showArea,
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          item.color.withValues(alpha: 0.2),
                          item.color.withValues(alpha: 0),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _LegendDot extends StatelessWidget {
  const _LegendDot({required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 7,
          height: 7,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 5),
        Text(
          label,
          style: TextStyle(
            fontSize: 10.5,
            color: AppColors.secondaryLabel(context),
          ),
        ),
      ],
    );
  }
}

class ProRankItem {
  const ProRankItem({
    required this.name,
    required this.count,
    required this.percent,
  });

  final String name;
  final int count;
  final double percent;
}

class ProRankList extends StatelessWidget {
  const ProRankList({
    super.key,
    required this.items,
    this.maxItems = 10,
    this.onMore,
    this.accent,
    this.emptyText,
  });

  final List<ProRankItem> items;
  final int maxItems;
  final VoidCallback? onMore;
  final Color? accent;
  final String? emptyText;

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) {
      return ProEmpty(
        message: emptyText ?? proText(context, zh: '暂无数据', en: 'No data yet'),
        compact: true,
      );
    }
    final visible = items.take(maxItems).toList(growable: false);
    final color = accent ?? CupertinoColors.activeBlue.resolveFrom(context);
    return Column(
      children: [
        for (var i = 0; i < visible.length; i++) ...[
          if (i > 0)
            Container(
              height: 0.5,
              color: AppColors.separator(context).withValues(alpha: 0.08),
            ),
          _RankRow(index: i, item: visible[i], accent: color),
        ],
        if (onMore != null && items.length > visible.length) ...[
          const SizedBox(height: 6),
          CupertinoButton(
            padding: EdgeInsets.zero,
            minimumSize: Size.zero,
            onPressed: onMore,
            child: Text(
              proText(context, zh: '查看更多', en: 'See more'),
              style: const TextStyle(fontSize: 12),
            ),
          ),
        ],
      ],
    );
  }
}

class _RankRow extends StatelessWidget {
  const _RankRow({
    required this.index,
    required this.item,
    required this.accent,
  });

  final int index;
  final ProRankItem item;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    final rankColor = switch (index) {
      0 => CupertinoColors.systemRed.resolveFrom(context),
      1 => CupertinoColors.systemOrange.resolveFrom(context),
      2 => CupertinoColors.systemYellow.resolveFrom(context),
      _ => AppColors.tertiaryLabel(context),
    };
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 7),
      child: Row(
        children: [
          SizedBox(
            width: 18,
            child: Text(
              '${index + 1}',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: rankColor,
              ),
            ),
          ),
          const SizedBox(width: 6),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.name.isEmpty ? '-' : item.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: AppColors.label(context),
                  ),
                ),
                const SizedBox(height: 4),
                ClipRRect(
                  borderRadius: BorderRadius.circular(999),
                  child: SizedBox(
                    height: 3,
                    child: Stack(
                      children: [
                        Positioned.fill(
                          child: ColoredBox(
                            color: AppColors.separator(
                              context,
                            ).withValues(alpha: 0.12),
                          ),
                        ),
                        Positioned.fill(
                          child: FractionallySizedBox(
                            alignment: Alignment.centerLeft,
                            widthFactor: (item.percent / 100).clamp(0.0, 1.0),
                            child: ColoredBox(
                              color: accent.withValues(alpha: 0.55),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                formatProValue(item.count, context: context),
                style: TextStyle(
                  fontSize: 11.5,
                  fontWeight: FontWeight.w600,
                  color: AppColors.label(context),
                ),
              ),
              Text(
                '${item.percent.toStringAsFixed(1)}%',
                style: TextStyle(
                  fontSize: 9.5,
                  color: AppColors.tertiaryLabel(context),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class ProEmpty extends StatelessWidget {
  const ProEmpty({
    super.key,
    required this.message,
    this.compact = false,
    this.icon = TablerIcons.database_off,
  });

  final String message;
  final bool compact;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: compact ? 16 : 44),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: compact ? 20 : 28,
              color: AppColors.tertiaryLabel(context),
            ),
            const SizedBox(height: 8),
            Text(
              message,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 12,
                color: AppColors.secondaryLabel(context),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class ProError extends StatelessWidget {
  const ProError({super.key, required this.error, this.onRetry});

  final Object error;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    return ProCard(
      child: Column(
        children: [
          ProEmpty(message: '$error', icon: TablerIcons.alert_triangle),
          if (onRetry != null)
            CupertinoButton(
              padding: EdgeInsets.zero,
              minimumSize: Size.zero,
              onPressed: onRetry,
              child: Text(context.l10n.nodes_retry),
            ),
        ],
      ),
    );
  }
}

class ProStatusPill extends StatelessWidget {
  const ProStatusPill({super.key, required this.healthy, required this.label});

  final bool healthy;
  final String label;

  @override
  Widget build(BuildContext context) {
    final color = healthy
        ? AppColors.success
        : CupertinoColors.systemRed.resolveFrom(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 6,
            height: 6,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 5),
          Text(
            label,
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w600,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}

/// 小号圆角标签，用于 IP / 归属地 / 规则等短文本。
class ProTag extends StatelessWidget {
  const ProTag({super.key, required this.text, required this.color});

  final String text;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.09),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        text,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          fontSize: 9,
          fontWeight: FontWeight.w500,
          color: color,
        ),
      ),
    );
  }
}

/// 列表底部的上一页 / 下一页。
class ProPager extends StatelessWidget {
  const ProPager({
    super.key,
    required this.page,
    required this.totalPages,
    this.onPrevious,
    this.onNext,
  });

  final int page;
  final int totalPages;
  final VoidCallback? onPrevious;
  final VoidCallback? onNext;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CupertinoButton(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            minimumSize: Size.zero,
            onPressed: onPrevious,
            child: const Icon(CupertinoIcons.chevron_left, size: 16),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10),
            child: Text(
              '$page / $totalPages',
              style: TextStyle(
                fontSize: 11,
                color: AppColors.secondaryLabel(context),
              ),
            ),
          ),
          CupertinoButton(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            minimumSize: Size.zero,
            onPressed: onNext,
            child: const Icon(CupertinoIcons.chevron_right, size: 16),
          ),
        ],
      ),
    );
  }
}

class ProPageTabs<T> extends StatelessWidget {
  const ProPageTabs({
    super.key,
    required this.values,
    required this.labels,
    required this.selected,
    required this.onChanged,
  });

  final List<T> values;
  final List<String> labels;
  final T selected;
  final ValueChanged<T> onChanged;

  @override
  Widget build(BuildContext context) {
    return ProSegmented<T>(
      values: values,
      labels: labels,
      selected: selected,
      onChanged: onChanged,
    );
  }
}
