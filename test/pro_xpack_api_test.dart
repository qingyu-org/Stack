import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mono_dash/core/network/dio_client.dart';
import 'package:mono_dash/data/api/monitor_api.dart';
import 'package:mono_dash/data/api/waf_api.dart';

class _RoutingAdapter implements HttpClientAdapter {
  _RoutingAdapter(this.handler);

  final dynamic Function(RequestOptions options) handler;
  final List<RequestOptions> requests = [];

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    requests.add(options);
    return ResponseBody.fromString(
      jsonEncode({'code': 200, 'data': handler(options)}),
      200,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

DioClient _client(_RoutingAdapter adapter) {
  final client = DioClient(
    baseUrl: 'http://panel.test',
    apiKey: 'test-key',
    userAgent: 'MonoDashTest',
    currentNodeName: 'hk-1',
  );
  client.raw.httpClientAdapter = adapter;
  return client;
}

void main() {
  test('WAF read APIs use the captured xpack contract', () async {
    final adapter = _RoutingAdapter((options) {
      return switch (options.path) {
        '/api/v2/xpack/waf/stat/days' => [
          {'day': '2026-11-25', 'reqCount': 12, 'attackCount': 3},
        ],
        '/api/v2/xpack/waf/attack/stat' => [
          {'name': 'China', 'value': 9},
        ],
        '/api/v2/xpack/waf/log/search' => {
          'total': 1,
          'items': [
            {
              'id': 7,
              'ip': '1.2.3.4',
              'action': 'deny',
              'uri': '/.env',
              'execRule': 'rule-1',
              'host': 'example.com',
              'localtime': '2026-11-26T08:00:00+08:00',
              'ipLocation': 'Beijing',
            },
          ],
        },
        '/api/v2/xpack/waf/block/search' => {
          'total': 1,
          'items': [
            {
              'ip': '1.2.3.4',
              'ipLocation': 'Beijing',
              'isBlock': 1,
              'blockingTime': 600,
              'createDate': '2026-11-26T08:00:00+08:00',
            },
          ],
        },
        _ => <String, dynamic>{},
      };
    });
    final client = _client(adapter);
    final api = WafApi(client);

    await api.status();
    await api.todayStat();
    final week = await api.weekPoints();
    await api.primeLocations();
    final top = await api.worldAttackTop();
    final logs = await api.searchLogs(page: 2, pageSize: 20);
    final blocks = await api.searchBlocks(page: 2, pageSize: 20);

    expect(week.single.day, '2026-11-25');
    expect(week.single.attackCount, 3);
    expect(top.single.name, 'China');
    expect(top.single.value, 9);
    expect(logs.total, 1);
    expect(logs.items.single.uri, '/.env');
    expect(logs.items.single.denied, isTrue);
    expect(blocks.items.single.blocked, isTrue);
    expect(blocks.items.single.blockingTime, 600);

    final logRequest = adapter.requests.firstWhere(
      (request) => request.path == '/api/v2/xpack/waf/log/search',
    );
    expect(logRequest.method, 'POST');
    expect(logRequest.data['page'], 2);
    expect(logRequest.data['action'], 'all');
    expect(logRequest.data['execRules'], isEmpty);

    final topRequest = adapter.requests.firstWhere(
      (request) => request.path == '/api/v2/xpack/waf/attack/stat',
    );
    expect(topRequest.data, {'resource': 'world', 'type': 'attack'});

    final primeIndex = adapter.requests.indexWhere(
      (request) => request.path == '/api/v2/xpack/waf/locations/world',
    );
    final topIndex = adapter.requests.indexWhere(
      (request) => request.path == '/api/v2/xpack/waf/attack/stat',
    );
    expect(primeIndex, isNonNegative);
    expect(primeIndex, lessThan(topIndex));

    for (final request in adapter.requests) {
      expect(request.headers['CurrentNode'], Uri.encodeComponent('hk-1'));
    }
    client.dispose();
  });

  test('monitor read APIs keep their distinct date formats', () async {
    final adapter = _RoutingAdapter((options) {
      return switch (options.path) {
        '/api/v2/xpack/waf/websites' => [
          {
            'id': 3,
            'primaryDomain': 'example.com',
            'alias': 'Example',
            'remark': '',
          },
        ],
        '/api/v2/xpack/monitor/rank' => [
          {'name': '/index', 'count': 8, 'percent': 80.0},
        ],
        '/api/v2/xpack/monitor/visitors/loc' => [
          {'name': 'China', 'value': 6},
        ],
        '/api/v2/xpack/monitor/trend' => [
          {'date': '2026-11-26', 'pv': 10, 'uv': 4, 'flow': 2048, 'req': 12},
        ],
        '/api/v2/xpack/monitor/logs/search' => {
          'total': 1,
          'items': [
            {
              'id': 5,
              'ip': '5.6.7.8',
              'ipLocation': 'Shanghai',
              'host': 'example.com',
              'uri': '/index',
              'method': 'GET',
              'statusCode': 200,
              'requestTime': 12,
              'sendBytes': 100,
              'receiveBytes': 2048,
              'os': 'iOS',
              'browser': 'Safari',
              'device': 'Mobile',
              'localtime': '2026-11-26T09:00:00+08:00',
            },
          ],
        },
        _ => <String, dynamic>{},
      };
    });
    final client = _client(adapter);
    final api = MonitorApi(client);
    final websites = await api.websites();
    final start = DateTime.utc(2026, 11, 20, 8);
    final end = DateTime.utc(2026, 11, 26, 8);

    await api.todayStat(websites.single.id);
    await api.qps(websites.single.id);
    final trend = await api.trend(websites.single.id, start: start, end: end);
    await api.rank(websites.single.id, 'uri', start: start, end: end);
    await api.locations(websites.single.id);
    final logs = await api.searchLogs(
      websiteId: websites.single.id,
      start: DateTime(2026, 11, 26),
      end: DateTime(2026, 11, 26, 23, 59, 59),
      page: 1,
      pageSize: 20,
    );

    expect(websites.single.displayName, 'Example');
    expect(trend.single.pv, 10);
    expect(logs.items.single.browser, 'Safari');

    final statRequest = adapter.requests.firstWhere(
      (request) => request.path == '/api/v2/xpack/monitor/stat',
    );
    expect(statRequest.data, {'websiteID': 3, 'dayRange': 'today'});

    final trendRequest = adapter.requests.firstWhere(
      (request) => request.path == '/api/v2/xpack/monitor/trend',
    );
    expect(trendRequest.data['dayRange'], ['2026-11-20', '2026-11-26']);

    final rankRequest = adapter.requests.firstWhere(
      (request) => request.path == '/api/v2/xpack/monitor/rank',
    );
    expect(rankRequest.data['dayRange'], ['20261120', '20261126']);
    expect(rankRequest.data['limit'], 10);
    expect(rankRequest.data['type'], 'uri');

    final logsRequest = adapter.requests.firstWhere(
      (request) => request.path == '/api/v2/xpack/monitor/logs/search',
    );
    expect(logsRequest.data['orderBy'], 'time');
    expect(logsRequest.data['order'], 'descending');
    expect(
      DateTime.parse(logsRequest.data['startTime']).toUtc(),
      DateTime(2026, 11, 26).toUtc(),
    );
    client.dispose();
  });
}
