import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/network/dio_client_provider.dart';
import '../../../../data/api/waf_api.dart';
import '../../../../domain/entities/pro_models.dart';

class WafOverviewData {
  const WafOverviewData({
    required this.status,
    required this.today,
    required this.week,
    required this.locations,
  });

  final WafStatus status;
  final WafTodayStat today;
  final List<WafDailyPoint> week;
  final List<WafLocationItem> locations;
}

final wafOverviewProvider = FutureProvider.autoDispose
    .family<WafOverviewData, int>((ref, serverId) async {
      final client = await ref.watch(dioClientProvider(serverId).future);
      final api = WafApi(client);
      final results = await Future.wait<Object?>([
        api.status(),
        api.todayStat(),
        api.weekPoints(),
        api.primeLocations(),
      ]);
      // 国家名称缓存必须在上一次请求完成后才能被攻击统计使用。
      final locations = await api.worldAttackTop();
      return WafOverviewData(
        status: results[0] as WafStatus,
        today: results[1] as WafTodayStat,
        week: results[2] as List<WafDailyPoint>,
        locations: locations,
      );
    });

final wafLogsProvider = FutureProvider.autoDispose
    .family<WafLogPage, (int, int)>((ref, key) async {
      final (serverId, page) = key;
      final client = await ref.watch(dioClientProvider(serverId).future);
      return WafApi(client).searchLogs(page: page, pageSize: 20);
    });

final wafLogDetailProvider = FutureProvider.autoDispose
    .family<WafLogEntry, (int, int)>((ref, key) async {
      final (serverId, logId) = key;
      final client = await ref.watch(dioClientProvider(serverId).future);
      return WafApi(client).logDetail(logId);
    });

final wafBlocksProvider = FutureProvider.autoDispose
    .family<WafBlockPage, (int, int)>((ref, key) async {
      final (serverId, page) = key;
      final client = await ref.watch(dioClientProvider(serverId).future);
      return WafApi(client).searchBlocks(page: page, pageSize: 20);
    });
