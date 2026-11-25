import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mono_dash/core/network/dio_client.dart';
import 'package:mono_dash/data/api/pro_api.dart';

class _RecordingAdapter implements HttpClientAdapter {
  _RecordingAdapter();

  final List<RequestOptions> requests = [];

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    requests.add(options);
    return ResponseBody.fromString(
      jsonEncode({'code': 200, 'data': <String, dynamic>{}}),
      200,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

DioClient _client(_RecordingAdapter adapter, {String nodeName = 'local'}) {
  final client = DioClient(
    baseUrl: 'http://panel.test',
    apiKey: 'test-key',
    userAgent: 'MonoDashTest',
    currentNodeName: nodeName,
  );
  client.raw.httpClientAdapter = adapter;
  return client;
}

void main() {
  test('ProApi routes WAF requests to xpack endpoints on the active node',
      () async {
    final adapter = _RecordingAdapter();
    final client = _client(adapter, nodeName: '香港节点');

    await ProApi(client, nodeName: '香港节点').loadWaf();

    final paths = adapter.requests.map((request) => request.path).toList();
    expect(paths, contains('/api/v2/xpack/waf/status'));
    expect(paths, contains('/api/v2/xpack/waf/attack/stat'));
    expect(paths, contains('/api/v2/xpack/waf/log/search'));
    expect(paths.every((path) => path.startsWith('/api/v2/')), isTrue);
    for (final request in adapter.requests) {
      expect(
        request.headers['CurrentNode'],
        Uri.encodeComponent('香港节点'),
      );
    }

    client.dispose();
  });

  test('ProApi sends the node explicitly to the core ops-report context',
      () async {
    final adapter = _RecordingAdapter();
    final client = _client(adapter);

    await ProApi(client, nodeName: 'hk-2').loadOpsReport();

    final contextRequest = adapter.requests.firstWhere(
      (request) => request.path == '/api/v2/core/ops-report/context',
    );
    expect(contextRequest.method, 'POST');
    expect(contextRequest.data, {'node': 'hk-2'});
    expect(
      adapter.requests.map((request) => request.path),
      contains('/api/v2/xpack/ops-report/snapshot'),
    );

    client.dispose();
  });
}
