import '../../../core/network/api_response_parser.dart';
import '../../../core/network/dio_client.dart';
import '../../../domain/entities/pro_models.dart';

/// 1Panel Pro 网站监控只读接口。
///
/// 官方 Web 端的日期参数并不统一：
/// - `stat` 使用 `"today"`；
/// - `trend` 使用 `["YYYY-MM-DD","YYYY-MM-DD"]`（UTC 日期）；
/// - `rank` 使用 `["YYYYMMDD","YYYYMMDD"]`（UTC 日期）；
/// - `logs/search` 使用本地日界转 UTC 的 ISO 时间。
class MonitorApi {
  MonitorApi(this._client);

  final DioClient _client;

  Future<MonitorStatus> status() async {
    final resp = await _client.get<Map<String, dynamic>>(
      '/api/v2/xpack/monitor/status',
    );
    return MonitorStatus.fromJson(ApiResponseParser.map(resp));
  }

  /// 监控站点列表与 WAF 站点列表共用同一接口。
  Future<List<MonitorWebsite>> websites() async {
    final resp = await _client.get<Map<String, dynamic>>(
      '/api/v2/xpack/waf/websites',
    );
    return ApiResponseParser.list(resp, MonitorWebsite.fromJson);
  }

  Future<MonitorTodayStat> todayStat(int websiteId) async {
    final resp = await _client.post<Map<String, dynamic>>(
      '/api/v2/xpack/monitor/stat',
      data: {'websiteID': websiteId, 'dayRange': 'today'},
    );
    return MonitorTodayStat.fromJson(ApiResponseParser.map(resp));
  }

  Future<MonitorQps> qps(int websiteId) async {
    final resp = await _client.post<Map<String, dynamic>>(
      '/api/v2/xpack/monitor/qps',
      data: {'websiteID': websiteId},
    );
    return MonitorQps.fromJson(ApiResponseParser.map(resp));
  }

  Future<List<MonitorTrendPoint>> trend(
    int websiteId, {
    required DateTime start,
    required DateTime end,
  }) async {
    final resp = await _client.post<Map<String, dynamic>>(
      '/api/v2/xpack/monitor/trend',
      data: {
        'websiteID': websiteId,
        'dayRange': [_isoDay(start), _isoDay(end)],
      },
    );
    return ApiResponseParser.list(resp, MonitorTrendPoint.fromJson);
  }

  Future<List<MonitorRankItem>> rank(
    int websiteId,
    String type, {
    required DateTime start,
    required DateTime end,
    int limit = 10,
  }) async {
    final resp = await _client.post<Map<String, dynamic>>(
      '/api/v2/xpack/monitor/rank',
      data: {
        'websiteID': websiteId,
        'type': type,
        'dayRange': [_compactDay(start), _compactDay(end)],
        'limit': limit,
      },
    );
    return ApiResponseParser.list(resp, MonitorRankItem.fromJson);
  }

  Future<List<MonitorLocationItem>> locations(
    int websiteId, {
    String resource = 'world',
  }) async {
    final resp = await _client.post<Map<String, dynamic>>(
      '/api/v2/xpack/monitor/visitors/loc',
      data: {'websiteID': websiteId, 'resource': resource},
    );
    return ApiResponseParser.list(resp, MonitorLocationItem.fromJson);
  }

  Future<MonitorLogPage> searchLogs({
    required int websiteId,
    required DateTime start,
    required DateTime end,
    int page = 1,
    int pageSize = 20,
    String ip = '',
    String ipLocation = '',
    String url = '',
    String method = '',
    String spider = '',
  }) async {
    final resp = await _client.post<Map<String, dynamic>>(
      '/api/v2/xpack/monitor/logs/search',
      data: {
        'page': page,
        'pageSize': pageSize,
        'total': 0,
        'ip': ip,
        'ipLocation': ipLocation,
        'url': url,
        'websiteID': websiteId,
        'method': method,
        'spider': spider,
        'orderBy': 'time',
        'order': 'descending',
        'startTime': start.toUtc().toIso8601String(),
        'endTime': end.toUtc().toIso8601String(),
      },
    );
    return MonitorLogPage.fromJson(ApiResponseParser.map(resp));
  }

  static String _isoDay(DateTime date) {
    final value = date.toUtc();
    return '${value.year.toString().padLeft(4, '0')}-'
        '${value.month.toString().padLeft(2, '0')}-'
        '${value.day.toString().padLeft(2, '0')}';
  }

  static String _compactDay(DateTime date) {
    final value = date.toUtc();
    return '${value.year.toString().padLeft(4, '0')}'
        '${value.month.toString().padLeft(2, '0')}'
        '${value.day.toString().padLeft(2, '0')}';
  }
}
