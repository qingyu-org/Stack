import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../storage/storage_service.dart';
import '../utils/server_host_normalizer.dart';
import '../../presentation/features/servers/providers/node_selection_provider.dart';
import '../../presentation/features/settings/providers/app_settings_provider.dart';
import 'dio_client.dart';

part 'dio_client_provider.g.dart';

/// `(面板, 节点)` 客户端缓存的键。
class NodeClientKey {
  const NodeClientKey(this.serverId, this.nodeName);

  final int serverId;
  final String nodeName;

  @override
  bool operator ==(Object other) {
    return other is NodeClientKey &&
        other.serverId == serverId &&
        other.nodeName == nodeName;
  }

  @override
  int get hashCode => Object.hash(serverId, nodeName);

  @override
  String toString() => 'NodeClientKey($serverId, $nodeName)';
}

/// 服务器配置（地址、API Key、证书）变更时递增。
///
/// [nodeDioClient] 监听它，因此编辑面板会重建该服务器下**所有**已缓存的
/// 节点客户端，包括已经不在当前节点列表里的旧节点，避免旧 API Key 残留。
@Riverpod(keepAlive: true)
class NodeClientRevision extends _$NodeClientRevision {
  @override
  int build(int serverId) => 0;

  void bump() => state = state + 1;
}

/// 单个节点的 DioClient（按 `(serverId, node)` 缓存）。
///
/// 每个节点拥有独立的连接池；切换节点只切换使用哪个客户端，不会销毁
/// 其它节点正在使用的客户端，避免中断进行中的上传/长请求。
@Riverpod(keepAlive: true)
Future<DioClient> nodeDioClient(Ref ref, NodeClientKey key) async {
  ref.watch(nodeClientRevisionProvider(key.serverId));
  final storage = ref.watch(storageServiceProvider);
  final server = await storage.getServer(key.serverId);
  if (server == null) {
    throw StateError('服务器不存在: ${key.serverId}');
  }
  final apiKey = await storage.getApiKey(key.serverId) ?? '';
  final settings = await ref.watch(appSettingsControllerProvider.future);
  final userAgent = await DioClient.defaultUserAgent();

  final client = DioClient(
    baseUrl: server.baseUrl.toString(),
    apiKey: apiKey,
    requestTimeout: Duration(seconds: settings.requestTimeoutSeconds),
    customHeaders: settings.customHeaders,
    userAgent: userAgent,
    allowInsecureConnections: server.allowInsecureConnections,
    currentNodeName: key.nodeName,
  );
  ref.onDispose(client.dispose);
  return client;
}

/// 当前激活节点对应的 DioClient。
///
/// 所有业务 Provider 继续使用这个 Provider 即可；节点切换时它返回另一个
/// 节点客户端的 future，但不会 dispose 旧客户端（旧客户端仍由
/// [nodeDioClientProvider] 持有，供进行中的请求 / 终端继续使用）。
@Riverpod(keepAlive: true)
Future<DioClient> dioClient(Ref ref, int serverId) async {
  final activeNode = await ref.watch(
    activeNodeControllerProvider(serverId).future,
  );
  return ref.watch(
    nodeDioClientProvider(NodeClientKey(serverId, activeNode)).future,
  );
}

/// 一次性构建的"裸" DioClient，用于添加服务器时的连通性测试。
///
/// 不缓存、不持久化，测试完直接 dispose。
Future<DioClient> createProbeClient({
  required String host,
  required int port,
  required String apiKey,
  required bool isHttps,
  int requestTimeoutSeconds =
      AppSettingsController.defaultRequestTimeoutSeconds,
  Map<String, String> customHeaders = const {},
  bool allowInsecureConnections = false,
  String currentNodeName = '',
}) async {
  final userAgent = await DioClient.defaultUserAgent();
  final baseUrl = buildServerBaseUrl(host: host, port: port, isHttps: isHttps);
  return DioClient(
    baseUrl: baseUrl,
    apiKey: apiKey,
    requestTimeout: Duration(seconds: requestTimeoutSeconds),
    customHeaders: customHeaders,
    userAgent: userAgent,
    allowInsecureConnections: allowInsecureConnections,
    currentNodeName: currentNodeName,
  );
}
