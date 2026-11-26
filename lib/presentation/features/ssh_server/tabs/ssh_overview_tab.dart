import 'dart:async';

import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_tabler_icons/flutter_tabler_icons.dart';

import '../../../../core/localization/l10n_x.dart';

import '../../../../core/utils/formatter.dart';
import '../../../../data/repositories_impl/server_repository_impl.dart';
import '../../../../data/services/ssh/ssh_connection.dart';
import '../../../../data/services/ssh/ssh_connection_manager.dart';
import '../../../../data/services/ssh/ssh_metrics.dart';
import '../../../../domain/entities/dashboard.dart';
import '../../../common/components/app_empty_state.dart';
import '../../../common/components/skeleton_item.dart';

import '../../dashboard/utils/dashboard_display_helpers.dart';
import '../../dashboard/widgets/disk_usage_list_card.dart';
import '../../dashboard/widgets/host_details_card.dart';
import '../../dashboard/widgets/info_card.dart';
import '../../dashboard/widgets/network_traffic_card.dart';
import '../../dashboard/widgets/process_section.dart';
import '../../dashboard/widgets/resource_usage_card.dart';

class SshOverviewTab extends ConsumerStatefulWidget {
  const SshOverviewTab({
    super.key,
    required this.serverId,
    required this.isActive,
  });

  final int serverId;
  final bool isActive;

  @override
  ConsumerState<SshOverviewTab> createState() => _SshOverviewTabState();
}

class _SshOverviewTabState extends ConsumerState<SshOverviewTab>
    with WidgetsBindingObserver {
  static const _pollInterval = Duration(seconds: 3);

  Dashboard? _dashboard;
  SshMetricsResult? _result;
  Object? _error;
  bool _loading = true;
  bool _inFlight = false;
  bool _foreground = true;
  DateTime? _retryAt;
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
  void didUpdateWidget(covariant SshOverviewTab oldWidget) {
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
    _load();
  }

  Future<void> _load() async {
    if (_inFlight) return;
    _inFlight = true;
    try {
      final manager = ref.read(sshConnectionManagerProvider);
      final repository = ref.read(serverRepositoryProvider);
      final server = await repository.find(widget.serverId);
      if (server == null) {
        throw const SshConnectionException('服务器不存在');
      }
      final connection = await manager.get(widget.serverId);
      final result = await SshMetricsCollector().fetch(
        connection: connection,
        server: server,
      );
      if (!mounted) return;
      setState(() {
        _dashboard = result.dashboard;
        _result = result;
        _error = null;
        _loading = false;
        _retryAt = null;
      });
    } catch (error) {
      if (!mounted) return;
      ref.read(sshConnectionManagerProvider).invalidateIfIdle(widget.serverId);
      setState(() {
        _error = error;
        _loading = false;
        _retryAt = DateTime.now().add(const Duration(seconds: 10));
      });
    } finally {
      _inFlight = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    final data = _dashboard;
    if (data == null) {
      if (_loading) return const _OverviewSkeleton();
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(
          parent: BouncingScrollPhysics(),
        ),
        padding: const EdgeInsets.fromLTRB(16, 24, 16, 32),
        children: [
          SizedBox(height: MediaQuery.sizeOf(context).height * 0.08),
          AppEmptyState(
            icon: TablerIcons.alert_triangle,
            title: context.l10n.dashboard_loadFailed,
            subtitle: _error?.toString() ?? '',
            actionLabel: context.l10n.common_retry,
            onAction: () {
              setState(() => _loading = true);
              _load();
            },
          ),
        ],
      );
    }

    final base = data.base;
    final current = data.current;
    final disks = visibleDashboardDisks(current.disks);
    final primaryDisk = primaryDashboardDisk(current.disks);
    final l10n = context.l10n;
    final result = _result;

    final metaRows = <(String, String)>[
      (
        l10n.ssh_overview_uptime,
        formatDashboardUptime(current.uptimeSeconds, l10n),
      ),
      (
        l10n.ssh_overview_load,
        '${current.load1.toStringAsFixed(2)} / '
            '${current.load5.toStringAsFixed(2)} / '
            '${current.load15.toStringAsFixed(2)}',
      ),
      (l10n.ssh_overview_processes, '${current.procs}'),
      (
        l10n.ssh_overview_downloadRate,
        '${Formatter.adaptiveBytes(result?.rxBytesPerSecond.round() ?? 0)}/s',
      ),
      (
        l10n.ssh_overview_uploadRate,
        '${Formatter.adaptiveBytes(result?.txBytesPerSecond.round() ?? 0)}/s',
      ),
      (l10n.ssh_overview_latency, '${result?.fetchMs ?? 0} ms'),
    ];

    return CustomScrollView(
      physics: const AlwaysScrollableScrollPhysics(
        parent: BouncingScrollPhysics(),
      ),
      slivers: [
        CupertinoSliverRefreshControl(onRefresh: _load),
        if (_error != null)
          SliverToBoxAdapter(
            child: _ErrorStrip(
              error: _error!,
              onRetry: () {
                setState(() => _error = null);
                _load();
              },
            ),
          ),
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(10, 8, 10, 32),
          sliver: SliverList.list(
            children: [
              InfoCard(
                title: l10n.ssh_overview_metaTitle,
                icon: TablerIcons.gauge,
                rows: metaRows,
              ),
              const SizedBox(height: 12),
              DashboardResourceUsageCard(
                base: base,
                current: current,
                disk: primaryDisk,
              ),
              const SizedBox(height: 12),
              DashboardNetworkTrafficCard(current: current),
              if (disks.isNotEmpty) ...[
                const SizedBox(height: 12),
                DashboardDiskUsageListCard(disks: disks),
              ],
              const SizedBox(height: 12),
              DashboardHostDetailsCard(base: base),
              if (current.topCpuItems.isNotEmpty ||
                  current.topMemItems.isNotEmpty) ...[
                const SizedBox(height: 12),
                DashboardProcessSection(current: current),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

class _OverviewSkeleton extends StatelessWidget {
  const _OverviewSkeleton();

  @override
  Widget build(BuildContext context) {
    return ListView(
      physics: const NeverScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(10, 8, 10, 32),
      children: const [
        SkeletonItem(width: double.infinity, height: 170, borderRadius: 12),
        SizedBox(height: 12),
        SkeletonItem(width: double.infinity, height: 210, borderRadius: 12),
        SizedBox(height: 12),
        SkeletonItem(width: double.infinity, height: 130, borderRadius: 12),
        SizedBox(height: 12),
        SkeletonItem(width: double.infinity, height: 180, borderRadius: 12),
      ],
    );
  }
}

class _ErrorStrip extends StatelessWidget {
  const _ErrorStrip({required this.error, required this.onRetry});

  final Object error;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final color = CupertinoColors.systemRed.resolveFrom(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
      child: Container(
        padding: const EdgeInsets.fromLTRB(12, 9, 8, 9),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.09),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(
          children: [
            Icon(TablerIcons.alert_circle, size: 15, color: color),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                '$error',
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(fontSize: 11.5, color: color),
              ),
            ),
            CupertinoButton(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              minimumSize: Size.zero,
              onPressed: onRetry,
              child: Text(
                context.l10n.common_retry,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: color,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
