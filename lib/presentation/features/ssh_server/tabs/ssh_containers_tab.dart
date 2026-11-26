import 'dart:async';

import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_tabler_icons/flutter_tabler_icons.dart';

import '../../../../core/localization/generated/app_localizations.dart';
import '../../../../core/localization/l10n_x.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../data/services/ssh/ssh_connection_manager.dart';
import '../../../../data/services/ssh/ssh_connection.dart';
import '../../../../data/services/ssh/ssh_containers.dart';
import '../../../common/app_toast.dart';
import '../../../common/components/app_empty_state.dart';
import '../../../common/components/frosted_filter_bar.dart';
import '../../../common/components/skeleton_item.dart';
import '../widgets/ssh_container_card.dart';
import '../widgets/ssh_container_sheets.dart';

enum _ContainerFilter { running, all }

class SshContainersTab extends ConsumerStatefulWidget {
  const SshContainersTab({
    super.key,
    required this.serverId,
    required this.isActive,
  });

  final int serverId;
  final bool isActive;

  @override
  ConsumerState<SshContainersTab> createState() => _SshContainersTabState();
}

class _SshContainersTabState extends ConsumerState<SshContainersTab>
    with WidgetsBindingObserver {
  static const _pollInterval = Duration(seconds: 5);

  final SshContainerService _service = SshContainerService();

  List<SshContainer> _containers = const [];
  _ContainerFilter _filter = _ContainerFilter.running;
  bool _loading = true;
  bool _inFlight = false;
  bool _operationInFlight = false;
  bool _foreground = true;
  DateTime? _retryAt;
  Object? _error;
  Object? _dockerError;
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
  void didUpdateWidget(covariant SshContainersTab oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!oldWidget.isActive && widget.isActive) _poll();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _timer?.cancel();
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
      final containers = await _service.list(connection);
      if (!mounted) return;
      setState(() {
        _containers = containers;
        _loading = false;
        _error = null;
        _dockerError = null;
        _retryAt = null;
      });
    } on SshDockerUnavailableException catch (error) {
      if (!mounted) return;
      setState(() {
        _dockerError = error;
        _error = null;
        _containers = const [];
        _loading = false;
        _retryAt = DateTime.now().add(const Duration(seconds: 10));
      });
    } catch (error) {
      if (!mounted) return;
      ref.read(sshConnectionManagerProvider).invalidateIfIdle(widget.serverId);
      setState(() {
        _error = error;
        _dockerError = null;
        _loading = false;
        _retryAt = DateTime.now().add(const Duration(seconds: 10));
      });
    } finally {
      _inFlight = false;
    }
  }

  List<SshContainer> get _visible {
    if (_filter == _ContainerFilter.all) return _containers;
    return _containers.where((container) => container.isRunning).toList();
  }

  int get _runningCount =>
      _containers.where((container) => container.isRunning).length;

  Future<void> _operate(SshContainer container, String action) async {
    if (_operationInFlight) return;
    final l10n = context.l10n;
    if (action == 'stop' || action == 'restart') {
      final isStop = action == 'stop';
      final confirmed = await showCupertinoDialog<bool>(
        context: context,
        builder: (dialogContext) => CupertinoAlertDialog(
          title: Text(
            isStop
                ? l10n.ssh_containers_confirmStopTitle
                : l10n.ssh_containers_confirmRestartTitle,
          ),
          content: Text(
            isStop
                ? l10n.ssh_containers_confirmStopMessage(container.name)
                : l10n.ssh_containers_confirmRestartMessage(container.name),
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
                isStop ? l10n.ssh_containers_stop : l10n.ssh_containers_restart,
              ),
            ),
          ],
        ),
      );
      if (confirmed != true || !mounted) return;
    }

    _operationInFlight = true;
    try {
      final connection = await ref
          .read(sshConnectionManagerProvider)
          .get(widget.serverId);
      await _service.operate(connection, container, action);
      if (!mounted) return;
      showAppSuccessToast(switch (action) {
        'stop' => l10n.ssh_containers_stopped,
        'restart' => l10n.ssh_containers_restarted,
        _ => l10n.ssh_containers_started,
      });
      await _load(silent: true);
    } catch (error) {
      if (!mounted) return;
      final detail = error is SshConnectionException
          ? error.toString()
          : '$error';
      showAppErrorToast(
        l10n.ssh_containers_operationFailed,
        description: detail,
      );
    } finally {
      _operationInFlight = false;
    }
  }

  void _openActions(SshContainer container) {
    showSshContainerActions(
      context,
      container: container,
      onLogs: () => showSshContainerLogs(
        context,
        serverId: widget.serverId,
        container: container,
      ),
      onStart: () => _operate(container, 'start'),
      onStop: () => _operate(container, 'stop'),
      onRestart: () => _operate(container, 'restart'),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final showFilter = !_loading && _dockerError == null && _error == null;

    return Column(
      children: [
        if (showFilter)
          FrostedFilterBar(
            items: [
              FilterItem(
                label: '${l10n.ssh_containers_running} ($_runningCount)',
                value: _ContainerFilter.running.name,
                icon: TablerIcons.player_play,
              ),
              FilterItem(
                label: '${l10n.ssh_containers_all} (${_containers.length})',
                value: _ContainerFilter.all.name,
                icon: TablerIcons.stack_2,
              ),
            ],
            selectedValue: _filter.name,
            onSelected: (value) {
              final filter = value == _ContainerFilter.all.name
                  ? _ContainerFilter.all
                  : _ContainerFilter.running;
              if (filter == _filter) return;
              setState(() => _filter = filter);
            },
          ),
        Expanded(child: _buildBody(l10n)),
      ],
    );
  }

  Widget _buildBody(AppLocalizations l10n) {
    if (_loading && _containers.isEmpty && _dockerError == null) {
      return ListView.builder(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
        itemCount: 4,
        itemBuilder: (_, _) => Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: Container(
            height: 164,
            decoration: BoxDecoration(
              color: AppColors.secondaryBackground(
                context,
              ).withValues(alpha: 0.4),
              borderRadius: BorderRadius.circular(16),
            ),
            child: const Center(
              child: SkeletonItem(
                width: double.infinity,
                height: 142,
                borderRadius: 12,
              ),
            ),
          ),
        ),
      );
    }
    if (_dockerError != null) {
      return _errorState(
        l10n,
        icon: TablerIcons.brand_docker,
        title: l10n.ssh_containers_unavailable,
        error: _dockerError!,
        onRetry: _load,
      );
    }
    if (_error != null && _containers.isEmpty) {
      return _errorState(
        l10n,
        icon: TablerIcons.alert_triangle,
        title: l10n.ssh_containers_loadFailed,
        error: _error!,
        onRetry: _load,
      );
    }

    final visible = _visible;
    if (visible.isEmpty) {
      final hasStopped =
          _filter == _ContainerFilter.running && _containers.isNotEmpty;
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(
          parent: BouncingScrollPhysics(),
        ),
        padding: const EdgeInsets.fromLTRB(16, 24, 16, 24),
        children: [
          SizedBox(height: MediaQuery.sizeOf(context).height * 0.1),
          AppEmptyState(
            icon: TablerIcons.box,
            title: hasStopped
                ? l10n.ssh_containers_emptyRunning
                : l10n.ssh_containers_empty,
            subtitle: hasStopped ? l10n.ssh_containers_emptyRunningHint : null,
            actionLabel: hasStopped ? l10n.ssh_containers_all : null,
            onAction: hasStopped
                ? () => setState(() => _filter = _ContainerFilter.all)
                : null,
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
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
          sliver: SliverList.builder(
            itemCount: visible.length,
            itemBuilder: (context, index) {
              final container = visible[index];
              return Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: SshContainerCard(
                  container: container,
                  onTap: () => _openActions(container),
                  onStart: () => _operate(container, 'start'),
                  onStop: () => _operate(container, 'stop'),
                  onRestart: () => _operate(container, 'restart'),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _errorState(
    AppLocalizations l10n, {
    required IconData icon,
    required String title,
    required Object error,
    required VoidCallback onRetry,
  }) {
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(
        parent: BouncingScrollPhysics(),
      ),
      padding: const EdgeInsets.fromLTRB(16, 24, 16, 24),
      children: [
        SizedBox(height: MediaQuery.sizeOf(context).height * 0.08),
        AppEmptyState(
          icon: icon,
          title: title,
          subtitle: '$error',
          actionLabel: l10n.common_retry,
          onAction: onRetry,
        ),
      ],
    );
  }
}
