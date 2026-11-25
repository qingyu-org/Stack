import 'package:dio/dio.dart';

import '../../../core/network/dio_client.dart';

/// 1Panel 专业版（XPack）只读接口。
///
/// 专业版端点的请求体/响应字段在不同版本间有差异，而且社区版会把它们
/// 裁剪掉。这里统一按“多候选请求 + 容错解析”处理：只要能拿到 JSON 就展示，
/// 全部失败时由页面给出可恢复的不可用状态。
class ProRequest {
  const ProRequest(this.method, this.path, {this.body, this.query});

  factory ProRequest.post(
    String path, {
    Map<String, dynamic>? body,
    Map<String, dynamic>? query,
  }) {
    return ProRequest('POST', path, body: body ?? const {}, query: query);
  }

  factory ProRequest.get(String path, {Map<String, dynamic>? query}) {
    return ProRequest('GET', path, query: query);
  }

  final String method;
  final String path;
  final Map<String, dynamic>? body;
  final Map<String, dynamic>? query;
}

class ProReadResult {
  const ProReadResult({
    required this.label,
    required this.ok,
    this.data,
    this.error,
  });

  final String label;
  final bool ok;
  final dynamic data;
  final Object? error;

  int? get statusCode {
    final value = error;
    if (value is DioException) return value.response?.statusCode;
    try {
      final dynamic dynamicError = value;
      final status = dynamicError.statusCode;
      return status is int ? status : null;
    } catch (_) {
      return null;
    }
  }

  bool get isUnavailable {
    final status = statusCode;
    return status == 403 || status == 404 || status == 405;
  }
}

class ProSnapshot {
  const ProSnapshot({required this.sections, required this.results});

  final Map<String, dynamic> sections;
  final List<ProReadResult> results;

  bool get anySuccess => results.any((result) => result.ok);

  bool get unavailable =>
      results.isNotEmpty && results.every((result) => !result.ok);

  bool get unauthorized =>
      unavailable && results.any((result) => result.statusCode == 403);

  List<ProReadResult> get failures => [
    for (final result in results)
      if (!result.ok) result,
  ];

  dynamic operator [](String label) => sections[label];
}

class ProApi {
  ProApi(this._client, {this.nodeName = 'local'});

  final DioClient _client;

  /// 当前节点名；少数 core 接口（如运维报表 context）需要显式传 node。
  final String nodeName;

  Future<ProSnapshot> loadWaf() {
    return _collect([
      _safe('status', [ProRequest.get('/api/v2/xpack/waf/status')]),
      _safe('attack', [
        ProRequest.post('/api/v2/xpack/waf/attack/stat', body: {}),
      ]),
      _safe('relation', [
        ProRequest.post('/api/v2/xpack/waf/relation/stat', body: {}),
      ]),
      _safe('stat', [ProRequest.get('/api/v2/xpack/waf/stat')]),
      _safe('websites', [
        ProRequest.get('/api/v2/xpack/waf/websites'),
        ProRequest.post(
          '/api/v2/xpack/waf/websites/search',
          body: {'page': 1, 'pageSize': 30},
        ),
      ]),
      _safe('logs', [
        ProRequest.post(
          '/api/v2/xpack/waf/log/search',
          body: {'page': 1, 'pageSize': 30},
        ),
      ]),
      _safe('cdn', [ProRequest.post('/api/v2/xpack/waf/cdn', body: {})]),
    ]);
  }

  Future<ProSnapshot> loadWebsiteMonitor() {
    return _collect([
      _safe('status', [ProRequest.get('/api/v2/xpack/monitor/status')]),
      _safe('stat', [ProRequest.post('/api/v2/xpack/monitor/stat', body: {})]),
      _safe('visitors', [
        ProRequest.post('/api/v2/xpack/monitor/visitors', body: {}),
      ]),
      _safe('locations', [
        ProRequest.post('/api/v2/xpack/monitor/visitors/loc', body: {}),
      ]),
      _safe('qps', [ProRequest.post('/api/v2/xpack/monitor/qps', body: {})]),
      _safe('trend', [
        ProRequest.post('/api/v2/xpack/monitor/trend', body: {}),
      ]),
      _safe('rank', [ProRequest.post('/api/v2/xpack/monitor/rank', body: {})]),
      _safe('websites', [
        ProRequest.post('/api/v2/xpack/monitor/websites', body: {}),
      ]),
      _safe('logs', [
        ProRequest.post(
          '/api/v2/xpack/monitor/logs/search',
          body: {'page': 1, 'pageSize': 30},
        ),
      ]),
      _safe('logStat', [
        ProRequest.post('/api/v2/xpack/monitor/logs/stat', body: {}),
      ]),
    ]);
  }

  Future<ProSnapshot> loadOpsReport() {
    return _collect([
      // core 路由不参与节点代理，需在 body 里显式指定 node。
      _safe('context', [
        ProRequest.post(
          '/api/v2/core/ops-report/context',
          body: {'node': nodeName},
        ),
      ]),
      _safe('snapshot', [
        ProRequest.post('/api/v2/xpack/ops-report/snapshot', body: {}),
      ]),
      _safe('runs', [
        ProRequest.post(
          '/api/v2/xpack/ops-report/runs/search',
          body: {'page': 1, 'pageSize': 20},
        ),
      ]),
    ]);
  }

  Future<ProSnapshot> loadTamper() {
    return _collect([
      _safe('templates', [
        ProRequest.post('/api/v2/xpack/tampers/template/list', body: {}),
        ProRequest.post(
          '/api/v2/xpack/tampers/template/search',
          body: {'page': 1, 'PageSize': 20, 'type': ''},
        ),
      ]),
      _safe('items', [
        ProRequest.post(
          '/api/v2/xpack/tampers/search',
          body: {
            'name': '',
            'page': 1,
            'pageSize': 30,
            'orderBy': 'created_at',
            'order': 'null',
            'websiteGroupId': 0,
          },
        ),
      ]),
      _safe('logs', [
        ProRequest.post(
          '/api/v2/xpack/tampers/search/log',
          body: {'page': 1, 'pageSize': 20},
        ),
      ]),
    ]);
  }

  Future<ProSnapshot> loadResourceSync() {
    return _collect([
      _safe('file', [
        ProRequest.post('/api/v2/core/xpack/exchange/file', body: {}),
      ]),
      _safe('image', [
        ProRequest.post('/api/v2/core/xpack/exchange/image', body: {}),
      ]),
      _safe('ssl', [
        ProRequest.post('/api/v2/core/xpack/exchange/ssl', body: {}),
      ]),
      _safe('app', [
        ProRequest.post('/api/v2/core/xpack/exchange/app', body: {}),
      ]),
    ]);
  }

  Future<ProSnapshot> _collect(List<Future<ProReadResult>> requests) async {
    final results = await Future.wait(requests);
    return ProSnapshot(
      sections: {
        for (final result in results)
          if (result.ok) result.label: result.data,
      },
      results: results,
    );
  }

  Future<ProReadResult> _safe(String label, List<ProRequest> requests) async {
    Object? lastError;
    for (final request in requests) {
      try {
        final data = await _execute(request);
        return ProReadResult(label: label, ok: true, data: data);
      } catch (error) {
        lastError = error;
      }
    }
    return ProReadResult(label: label, ok: false, error: lastError);
  }

  Future<dynamic> _execute(ProRequest request) async {
    final response = switch (request.method) {
      'GET' => await _client.get<dynamic>(request.path, query: request.query),
      _ => await _client.post<dynamic>(
        request.path,
        data: request.body ?? const <String, dynamic>{},
        query: request.query,
      ),
    };
    return _unwrap(response.data);
  }

  dynamic _unwrap(dynamic body) {
    if (body is Map && body.containsKey('data')) return body['data'];
    return body;
  }
}
