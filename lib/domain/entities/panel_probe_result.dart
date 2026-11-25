import '../../domain/entities/panel_node.dart';

/// 添加 / 编辑面板时自动探测出的专业版信息。
class PanelProbeResult {
  const PanelProbeResult({
    required this.isPro,
    required this.nodes,
    this.licenseStatus = '',
    this.productPro = '',
    this.nodeApiAvailable = false,
    this.apiError = '',
  });

  final bool isPro;

  /// 始终包含 `local`，并按主节点优先排序。
  final List<PanelNode> nodes;

  final String licenseStatus;
  final String productPro;

  /// `/core/nodes/*` 是否可用（可用即代表面板至少具备多机能力）。
  final bool nodeApiAvailable;

  /// 探测失败原因，仅用于调试/提示，不影响添加面板。
  final String apiError;
}
