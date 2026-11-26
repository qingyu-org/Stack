import 'dart:async';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart' show SelectableText;
import 'package:flutter/material.dart' show Tooltip;
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_tabler_icons/flutter_tabler_icons.dart';

import '../../../../core/localization/generated/app_localizations.dart';
import '../../../../core/localization/l10n_x.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../data/services/ssh/ssh_connection_manager.dart';
import '../../../../data/services/ssh/ssh_containers.dart';
import '../../../common/app_toast.dart';
import '../../../common/components/action_sheet_info_card.dart';
import '../../../common/components/action_sheet_launcher.dart';
import '../../../common/components/action_sheet_scaffold.dart';
import '../../../common/components/app_action_components.dart';
import '../../../common/components/app_empty_state.dart';
import '../../../common/components/status_pill.dart';

void showSshContainerActions(
  BuildContext context, {
  required SshContainer container,
  required VoidCallback onLogs,
  required VoidCallback onStart,
  required VoidCallback onStop,
  required VoidCallback onRestart,
}) {
  showActionSheet<void>(
    context: context,
    builder: (sheetContext) {
      final statusColor = _statusColor(sheetContext, container);
      return ActionSheetScaffold(
        infoCard: ActionSheetInfoCard(
          leading: Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: statusColor.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Icon(TablerIcons.box, size: 28, color: statusColor),
          ),
          title: container.name.isEmpty ? container.shortId : container.name,
          subtitle: container.image,
          trailing: StatusPill(
            label: container.state.toUpperCase(),
            active: container.isRunning,
            activeColor: statusColor,
            inactiveColor: statusColor,
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            AppSectionHeader(
              title: context.l10n.ssh_containers_details,
              icon: TablerIcons.settings_automation,
            ),
            AppActionGroup(
              children: [
                AppActionRow(
                  icon: TablerIcons.logs,
                  iconColor: CupertinoColors.systemBrown,
                  title: context.l10n.ssh_containers_logs,
                  subtitle: Text(context.l10n.ssh_containers_logsHint),
                  onTap: () {
                    Navigator.of(sheetContext).pop();
                    onLogs();
                  },
                ),
                AppActionRow(
                  icon: TablerIcons.player_play,
                  iconColor: CupertinoColors.systemGreen,
                  title: context.l10n.ssh_containers_start,
                  subtitle: Text(context.l10n.ssh_containers_startHint),
                  enabled: !container.isRunning && !container.isPaused,
                  onTap: () {
                    Navigator.of(sheetContext).pop();
                    onStart();
                  },
                ),
                AppActionRow(
                  icon: TablerIcons.player_stop,
                  iconColor: CupertinoColors.systemRed,
                  title: context.l10n.ssh_containers_stop,
                  subtitle: Text(context.l10n.ssh_containers_stopHint),
                  enabled: container.isRunning,
                  onTap: () {
                    Navigator.of(sheetContext).pop();
                    onStop();
                  },
                ),
                AppActionRow(
                  icon: TablerIcons.refresh,
                  iconColor: CupertinoColors.systemBlue,
                  title: context.l10n.ssh_containers_restart,
                  subtitle: Text(context.l10n.ssh_containers_restartHint),
                  enabled: container.isRunning,
                  onTap: () {
                    Navigator.of(sheetContext).pop();
                    onRestart();
                  },
                ),
              ],
            ),
            const SizedBox(height: 16),
          ],
        ),
      );
    },
  );
}

Future<void> showSshContainerLogs(
  BuildContext context, {
  required int serverId,
  required SshContainer container,
}) {
  return showActionSheet<void>(
    context: context,
    builder: (_) =>
        _SshContainerLogsSheet(serverId: serverId, container: container),
  );
}

class _SshContainerLogsSheet extends ConsumerStatefulWidget {
  const _SshContainerLogsSheet({
    required this.serverId,
    required this.container,
  });

  final int serverId;
  final SshContainer container;

  @override
  ConsumerState<_SshContainerLogsSheet> createState() =>
      _SshContainerLogsSheetState();
}

class _SshContainerLogsSheetState
    extends ConsumerState<_SshContainerLogsSheet> {
  final SshContainerService _service = SshContainerService();
  String _logs = '';
  Object? _error;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    if (!mounted) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final connection = await ref
          .read(sshConnectionManagerProvider)
          .get(widget.serverId);
      final logs = await _service.logs(connection, widget.container);
      if (!mounted) return;
      setState(() {
        _logs = logs;
        _loading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _error = error;
        _loading = false;
      });
    }
  }

  Future<void> _copy() async {
    if (_logs.isEmpty) return;
    await Clipboard.setData(ClipboardData(text: _logs));
    if (!mounted) return;
    showAppSuccessToast(context.l10n.ssh_containers_copyLogs);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final statusColor = _statusColor(context, widget.container);

    return ActionSheetScaffold(
      maxHeightFactor: 0.9,
      contentPadding: EdgeInsets.zero,
      infoCard: ActionSheetInfoCard(
        leading: Container(
          width: 56,
          height: 56,
          decoration: BoxDecoration(
            color: statusColor.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Icon(TablerIcons.logs, size: 28, color: statusColor),
        ),
        title: widget.container.name.isEmpty
            ? widget.container.shortId
            : widget.container.name,
        subtitle: l10n.ssh_containers_logsTitle,
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            _SheetIconButton(
              icon: TablerIcons.copy,
              tooltip: l10n.ssh_containers_copyLogs,
              onPressed: _loading ? null : _copy,
            ),
            const SizedBox(width: 4),
            _SheetIconButton(
              icon: TablerIcons.refresh,
              tooltip: l10n.common_retry,
              onPressed: _loading ? null : _load,
            ),
          ],
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 20),
        child: Container(
          width: double.infinity,
          height: MediaQuery.sizeOf(context).height * 0.52,
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: AppColors.secondaryBackground(
              context,
            ).withValues(alpha: 0.5),
            borderRadius: BorderRadius.circular(16),
          ),
          child: _buildLogContent(l10n),
        ),
      ),
    );
  }

  Widget _buildLogContent(AppLocalizations l10n) {
    if (_loading) {
      return const Center(child: CupertinoActivityIndicator());
    }
    if (_error != null) {
      return AppEmptyState(
        icon: TablerIcons.alert_triangle,
        title: l10n.ssh_containers_logsLoadFailed,
        subtitle: '$_error',
        actionLabel: l10n.common_retry,
        onAction: _load,
      );
    }
    if (_logs.isEmpty) {
      return Center(
        child: Text(
          l10n.ssh_containers_logsEmpty,
          style: TextStyle(color: AppColors.secondaryLabel(context)),
        ),
      );
    }
    return SingleChildScrollView(
      reverse: true,
      child: SelectableText(
        _logs,
        style: TextStyle(
          fontSize: 11.5,
          height: 1.45,
          fontFamily: 'Menlo',
          color: AppColors.label(context),
        ),
      ),
    );
  }
}

class _SheetIconButton extends StatelessWidget {
  const _SheetIconButton({
    required this.icon,
    required this.tooltip,
    this.onPressed,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: CupertinoButton(
        padding: EdgeInsets.zero,
        minimumSize: const Size(32, 32),
        onPressed: onPressed,
        child: Icon(
          icon,
          size: 19,
          color: onPressed == null
              ? AppColors.tertiaryLabel(context)
              : AppColors.secondaryLabel(context),
        ),
      ),
    );
  }
}

Color _statusColor(BuildContext context, SshContainer container) {
  if (container.isRunning) {
    return CupertinoColors.systemGreen.resolveFrom(context);
  }
  if (container.isPaused) {
    return CupertinoColors.systemYellow.resolveFrom(context);
  }
  return CupertinoColors.systemGrey.resolveFrom(context);
}
