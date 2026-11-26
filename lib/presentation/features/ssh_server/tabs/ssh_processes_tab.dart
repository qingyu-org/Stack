import 'dart:async';

import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_tabler_icons/flutter_tabler_icons.dart';

import '../../../../core/localization/generated/app_localizations.dart';
import '../../../../core/localization/l10n_x.dart';
import '../../../../core/utils/formatter.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../data/services/ssh/ssh_connection.dart';
import '../../../../data/services/ssh/ssh_connection_manager.dart';
import '../../../../data/services/ssh/ssh_processes.dart';
import '../../../common/app_toast.dart';
import '../../../common/components/action_sheet_info_card.dart';
import '../../../common/components/action_sheet_launcher.dart';
import '../../../common/components/action_sheet_scaffold.dart';
import '../../../common/components/app_action_components.dart';
import '../../../common/components/app_empty_state.dart';
import '../../../common/components/skeleton_item.dart';
import '../../../common/components/thin_divider.dart';
import '../../process/widgets/process_item.dart';

class SshProcessesTab extends ConsumerStatefulWidget {
  const SshProcessesTab({
    super.key,
    required this.serverId,
    required this.isActive,
  });

  final int serverId;
  final bool isActive;

  @override
  ConsumerState<SshProcessesTab> createState() => _SshProcessesTabState();
}

enum _ProcessSort { cpu, memory, pid }

class _SshProcessesTabState extends ConsumerState<SshProcessesTab>
    with WidgetsBindingObserver {
  static const _pollInterval = Duration(seconds: 4);

  final SshProcessService _service = SshProcessService();
  final TextEditingController _searchController = TextEditingController();

  List<SshProcessInfo> _items = const [];
  bool _loading = true;
  bool _inFlight = false;
  bool _foreground = true;
  DateTime? _retryAt;
  Object? _error;
  String _query = '';
  _ProcessSort _sort = _ProcessSort.cpu;
  bool _descending = true;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _load();
    _timer = Timer.periodic(_pollInterval, (_) => _poll());
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final foreground = state == AppLifecycleState.resumed;
    if (foreground == _foreground) return;
    _foreground = foreground;
    if (foreground) _poll();
  }

  @override
  void didUpdateWidget(covariant SshProcessesTab oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!oldWidget.isActive && widget.isActive) _poll();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _timer?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  void _poll() {
    if (!mounted || !widget.isActive || !_foreground) return;
    final retryAt = _retryAt;
    if (retryAt != null && DateTime.now().isBefore(retryAt)) return;
    _load(silent: true);
  }

  Future<void> _load({bool silent = false}) async {
    if (_inFlight) return;
    _inFlight = true;
    if (!silent && mounted) setState(() => _loading = true);
    try {
      final connection = await ref
          .read(sshConnectionManagerProvider)
          .get(widget.serverId);
      final items = await _service.list(connection);
      if (!mounted) return;
      setState(() {
        _items = items;
        _loading = false;
        _error = null;
        _retryAt = null;
      });
    } catch (error) {
      if (!mounted) return;
      ref.read(sshConnectionManagerProvider).invalidateIfIdle(widget.serverId);
      setState(() {
        _loading = false;
        _error = error;
        _retryAt = DateTime.now().add(const Duration(seconds: 10));
      });
    } finally {
      _inFlight = false;
    }
  }

  List<SshProcessInfo> get _visibleItems {
    final query = _query.toLowerCase();
    final filtered = query.isEmpty
        ? [..._items]
        : _items
              .where(
                (item) =>
                    item.name.toLowerCase().contains(query) ||
                    item.user.toLowerCase().contains(query) ||
                    '${item.pid}' == query ||
                    '${item.pid}'.contains(query),
              )
              .toList();
    filtered.sort((a, b) {
      final compare = switch (_sort) {
        _ProcessSort.cpu => a.cpuPercent.compareTo(b.cpuPercent),
        _ProcessSort.memory => a.rssBytes.compareTo(b.rssBytes),
        _ProcessSort.pid => a.pid.compareTo(b.pid),
      };
      return _descending ? -compare : compare;
    });
    return filtered;
  }

  Future<void> _showSortMenu() async {
    final l10n = context.l10n;
    final selected = await showCupertinoModalPopup<_ProcessSort>(
      context: context,
      builder: (sheetContext) => CupertinoActionSheet(
        title: Text(l10n.ssh_processes_sortTitle),
        actions: [
          _sortAction(
            sheetContext,
            _ProcessSort.cpu,
            l10n.ssh_processes_sortCpu,
          ),
          _sortAction(
            sheetContext,
            _ProcessSort.memory,
            l10n.ssh_processes_sortMemory,
          ),
          _sortAction(
            sheetContext,
            _ProcessSort.pid,
            l10n.ssh_processes_sortPid,
          ),
        ],
        cancelButton: CupertinoActionSheetAction(
          onPressed: () => Navigator.of(sheetContext).pop(),
          child: Text(l10n.common_cancel),
        ),
      ),
    );
    if (selected == null) return;
    setState(() {
      if (_sort == selected) {
        _descending = !_descending;
      } else {
        _sort = selected;
        _descending = true;
      }
    });
  }

  CupertinoActionSheetAction _sortAction(
    BuildContext sheetContext,
    _ProcessSort sort,
    String label,
  ) {
    return CupertinoActionSheetAction(
      onPressed: () => Navigator.of(sheetContext).pop(sort),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(label),
          if (_sort == sort) ...[
            const SizedBox(width: 6),
            Icon(
              _descending
                  ? TablerIcons.sort_descending
                  : TablerIcons.sort_ascending,
              size: 14,
              color: CupertinoColors.activeBlue.resolveFrom(sheetContext),
            ),
          ],
        ],
      ),
    );
  }

  Future<void> _openProcess(SshProcessInfo process) async {
    final action = await showActionSheet<String>(
      context: context,
      builder: (_) => _SshProcessSheet(process: process),
    );
    if (!mounted || action == null) return;
    await _killProcess(process, force: action == 'force');
  }

  Future<void> _killProcess(
    SshProcessInfo process, {
    bool force = false,
  }) async {
    final l10n = context.l10n;
    final confirmed = await showCupertinoDialog<bool>(
      context: context,
      builder: (dialogContext) => CupertinoAlertDialog(
        title: Text(l10n.ssh_processes_killTitle),
        content: Text(
          l10n.ssh_processes_killConfirm(process.name, process.pid),
        ),
        actions: [
          CupertinoDialogAction(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: Text(l10n.common_cancel),
          ),
          CupertinoDialogAction(
            isDestructiveAction: true,
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: Text(
              force ? l10n.ssh_processes_forceKill : l10n.ssh_processes_kill,
            ),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    try {
      final connection = await ref
          .read(sshConnectionManagerProvider)
          .get(widget.serverId);
      await _service.kill(connection, process.pid, force: force);
      if (!mounted) return;
      showAppSuccessToast(l10n.ssh_processes_killed);
      await _load(silent: true);
    } catch (error) {
      if (!mounted) return;
      final detail = error is SshConnectionException
          ? error.toString()
          : '$error';
      showAppErrorToast(l10n.ssh_processes_killTitle, description: detail);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final items = _visibleItems;

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
          child: Row(
            children: [
              Expanded(
                child: SizedBox(
                  height: 36,
                  child: CupertinoSearchTextField(
                    controller: _searchController,
                    placeholder: l10n.ssh_processes_searchPlaceholder,
                    backgroundColor: AppColors.secondaryBackground(
                      context,
                    ).withValues(alpha: 0.58),
                    borderRadius: BorderRadius.circular(11),
                    placeholderStyle: TextStyle(
                      color: AppColors.tertiaryLabel(context),
                      fontSize: 13,
                    ),
                    itemColor: AppColors.secondaryLabel(context),
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    onChanged: (value) => setState(() => _query = value.trim()),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              CupertinoButton(
                padding: EdgeInsets.zero,
                minimumSize: const Size(36, 36),
                onPressed: _showSortMenu,
                child: Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: AppColors.secondaryBackground(
                      context,
                    ).withValues(alpha: 0.58),
                    borderRadius: BorderRadius.circular(11),
                    border: Border.all(
                      color: AppColors.separator(
                        context,
                      ).withValues(alpha: 0.14),
                      width: 0.5,
                    ),
                  ),
                  child: Icon(
                    _descending
                        ? TablerIcons.sort_descending
                        : TablerIcons.sort_ascending,
                    size: 17,
                    color: AppColors.secondaryLabel(context),
                  ),
                ),
              ),
            ],
          ),
        ),
        Expanded(child: _buildBody(l10n, items)),
      ],
    );
  }

  Widget _buildBody(AppLocalizations l10n, List<SshProcessInfo> items) {
    if (_loading && _items.isEmpty) {
      return ListView.builder(
        padding: const EdgeInsets.fromLTRB(10, 2, 10, 24),
        itemCount: 8,
        itemBuilder: (_, _) => const Padding(
          padding: EdgeInsets.only(bottom: 8),
          child: SkeletonItem(width: double.infinity, height: 118),
        ),
      );
    }
    if (_error != null && _items.isEmpty) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(
          parent: BouncingScrollPhysics(),
        ),
        padding: const EdgeInsets.fromLTRB(16, 24, 16, 24),
        children: [
          SizedBox(height: MediaQuery.sizeOf(context).height * 0.06),
          AppEmptyState(
            icon: TablerIcons.alert_triangle,
            title: l10n.ssh_processes_loadFailed,
            subtitle: '$_error',
            actionLabel: l10n.common_retry,
            onAction: _load,
          ),
        ],
      );
    }
    if (items.isEmpty) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(
          parent: BouncingScrollPhysics(),
        ),
        padding: const EdgeInsets.fromLTRB(16, 24, 16, 24),
        children: [
          SizedBox(height: MediaQuery.sizeOf(context).height * 0.1),
          AppEmptyState(
            icon: TablerIcons.cpu,
            title: l10n.ssh_processes_empty,
            subtitle: _query.isEmpty ? null : l10n.process_noResultsSubtitle,
          ),
        ],
      );
    }

    return CustomScrollView(
      physics: const AlwaysScrollableScrollPhysics(
        parent: BouncingScrollPhysics(),
      ),
      slivers: [
        CupertinoSliverRefreshControl(onRefresh: _load),
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(10, 2, 10, 24),
          sliver: SliverList.builder(
            itemCount: items.length,
            itemBuilder: (context, index) {
              final item = items[index];
              return ProcessItem(
                item: item.toProcessItemMap(),
                onTap: () => _openProcess(item),
              );
            },
          ),
        ),
      ],
    );
  }
}

class _SshProcessSheet extends StatelessWidget {
  const _SshProcessSheet({required this.process});

  final SshProcessInfo process;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final green = CupertinoColors.systemGreen.resolveFrom(context);

    return ActionSheetScaffold(
      isAdaptive: true,
      showHandle: false,
      maxHeightFactor: 0.86,
      contentPadding: EdgeInsets.zero,
      infoCard: ActionSheetInfoCard(
        leading: Container(
          width: 56,
          height: 56,
          decoration: BoxDecoration(
            color: green.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Icon(TablerIcons.cpu, size: 30, color: green),
        ),
        title: process.name,
        subtitle: 'PID ${process.pid}',
        trailing: _ProcessStatusBadge(status: process.status),
      ),
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              decoration: _groupDecoration(context),
              child: Column(
                children: [
                  _InfoRow(label: l10n.ssh_processes_user, value: process.user),
                  const ThinDivider(indent: 14),
                  _InfoRow(
                    label: l10n.ssh_processes_cpu,
                    value: '${process.cpuPercent.toStringAsFixed(1)}%',
                  ),
                  const ThinDivider(indent: 14),
                  _InfoRow(
                    label: l10n.ssh_processes_memory,
                    value:
                        '${process.rssBytes <= 0 ? '--' : Formatter.adaptiveBytes(process.rssBytes)}'
                        '  (${process.memPercent.toStringAsFixed(1)}%)',
                  ),
                  const ThinDivider(indent: 14),
                  _InfoRow(
                    label: l10n.ssh_processes_threads,
                    value: '${process.threads}',
                  ),
                ],
              ),
            ),
            const SizedBox(height: 18),
            AppSectionHeader(
              title: l10n.ssh_processes_command,
              icon: TablerIcons.terminal,
            ),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(14),
              decoration: _groupDecoration(context),
              child: Text(
                process.args.isEmpty ? process.name : process.args,
                maxLines: 6,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 12,
                  height: 1.4,
                  fontFamily: 'Menlo',
                  color: AppColors.secondaryLabel(context),
                ),
              ),
            ),
            const SizedBox(height: 18),
            AppSectionHeader(
              title: l10n.ssh_processes_actions,
              icon: TablerIcons.player_stop,
            ),
            AppActionGroup(
              children: [
                AppActionRow(
                  icon: TablerIcons.player_stop,
                  iconColor: CupertinoColors.systemOrange,
                  title: l10n.ssh_processes_kill,
                  subtitle: Text(l10n.ssh_processes_termHint),
                  isDestructive: true,
                  onTap: () => Navigator.of(context).pop('term'),
                ),
                AppActionRow(
                  icon: TablerIcons.bolt,
                  iconColor: CupertinoColors.systemRed,
                  title: l10n.ssh_processes_forceKill,
                  subtitle: Text(l10n.ssh_processes_forceKillHint),
                  isDestructive: true,
                  onTap: () => Navigator.of(context).pop('force'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

BoxDecoration _groupDecoration(BuildContext context) {
  return BoxDecoration(
    color: AppColors.secondaryBackground(context).withValues(alpha: 0.5),
    borderRadius: BorderRadius.circular(16),
  );
}

class _ProcessStatusBadge extends StatelessWidget {
  const _ProcessStatusBadge({required this.status});

  final String status;

  @override
  Widget build(BuildContext context) {
    final color = switch (status) {
      'running' => CupertinoColors.systemGreen,
      'sleep' || 'idle' => CupertinoColors.systemGrey,
      'stop' || 'zombie' || 'wait' => CupertinoColors.systemRed,
      _ => CupertinoColors.systemGrey,
    };
    final resolved = color.resolveFrom(context);

    return Container(
      height: 30,
      padding: const EdgeInsets.symmetric(horizontal: 10),
      decoration: BoxDecoration(
        color: resolved.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(TablerIcons.circle_filled, size: 8, color: resolved),
          const SizedBox(width: 6),
          Text(
            status,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: resolved,
            ),
          ),
        ],
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      child: Row(
        children: [
          SizedBox(
            width: 72,
            child: Text(
              label,
              style: TextStyle(
                fontSize: 13,
                color: AppColors.secondaryLabel(context),
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: AppColors.label(context),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
