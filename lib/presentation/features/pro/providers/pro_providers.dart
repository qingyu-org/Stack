import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/network/dio_client_provider.dart';
import '../../../../data/api/pro_api.dart';
import '../../servers/providers/node_selection_provider.dart';

enum ProFeature { waf, monitor, opsReport, tamper, resourceSync }

/// 按 `(serverId, feature)` 缓存专业版只读数据。
final proSnapshotProvider = FutureProvider.autoDispose
    .family<ProSnapshot, (int, ProFeature)>((ref, key) async {
      final (serverId, feature) = key;
      final client = await ref.watch(dioClientProvider(serverId).future);
      final activeNode = await ref.watch(
        activeNodeControllerProvider(serverId).future,
      );
      final api = ProApi(client, nodeName: activeNode);
      return switch (feature) {
        ProFeature.waf => api.loadWaf(),
        ProFeature.monitor => api.loadWebsiteMonitor(),
        ProFeature.opsReport => api.loadOpsReport(),
        ProFeature.tamper => api.loadTamper(),
        ProFeature.resourceSync => api.loadResourceSync(),
      };
    });
