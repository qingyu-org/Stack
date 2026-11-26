import 'package:flutter/cupertino.dart';
import 'package:flutter_tabler_icons/flutter_tabler_icons.dart';

import '../../../../core/localization/l10n_x.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../data/services/ssh/ssh_containers.dart';
import '../../../common/components/status_pill.dart';
import '../../../common/components/thin_divider.dart';

class SshContainerCard extends StatelessWidget {
  const SshContainerCard({
    super.key,
    required this.container,
    required this.onTap,
    this.onStart,
    this.onStop,
    this.onRestart,
  });

  final SshContainer container;
  final VoidCallback onTap;
  final VoidCallback? onStart;
  final VoidCallback? onStop;
  final VoidCallback? onRestart;

  @override
  Widget build(BuildContext context) {
    final paused = container.isPaused;
    final statusColor = container.isRunning
        ? CupertinoColors.systemGreen.resolveFrom(context)
        : paused
        ? CupertinoColors.systemYellow.resolveFrom(context)
        : CupertinoColors.systemGrey.resolveFrom(context);
    final compose = [
      if (container.composeProject.isNotEmpty) container.composeProject,
      if (container.composeService.isNotEmpty) container.composeService,
    ].join(' / ');
    final ports = _prettyPorts(container.ports);

    return CupertinoButton(
      padding: EdgeInsets.zero,
      onPressed: onTap,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppColors.secondaryBackground(context).withValues(alpha: 0.58),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: AppColors.separator(context).withValues(alpha: 0.1),
            width: 0.5,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    color: statusColor.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(TablerIcons.box, size: 24, color: statusColor),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        container.name.isEmpty
                            ? container.shortId
                            : container.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: AppColors.label(context),
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        container.image,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 12,
                          color: AppColors.secondaryLabel(context),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                StatusPill(
                  label: container.state.toUpperCase(),
                  active: container.isRunning,
                  activeColor: statusColor,
                  inactiveColor: statusColor,
                ),
              ],
            ),
            if (compose.isNotEmpty) ...[
              const SizedBox(height: 10),
              Row(
                children: [
                  Icon(
                    TablerIcons.stack_2,
                    size: 14,
                    color: AppColors.tertiaryLabel(context),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    '${context.l10n.ssh_containers_compose} · $compose',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 11.5,
                      color: AppColors.tertiaryLabel(context),
                    ),
                  ),
                ],
              ),
            ],
            if (container.status.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(
                container.status,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 12,
                  color: AppColors.secondaryLabel(context),
                ),
              ),
            ],
            if (ports.isNotEmpty) ...[
              const SizedBox(height: 8),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    TablerIcons.plug_connected,
                    size: 14,
                    color: AppColors.tertiaryLabel(context),
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      '${context.l10n.ssh_containers_ports} · $ports',
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 11.5,
                        height: 1.35,
                        color: AppColors.tertiaryLabel(context),
                      ),
                    ),
                  ),
                ],
              ),
            ],
            const SizedBox(height: 12),
            const ThinDivider(indent: 0),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _CardAction(
                    icon: TablerIcons.player_play,
                    label: context.l10n.ssh_containers_start,
                    color: CupertinoColors.systemGreen,
                    enabled: !container.isRunning && !paused,
                    onTap: onStart,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _CardAction(
                    icon: TablerIcons.player_stop,
                    label: context.l10n.ssh_containers_stop,
                    color: CupertinoColors.systemRed,
                    enabled: container.isRunning,
                    onTap: onStop,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _CardAction(
                    icon: TablerIcons.refresh,
                    label: context.l10n.ssh_containers_restart,
                    color: CupertinoColors.systemBlue,
                    enabled: container.isRunning,
                    onTap: onRestart,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  String _prettyPorts(String raw) {
    final parts = <String>[];
    for (final value in raw.split(',')) {
      final port = value.trim();
      if (port.isEmpty || parts.contains(port)) continue;
      parts.add(port);
    }
    return parts.join('  ·  ');
  }
}

class _CardAction extends StatelessWidget {
  const _CardAction({
    required this.icon,
    required this.label,
    required this.color,
    this.enabled = true,
    this.onTap,
  });

  final IconData icon;
  final String label;
  final Color color;
  final bool enabled;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return CupertinoButton(
      padding: EdgeInsets.zero,
      onPressed: enabled ? onTap : null,
      child: Opacity(
        opacity: enabled ? 1 : 0.35,
        child: Container(
          height: 34,
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 15, color: color),
              const SizedBox(width: 5),
              Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
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
