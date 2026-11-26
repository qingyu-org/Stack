import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/localization/l10n_x.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../domain/entities/dashboard.dart';
import '../../../../domain/entities/panel_node.dart';
import '../../../../domain/entities/server.dart';
import '../../settings/providers/app_settings_provider.dart';
import '../providers/node_providers.dart';
import 'server_card_compact.dart';
import 'server_card_metrics.dart';
import 'server_card_shared.dart';
import 'server_card_simple.dart';
import 'server_card_terminal.dart';

/// 专业版多机面板里的单个节点卡片。
///
/// 复用社区版 [SimpleServerCard] 的完整信息层级（系统、延迟、CPU/内存/
/// 磁盘、网站/数据库/应用/计划任务数量），只是把标题换成节点名，并由
/// 该节点自己的 DioClient 拉取快照。
class NodeServerCard extends ConsumerWidget {
  const NodeServerCard({
    super.key,
    required this.server,
    required this.node,
    required this.onTap,
    this.onLongPress,
    this.isSelected = false,
    this.showCountLinks = false,
    this.style = ServerCardStyle.simple,
  });

  final Server server;
  final PanelNode node;
  final VoidCallback onTap;
  final VoidCallback? onLongPress;
  final bool isSelected;
  final bool showCountLinks;
  final ServerCardStyle style;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final snapshot = ref.watch(
      nodeDashboardSnapshotProvider((server.id, node.name)),
    );
    final data = snapshot.valueOrNull;
    final dashboard = data?.dashboard;
    final status = ServerCardStatus.fromSnapshot(
      isLoading: snapshot.isLoading,
      hasData: dashboard != null,
      hasError: snapshot.hasError,
      latencyMs: data?.fetchMs,
    );
    final subtitle = _subtitle(node, dashboard?.base);
    final card = switch (style) {
      ServerCardStyle.simple => SimpleServerCard(
        server: server,
        dashboard: dashboard,
        status: status,
        onTap: onTap,
        isSelected: isSelected,
        loading: snapshot.isLoading && dashboard == null,
        titleOverride: node.displayName,
        subtitleOverride: subtitle,
        titleBadge: node.isPro ? const NodeEditionBadge.pro() : null,
        showCountLinks: showCountLinks,
      ),
      ServerCardStyle.terminal => TerminalServerCard(
        server: server,
        dashboard: dashboard,
        status: status,
        onTap: onTap,
        isSelected: isSelected,
        loading: snapshot.isLoading && dashboard == null,
        titleOverride: node.displayName,
        subtitleOverride: subtitle,
        titleBadge: node.isPro ? const NodeEditionBadge.pro() : null,
      ),
      ServerCardStyle.compact => CompactServerCard(
        server: server,
        dashboard: dashboard,
        status: status,
        onTap: onTap,
        isSelected: isSelected,
        loading: snapshot.isLoading && dashboard == null,
        titleOverride: node.displayName,
        subtitleOverride: subtitle,
        titleBadge: node.isPro ? const NodeEditionBadge.pro() : null,
      ),
      ServerCardStyle.metrics => MetricsServerCard(
        server: server,
        dashboard: dashboard,
        status: status,
        onTap: onTap,
        isSelected: isSelected,
        loading: snapshot.isLoading && dashboard == null,
        titleOverride: node.displayName,
        subtitleOverride: subtitle,
        titleBadge: node.isPro ? const NodeEditionBadge.pro() : null,
      ),
    };

    if (onLongPress == null) return card;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onLongPress: onLongPress,
      child: card,
    );
  }

  String _subtitle(PanelNode node, DashboardBase? base) {
    final parts = <String>[
      if (node.isLocal) 'local',
      if (node.address.isNotEmpty) node.address,
      if (node.version.isNotEmpty) node.version,
    ];
    if (parts.isNotEmpty) return parts.join(' · ');
    final pretty = base?.prettyDistro;
    if (pretty != null && pretty.isNotEmpty) return pretty;
    return '${node.name}:${node.port}';
  }
}

/// 节点版本标签：专业版 / 社区版。
class NodeEditionBadge extends StatelessWidget {
  const NodeEditionBadge.pro({super.key}) : _isPro = true;

  const NodeEditionBadge.community({super.key}) : _isPro = false;

  final bool _isPro;

  @override
  Widget build(BuildContext context) {
    final color = _isPro
        ? CupertinoColors.activeBlue.resolveFrom(context)
        : AppColors.secondaryLabel(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.11),
        borderRadius: BorderRadius.circular(5),
      ),
      child: Text(
        _isPro ? context.l10n.nodes_pro : context.l10n.nodes_community,
        style: TextStyle(
          fontSize: 9,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.1,
          color: color,
          height: 1.1,
        ),
      ),
    );
  }
}
