import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_tabler_icons/flutter_tabler_icons.dart';

import '../../../../core/localization/l10n_x.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../domain/entities/dashboard.dart';
import '../../../../domain/entities/panel_node.dart';
import '../../../../domain/entities/server.dart';
import '../../../common/app_toast.dart';
import '../../../common/components/action_sheet_launcher.dart';
import '../../../common/components/action_sheet_scaffold.dart';
import '../../servers/providers/node_providers.dart';
import '../../servers/providers/node_selection_provider.dart';
import '../../servers/providers/servers_provider.dart';
import '../utils/pro_data_utils.dart';
import '../widgets/pro_page_scaffold.dart';
import '../widgets/pro_ui.dart';

enum _NodeTab { overview, manage }

/// 专业版多机管理。
///
/// 「概览」用每台节点自己的 dashboard 展示资源与服务数量；「节点管理」更
/// 偏向拓扑与授权信息，并允许把某台节点设为当前节点。所有操作都只切换
/// `CurrentNode`，不直接改动机器本身。
class NodeManagementPage extends ConsumerStatefulWidget {
  const NodeManagementPage({super.key, required this.serverId});

  final int serverId;

  @override
  ConsumerState<NodeManagementPage> createState() => _NodeManagementPageState();
}

class _NodeManagementPageState extends ConsumerState<NodeManagementPage> {
  _NodeTab _tab = _NodeTab.overview;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final server = _findServer(ref.watch(serversNotifierProvider).valueOrNull);
    final nodesAsync = ref.watch(serverNodesProvider(widget.serverId));
    final nodes =
        nodesAsync.valueOrNull ?? server?.nodes ?? const <PanelNode>[];
    final activeNode =
        ref.watch(activeNodeControllerProvider(widget.serverId)).valueOrNull ??
        PanelNode.localName;

    return ProPageScaffold(
      title: l10n.nodes_management,
      onRefresh: () async {
        ref.invalidate(serverNodesProvider(widget.serverId));
        for (final node in nodes) {
          ref.invalidate(
            nodeDashboardSnapshotProvider((widget.serverId, node.name)),
          );
        }
        try {
          await ref.read(serverNodesProvider(widget.serverId).future);
        } catch (_) {
          // 错误由页面状态展示。
        }
      },
      children: [
        if (server != null)
          _ClusterHero(
            server: server,
            nodes: nodes,
            loading: nodesAsync.isLoading && nodes.isEmpty,
          ),
        const SizedBox(height: 12),
        ProPageTabs<_NodeTab>(
          values: _NodeTab.values,
          labels: [
            proText(context, zh: '概览', en: 'Overview'),
            proText(context, zh: '节点管理', en: 'Nodes'),
          ],
          selected: _tab,
          onChanged: (value) => setState(() => _tab = value),
        ),
        const SizedBox(height: 12),
        nodesAsync.when(
          loading: () => nodes.isEmpty
              ? const Padding(
                  padding: EdgeInsets.symmetric(vertical: 60),
                  child: Center(child: CupertinoActivityIndicator()),
                )
              : _buildTab(context, server, nodes, activeNode),
          error: (error, _) => ProError(
            error: error,
            onRetry: () => ref.invalidate(serverNodesProvider(widget.serverId)),
          ),
          data: (liveNodes) {
            if (liveNodes.isEmpty) {
              return ProCard(
                child: ProEmpty(
                  message: l10n.nodes_empty,
                  icon: TablerIcons.sitemap_off,
                ),
              );
            }
            return _buildTab(context, server, liveNodes, activeNode);
          },
        ),
      ],
    );
  }

  Widget _buildTab(
    BuildContext context,
    Server? server,
    List<PanelNode> nodes,
    String activeNode,
  ) {
    return switch (_tab) {
      _NodeTab.overview => _NodeOverview(
        serverId: widget.serverId,
        nodes: nodes,
        activeNode: activeNode,
        onSelect: (node) => _selectNode(node, pop: true),
      ),
      _NodeTab.manage => _NodeManageList(
        nodes: nodes,
        activeNode: activeNode,
        onSelect: (node) => _selectNode(node, pop: false),
        onOpenDetails: (node) => _showNodeDetails(context, node, activeNode),
      ),
    };
  }

  Future<void> _selectNode(PanelNode node, {required bool pop}) async {
    await ref
        .read(activeNodeControllerProvider(widget.serverId).notifier)
        .select(node.name);
    if (!mounted) return;
    showAppSuccessToast(
      proText(
        context,
        zh: '已切换到 ${node.isLocal ? context.l10n.nodes_local : node.displayName}',
        en: 'Switched to ${node.isLocal ? context.l10n.nodes_local : node.displayName}',
      ),
    );
    if (pop) Navigator.of(context).pop(node.name);
  }

  Future<void> _showNodeDetails(
    BuildContext context,
    PanelNode node,
    String activeNode,
  ) {
    return showActionSheet(
      context: context,
      builder: (sheetContext) => _NodeDetailSheet(
        node: node,
        isActive: node.name == activeNode,
        onSelect: () {
          Navigator.of(sheetContext).pop();
          _selectNode(node, pop: true);
        },
      ),
    );
  }

  Server? _findServer(List<Server>? servers) {
    if (servers == null) return null;
    for (final server in servers) {
      if (server.id == widget.serverId) return server;
    }
    return null;
  }
}

class _ClusterHero extends StatelessWidget {
  const _ClusterHero({
    required this.server,
    required this.nodes,
    required this.loading,
  });

  final Server server;
  final List<PanelNode> nodes;
  final bool loading;

  @override
  Widget build(BuildContext context) {
    final online = nodes.where((node) => node.isOnline).length;
    final blue = CupertinoColors.activeBlue.resolveFrom(context);
    return ProCard(
      padding: const EdgeInsets.fromLTRB(15, 14, 15, 14),
      child: Row(
        children: [
          Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(
              color: blue.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(TablerIcons.sitemap, size: 23, color: blue),
          ),
          const SizedBox(width: 11),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  server.displayName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    letterSpacing: -0.3,
                    color: AppColors.label(context),
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  server.baseUrl.toString(),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 10.5,
                    fontFamily: 'Menlo',
                    color: AppColors.secondaryLabel(context),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          if (loading)
            const CupertinoActivityIndicator(radius: 8)
          else
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  '$online/${nodes.length}',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: AppColors.label(context),
                  ),
                ),
                Text(
                  proText(context, zh: '在线节点', en: 'online'),
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

class _NodeOverview extends ConsumerWidget {
  const _NodeOverview({
    required this.serverId,
    required this.nodes,
    required this.activeNode,
    required this.onSelect,
  });

  final int serverId;
  final List<PanelNode> nodes;
  final String activeNode;
  final ValueChanged<PanelNode> onSelect;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    var websites = 0;
    var apps = 0;
    var databases = 0;
    var cronjobs = 0;
    var loaded = 0;
    for (final node in nodes) {
      final snapshot = ref
          .watch(nodeDashboardSnapshotProvider((serverId, node.name)))
          .valueOrNull;
      if (snapshot == null) continue;
      loaded++;
      final base = snapshot.dashboard.base;
      websites += base.websiteNumber;
      apps += base.appInstalledNumber;
      databases += base.databaseNumber;
      cronjobs += base.cronjobNumber;
    }
    final blue = CupertinoColors.activeBlue.resolveFrom(context);
    final purple = CupertinoColors.systemPurple.resolveFrom(context);
    final teal = CupertinoColors.systemTeal.resolveFrom(context);
    final orange = CupertinoColors.systemOrange.resolveFrom(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ProCard(
          title: proText(context, zh: '集群资源', en: 'Cluster'),
          trailing: Text(
            loaded == nodes.length
                ? proText(context, zh: '全部节点', en: 'All nodes')
                : '$loaded/${nodes.length}',
            style: TextStyle(
              fontSize: 10,
              color: AppColors.tertiaryLabel(context),
            ),
          ),
          child: ProMetricGrid(
            columns: 2,
            metrics: [
              ProMetricData(
                label: proText(context, zh: '网站', en: 'Websites'),
                value: formatProValue(websites, context: context),
                icon: TablerIcons.world_www,
                color: blue,
              ),
              ProMetricData(
                label: proText(context, zh: '应用', en: 'Apps'),
                value: formatProValue(apps, context: context),
                icon: TablerIcons.apps,
                color: purple,
              ),
              ProMetricData(
                label: proText(context, zh: '数据库', en: 'Databases'),
                value: formatProValue(databases, context: context),
                icon: TablerIcons.database,
                color: teal,
              ),
              ProMetricData(
                label: proText(context, zh: '计划任务', en: 'Cron jobs'),
                value: formatProValue(cronjobs, context: context),
                icon: TablerIcons.clock,
                color: orange,
              ),
            ],
          ),
        ),
        for (final node in nodes)
          _NodeOverviewCard(
            serverId: serverId,
            node: node,
            isActive: node.name == activeNode,
            onTap: () => onSelect(node),
          ),
      ],
    );
  }
}

class _NodeOverviewCard extends ConsumerWidget {
  const _NodeOverviewCard({
    required this.serverId,
    required this.node,
    required this.isActive,
    required this.onTap,
  });

  final int serverId;
  final PanelNode node;
  final bool isActive;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(
      nodeDashboardSnapshotProvider((serverId, node.name)),
    );
    final snapshot = async.valueOrNull;
    final current = snapshot?.dashboard.current;
    final base = snapshot?.dashboard.base;
    final disk = _rootDisk(current?.disks);
    final blue = CupertinoColors.activeBlue.resolveFrom(context);

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.fromLTRB(14, 13, 14, 13),
        decoration: BoxDecoration(
          color: isActive
              ? blue.withValues(alpha: 0.07)
              : AppColors.secondaryBackground(context).withValues(alpha: 0.68),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: isActive
                ? blue.withValues(alpha: 0.42)
                : AppColors.separator(context).withValues(alpha: 0.14),
            width: isActive ? 1 : 0.6,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                _NodeAvatar(node: node),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Flexible(
                            child: Text(
                              node.isLocal
                                  ? context.l10n.nodes_local
                                  : node.displayName,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 14.5,
                                fontWeight: FontWeight.w700,
                                letterSpacing: -0.2,
                                color: AppColors.label(context),
                              ),
                            ),
                          ),
                          const SizedBox(width: 6),
                          if (isActive)
                            ProTag(
                              text: context.l10n.nodes_current,
                              color: blue,
                            ),
                          if (node.isPro) ...[
                            const SizedBox(width: 4),
                            ProTag(
                              text: context.l10n.nodes_pro,
                              color: CupertinoColors.systemPurple.resolveFrom(
                                context,
                              ),
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: 3),
                      Text(
                        [
                          node.alias.isNotEmpty &&
                                  node.alias != node.displayName
                              ? node.alias
                              : null,
                          node.address.isNotEmpty ? node.address : null,
                          snapshot == null ? null : '${snapshot.fetchMs} ms',
                        ].whereType<String>().join(' · '),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 10,
                          fontFamily: 'Menlo',
                          color: AppColors.secondaryLabel(context),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 6),
                _StatusDot(online: node.isOnline),
              ],
            ),
            const SizedBox(height: 11),
            if (async.isLoading && snapshot == null)
              SizedBox(
                height: 42,
                child: Center(
                  child: CupertinoActivityIndicator(
                    radius: 8,
                    color: AppColors.tertiaryLabel(context),
                  ),
                ),
              )
            else if (async.hasError && snapshot == null)
              Row(
                children: [
                  Icon(
                    TablerIcons.alert_triangle,
                    size: 13,
                    color: CupertinoColors.systemOrange.resolveFrom(context),
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      proText(
                        context,
                        zh: '节点数据获取失败，点击重试',
                        en: 'Failed to load node data, tap to retry',
                      ),
                      style: TextStyle(
                        fontSize: 11,
                        color: AppColors.secondaryLabel(context),
                      ),
                    ),
                  ),
                  GestureDetector(
                    onTap: () => ref.invalidate(
                      nodeDashboardSnapshotProvider((serverId, node.name)),
                    ),
                    child: Text(
                      context.l10n.nodes_retry,
                      style: TextStyle(fontSize: 11, color: blue),
                    ),
                  ),
                ],
              )
            else
              Column(
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: _UsageBar(
                          label: 'CPU',
                          percent: current?.cpuUsedPercent ?? 0,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _UsageBar(
                          label: proText(context, zh: '内存', en: 'MEM'),
                          percent: current?.memoryUsedPercent ?? 0,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _UsageBar(
                          label: proText(context, zh: '磁盘', en: 'DISK'),
                          percent: disk?.usedPercent ?? 0,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 11),
                  Row(
                    children: [
                      _MiniCount(
                        icon: TablerIcons.world_www,
                        label: proText(context, zh: '网站', en: 'Sites'),
                        value: base?.websiteNumber,
                      ),
                      _MiniCount(
                        icon: TablerIcons.apps,
                        label: proText(context, zh: '应用', en: 'Apps'),
                        value: base?.appInstalledNumber,
                      ),
                      _MiniCount(
                        icon: TablerIcons.database,
                        label: proText(context, zh: '数据', en: 'DB'),
                        value: base?.databaseNumber,
                      ),
                      _MiniCount(
                        icon: TablerIcons.clock,
                        label: proText(context, zh: '任务', en: 'Cron'),
                        value: base?.cronjobNumber,
                      ),
                      const Spacer(),
                      Icon(
                        CupertinoIcons.chevron_right,
                        size: 12,
                        color: AppColors.tertiaryLabel(context),
                      ),
                    ],
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }

  static DiskUsage? _rootDisk(List<DiskUsage>? disks) {
    if (disks == null || disks.isEmpty) return null;
    for (final disk in disks) {
      if (disk.path == '/') return disk;
    }
    return disks.first;
  }
}

class _NodeManageList extends StatelessWidget {
  const _NodeManageList({
    required this.nodes,
    required this.activeNode,
    required this.onSelect,
    required this.onOpenDetails,
  });

  final List<PanelNode> nodes;
  final String activeNode;
  final ValueChanged<PanelNode> onSelect;
  final ValueChanged<PanelNode> onOpenDetails;

  @override
  Widget build(BuildContext context) {
    final online = nodes.where((node) => node.isOnline).length;
    final proCount = nodes.where((node) => node.isPro).length;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ProCard(
          title: proText(context, zh: '节点拓扑', en: 'Topology'),
          trailing: ProStatusPill(
            healthy: online == nodes.length && nodes.isNotEmpty,
            label: '$online/${nodes.length}',
          ),
          child: Row(
            children: [
              Expanded(
                child: _TopologyStat(
                  label: proText(context, zh: '主节点', en: 'Primary'),
                  value: nodes.where((node) => node.isLocal).length.toString(),
                ),
              ),
              Expanded(
                child: _TopologyStat(
                  label: proText(context, zh: '子节点', en: 'Children'),
                  value: nodes.where((node) => !node.isLocal).length.toString(),
                ),
              ),
              Expanded(
                child: _TopologyStat(
                  label: proText(context, zh: '专业版节点', en: 'Pro nodes'),
                  value: proCount.toString(),
                ),
              ),
            ],
          ),
        ),
        ProCard(
          padding: const EdgeInsets.fromLTRB(8, 12, 8, 4),
          title: proText(context, zh: '全部节点', en: 'All nodes'),
          child: Column(
            children: [
              for (var i = 0; i < nodes.length; i++) ...[
                if (i > 0)
                  Container(
                    height: 0.5,
                    margin: const EdgeInsets.symmetric(horizontal: 8),
                    color: AppColors.separator(context).withValues(alpha: 0.1),
                  ),
                _ManageRow(
                  node: nodes[i],
                  isActive: nodes[i].name == activeNode,
                  onTap: () => onOpenDetails(nodes[i]),
                  onSelect: () => onSelect(nodes[i]),
                ),
              ],
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(4, 0, 4, 12),
          child: Text(
            proText(
              context,
              zh: '切换节点只会改变 App 读取和管理哪台机器，不会重启或修改节点服务。',
              en:
                  'Switching nodes only changes which machine the app reads '
                  'and manages. It does not restart or modify any service.',
            ),
            style: TextStyle(
              fontSize: 10.5,
              height: 1.45,
              color: AppColors.tertiaryLabel(context),
            ),
          ),
        ),
      ],
    );
  }
}

class _ManageRow extends StatelessWidget {
  const _ManageRow({
    required this.node,
    required this.isActive,
    required this.onTap,
    required this.onSelect,
  });

  final PanelNode node;
  final bool isActive;
  final VoidCallback onTap;
  final VoidCallback onSelect;

  @override
  Widget build(BuildContext context) {
    final blue = CupertinoColors.activeBlue.resolveFrom(context);
    final green = AppColors.success;
    final address = [node.address, if (node.port > 0) ':${node.port}'].join();
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(8, 10, 8, 10),
        child: Row(
          children: [
            _NodeAvatar(node: node, size: 34),
            const SizedBox(width: 9),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          node.isLocal
                              ? context.l10n.nodes_local
                              : node.displayName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: AppColors.label(context),
                          ),
                        ),
                      ),
                      if (isActive) ...[
                        const SizedBox(width: 5),
                        ProTag(text: context.l10n.nodes_current, color: blue),
                      ],
                    ],
                  ),
                  const SizedBox(height: 3),
                  Text(
                    [
                      node.isLocal
                          ? proText(context, zh: '主节点', en: 'Primary')
                          : proText(context, zh: '子节点', en: 'Child'),
                      if (address.isNotEmpty) address,
                      if (node.version.isNotEmpty) 'v${node.version}',
                    ].join(' · '),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 10,
                      fontFamily: 'Menlo',
                      color: AppColors.secondaryLabel(context),
                    ),
                  ),
                  const SizedBox(height: 5),
                  Wrap(
                    spacing: 4,
                    runSpacing: 4,
                    children: [
                      ProTag(
                        text: node.isOnline
                            ? proText(context, zh: '健康', en: 'Healthy')
                            : proText(context, zh: '离线', en: 'Offline'),
                        color: node.isOnline
                            ? green
                            : CupertinoColors.systemRed.resolveFrom(context),
                      ),
                      ProTag(
                        text: node.isBound
                            ? proText(context, zh: '已绑定', en: 'Bound')
                            : proText(context, zh: '未绑定', en: 'Unbound'),
                        color: CupertinoColors.systemGrey.resolveFrom(context),
                      ),
                      if (node.isPro)
                        ProTag(
                          text: context.l10n.nodes_pro,
                          color: CupertinoColors.systemPurple.resolveFrom(
                            context,
                          ),
                        ),
                      if (node.syncStatus.isNotEmpty)
                        ProTag(
                          text: node.syncStatus,
                          color: CupertinoColors.systemTeal.resolveFrom(
                            context,
                          ),
                        ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(width: 6),
            if (isActive)
              Icon(CupertinoIcons.checkmark_alt, size: 15, color: blue)
            else
              CupertinoButton(
                padding: EdgeInsets.zero,
                minimumSize: Size.zero,
                onPressed: onSelect,
                child: Container(
                  width: 28,
                  height: 28,
                  decoration: BoxDecoration(
                    color: blue.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(9),
                  ),
                  child: Icon(
                    TablerIcons.arrow_left_right,
                    size: 14,
                    color: blue,
                  ),
                ),
              ),
            const SizedBox(width: 4),
            Icon(
              CupertinoIcons.chevron_right,
              size: 12,
              color: AppColors.tertiaryLabel(context),
            ),
          ],
        ),
      ),
    );
  }
}

class _TopologyStat extends StatelessWidget {
  const _TopologyStat({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          value,
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w700,
            letterSpacing: -0.6,
            color: AppColors.label(context),
          ),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: TextStyle(
            fontSize: 10,
            color: AppColors.tertiaryLabel(context),
          ),
        ),
      ],
    );
  }
}

class _NodeAvatar extends StatelessWidget {
  const _NodeAvatar({required this.node, this.size = 40});

  final PanelNode node;
  final double size;

  static const _colors = [
    Color(0xFF3B82F6),
    Color(0xFF14B8A6),
    Color(0xFF10B981),
    Color(0xFFF59E0B),
    Color(0xFF6366F1),
    Color(0xFFEF4444),
    Color(0xFF8B5CF6),
    Color(0xFFEC4899),
  ];

  @override
  Widget build(BuildContext context) {
    final name = node.isLocal ? context.l10n.nodes_local : node.displayName;
    final rune = name.isEmpty ? 0x3F : name.runes.first;
    final color = _colors[rune % _colors.length];
    final letter = String.fromCharCode(rune).toUpperCase();
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(size * 0.3),
      ),
      child: Text(
        letter,
        style: TextStyle(
          fontSize: size * 0.38,
          fontWeight: FontWeight.w700,
          color: color,
        ),
      ),
    );
  }
}

class _StatusDot extends StatelessWidget {
  const _StatusDot({required this.online});

  final bool online;

  @override
  Widget build(BuildContext context) {
    final color = online
        ? AppColors.success
        : CupertinoColors.systemGrey.resolveFrom(context);
    return Container(
      width: 7,
      height: 7,
      decoration: BoxDecoration(color: color, shape: BoxShape.circle),
    );
  }
}

class _UsageBar extends StatelessWidget {
  const _UsageBar({required this.label, required this.percent});

  final String label;
  final double percent;

  @override
  Widget build(BuildContext context) {
    final value = percent.clamp(0, 100).toDouble();
    final color = value >= 85
        ? AppColors.error
        : value >= 65
        ? CupertinoColors.systemOrange.resolveFrom(context)
        : CupertinoColors.activeBlue.resolveFrom(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              label,
              style: TextStyle(
                fontSize: 8.5,
                fontWeight: FontWeight.w600,
                letterSpacing: 0.2,
                color: AppColors.tertiaryLabel(context),
              ),
            ),
            const Spacer(),
            Text(
              '${value.round()}%',
              style: TextStyle(
                fontSize: 9,
                fontWeight: FontWeight.w600,
                color: AppColors.secondaryLabel(context),
              ),
            ),
          ],
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
                    color: AppColors.separator(context).withValues(alpha: 0.16),
                  ),
                ),
                Positioned.fill(
                  child: FractionallySizedBox(
                    alignment: Alignment.centerLeft,
                    widthFactor: value / 100,
                    child: ColoredBox(color: color),
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

class _MiniCount extends StatelessWidget {
  const _MiniCount({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final int? value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: 12),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 11, color: AppColors.tertiaryLabel(context)),
          const SizedBox(width: 3),
          Text(
            value == null ? '—' : '$value',
            style: TextStyle(
              fontSize: 9.5,
              fontWeight: FontWeight.w600,
              color: AppColors.secondaryLabel(context),
            ),
          ),
          const SizedBox(width: 3),
          Text(
            label,
            style: TextStyle(
              fontSize: 9,
              color: AppColors.tertiaryLabel(context),
            ),
          ),
        ],
      ),
    );
  }
}

class _NodeDetailSheet extends StatelessWidget {
  const _NodeDetailSheet({
    required this.node,
    required this.isActive,
    required this.onSelect,
  });

  final PanelNode node;
  final bool isActive;
  final VoidCallback onSelect;

  @override
  Widget build(BuildContext context) {
    final blue = CupertinoColors.activeBlue.resolveFrom(context);
    final address = [node.address, if (node.port > 0) ':${node.port}'].join();
    return ActionSheetScaffold(
      title: proText(context, zh: '节点详情', en: 'Node details'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              _NodeAvatar(node: node, size: 46),
              const SizedBox(width: 11),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      node.isLocal
                          ? context.l10n.nodes_local
                          : node.displayName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: AppColors.label(context),
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      node.isLocal
                          ? proText(context, zh: '主节点', en: 'Primary node')
                          : proText(context, zh: '子节点', en: 'Child node'),
                      style: TextStyle(
                        fontSize: 11,
                        color: AppColors.secondaryLabel(context),
                      ),
                    ),
                  ],
                ),
              ),
              ProStatusPill(
                healthy: node.isOnline,
                label: node.isOnline
                    ? proText(context, zh: '健康', en: 'Healthy')
                    : proText(context, zh: '离线', en: 'Offline'),
              ),
            ],
          ),
          const SizedBox(height: 16),
          ProCard(
            title: proText(context, zh: '基本信息', en: 'General'),
            child: Column(
              children: [
                _DetailRow(
                  label: proText(context, zh: '节点名称', en: 'Name'),
                  value: node.name,
                  monospace: true,
                ),
                if (node.alias.isNotEmpty)
                  _DetailRow(
                    label: proText(context, zh: '别名', en: 'Alias'),
                    value: node.alias,
                  ),
                _DetailRow(
                  label: proText(context, zh: '地址', en: 'Address'),
                  value: address.isEmpty ? '-' : address,
                  monospace: true,
                ),
                if (node.nodePort > 0)
                  _DetailRow(
                    label: proText(context, zh: '节点端口', en: 'Node port'),
                    value: '${node.nodePort}',
                    monospace: true,
                  ),
                if (node.version.isNotEmpty)
                  _DetailRow(
                    label: proText(context, zh: '版本', en: 'Version'),
                    value: 'v${node.version}',
                  ),
                _DetailRow(
                  label: proText(context, zh: '版本类型', en: 'Edition'),
                  value: node.isPro
                      ? context.l10n.nodes_pro
                      : context.l10n.nodes_community,
                ),
                _DetailRow(
                  label: proText(context, zh: '授权绑定', en: 'License'),
                  value: node.isBound
                      ? proText(context, zh: '已绑定', en: 'Bound')
                      : proText(context, zh: '未绑定', en: 'Unbound'),
                ),
                if (node.syncStatus.isNotEmpty)
                  _DetailRow(
                    label: proText(context, zh: '同步状态', en: 'Sync'),
                    value: node.syncStatus,
                  ),
                if (node.groupBelong.isNotEmpty)
                  _DetailRow(
                    label: proText(context, zh: '所属分组', en: 'Group'),
                    value: node.groupBelong,
                  ),
                if (node.description.isNotEmpty)
                  _DetailRow(
                    label: proText(context, zh: '备注', en: 'Note'),
                    value: node.description,
                  ),
              ],
            ),
          ),
          Row(
            children: [
              Expanded(
                child: CupertinoButton(
                  padding: const EdgeInsets.symmetric(vertical: 11),
                  color: AppColors.tertiaryBackground(
                    context,
                  ).withValues(alpha: 0.8),
                  onPressed: () async {
                    if (address.isEmpty) return;
                    await Clipboard.setData(ClipboardData(text: address));
                    if (context.mounted) {
                      showAppSuccessToast(
                        proText(context, zh: '地址已复制', en: 'Address copied'),
                      );
                    }
                  },
                  child: Text(
                    proText(context, zh: '复制地址', en: 'Copy address'),
                    style: TextStyle(
                      fontSize: 13,
                      color: AppColors.label(context),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: CupertinoButton(
                  padding: const EdgeInsets.symmetric(vertical: 11),
                  color: isActive
                      ? AppColors.tertiaryBackground(
                          context,
                        ).withValues(alpha: 0.8)
                      : blue,
                  onPressed: isActive ? null : onSelect,
                  child: Text(
                    isActive
                        ? proText(context, zh: '当前节点', en: 'Current')
                        : proText(context, zh: '切换到此节点', en: 'Switch here'),
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: isActive
                          ? AppColors.secondaryLabel(context)
                          : CupertinoColors.white,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  const _DetailRow({
    required this.label,
    required this.value,
    this.monospace = false,
  });

  final String label;
  final String value;
  final bool monospace;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 88,
            child: Text(
              label,
              style: TextStyle(
                fontSize: 11,
                color: AppColors.secondaryLabel(context),
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              value.isEmpty ? '-' : value,
              style: TextStyle(
                fontSize: 11,
                height: 1.4,
                fontFamily: monospace ? 'Menlo' : null,
                color: AppColors.label(context),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
