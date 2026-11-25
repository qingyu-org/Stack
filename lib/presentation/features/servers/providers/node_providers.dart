import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/network/dio_client_provider.dart';
import '../../../../data/api/node_api.dart';
import '../../../../data/repositories_impl/server_repository_impl.dart';
import '../../../../domain/entities/panel_node.dart';

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

      return PanelNode.normalize(nodes, isPro: server?.isProActive ?? true);
    });
