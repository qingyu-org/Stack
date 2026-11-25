import '../../core/network/dio_client.dart';
import '../../domain/entities/panel_node.dart';
import '../../domain/entities/panel_probe_result.dart';
import '../api/node_api.dart';

/// 探测 1Panel 面板是否为专业版，并拉取节点列表。
///
/// 该过程永远不抛异常：社区版缺接口、网络抖动、权限不足都降级为普通
/// 单机面板，保证“添加服务器”不会被专业版探测阻塞。
class PanelProbeService {
  const PanelProbeService._();

  static Future<PanelProbeResult> detect(DioClient client) async {
    final api = NodeApi(client);
    var licenseStatus = '';
    var productPro = '';
    var isPro = false;
    var nodeApiAvailable = false;
    var error = '';

    try {
      final license = await api.getLicenseStatus();
      licenseStatus = license.status;
      productPro = license.productPro;
      isPro = license.isPro;
    } catch (_) {
      // 社区版 / 未授权 / 接口被裁剪，均按非专业版继续。
    }

    var nodes = <PanelNode>[];
    List<PanelNode>? currentNodes;
    try {
      nodes = await api.listNodes();
      nodeApiAvailable = nodes.isNotEmpty;
      // 官方 Pro 用每个节点自己的 isXpack 决定该节点是否有 Pro 菜单。
      if (nodes.any((node) => node.isXpack)) isPro = true;
    } catch (e) {
      error = '$e';
    }

    if (nodeApiAvailable) {
      try {
        currentNodes = await api.listCurrentNodes();
        nodes = PanelNode.mergeSimpleMetrics(nodes, currentNodes);
      } catch (_) {
        // 资源指标是锦上添花，失败不影响节点结构。
      }
    }

    return PanelProbeResult(
      isPro: isPro,
      nodes: PanelNode.normalize(nodes, isPro: isPro),
      licenseStatus: licenseStatus,
      productPro: productPro,
      nodeApiAvailable: nodeApiAvailable,
      apiError: error,
    );
  }
}
