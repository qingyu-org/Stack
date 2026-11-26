import 'dart:math' as math;

import 'package:flutter/cupertino.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:flutter_tabler_icons/flutter_tabler_icons.dart';

import '../../../../core/localization/l10n_x.dart';
import '../../../../core/performance/performance_mode.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../domain/entities/dashboard.dart';
import '../../../../domain/entities/server.dart';
import '../../../common/components/skeleton_item.dart';
import '../../../common/components/thin_divider.dart';
import 'server_card_shared.dart';

/// 指标型服务器卡片：用环形图展示 CPU / 内存 / 磁盘，底部补充运行时间、
/// 负载与进程数，适合快速判断机器当前状态。
class MetricsServerCard extends StatelessWidget {
  const MetricsServerCard({
    super.key,
    required this.server,
    required this.dashboard,
    required this.status,
    required this.onTap,
    required this.isSelected,
    this.loading = false,
    this.titleOverride,
    this.subtitleOverride,
    this.titleBadge,
  });

  final Server server;
  final Dashboard? dashboard;
  final ServerCardStatus status;
  final VoidCallback? onTap;
  final bool isSelected;
  final bool loading;
  final String? titleOverride;
  final String? subtitleOverride;
  final Widget? titleBadge;

  @override
  Widget build(BuildContext context) {
    final base = dashboard?.base;
    final current = dashboard?.current;
    final disk = current == null ? null : primaryDisk(current.disks);
    final title =
        titleOverride ??
        (server.name?.isNotEmpty == true
            ? server.name!
            : (base?.hostname.isNotEmpty == true
                  ? base!.hostname
                  : server.displayName));
    final subtitle =
        subtitleOverride ??
        (base == null
            ? server.displayAddress
            : serverSubtitle(
                distro: base.prettyDistro,
                ip: base.ipV4Addr,
                fallback: base.platform,
              ));

    return DecoratedBox(
      decoration: BoxDecoration(
        color: AppColors.secondaryBackground(context).withValues(alpha: 0.58),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isSelected
              ? CupertinoColors.activeBlue.resolveFrom(context)
              : AppColors.separator(context).withValues(alpha: 0.16),
          width: isSelected ? 1.2 : 0.8,
        ),
        boxShadow: [
          BoxShadow(
            color: CupertinoColors.black.withValues(
              alpha: CupertinoTheme.brightnessOf(context) == Brightness.dark
                  ? 0.16
                  : 0.035,
            ),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: CupertinoButton(
        padding: EdgeInsets.zero,
        borderRadius: BorderRadius.circular(16),
        onPressed: loading ? null : onTap,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(15, 14, 15, 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  if (loading)
                    const SkeletonItem(width: 30, height: 30, borderRadius: 8)
                  else
                    SizedBox(
                      width: 30,
                      height: 30,
                      child: SvgPicture.asset(
                        osAsset(base),
                        fit: BoxFit.contain,
                      ),
                    ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (loading)
                          const SkeletonItem.text(width: 116, height: 15)
                        else
                          Row(
                            children: [
                              Flexible(
                                child: Text(
                                  title,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w800,
                                    height: 1.1,
                                    letterSpacing: -0.3,
                                    color: AppColors.label(context),
                                  ),
                                ),
                              ),
                              if (titleBadge != null) ...[
                                const SizedBox(width: 6),
                                titleBadge!,
                              ],
                            ],
                          ),
                        const SizedBox(height: 3),
                        if (loading)
                          const SkeletonItem.text(width: 140, height: 11)
                        else
                          Text(
                            subtitle.isEmpty ? '--' : subtitle,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 11.5,
                              fontWeight: FontWeight.w500,
                              color: AppColors.secondaryLabel(context),
                            ),
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  _MetricsStatus(status: status),
                ],
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: _MetricRing(
                      label: 'CPU',
                      percent: current?.cpuUsedPercent,
                      loading: loading,
                    ),
                  ),
                  Expanded(
                    child: _MetricRing(
                      label: context.l10n.servers_memory,
                      percent: current?.memoryUsedPercent,
                      loading: loading,
                    ),
                  ),
                  Expanded(
                    child: _MetricRing(
                      label: context.l10n.servers_disk,
                      percent: disk?.usedPercent,
                      loading: loading,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              const ThinDivider(),
              const SizedBox(height: 9),
              _MetricsFooter(
                uptimeSeconds: current?.uptimeSeconds,
                load1: current?.load1,
                procs: current?.procs,
                loading: loading,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MetricRing extends StatelessWidget {
  const _MetricRing({
    required this.label,
    required this.percent,
    required this.loading,
  });

  final String label;
  final double? percent;
  final bool loading;

  @override
  Widget build(BuildContext context) {
    final clamped = percent?.clamp(0, 100).toDouble();
    final color = _usageColor(context, clamped);
    final animate = !PerformanceModeScope.of(context);
    final target = (clamped ?? 0) / 100;

    return Column(
      children: [
        SizedBox(
          width: 54,
          height: 54,
          child: Stack(
            alignment: Alignment.center,
            children: [
              if (loading)
                const SkeletonItem(width: 54, height: 54, isCircle: true)
              else ...[
                TweenAnimationBuilder<double>(
                  duration: animate
                      ? const Duration(milliseconds: 550)
                      : Duration.zero,
                  curve: Curves.easeOutCubic,
                  tween: Tween<double>(begin: 0, end: target),
                  builder: (context, value, _) {
                    return CustomPaint(
                      size: const Size.square(54),
                      painter: _RingPainter(
                        value: value,
                        color: color,
                        track: AppColors.separator(
                          context,
                        ).withValues(alpha: 0.18),
                      ),
                    );
                  },
                ),
                Text(
                  clamped == null ? '--' : formatPercent(clamped),
                  style: TextStyle(
                    fontSize: clamped == null ? 12 : 12.5,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.4,
                    color: clamped == null
                        ? AppColors.tertiaryLabel(context)
                        : AppColors.label(context),
                  ),
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: 6),
        Text(
          label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w600,
            color: AppColors.secondaryLabel(context),
          ),
        ),
      ],
    );
  }
}

class _RingPainter extends CustomPainter {
  _RingPainter({required this.value, required this.color, required this.track});

  final double value;
  final Color color;
  final Color track;

  @override
  void paint(Canvas canvas, Size size) {
    const stroke = 5.0;
    final center = size.center(Offset.zero);
    final radius = size.shortestSide / 2 - stroke / 2;
    final rect = Rect.fromCircle(center: center, radius: radius);

    final trackPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..color = track;
    canvas.drawCircle(center, radius, trackPaint);

    if (value <= 0) return;
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..strokeCap = StrokeCap.round
      ..color = color;
    canvas.drawArc(
      rect,
      -math.pi / 2,
      2 * math.pi * value.clamp(0, 1).toDouble(),
      false,
      paint,
    );
  }

  @override
  bool shouldRepaint(_RingPainter oldDelegate) {
    return oldDelegate.value != value ||
        oldDelegate.color != color ||
        oldDelegate.track != track;
  }
}

class _MetricsFooter extends StatelessWidget {
  const _MetricsFooter({
    required this.uptimeSeconds,
    required this.load1,
    required this.procs,
    required this.loading,
  });

  final int? uptimeSeconds;
  final double? load1;
  final int? procs;
  final bool loading;

  @override
  Widget build(BuildContext context) {
    if (loading) {
      return const Row(
        children: [
          Expanded(child: SkeletonItem.text(width: 68, height: 10)),
          SizedBox(width: 12),
          Expanded(child: SkeletonItem.text(width: 52, height: 10)),
          SizedBox(width: 12),
          Expanded(child: SkeletonItem.text(width: 56, height: 10)),
        ],
      );
    }

    final l10n = context.l10n;
    return Row(
      children: [
        Expanded(
          child: _FooterItem(
            icon: TablerIcons.clock,
            label: l10n.dashboard_uptime,
            value: uptimeSeconds == null || uptimeSeconds! <= 0
                ? '--'
                : formatUptime(uptimeSeconds!),
          ),
        ),
        Expanded(
          child: _FooterItem(
            icon: TablerIcons.activity,
            label: l10n.dashboard_load,
            value: load1 == null ? '--' : load1!.toStringAsFixed(2),
          ),
        ),
        Expanded(
          child: _FooterItem(
            icon: TablerIcons.stack_2,
            label: l10n.servers_procs,
            value: procs == null ? '--' : '$procs',
          ),
        ),
      ],
    );
  }
}

class _FooterItem extends StatelessWidget {
  const _FooterItem({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 12, color: AppColors.tertiaryLabel(context)),
        const SizedBox(width: 4),
        Flexible(
          child: Text.rich(
            TextSpan(
              children: [
                TextSpan(
                  text: '$label ',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w500,
                    color: AppColors.tertiaryLabel(context),
                  ),
                ),
                TextSpan(
                  text: value,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: AppColors.secondaryLabel(context),
                  ),
                ),
              ],
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }
}

class _MetricsStatus extends StatelessWidget {
  const _MetricsStatus({required this.status});

  final ServerCardStatus status;

  @override
  Widget build(BuildContext context) {
    if (status.isLoading) {
      return const CupertinoActivityIndicator(radius: 7);
    }

    final hasData = status.hasFreshData;
    final color = hasData
        ? CupertinoColors.systemGreen.resolveFrom(context)
        : status.hasRefreshError
        ? CupertinoColors.systemRed.resolveFrom(context)
        : CupertinoColors.systemGrey.resolveFrom(context);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.09),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 5,
            height: 5,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 4),
          Text(
            status.latencyMs == null
                ? status.simpleLabel(context.l10n)
                : '${status.latencyMs}ms',
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w700,
              height: 1,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}

Color _usageColor(BuildContext context, double? percent) {
  if (percent == null) return AppColors.tertiaryLabel(context);
  if (percent >= 85) return CupertinoColors.systemRed.resolveFrom(context);
  if (percent >= 60) return CupertinoColors.systemOrange.resolveFrom(context);
  return CupertinoColors.systemGreen.resolveFrom(context);
}
