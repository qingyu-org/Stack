import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/network/dio_client_provider.dart';
import '../../../../data/api/dashboard_api.dart';
import '../../../../data/api/node_api.dart';
import '../../../../data/repositories_impl/server_repository_impl.dart';
import '../../../../domain/entities/panel_node.dart';
import 'node_selection_provider.dart';
import 'servers_provider.dart';

/// 拉取面板下的实时节点列表（含主节点）。
///
/// 该请求走主面板的 `/core/nodes/*`，不会被子节点代理；失败时回退到
/// 添加/编辑面板时缓存的节点，保证离线时组卡仍有结构可展示。
final serverNodesProvider = FutureProvider.autoDispose
    .family<List<PanelNode>, int>((ref, serverId) async {
      final client = await ref.watch(dioClientProvider(serverId).future);
      final server = await ref.watch(serverRepositoryProvider).find(serverId);
      final api = NodeApi(client);

      List<PanelNode> nodes;
      try {
        nodes = await api.listNodes();
      } catch (error) {
        final cached = server?.nodes ?? const <PanelNode>[];
        if (cached.isNotEmpty) return cached;
        rethrow;
      }

      try {
        nodes = PanelNode.mergeSimpleMetrics(
          nodes,
          await api.listSimpleNodes(),
        );
      } catch (_) {
        // 指标接口不可用时只展示节点结构。
      }

      final normalized = PanelNode.normalize(
        nodes,
        isPro: server?.isProActive ?? true,
      );

      // 拓扑可能在上次探测之后发生变化（新增/删除子节点）。把最新节点
      // 写回 Server，既能让组卡立即更新，也能保证重启后活动节点校验
      // 仍然认得这些节点。仅在节点名集合变化时写入，避免无谓的存储抖动。
      if (server != null && _topologyChanged(server.nodes, normalized)) {
        server.nodes = normalized;
        if (normalized.any((node) => !node.isLocal)) {
          server.isPro = true;
          server.proCheckedAt = DateTime.now();
        }
        try {
          await ref.read(serverRepositoryProvider).update(server);
        } catch (_) {
          // 持久化失败不影响本次展示。
        }
      }

      return normalized;
    });

bool _topologyChanged(List<PanelNode> cached, List<PanelNode> live) {
  if (cached.length != live.length) return true;
  final cachedByName = {for (final node in cached) node.name: node};
  for (final node in live) {
    final previous = cachedByName[node.name];
    if (previous == null) return true;
    if (previous.isXpack != node.isXpack) return true;
    if (previous.alias != node.alias) return true;
  }
  return false;
}

/// 单个节点的完整 dashboard 快照（系统、CPU/内存/磁盘、网站/应用/数据库/
/// 计划任务数量），并记录请求耗时作为节点延迟。
final nodeDashboardSnapshotProvider = FutureProvider.autoDispose
    .family<ServerDashboardSnapshot, (int, String)>((ref, key) async {
      final (serverId, nodeName) = key;
      final client = await ref.watch(
        nodeDioClientProvider(NodeClientKey(serverId, nodeName)).future,
      );
      final stopWatch = Stopwatch()..start();
      final dashboard = await DashboardApi(client).getDashboardSnapshot();
      return ServerDashboardSnapshot(
        dashboard: dashboard,
        fetchMs: stopWatch.elapsedMilliseconds,
      );
    });

/// 当前活动节点是否拥有 Pro 能力。
///
/// 1Panel Pro 只有主节点（isXpack=true）有 WAF/监控/报表等菜单；子节点
/// 即使 isBound=true 也按社区版展示。节点列表不可用时退回面板级判断。
final activeNodeIsProProvider = Provider.autoDispose.family<bool, int>((
  ref,
  serverId,
) {
  final activeNode =
      ref.watch(activeNodeControllerProvider(serverId)).valueOrNull ??
      PanelNode.localName;
  final server = ref
      .watch(serversNotifierProvider)
      .valueOrNull
      ?.where((item) => item.id == serverId)
      .firstOrNull;
  final nodes =
      ref.watch(serverNodesProvider(serverId)).valueOrNull ??
      server?.nodes ??
      const <PanelNode>[];
  for (final node in nodes) {
    if (node.name == activeNode) return node.isPro;
  }
  return server?.isProActive ?? false;
});

extension _FirstOrNull<T> on Iterable<T> {
  T? get firstOrNull => isEmpty ? null : first;
}
