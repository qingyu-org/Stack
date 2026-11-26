import 'package:flutter/cupertino.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../../../core/localization/l10n_x.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../domain/entities/dashboard.dart';
import '../../../../domain/entities/server.dart';
import '../../../common/components/skeleton_item.dart';
import 'server_card_shared.dart';

/// 紧凑型服务器卡片：一行标题 + 一行实时指标，适合面板数量较多时快速浏览。
class CompactServerCard extends StatelessWidget {
  const CompactServerCard({
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

    final isDark = CupertinoTheme.brightnessOf(context) == Brightness.dark;

    return DecoratedBox(
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1C1C1E) : const Color(0xFFFFFFFF),
        borderRadius: BorderRadius.circular(13),
        border: Border.all(
          color: isSelected
              ? CupertinoColors.activeBlue.resolveFrom(context)
              : (isDark ? const Color(0xFF30343B) : const Color(0xFFE9EDF2)),
          width: isSelected ? 1.2 : 0.8,
        ),
        boxShadow: [
          BoxShadow(
            color: CupertinoColors.black.withValues(
              alpha: isDark ? 0.16 : 0.035,
            ),
            blurRadius: isDark ? 6 : 12,
            offset: Offset(0, isDark ? 2 : 4),
          ),
        ],
      ),
      child: CupertinoButton(
        padding: EdgeInsets.zero,
        borderRadius: BorderRadius.circular(13),
        onPressed: loading ? null : onTap,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(13, 12, 13, 12),
          child: Row(
            children: [
              if (loading)
                const SkeletonItem(width: 32, height: 32, borderRadius: 8)
              else
                SizedBox(
                  width: 32,
                  height: 32,
                  child: SvgPicture.asset(osAsset(base), fit: BoxFit.contain),
                ),
              const SizedBox(width: 11),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (loading)
                      const SkeletonItem.text(width: 120, height: 15)
                    else
                      Row(
                        children: [
                          Flexible(
                            child: Text(
                              title,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w700,
                                height: 1.1,
                                letterSpacing: -0.2,
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
                    const SizedBox(height: 4),
                    if (loading)
                      const SkeletonItem.text(width: 150, height: 11)
                    else
                      Text(
                        subtitle.isEmpty ? '--' : subtitle,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w500,
                          height: 1.15,
                          color: AppColors.secondaryLabel(context),
                        ),
                      ),
                    const SizedBox(height: 6),
                    _CompactMetrics(
                      cpuPercent: current?.cpuUsedPercent,
                      memoryPercent: current?.memoryUsedPercent,
                      diskPercent: disk?.usedPercent,
                      loading: loading,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              _CompactStatus(status: status),
            ],
          ),
        ),
      ),
    );
  }
}

class _CompactMetrics extends StatelessWidget {
  const _CompactMetrics({
    required this.cpuPercent,
    required this.memoryPercent,
    required this.diskPercent,
    this.loading = false,
  });

  final double? cpuPercent;
  final double? memoryPercent;
  final double? diskPercent;
  final bool loading;

  @override
  Widget build(BuildContext context) {
    if (loading) {
      return const SkeletonItem.text(width: 168, height: 10);
    }

    return Wrap(
      spacing: 10,
      runSpacing: 3,
      children: [
        _CompactMetric(label: 'CPU', percent: cpuPercent),
        _CompactMetric(
          label: context.l10n.servers_memory,
          percent: memoryPercent,
        ),
        _CompactMetric(label: context.l10n.servers_disk, percent: diskPercent),
      ],
    );
  }
}

class _CompactMetric extends StatelessWidget {
  const _CompactMetric({required this.label, required this.percent});

  final String label;
  final double? percent;

  @override
  Widget build(BuildContext context) {
    final color = _usageColor(context, percent);
    final value = percent == null ? '--' : formatPercent(percent!);

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 5,
          height: 5,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 4),
        Text(
          label,
          style: TextStyle(
            fontSize: 10.5,
            fontWeight: FontWeight.w600,
            height: 1,
            color: AppColors.tertiaryLabel(context),
          ),
        ),
        const SizedBox(width: 3),
        Text(
          value,
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w700,
            height: 1,
            color: color,
            letterSpacing: -0.2,
          ),
        ),
      ],
    );
  }
}

class _CompactStatus extends StatelessWidget {
  const _CompactStatus({required this.status});

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
    final latency = status.latencyMs;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 7,
          height: 7,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(color: color.withValues(alpha: 0.35), blurRadius: 4),
            ],
          ),
        ),
        const SizedBox(height: 4),
        Text(
          latency == null ? '--' : '${latency}ms',
          style: TextStyle(
            fontSize: 9.5,
            fontWeight: FontWeight.w700,
            height: 1,
            color: AppColors.secondaryLabel(context),
          ),
        ),
      ],
    );
  }
}

Color _usageColor(BuildContext context, double? percent) {
  if (percent == null) return AppColors.tertiaryLabel(context);
  if (percent >= 85) return CupertinoColors.systemRed.resolveFrom(context);
  if (percent >= 60) return CupertinoColors.systemOrange.resolveFrom(context);
  return CupertinoColors.systemGreen.resolveFrom(context);
}
