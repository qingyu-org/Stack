import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_tabler_icons/flutter_tabler_icons.dart';

import '../../../../core/localization/l10n_x.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../domain/entities/panel_node.dart';
import '../../../../domain/entities/server.dart';
import '../../settings/providers/app_settings_provider.dart';
import '../providers/node_providers.dart';
import '../providers/node_selection_provider.dart';
import 'node_server_card.dart';

/// 专业版多机面板在服务器列表里的组卡。
///
/// 一张大面板卡里纵向铺开每个节点的完整社区版服务器卡；节点卡保留
/// 系统、延迟、CPU/内存/磁盘与网站/数据库/应用/任务数量，而不是缩成
/// 一排小格子。
class ServerGroupCard extends ConsumerWidget {
  const ServerGroupCard({
    super.key,
    required this.server,
    required this.onOpenNode,
    this.onLongPressNode,
    this.onLongPressHeader,
    this.isSelected = false,
    this.style = ServerCardStyle.simple,
  });

  final Server server;
  final ValueChanged<String> onOpenNode;
  final ServerCardStyle style;

  /// 长按某个节点卡（传入节点卡自身的 context，用于锚定菜单）。
  final void Function(BuildContext context, PanelNode node)? onLongPressNode;

  /// 长按面板标题区域。
  final void Function(BuildContext context)? onLongPressHeader;

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
    final hasProNode = nodes.any((node) => node.isPro);

    return Builder(
      builder: (cardContext) => Container(
        padding: const EdgeInsets.fromLTRB(12, 12, 12, 14),
        decoration: BoxDecoration(
          color: AppColors.secondaryBackground(context).withValues(alpha: 0.64),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
            color: isSelected
                ? CupertinoColors.activeBlue.withValues(alpha: 0.55)
                : AppColors.separator(context).withValues(alpha: 0.16),
            width: isSelected ? 1.2 : 0.6,
          ),
          boxShadow: [
            BoxShadow(
              color: CupertinoColors.black.withValues(
                alpha: CupertinoTheme.brightnessOf(context) == Brightness.dark
                    ? 0.2
                    : 0.035,
              ),
              blurRadius: 18,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            GestureDetector(
              behavior: HitTestBehavior.opaque,
              onLongPress: () => onLongPressHeader?.call(cardContext),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(2, 0, 2, 10),
                child: Row(
                  children: [
                    Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: CupertinoColors.activeBlue.withValues(
                          alpha: 0.11,
                        ),
                        borderRadius: BorderRadius.circular(11),
                      ),
                      child: const Icon(
                        TablerIcons.server_2,
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
                                    fontSize: 18,
                                    fontWeight: FontWeight.w800,
                                    letterSpacing: -0.45,
                                    color: AppColors.label(context),
                                  ),
                                ),
                              ),
                              if (hasProNode) ...[
                                const SizedBox(width: 6),
                                const NodeEditionBadge.pro(),
                              ],
                            ],
                          ),
                          const SizedBox(height: 2),
                          Text(
                            '${nodes.length} ${l10n.nodes_title} · '
                            '$onlineCount ${l10n.nodes_online}',
                            style: TextStyle(
                              fontSize: 11.5,
                              fontWeight: FontWeight.w500,
                              color: AppColors.secondaryLabel(context),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    if (nodesAsync.isLoading && nodesAsync.valueOrNull == null)
                      const CupertinoActivityIndicator(radius: 8)
                    else
                      _OnlinePill(online: onlineCount, total: nodes.length),
                  ],
                ),
              ),
            ),
            nodesAsync.when(
              data: (liveNodes) =>
                  _buildNodes(context, cardContext, liveNodes, activeNode),
              loading: () =>
                  _buildNodes(context, cardContext, nodes, activeNode),
              error: (error, _) => _NodeError(
                message: l10n.nodes_loadFailed,
                onRetry: () => ref.invalidate(serverNodesProvider(server.id)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNodes(
    BuildContext context,
    BuildContext cardContext,
    List<PanelNode> nodes,
    String? activeNode,
  ) {
    if (nodes.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 18),
        child: Text(
          context.l10n.nodes_empty,
          style: TextStyle(
            fontSize: 12,
            color: AppColors.secondaryLabel(context),
          ),
        ),
      );
    }
    return Column(
      children: [
        for (var i = 0; i < nodes.length; i++) ...[
          if (i > 0) const SizedBox(height: 9),
          NodeServerCard(
            server: server,
            node: nodes[i],
            isSelected: (activeNode ?? PanelNode.localName) == nodes[i].name,
            style: style,
            onTap: () => onOpenNode(nodes[i].name),
            onLongPress: onLongPressNode == null
                ? null
                : () => onLongPressNode!(cardContext, nodes[i]),
          ),
        ],
      ],
    );
  }
}

class _OnlinePill extends StatelessWidget {
  const _OnlinePill({required this.online, required this.total});

  final int online;
  final int total;

  @override
  Widget build(BuildContext context) {
    final allOnline = total > 0 && online == total;
    final color = allOnline
        ? AppColors.success
        : (online == 0
              ? AppColors.secondaryLabel(context)
              : CupertinoColors.systemOrange.resolveFrom(context));
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.09),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withValues(alpha: 0.12), width: 0.5),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 6,
            height: 6,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 5),
          Text(
            '$online/$total',
            style: TextStyle(
              fontSize: 10.5,
              fontWeight: FontWeight.w700,
              color: color,
              height: 1,
            ),
          ),
        ],
      ),
    );
  }
}

class _NodeError extends StatelessWidget {
  const _NodeError({required this.message, this.onRetry});

  final String message;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
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
