import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mono_dash/core/network/interceptors/auth_interceptor.dart';
import 'package:mono_dash/domain/entities/panel_node.dart';
import 'package:mono_dash/domain/entities/server.dart';

void main() {
  group('PanelNode', () {
    test('normalize always keeps a primary node and sorts it first', () {
      final nodes = PanelNode.normalize([
        const PanelNode(id: '7', name: '香港节点', status: 'Healthy'),
        const PanelNode(id: '8', name: '东京节点', status: 'UnHealthy'),
      ], isPro: true);

      expect(nodes, hasLength(3));
      expect(nodes.first.isLocal, isTrue);
      expect(nodes.first.name, PanelNode.localName);
      expect(nodes.any((node) => node.name == '香港节点'), isTrue);
    });

    test('mergeSimpleMetrics enriches list entries by node name', () {
      final merged = PanelNode.mergeSimpleMetrics(
        const [PanelNode(id: '7', name: 'hk', status: 'Healthy')],
        const [
          PanelNode(
            id: 'hk',
            name: 'hk',
            cpuUsedPercent: 12.5,
            memoryUsedPercent: 34,
          ),
        ],
      );

      expect(merged.single.cpuUsedPercent, 12.5);
      expect(merged.single.memoryUsedPercent, 34);
      expect(merged.single.status, 'Healthy');
    });
  });

  group('Server Pro metadata', () {
    test('round-trips nodes and edition override', () {
      final server = Server()
        ..host = '127.0.0.1'
        ..port = 10000
        ..isPro = true
        ..editionOverride = PanelEditionOverride.auto
        ..nodes = [
          PanelNode.local(isPro: true),
          const PanelNode(id: '7', name: 'hk', status: 'Healthy'),
        ];

      final decoded = Server.fromJson(server.toJson());

      expect(decoded.isPro, isTrue);
      expect(decoded.isProActive, isTrue);
      expect(decoded.hasChildNodes, isTrue);
      expect(decoded.nodeByName('hk')?.name, 'hk');
    });

    test('old records without Pro fields default safely', () {
      final decoded = Server.fromJson({
        'id': 1,
        'host': 'example.com',
        'port': 10000,
      });

      expect(decoded.isPro, isFalse);
      expect(decoded.isProActive, isFalse);
      expect(decoded.editionOverride, PanelEditionOverride.auto);
      expect(decoded.nodes, isEmpty);
    });

    test('manual override wins over auto detection', () {
      final server = Server()
        ..host = 'example.com'
        ..port = 10000
        ..isPro = false
        ..editionOverride = PanelEditionOverride.pro;

      expect(server.isProActive, isTrue);
    });
  });

  group('AuthInterceptor node routing', () {
    test('encodes CurrentNode and strips legacy operateNode query', () async {
      final interceptor = AuthInterceptor('api-key', nodeName: '香港 node');
      final options = RequestOptions(
        path: '/api/v2/websites/search',
        queryParameters: {'operateNode': 'local', 'page': 1},
      );
      final handler = RequestInterceptorHandler();

      interceptor.onRequest(options, handler);
      final handled = (await handler.future).data as RequestOptions;

      expect(handled.headers['CurrentNode'], Uri.encodeComponent('香港 node'));
      expect(handled.queryParameters.containsKey('operateNode'), isFalse);
      expect(handled.queryParameters['page'], 1);
    });

    test('sends CurrentNode=local for the primary node', () async {
      final interceptor = AuthInterceptor('api-key', nodeName: 'local');
      final options = RequestOptions(path: '/api/v2/dashboard/base/os');
      final handler = RequestInterceptorHandler();

      interceptor.onRequest(options, handler);
      final handled = (await handler.future).data as RequestOptions;

      // 1Panel Web 端对主节点同样发送 local；部分 XPack 接口依赖该头。
      expect(handled.headers['CurrentNode'], 'local');
    });

    test('omits CurrentNode when no node is known', () async {
      final interceptor = AuthInterceptor('api-key');
      final options = RequestOptions(path: '/api/v2/dashboard/base/os');
      final handler = RequestInterceptorHandler();

      interceptor.onRequest(options, handler);
      final handled = (await handler.future).data as RequestOptions;

      expect(handled.headers.containsKey('CurrentNode'), isFalse);
    });
  });
}
