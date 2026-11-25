import '../../../core/network/api_response_parser.dart';
import '../../../core/network/dio_client.dart';
import '../../../domain/entities/panel_node.dart';

/// 1Panel 专业版节点与授权相关 API。
///
/// 社区版没有 `/core/nodes/*` 与 `/core/licenses/status`，调用会返回
/// 404/403；调用方应把它当作能力边界而不是致命错误。
class NodeApi {
  NodeApi(this._client);

  final DioClient _client;

  /// POST /api/v2/core/nodes/list
  ///
  /// `type` 常用 `all` / `free`。返回的 `local` 代表主面板自身。
  Future<List<PanelNode>> listNodes({String type = 'all'}) async {
    final resp = await _client.post<Map<String, dynamic>>(
      '/api/v2/core/nodes/list',
      data: {'type': type},
    );
    return ApiResponseParser.list(resp, _nodeFromJson);
  }

  /// GET /api/v2/core/nodes/all
  Future<List<PanelNode>> listAllNodes() async {
    final resp = await _client.get<Map<String, dynamic>>(
      '/api/v2/core/nodes/all',
    );
    return ApiResponseParser.list(resp, _nodeFromJson);
  }

  /// GET /api/v2/core/nodes/simple/all
  ///
  /// 返回节点卡片需要的 CPU / 内存概览。
  Future<List<PanelNode>> listSimpleNodes() async {
    final resp = await _client.get<Map<String, dynamic>>(
      '/api/v2/core/nodes/simple/all',
    );
    return ApiResponseParser.list(resp, _nodeFromJson);
  }

  /// GET /api/v2/core/licenses/status
  Future<NodeLicenseStatus> getLicenseStatus() async {
    final resp = await _client.get<Map<String, dynamic>>(
      '/api/v2/core/licenses/status',
    );
    return ApiResponseParser.object(resp, NodeLicenseStatus.fromJson);
  }

  /// GET /api/v2/core/licenses/master/status
  Future<NodeLicenseStatus> getMasterLicenseStatus() async {
    final resp = await _client.get<Map<String, dynamic>>(
      '/api/v2/core/licenses/master/status',
    );
    return ApiResponseParser.object(resp, NodeLicenseStatus.fromJson);
  }

  /// GET /api/v2/dashboard/current/node
  ///
  /// 返回当前节点（由 `CurrentNode` 头决定）的资源摘要。
  Future<PanelNode?> getCurrentNodeSummary() async {
    final resp = await _client.get<Map<String, dynamic>>(
      '/api/v2/dashboard/current/node',
    );
    final map = ApiResponseParser.map(resp);
    if (map['name'] == null && map['hostname'] == null) return null;
    return PanelNode.fromJson(Map<String, Object?>.from(map));
  }

  static PanelNode _nodeFromJson(Map<String, dynamic> json) {
    return PanelNode.fromJson(Map<String, Object?>.from(json));
  }
}

class NodeLicenseStatus {
  const NodeLicenseStatus({
    required this.status,
    required this.productPro,
    this.message = '',
  });

  /// 1Panel 返回 `Bound` 表示专业版授权已绑定。
  final String status;

  /// 产品授权到期时间（时间戳字符串），未授权时可能为空。
  final String productPro;

  final String message;

  bool get isPro => status.trim().toLowerCase() == 'bound';

  factory NodeLicenseStatus.fromJson(Map<String, dynamic> json) {
    return NodeLicenseStatus(
      status: (json['status'] ?? '').toString(),
      productPro: (json['productPro'] ?? '').toString(),
      message: (json['message'] ?? '').toString(),
    );
  }
}
