import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/widgets/ios_server_widget_bridge.dart';
import '../../../../data/repositories_impl/server_repository_impl.dart';
import '../../../../data/services/ssh/ssh_connection.dart';
import '../../../../data/services/ssh/ssh_connection_manager.dart';
import '../../../../data/services/ssh/ssh_metrics.dart';
import 'servers_provider.dart';

/// SSH 服务器首页卡片的实时指标快照。
final sshDashboardSnapshotProvider = FutureProvider.autoDispose
    .family<ServerDashboardSnapshot, int>((ref, serverId) async {
      final manager = ref.watch(sshConnectionManagerProvider);
      final repository = ref.watch(serverRepositoryProvider);
      final server = await repository.find(serverId);
      if (server == null) {
        throw const SshConnectionException('服务器不存在');
      }
      final connection = await manager.get(serverId);
      final result = await SshMetricsCollector().fetch(
        connection: connection,
        server: server,
      );
      unawaited(
        IosServerWidgetBridge.upsertSnapshot(
          server: server,
          dashboard: result.dashboard,
          latencyMs: result.fetchMs,
        ),
      );
      return ServerDashboardSnapshot(
        dashboard: result.dashboard,
        fetchMs: result.fetchMs,
      );
    });
