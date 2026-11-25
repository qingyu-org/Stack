import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/localization/l10n_x.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../domain/entities/panel_node.dart';
import '../../../../domain/entities/server.dart';
import '../../servers/providers/node_providers.dart';
import '../../servers/providers/node_selection_provider.dart';
import '../../servers/providers/servers_provider.dart';
import '../widgets/pro_page_scaffold.dart';
import '../widgets/pro_snapshot_view.dart';

/// 专业版面板的节点总览。
///
/// 点击节点会把它设为当前节点并返回上一页；回到详情页后所有数据会按
/// `CurrentNode` 自动刷新。
class NodeManagementPage extends ConsumerWidget {
  const NodeManagementPage({super.key, required this.serverId});

  final int serverId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final server = _findServer(ref, serverId);
    final nodesAsync = ref.watch(serverNodesProvider(serverId));
    final activeNode =
        ref.watch(activeNodeControllerProvider(serverId)).valueOrNull ??
        PanelNode.localName;

    return ProPageScaffold(
      title: l10n.nodes_management,
      onRefresh: () async {
        ref.invalidate(serverNodesProvider(serverId));
        try {
          await ref.read(serverNodesProvider(serverId).future);
        } catch (_) {
          // 错误由页面状态展示。
        }
      },
      children: [
        if (server != null)
          _SummaryCard(server: server, nodes: nodesAsync.valueOrNull ?? []),
        nodesAsync.when(
          data: (nodes) => nodes.isEmpty
              ? ProSectionCard(
                  title: l10n.nodes_title,
                  child: Text(
                    l10n.nodes_empty,
                    style: TextStyle(
                      fontSize: 12,
                      color: AppColors.secondaryLabel(context),
                    ),
                  ),
                )
              : Column(
                  children: [
                    for (final node in nodes)
                      _NodeCard(
                        node: node,
                        isActive: node.name == activeNode,
                        onTap: () => _selectNode(context, ref, node),
                      ),
                  ],
                ),
          loading: () => const Padding(
            padding: EdgeInsets.symmetric(vertical: 60),
            child: Center(child: CupertinoActivityIndicator()),
          ),
          error: (error, stack) => ProUnavailableView(
            description: '${error}',
            onRetry: () => ref.invalidate(serverNodesProvider(serverId)),
          ),
        ),
      ],
    );
  }

  Future<void> _selectNode(
    BuildContext context,
    WidgetRef ref,
    PanelNode node,
  ) async {
    await ref
        .read(activeNodeControllerProvider(serverId).notifier)
        .select(node.name);
    if (!context.mounted) return;
    Navigator.of(context).pop(node.name);
  }

  Server? _findServer(WidgetRef ref, int serverId) {
    final servers = ref.watch(serversNotifierProvider).valueOrNull;
    if (servers == null) return null;
    for (final server in servers) {
      if (server.id == serverId) return server;
    }
    return null;
  }
}

class _SummaryCard extends StatelessWidget {
  const _SummaryCard({required this.server, required this.nodes});

  final Server server;
  final List<PanelNode> nodes;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final online = nodes.where((node) => node.isOnline).length;
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      decoration: BoxDecoration(
        color: AppColors.secondaryBackground(context).withValues(alpha: 0.68),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: AppColors.separator(context).withValues(alpha: 0.14),
          width: 0.5,
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: CupertinoColors.activeBlue.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(
              CupertinoIcons.rectangle_stack_fill,
              size: 20,
              color: CupertinoColors.activeBlue,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  server.displayName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: AppColors.label(context),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '${nodes.length} ${l10n.nodes_title}'
                  ' · $online ${l10n.nodes_online}',
                  style: TextStyle(
                    fontSize: 11.5,
                    color: AppColors.secondaryLabel(context),
                  ),
                ),
              ],
            ),
          ),
          if (server.isPro)
            _Badge(label: l10n.nodes_pro, color: CupertinoColors.activeBlue),
        ],
      ),
    );
  }
}

class _NodeCard extends StatelessWidget {
  const _NodeCard({
    required this.node,
    required this.isActive,
    required this.onTap,
  });

  final PanelNode node;
  final bool isActive;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final statusColor = node.isOnline
        ? AppColors.success
        : AppColors.secondaryLabel(context);
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
        decoration: BoxDecoration(
          color: isActive
              ? CupertinoColors.activeBlue.withValues(alpha: 0.1)
              : AppColors.secondaryBackground(context).withValues(alpha: 0.68),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isActive
                ? CupertinoColors.activeBlue.withValues(alpha: 0.5)
                : AppColors.separator(context).withValues(alpha: 0.14),
            width: isActive ? 1 : 0.5,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: statusColor,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 7),
                Expanded(
                  child: Text(
                    node.isLocal ? l10n.nodes_local : node.displayName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: AppColors.label(context),
                    ),
                  ),
                ),
                if (isActive)
                  _Badge(
                    label: l10n.nodes_current,
                    color: CupertinoColors.activeBlue,
                  ),
                if (node.isPro) ...[
                  const SizedBox(width: 6),
                  _Badge(
                    label: l10n.nodes_pro,
                    color: CupertinoColors.systemPurple,
                  ),
                ],
              ],
            ),
            const SizedBox(height: 4),
            Text(
              [
                node.address.isNotEmpty ? node.address : null,
                node.version.isNotEmpty
                    ? l10n.nodes_version(node.version)
                    : null,
                node.isOnline ? l10n.nodes_online : l10n.nodes_offline,
              ].whereType<String>().join(' · '),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 11,
                height: 1.35,
                color: AppColors.secondaryLabel(context),
              ),
            ),
            if (node.cpuUsedPercent != null ||
                node.memoryUsedPercent != null) ...[
              const SizedBox(height: 9),
              Row(
                children: [
                  Expanded(
                    child: _MetricBar(
                      label: 'CPU',
                      percent: node.cpuUsedPercent,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _MetricBar(
                      label: 'MEM',
                      percent: node.memoryUsedPercent,
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _MetricBar extends StatelessWidget {
  const _MetricBar({required this.label, required this.percent});

  final String label;
  final double? percent;

  @override
  Widget build(BuildContext context) {
    final value = (percent ?? 0).clamp(0, 100).toDouble();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              label,
              style: TextStyle(
                fontSize: 9.5,
                fontWeight: FontWeight.w600,
                color: AppColors.tertiaryLabel(context),
              ),
            ),
            const Spacer(),
            Text(
              '${value.round()}%',
              style: TextStyle(
                fontSize: 9.5,
                color: AppColors.secondaryLabel(context),
              ),
            ),
          ],
        ),
        const SizedBox(height: 3),
        ClipRRect(
          borderRadius: BorderRadius.circular(2),
          child: SizedBox(
            height: 3,
            child: Stack(
              children: [
                Positioned.fill(
                  child: ColoredBox(
                    color: AppColors.separator(context).withValues(alpha: 0.18),
                  ),
                ),
                Positioned.fill(
                  child: FractionallySizedBox(
                    alignment: Alignment.centerLeft,
                    widthFactor: value / 100,
                    child: ColoredBox(
                      color: value >= 85
                          ? AppColors.error
                          : CupertinoColors.activeBlue,
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

class _Badge extends StatelessWidget {
  const _Badge({required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 9,
          fontWeight: FontWeight.w700,
          color: color,
        ),
      ),
    );
  }
}
