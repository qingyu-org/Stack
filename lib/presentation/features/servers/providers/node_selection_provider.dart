import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/storage/storage_service.dart';
import '../../../../domain/entities/panel_node.dart';

/// 当前面板正在操作的节点名。
///
/// 1Panel 专业版通过 `CurrentNode` 请求头把 API 调用路由到子节点。这里把
/// 选择保存在本地（每台面板一份），`dioClientProvider` 会 watch 它，因此
/// 切换节点时网络客户端与所有依赖的数据 Provider 都会自动重建/刷新。
final activeNodeControllerProvider = AsyncNotifierProvider.autoDispose
    .family<ActiveNodeController, String, int>(ActiveNodeController.new);

class ActiveNodeController extends AutoDisposeFamilyAsyncNotifier<String, int> {
  @override
  Future<String> build(int serverId) async {
    final storage = ref.watch(storageServiceProvider);
    final stored = storage.activeNodeName(serverId);
    final server = await storage.getServer(serverId);
    if (server == null || server.nodes.isEmpty) return stored;
    final exists = server.nodes.any((node) => node.name == stored);
    if (exists) return stored;
    await storage.setActiveNodeName(serverId, PanelNode.localName);
    return PanelNode.localName;
  }

  /// 切换当前节点。`local` 表示主面板本身。
  Future<void> select(String nodeName) async {
    final name = nodeName.trim().isEmpty
        ? PanelNode.localName
        : nodeName.trim();
    state = AsyncData(name);
    await ref
        .read(storageServiceProvider)
        .setActiveNodeName(arg, name == PanelNode.localName ? '' : name);
  }

  Future<void> resetToLocal() => select(PanelNode.localName);
}
