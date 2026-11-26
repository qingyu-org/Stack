import 'package:flutter/cupertino.dart';
import 'package:flutter_tabler_icons/flutter_tabler_icons.dart';

import '../../../../core/localization/l10n_x.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../domain/entities/dashboard.dart';
import '../../../common/components/info_panel.dart';
import '../../../common/components/skeleton_item.dart';
import '../../../common/components/thin_divider.dart';
import '../utils/dashboard_display_helpers.dart';
import '../utils/virtualization_info.dart';

class DashboardHostDetailsCard extends StatelessWidget {
  const DashboardHostDetailsCard({
    super.key,
    required this.base,
    this.loading = false,
  });

  final DashboardBase base;
  final bool loading;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final system = firstNotEmpty(base.prettyDistro, base.os);
    final cpuClock = base.cpuMhz > 0
        ? '${(base.cpuMhz / 1000).toStringAsFixed(2)} GHz'
        : '';
    final coreSummary = base.cpuCores > 0 || base.cpuLogicalCores > 0
        ? l10n.dashboard_cpuCoreSummary(base.cpuCores, base.cpuLogicalCores)
        : '';
    final virtualization = parseVirtualizationInfo(base.virtualizationSystem);
    final proxy = _visibleProxy(base.systemProxy);

    final rows = <Widget>[
      _HostDetailRow(
        label: l10n.dashboard_system,
        loading: loading,
        child: _tags(context, [system], CupertinoColors.systemGrey),
      ),
      if (loading || base.ipV4Addr.isNotEmpty) ...[
        const ThinDivider(),
        _HostDetailRow(
          label: 'IPv4',
          loading: loading,
          child: Text(
            base.ipV4Addr,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: AppColors.label(context),
            ),
          ),
        ),
      ],
      if (loading ||
          base.kernelVersion.isNotEmpty ||
          base.kernelArch.isNotEmpty) ...[
        const ThinDivider(),
        _HostDetailRow(
          label: l10n.dashboard_kernel,
          loading: loading,
          child: _tags(context, [
            base.kernelVersion,
            base.kernelArch,
          ], CupertinoColors.systemIndigo),
        ),
      ],
      if (loading ||
          base.cpuModelName.isNotEmpty ||
          coreSummary.isNotEmpty) ...[
        const ThinDivider(),
        _HostDetailRow(
          label: 'CPU',
          loading: loading,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (base.cpuModelName.isNotEmpty) ...[
                Text(
                  base.cpuModelName,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    height: 1.25,
                    color: AppColors.label(context),
                  ),
                ),
                const SizedBox(height: 6),
              ],
              _tags(context, [
                coreSummary,
                cpuClock,
              ], CupertinoColors.activeBlue),
            ],
          ),
        ),
      ],
      if (!loading && !virtualization.isEmpty) ...[
        const ThinDivider(),
        _HostDetailRow(
          label: l10n.dashboard_virtualization,
          child: _virtualizationTags(context, virtualization),
        ),
      ],
      if (!loading && proxy.isNotEmpty) ...[
        const ThinDivider(),
        _HostDetailRow(
          label: l10n.dashboard_systemProxy,
          child: _tags(context, [proxy], CupertinoColors.systemOrange),
        ),
      ],
    ];

    return InfoPanel(
      title: l10n.dashboard_hostDetailsTitle,
      icon: TablerIcons.server,
      iconColor: CupertinoColors.systemGrey.resolveFrom(context),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: rows,
      ),
    );
  }

  /// `noProxy` / `none` 是 1Panel 表示“未设置代理”的占位值，直接隐藏。
  String _visibleProxy(String value) {
    final trimmed = value.trim();
    final lower = trimmed.toLowerCase();
    if (trimmed.isEmpty ||
        lower == 'noproxy' ||
        lower == 'none' ||
        lower == 'no proxy' ||
        lower == 'direct') {
      return '';
    }
    return trimmed;
  }

  Widget _virtualizationTags(BuildContext context, VirtualizationInfo info) {
    final l10n = context.l10n;
    final role = switch (info.role) {
      'host' => l10n.dashboard_virtualizationHost,
      'guest' => l10n.dashboard_virtualizationGuest,
      'container' => l10n.dashboard_virtualizationContainer,
      _ => null,
    };

    return Wrap(
      spacing: 6,
      runSpacing: 6,
      children: [
        if (info.system != null)
          _InfoTag(
            text: info.system!,
            color: CupertinoColors.systemTeal.resolveFrom(context),
          ),
        if (role != null)
          _InfoTag(
            text: role,
            color: CupertinoColors.systemPurple.resolveFrom(context),
          ),
        for (final tag in info.extraTags)
          _InfoTag(
            text: tag,
            color: CupertinoColors.systemGrey.resolveFrom(context),
          ),
      ],
    );
  }

  Widget _tags(
    BuildContext context,
    List<String> values,
    CupertinoDynamicColor color,
  ) {
    final visible = [
      for (final value in values)
        if (value.trim().isNotEmpty) value.trim(),
    ];
    if (visible.isEmpty) {
      return Text(
        '-',
        style: TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w600,
          color: AppColors.secondaryLabel(context),
        ),
      );
    }

    return Wrap(
      spacing: 6,
      runSpacing: 6,
      children: [
        for (final value in visible)
          _InfoTag(text: value, color: color.resolveFrom(context)),
      ],
    );
  }
}

class _HostDetailRow extends StatelessWidget {
  const _HostDetailRow({
    required this.label,
    required this.child,
    this.loading = false,
  });

  final String label;
  final Widget child;
  final bool loading;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 9),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 88,
            child: Padding(
              padding: const EdgeInsets.only(top: 3),
              child: Text(
                label,
                style: TextStyle(
                  fontSize: 13,
                  color: AppColors.secondaryLabel(context),
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: loading
                ? const Align(
                    alignment: Alignment.centerLeft,
                    child: SkeletonItem.text(width: 96, height: 14),
                  )
                : child,
          ),
        ],
      ),
    );
  }
}

class _InfoTag extends StatelessWidget {
  const _InfoTag({required this.text, required this.color});

  final String text;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(maxWidth: 220),
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withValues(alpha: 0.14), width: 0.5),
      ),
      child: Text(
        text,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          fontSize: 11.5,
          fontWeight: FontWeight.w600,
          color: color,
          height: 1.2,
        ),
      ),
    );
  }
}
