import '../../../core/network/api_response_parser.dart';
import '../../../core/network/dio_client.dart';
import '../../../domain/entities/pro_models.dart';

/// 1Panel Pro WAF 只读接口（字段来自 v2.5.x 官方 Web 端）。
class WafApi {
  WafApi(this._client);

  final DioClient _client;

  Future<WafStatus> status() async {
    final resp = await _client.get<Map<String, dynamic>>(
      '/api/v2/xpack/waf/status',
    );
    return WafStatus.fromJson(ApiResponseParser.map(resp));
  }

  Future<WafTodayStat> todayStat() async {
    final resp = await _client.get<Map<String, dynamic>>(
      '/api/v2/xpack/waf/stat',
    );
    return WafTodayStat.fromJson(ApiResponseParser.map(resp));
  }

  Future<List<WafDailyPoint>> weekPoints() async {
    final resp = await _client.get<Map<String, dynamic>>(
      '/api/v2/xpack/waf/stat/days',
    );
    return ApiResponseParser.list(resp, WafDailyPoint.fromJson);
  }

  /// 预热世界地图的国家名称缓存。
  ///
  /// 1Panel Web 端加载 WAF 概览时会先请求该接口；缺少这次调用时
  /// `/attack/stat` 会返回 193 条 `{value:0,name:""}` 的空数据。
  Future<void> primeLocations() async {
    await _client.get<Map<String, dynamic>>(
      '/api/v2/xpack/waf/locations/world',
    );
  }

  Future<List<WafLocationItem>> worldAttackTop() async {
    final resp = await _client.post<Map<String, dynamic>>(
      '/api/v2/xpack/waf/attack/stat',
      data: {'resource': 'world', 'type': 'attack'},
    );
    return ApiResponseParser.list(resp, WafLocationItem.fromJson);
  }

  Future<WafLogPage> searchLogs({
    int page = 1,
    int pageSize = 20,
    String ip = '',
    String ipLocation = '',
    String host = '',
    String url = '',
    String websiteKey = '',
    List<String> execRules = const [],
    String action = 'all',
  }) async {
    final resp = await _client.post<Map<String, dynamic>>(
      '/api/v2/xpack/waf/log/search',
      data: {
        'page': page,
        'pageSize': pageSize,
        'ip': ip,
        'ipLocation': ipLocation,
        'host': host,
        'url': url,
        'websiteKey': websiteKey,
        'execRules': execRules,
        'action': action,
      },
    );
    return WafLogPage.fromJson(ApiResponseParser.map(resp));
  }

  Future<WafLogEntry> logDetail(int id) async {
    final resp = await _client.get<Map<String, dynamic>>(
      '/api/v2/xpack/waf/log/detail/$id',
    );
    return WafLogEntry.fromJson(ApiResponseParser.map(resp));
  }

  Future<WafBlockPage> searchBlocks({
    int page = 1,
    int pageSize = 20,
    String ip = '',
  }) async {
    final resp = await _client.post<Map<String, dynamic>>(
      '/api/v2/xpack/waf/block/search',
      data: {'page': page, 'pageSize': pageSize, 'total': 0, 'ip': ip},
    );
    return WafBlockPage.fromJson(ApiResponseParser.map(resp));
  }
}
