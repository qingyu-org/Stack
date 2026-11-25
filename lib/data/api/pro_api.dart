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
  ProApi(this._client);

  final DioClient _client;

  Future<ProSnapshot> loadWaf() {
    return _collect([
      _safe('attack', [
        ProRequest.post('/api/v2/xpack/waf/attack/stat', body: {}),
        ProRequest.get('/api/v2/xpack/waf/attack/stat'),
      ]),
      _safe('relation', [
        ProRequest.post('/api/v2/xpack/waf/relation/stat', body: {}),
        ProRequest.get('/api/v2/xpack/waf/relation/stat'),
      ]),
      _safe('websites', [
        ProRequest.post('/api/v2/xpack/waf/config/website', body: {}),
        ProRequest.get('/api/v2/xpack/waf/config/website'),
      ]),
      _safe('cdn', [
        ProRequest.post('/api/v2/xpack/waf/cdn', body: {}),
        ProRequest.get('/api/v2/xpack/waf/cdn'),
      ]),
      _safe('logs', [
        ProRequest.post(
          '/api/v2/xpack/waf/log/search',
          body: {'page': 1, 'pageSize': 30},
        ),
        ProRequest.post(
          '/api/v2/xpack/waf/search',
          body: {'page': 1, 'pageSize': 30},
        ),
        ProRequest.post(
          '/api/v2/xpack/waf/attack/search',
          body: {'page': 1, 'pageSize': 30},
        ),
      ]),
    ]);
  }

  Future<ProSnapshot> loadWebsiteMonitor() {
    return _collect([
      _safe('stat', [
        ProRequest.post('/api/v2/xpack/monitor/stat', body: {}),
        ProRequest.get('/api/v2/xpack/monitor/stat'),
      ]),
      _safe('visitors', [
        ProRequest.post('/api/v2/xpack/monitor/visitors', body: {}),
        ProRequest.get('/api/v2/xpack/monitor/visitors'),
      ]),
      _safe('qps', [
        ProRequest.post('/api/v2/xpack/monitor/qps', body: {}),
        ProRequest.get('/api/v2/xpack/monitor/qps'),
      ]),
      _safe('trend', [
        ProRequest.post('/api/v2/xpack/monitor/trend', body: {}),
        ProRequest.get('/api/v2/xpack/monitor/trend'),
      ]),
      _safe('rank', [
        ProRequest.post('/api/v2/xpack/monitor/rank', body: {}),
        ProRequest.get('/api/v2/xpack/monitor/rank'),
      ]),
      _safe('websites', [
        ProRequest.post('/api/v2/xpack/monitor/websites', body: {}),
        ProRequest.get('/api/v2/xpack/monitor/websites'),
      ]),
    ]);
  }

  Future<ProSnapshot> loadOpsReport() {
    return _collect([
      _safe('overview', [
        ProRequest.get('/api/v2/xpack/ops-report/overview'),
        ProRequest.post('/api/v2/xpack/ops-report/overview', body: {}),
      ]),
      _safe('system', [
        ProRequest.get('/api/v2/xpack/ops-report/system'),
        ProRequest.post('/api/v2/xpack/ops-report/system', body: {}),
      ]),
      _safe('login', [
        ProRequest.get('/api/v2/xpack/ops-report/login'),
        ProRequest.post('/api/v2/xpack/ops-report/login', body: {}),
      ]),
    ]);
  }

  Future<ProSnapshot> loadTamper() {
    return _collect([
      _safe('templates', [
        ProRequest.post('/api/v2/xpack/tampers/template/list', body: {}),
        ProRequest.get('/api/v2/xpack/tampers/template/list'),
      ]),
      _safe('items', [
        ProRequest.post(
          '/api/v2/xpack/tampers/search',
          body: {'page': 1, 'pageSize': 30},
        ),
        ProRequest.post(
          '/api/v2/xpack/tampers/list',
          body: {'page': 1, 'pageSize': 30},
        ),
        ProRequest.get('/api/v2/xpack/tampers/search'),
      ]),
    ]);
  }

  Future<ProSnapshot> loadResourceSync() {
    return _collect([
      _safe('file', [
        ProRequest.post('/api/v2/xpack/sync/file', body: {}),
        ProRequest.get('/api/v2/xpack/sync/file'),
      ]),
      _safe('image', [
        ProRequest.post('/api/v2/xpack/sync/image', body: {}),
        ProRequest.get('/api/v2/xpack/sync/image'),
      ]),
      _safe('ssl', [
        ProRequest.post('/api/v2/xpack/sync/ssl', body: {}),
        ProRequest.get('/api/v2/xpack/sync/ssl'),
      ]),
      _safe('app', [
        ProRequest.post('/api/v2/xpack/sync/app', body: {}),
        ProRequest.get('/api/v2/xpack/sync/app'),
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
