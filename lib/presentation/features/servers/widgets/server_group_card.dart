import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/localization/l10n_x.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../domain/entities/panel_node.dart';
import '../../../../domain/entities/server.dart';
import '../providers/node_providers.dart';
import '../providers/node_selection_provider.dart';

/// 专业版多机面板在服务器列表里的组卡：一个大圆角卡片包住主节点与子节点。
class ServerGroupCard extends ConsumerWidget {
  const ServerGroupCard({
    super.key,
    required this.server,
    required this.onOpenNode,
    this.onLongPress,
    this.isSelected = false,
  });

  final Server server;
  final ValueChanged<String> onOpenNode;
  final VoidCallback? onLongPress;
  final bool isSelected;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final nodesAsync = ref.watch(serverNodesProvider(server.id));
    final activeNode = ref
        .watch(activeNodeControllerProvider(server.id))
        .valueOrNull;
    final nodes = nodesAsync.valueOrNull ?? server.nodes;
    final onlineCount = nodes.where((node) => node.isOnline).length;

    return Container(
      decoration: BoxDecoration(
        color: AppColors.secondaryBackground(context).withValues(alpha: 0.72),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: isSelected
              ? CupertinoColors.activeBlue.withValues(alpha: 0.6)
              : AppColors.separator(context).withValues(alpha: 0.16),
          width: isSelected ? 1.2 : 0.5,
        ),
      ),
      child: Column(
        children: [
          GestureDetector(
            behavior: HitTestBehavior.opaque,
            onLongPress: onLongPress,
            onTap: () => onOpenNode(PanelNode.localName),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(14, 14, 12, 10),
              child: Row(
                children: [
                  Container(
                    width: 38,
                    height: 38,
                    decoration: BoxDecoration(
                      color: CupertinoColors.activeBlue.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(
                      CupertinoIcons.rectangle_stack_fill,
                      size: 19,
                      color: CupertinoColors.activeBlue,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Flexible(
                              child: Text(
                                server.displayName,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontSize: 17,
                                  fontWeight: FontWeight.w700,
                                  letterSpacing: -0.3,
                                  color: AppColors.label(context),
                                ),
                              ),
                            ),
                            const SizedBox(width: 6),
                            _ProBadge(label: l10n.nodes_pro),
                          ],
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '${nodes.length} ${l10n.nodes_title}'
                          ' · $onlineCount ${l10n.nodes_online}',
                          style: TextStyle(
                            fontSize: 12,
                            color: AppColors.secondaryLabel(context),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  if (nodesAsync.isLoading)
                    const CupertinoActivityIndicator(radius: 8)
                  else
                    Icon(
                      CupertinoIcons.chevron_right,
                      size: 16,
                      color: AppColors.tertiaryLabel(context),
                    ),
                ],
              ),
            ),
          ),
          Container(
            height: 0.5,
            margin: const EdgeInsets.symmetric(horizontal: 14),
            color: AppColors.separator(context).withValues(alpha: 0.12),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
            child: nodesAsync.when(
              data: (nodes) => _NodeGrid(
                nodes: nodes,
                activeNode: activeNode,
                onTap: onOpenNode,
                onLongPress: onLongPress,
              ),
              loading: () => nodes.isEmpty
                  ? const Padding(
                      padding: EdgeInsets.symmetric(vertical: 18),
                      child: CupertinoActivityIndicator(),
                    )
                  : _NodeGrid(
                      nodes: nodes,
                      activeNode: activeNode,
                      onTap: onOpenNode,
                      onLongPress: onLongPress,
                    ),
              error: (error, _) => _NodeError(
                message: l10n.nodes_loadFailed,
                onRetry: () => ref.invalidate(serverNodesProvider(server.id)),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _NodeGrid extends StatelessWidget {
  const _NodeGrid({
    required this.nodes,
    required this.activeNode,
    required this.onTap,
    this.onLongPress,
  });

  final List<PanelNode> nodes;
  final String? activeNode;
  final ValueChanged<String> onTap;
  final VoidCallback? onLongPress;

  @override
  Widget build(BuildContext context) {
    if (nodes.isEmpty) {
      return _NodeError(message: context.l10n.nodes_empty, onRetry: null);
    }
    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = constraints.maxWidth >= 560 ? 3 : 2;
        const spacing = 10.0;
        final width =
            (constraints.maxWidth - spacing * (columns - 1)) / columns;
        return Wrap(
          spacing: spacing,
          runSpacing: spacing,
          children: [
            for (final node in nodes)
              SizedBox(
                width: width,
                child: _NodeTile(
                  node: node,
                  isActive: (activeNode ?? PanelNode.localName) == node.name,
                  onTap: () => onTap(node.name),
                  onLongPress: onLongPress,
                ),
              ),
          ],
        );
      },
    );
  }
}

class _NodeTile extends StatelessWidget {
  const _NodeTile({
    required this.node,
    required this.isActive,
    required this.onTap,
    this.onLongPress,
  });

  final PanelNode node;
  final bool isActive;
  final VoidCallback onTap;
  final VoidCallback? onLongPress;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final statusColor = node.isOnline
        ? AppColors.success
        : AppColors.secondaryLabel(context);
    final title = node.isLocal ? l10n.nodes_local : node.displayName;
    final subtitle = !node.isOnline
        ? l10n.nodes_offline
        : (node.version.isNotEmpty
              ? l10n.nodes_version(node.version)
              : (node.address.isNotEmpty ? node.address : l10n.nodes_online));

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      onLongPress: onLongPress,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.fromLTRB(10, 9, 10, 9),
        decoration: BoxDecoration(
          color: isActive
              ? CupertinoColors.activeBlue.withValues(alpha: 0.1)
              : AppColors.tertiaryBackground(context).withValues(alpha: 0.55),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isActive
                ? CupertinoColors.activeBlue.withValues(alpha: 0.5)
                : AppColors.separator(context).withValues(alpha: 0.1),
            width: isActive ? 1 : 0.5,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                Container(
                  width: 7,
                  height: 7,
                  decoration: BoxDecoration(
                    color: statusColor,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: AppColors.label(context),
                    ),
                  ),
                ),
                if (node.isPro && !node.isLocal)
                  Icon(
                    CupertinoIcons.checkmark_seal_fill,
                    size: 11,
                    color: CupertinoColors.activeBlue.withValues(alpha: 0.8),
                  ),
              ],
            ),
            const SizedBox(height: 3),
            Text(
              subtitle,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 10.5,
                color: AppColors.secondaryLabel(context),
              ),
            ),
            if (node.cpuUsedPercent != null ||
                node.memoryUsedPercent != null) ...[
              const SizedBox(height: 7),
              Row(
                children: [
                  Expanded(
                    child: _MiniMetric(
                      label: 'CPU',
                      percent: node.cpuUsedPercent,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _MiniMetric(
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

class _MiniMetric extends StatelessWidget {
  const _MiniMetric({required this.label, required this.percent});

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
                fontSize: 9,
                fontWeight: FontWeight.w600,
                color: AppColors.tertiaryLabel(context),
              ),
            ),
            const Spacer(),
            Text(
              '${value.round()}%',
              style: TextStyle(
                fontSize: 9,
                color: AppColors.secondaryLabel(context),
              ),
            ),
          ],
        ),
        const SizedBox(height: 2),
        ClipRRect(
          borderRadius: BorderRadius.circular(2),
          child: SizedBox(
            height: 3,
            child: Stack(
              children: [
                Positioned.fill(
                  child: ColoredBox(
                    color: AppColors.separator(context).withValues(alpha: 0.2),
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

class _NodeError extends StatelessWidget {
  const _NodeError({required this.message, required this.onRetry});

  final String message;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Flexible(
            child: Text(
              message,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 12,
                color: AppColors.secondaryLabel(context),
              ),
            ),
          ),
          if (onRetry != null) ...[
            const SizedBox(width: 10),
            CupertinoButton(
              padding: EdgeInsets.zero,
              minimumSize: Size.zero,
              onPressed: onRetry,
              child: Text(
                context.l10n.nodes_retry,
                style: const TextStyle(fontSize: 12),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _ProBadge extends StatelessWidget {
  const _ProBadge({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
      decoration: BoxDecoration(
        color: CupertinoColors.activeBlue.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        label,
        style: const TextStyle(
          fontSize: 9,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.2,
          color: CupertinoColors.activeBlue,
        ),
      ),
    );
  }
}
