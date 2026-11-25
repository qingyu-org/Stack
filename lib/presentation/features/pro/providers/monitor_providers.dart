import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/network/dio_client_provider.dart';
import '../../../../data/api/monitor_api.dart';
import '../../../../domain/entities/pro_models.dart';

enum MonitorRange {
  today(1),
  week(7),
  month(30);

  const MonitorRange(this.days);

  final int days;
}

class MonitorOverviewData {
  const MonitorOverviewData({
    required this.status,
    required this.today,
    required this.qps,
    required this.locations,
  });

  final MonitorStatus status;
  final MonitorTodayStat today;
  final MonitorQps qps;
  final List<MonitorLocationItem> locations;
}

final monitorWebsitesProvider = FutureProvider.autoDispose
    .family<List<MonitorWebsite>, int>((ref, serverId) async {
      final client = await ref.watch(dioClientProvider(serverId).future);
      return MonitorApi(client).websites();
    });

final monitorOverviewProvider = FutureProvider.autoDispose
    .family<MonitorOverviewData, (int, int)>((ref, key) async {
      final (serverId, websiteId) = key;
      final client = await ref.watch(dioClientProvider(serverId).future);
      final api = MonitorApi(client);
      final results = await Future.wait<Object>([
        api.status(),
        api.todayStat(websiteId),
        api.qps(websiteId),
        api.locations(websiteId),
      ]);
      return MonitorOverviewData(
        status: results[0] as MonitorStatus,
        today: results[1] as MonitorTodayStat,
        qps: results[2] as MonitorQps,
        locations: results[3] as List<MonitorLocationItem>,
      );
    });

final monitorTrendProvider = FutureProvider.autoDispose
    .family<List<MonitorTrendPoint>, (int, int, MonitorRange)>((
      ref,
      key,
    ) async {
      final (serverId, websiteId, range) = key;
      final client = await ref.watch(dioClientProvider(serverId).future);
      final now = DateTime.now().toUtc();
      final start = now.subtract(Duration(days: range.days - 1));
      return MonitorApi(client).trend(websiteId, start: start, end: now);
    });

final monitorRanksProvider = FutureProvider.autoDispose
    .family<Map<String, List<MonitorRankItem>>, (int, int, MonitorRange)>((
      ref,
      key,
    ) async {
      final (serverId, websiteId, range) = key;
      final client = await ref.watch(dioClientProvider(serverId).future);
      final api = MonitorApi(client);
      final now = DateTime.now().toUtc();
      final start = now.subtract(Duration(days: range.days - 1));
      const types = ['uri', 'referer', 'os', 'browser', 'device'];
      final results = await Future.wait([
        for (final type in types)
          api.rank(websiteId, type, start: start, end: now, limit: 50),
      ]);
      return {for (var i = 0; i < types.length; i++) types[i]: results[i]};
    });

final monitorLogsProvider = FutureProvider.autoDispose
    .family<MonitorLogPage, (int, int, MonitorRange, int)>((ref, key) async {
      final (serverId, websiteId, range, page) = key;
      final client = await ref.watch(dioClientProvider(serverId).future);
      final now = DateTime.now();
      final start = DateTime(
        now.year,
        now.month,
        now.day,
      ).subtract(Duration(days: range.days - 1));
      final end = DateTime(now.year, now.month, now.day, 23, 59, 59);
      return MonitorApi(client).searchLogs(
        websiteId: websiteId,
        start: start,
        end: end,
        page: page,
        pageSize: 20,
      );
    });
