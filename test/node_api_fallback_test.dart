import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mono_dash/core/network/dio_client.dart';
import 'package:mono_dash/core/network/network_exceptions.dart';
import 'package:mono_dash/data/api/node_api.dart';

class _StatusAdapter implements HttpClientAdapter {
  _StatusAdapter(this.searchStatus);

  final int searchStatus;
  final List<String> requests = [];

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    requests.add(options.path);
    if (options.path == '/api/v2/core/xpack/nodes/search') {
      return ResponseBody.fromString(
        jsonEncode({'code': searchStatus, 'message': 'probe'}),
        searchStatus,
        headers: {
          Headers.contentTypeHeader: [Headers.jsonContentType],
        },
      );
    }
    return ResponseBody.fromString(
      jsonEncode({
        'code': 200,
        'data': [
          {'name': 'local', 'isXpack': true, 'isBound': true},
        ],
      }),
      200,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

DioClient _client(_StatusAdapter adapter) {
  final client = DioClient(
    baseUrl: 'http://panel.test',
    apiKey: 'not-a-real-key',
    userAgent: 'MonoDashTest',
    currentNodeName: 'local',
  );
  client.raw.httpClientAdapter = adapter;
  return client;
}

void main() {
  test(
    'falls back to the legacy node list only when xpack is missing',
    () async {
      final adapter = _StatusAdapter(404);
      final client = _client(adapter);

      final nodes = await NodeApi(client).listNodes();

      expect(nodes.single.name, 'local');
      expect(
        adapter.requests,
        containsAll([
          '/api/v2/core/xpack/nodes/search',
          '/api/v2/core/nodes/list',
        ]),
      );
      client.dispose();
    },
  );

  test(
    'rethrows server errors instead of hiding them behind a fallback',
    () async {
      final adapter = _StatusAdapter(500);
      final client = _client(adapter);

      await expectLater(
        NodeApi(client).listNodes(),
        throwsA(isA<ServerException>()),
      );
      expect(
        adapter.requests.where((path) => path == '/api/v2/core/nodes/list'),
        isEmpty,
      );
      client.dispose();
    },
  );
}
