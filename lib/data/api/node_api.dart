import '../../../core/network/api_response_parser.dart';
import '../../../core/network/dio_client.dart';
import '../../../core/network/network_exceptions.dart';
import '../../../domain/entities/panel_node.dart';

/// 1Panel 专业版节点与授权相关 API。
///
/// 社区版没有 `/core/xpack/nodes/*` 与 `/core/licenses/*`，调用会返回
/// 404/403；调用方应把它当作能力边界而不是致命错误。
class NodeApi {
  NodeApi(this._client);

  final DioClient _client;

  /// POST /api/v2/core/xpack/nodes/search
  ///
  /// 1Panel Pro 的节点管理接口（官方 Web 端使用）。返回的 `local` 代表
  /// 主面板自身；每个节点都带 `isXpack`，可用来判断该节点是否有 Pro 菜单。
  Future<List<PanelNode>> listNodes({String type = 'all'}) async {
    try {
      final resp = await _client.post<Map<String, dynamic>>(
        '/api/v2/core/xpack/nodes/search',
        data: {'page': 1, 'pageSize': 100},
      );
      final nodes = _parseNodeItems(resp.data ?? const {});
      if (nodes.isNotEmpty) return nodes;
    } on AppNetworkException catch (error) {
      // 只有「接口不存在/无权访问」才回退；网络、401、5xx 必须暴露给
      // 上层，否则会静默显示过期拓扑。
      if (!_isUnsupportedEndpoint(error)) rethrow;
    }

    final resp = await _client.post<Map<String, dynamic>>(
      '/api/v2/core/nodes/list',
      data: {'type': type},
    );
    return ApiResponseParser.list(resp, _nodeFromJson);
  }

  /// GET /api/v2/core/xpack/nodes/current
  ///
  /// 返回所有节点的实时资源概览（CPU/内存），官方 Web 端节点卡片使用它。
  Future<List<PanelNode>> listCurrentNodes() async {
    try {
      final resp = await _client.get<Map<String, dynamic>>(
        '/api/v2/core/xpack/nodes/current',
      );
      final nodes = ApiResponseParser.list(resp, _nodeFromJson);
      if (nodes.isNotEmpty) return nodes;
    } on AppNetworkException catch (error) {
      if (!_isUnsupportedEndpoint(error)) rethrow;
    }

    final resp = await _client.get<Map<String, dynamic>>(
      '/api/v2/core/nodes/simple/all',
    );
    return ApiResponseParser.list(resp, _nodeFromJson);
  }

  /// GET /api/v2/core/nodes/all（旧版 Pro）
  Future<List<PanelNode>> listAllNodes() async {
    final resp = await _client.get<Map<String, dynamic>>(
      '/api/v2/core/nodes/all',
    );
    return ApiResponseParser.list(resp, _nodeFromJson);
  }

  /// 兼容旧调用名；返回实时资源概览。
  Future<List<PanelNode>> listSimpleNodes() => listCurrentNodes();

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

  static bool _isUnsupportedEndpoint(AppNetworkException error) {
    final status = error.statusCode;
    return status == 403 || status == 404 || status == 405;
  }

  static List<PanelNode> _parseNodeItems(Map<String, dynamic> resp) {
    final data = resp['data'];
    if (data is List) {
      return [
        for (final item in data)
          if (item is Map) _nodeFromJson(Map<String, dynamic>.from(item)),
      ];
    }
    if (data is Map) {
      final items = data['items'] ?? data['list'];
      if (items is List) {
        return [
          for (final item in items)
            if (item is Map) _nodeFromJson(Map<String, dynamic>.from(item)),
        ];
      }
    }
    return const [];
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

  /// 1Panel 返回 `Bound`（或旧版 `Bound`/`bound`）表示专业版授权已绑定。
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
