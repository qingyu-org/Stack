import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_tabler_icons/flutter_tabler_icons.dart';

import '../../../../core/localization/l10n_x.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../domain/entities/panel_node.dart';
import '../../../../domain/entities/pro_models.dart';
import '../../../common/components/action_sheet_launcher.dart';
import '../../../common/components/action_sheet_scaffold.dart';
import '../../servers/providers/node_providers.dart';
import '../../servers/providers/node_selection_provider.dart';
import '../providers/monitor_providers.dart';
import '../utils/pro_data_utils.dart';
import '../widgets/pro_detail_sheets.dart';
import '../widgets/pro_page_scaffold.dart';
import '../widgets/pro_ui.dart';

enum _MonitorTab { overview, stats, logs }

class WebsiteMonitorPage extends ConsumerStatefulWidget {
  const WebsiteMonitorPage({
    super.key,
    required this.serverId,
    this.initialWebsiteId,
  });

  final int serverId;
  final int? initialWebsiteId;

  @override
  ConsumerState<WebsiteMonitorPage> createState() => _WebsiteMonitorPageState();
}

class _WebsiteMonitorPageState extends ConsumerState<WebsiteMonitorPage> {
  _MonitorTab _tab = _MonitorTab.overview;
  MonitorRange _overviewRange = MonitorRange.week;
  MonitorRange _statsRange = MonitorRange.week;
  MonitorRange _logsRange = MonitorRange.today;
  int _logsPage = 1;
  int? _websiteId;

  static const _pageSize = 20;

  MonitorWebsite? _resolveSelected(List<MonitorWebsite> websites) {
    final id = _websiteId ?? widget.initialWebsiteId;
    for (final website in websites) {
      if (website.id == id) return website;
    }
    return websites.isEmpty ? null : websites.first;
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final nodeIsPro = ref.watch(activeNodeIsProProvider(widget.serverId));
    final activeNode =
        ref.watch(activeNodeControllerProvider(widget.serverId)).valueOrNull ??
        PanelNode.localName;
    final nodeLabel = activeNode == PanelNode.localName
        ? l10n.nodes_local
        : activeNode;

    return ProPageScaffold(
      title: '${l10n.pro_monitor_title} · $nodeLabel',
      onRefresh: nodeIsPro ? _refresh : null,
      children: [
        if (!nodeIsPro)
          ProCard(
            child: ProEmpty(
              message: proText(
                context,
                zh: '当前节点为社区版，没有网站监控数据。请切换到主节点。',
                en:
                    'This node is Community Edition and has no website '
                    'monitoring data. Switch to the primary node.',
              ),
              icon: TablerIcons.chart_line,
            ),
          )
        else
          _MonitorBody(
            serverId: widget.serverId,
            selected: _websiteId,
            tab: _tab,
            overviewRange: _overviewRange,
            statsRange: _statsRange,
            logsRange: _logsRange,
            logsPage: _logsPage,
            pageSize: _pageSize,
            onTabChanged: (value) => setState(() => _tab = value),
            onWebsiteChanged: (id) => setState(() {
              _websiteId = id;
              _logsPage = 1;
            }),
            onOverviewRangeChanged: (value) =>
                setState(() => _overviewRange = value),
            onStatsRangeChanged: (value) => setState(() => _statsRange = value),
            onLogsRangeChanged: (value) => setState(() {
              _logsRange = value;
              _logsPage = 1;
            }),
            onLogsPageChanged: (page) => setState(() => _logsPage = page),
          ),
      ],
    );
  }

  Future<void> _refresh() async {
    final websites = ref
        .read(monitorWebsitesProvider(widget.serverId))
        .valueOrNull;
    final site = websites == null ? null : _resolveSelected(websites);
    if (site == null) {
      ref.invalidate(monitorWebsitesProvider(widget.serverId));
      return;
    }
    ref.invalidate(monitorWebsitesProvider(widget.serverId));
    switch (_tab) {
      case _MonitorTab.overview:
        ref.invalidate(monitorOverviewProvider((widget.serverId, site.id)));
        ref.invalidate(
          monitorTrendProvider((widget.serverId, site.id, _overviewRange)),
        );
      case _MonitorTab.stats:
        ref.invalidate(
          monitorRanksProvider((widget.serverId, site.id, _statsRange)),
        );
      case _MonitorTab.logs:
        ref.invalidate(
          monitorLogsProvider((
            widget.serverId,
            site.id,
            _logsRange,
            _logsPage,
          )),
        );
    }
    try {
      await ref.read(monitorWebsitesProvider(widget.serverId).future);
    } catch (_) {}
  }
}

class _MonitorBody extends ConsumerWidget {
  const _MonitorBody({
    required this.serverId,
    required this.selected,
    required this.tab,
    required this.overviewRange,
    required this.statsRange,
    required this.logsRange,
    required this.logsPage,
    required this.pageSize,
    required this.onTabChanged,
    required this.onWebsiteChanged,
    required this.onOverviewRangeChanged,
    required this.onStatsRangeChanged,
    required this.onLogsRangeChanged,
    required this.onLogsPageChanged,
  });

  final int serverId;
  final int? selected;
  final _MonitorTab tab;
  final MonitorRange overviewRange;
  final MonitorRange statsRange;
  final MonitorRange logsRange;
  final int logsPage;
  final int pageSize;
  final ValueChanged<_MonitorTab> onTabChanged;
  final ValueChanged<int> onWebsiteChanged;
  final ValueChanged<MonitorRange> onOverviewRangeChanged;
  final ValueChanged<MonitorRange> onStatsRangeChanged;
  final ValueChanged<MonitorRange> onLogsRangeChanged;
  final ValueChanged<int> onLogsPageChanged;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(monitorWebsitesProvider(serverId));
    return async.when(
      loading: () => const Padding(
        padding: EdgeInsets.symmetric(vertical: 80),
        child: Center(child: CupertinoActivityIndicator()),
      ),
      error: (error, _) => ProError(
        error: error,
        onRetry: () => ref.invalidate(monitorWebsitesProvider(serverId)),
      ),
      data: (websites) {
        if (websites.isEmpty) {
          return ProCard(
            child: ProEmpty(
              message: proText(
                context,
                zh: '还没有开启监控的网站。请在 1Panel 的网站监控中启用站点。',
                en:
                    'No website is being monitored. Enable monitoring for a '
                    'site in 1Panel first.',
              ),
              icon: TablerIcons.world_www,
            ),
          );
        }
        MonitorWebsite? site;
        final wanted = selected;
        for (final website in websites) {
          if (website.id == wanted) site = website;
        }
        site ??= websites.first;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _WebsiteSwitcher(
              websites: websites,
              selected: site,
              onSelected: onWebsiteChanged,
            ),
            const SizedBox(height: 12),
            ProPageTabs<_MonitorTab>(
              values: _MonitorTab.values,
              labels: [
                proText(context, zh: '概览', en: 'Overview'),
                proText(context, zh: '访问统计', en: 'Traffic'),
                proText(context, zh: '请求日志', en: 'Requests'),
              ],
              selected: tab,
              onChanged: onTabChanged,
            ),
            const SizedBox(height: 12),
            switch (tab) {
              _MonitorTab.overview => _MonitorOverview(
                serverId: serverId,
                websiteId: site.id,
                range: overviewRange,
                onRangeChanged: onOverviewRangeChanged,
              ),
              _MonitorTab.stats => _MonitorStats(
                serverId: serverId,
                websiteId: site.id,
                range: statsRange,
                onRangeChanged: onStatsRangeChanged,
              ),
              _MonitorTab.logs => _MonitorLogs(
                serverId: serverId,
                websiteId: site.id,
                range: logsRange,
                page: logsPage,
                pageSize: pageSize,
                onRangeChanged: onLogsRangeChanged,
                onPageChanged: onLogsPageChanged,
              ),
            },
          ],
        );
      },
    );
  }
}

class _WebsiteSwitcher extends StatelessWidget {
  const _WebsiteSwitcher({
    required this.websites,
    required this.selected,
    required this.onSelected,
  });

  final List<MonitorWebsite> websites;
  final MonitorWebsite selected;
  final ValueChanged<int> onSelected;

  @override
  Widget build(BuildContext context) {
    final blue = CupertinoColors.activeBlue.resolveFrom(context);
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: websites.length <= 1 ? null : () => _open(context),
      child: Container(
        padding: const EdgeInsets.fromLTRB(13, 11, 13, 11),
        decoration: BoxDecoration(
          color: AppColors.secondaryBackground(context).withValues(alpha: 0.68),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: AppColors.separator(context).withValues(alpha: 0.14),
            width: 0.6,
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: blue.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(TablerIcons.world_www, size: 18, color: blue),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    selected.displayName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 14.5,
                      fontWeight: FontWeight.w700,
                      letterSpacing: -0.2,
                      color: AppColors.label(context),
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    selected.primaryDomain,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 10.5,
                      fontFamily: 'Menlo',
                      color: AppColors.secondaryLabel(context),
                    ),
                  ),
                ],
              ),
            ),
            if (websites.length > 1) ...[
              Text(
                proText(context, zh: '切换', en: 'Switch'),
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w500,
                  color: AppColors.tertiaryLabel(context),
                ),
              ),
              const SizedBox(width: 2),
              Icon(
                CupertinoIcons.chevron_down,
                size: 13,
                color: AppColors.tertiaryLabel(context),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Future<void> _open(BuildContext context) {
    return showActionSheet(
      context: context,
      builder: (_) => ActionSheetScaffold(
        title: proText(context, zh: '选择网站', en: 'Choose website'),
        child: Column(
          children: [
            for (final website in websites)
              GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () {
                  Navigator.of(context).pop();
                  onSelected(website.id);
                },
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 11),
                  child: Row(
                    children: [
                      Icon(
                        website.id == selected.id
                            ? TablerIcons.circle_check_filled
                            : TablerIcons.circle,
                        size: 18,
                        color: website.id == selected.id
                            ? CupertinoColors.activeBlue.resolveFrom(context)
                            : AppColors.tertiaryLabel(context),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              website.displayName,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 13.5,
                                fontWeight: FontWeight.w600,
                                color: AppColors.label(context),
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              website.primaryDomain,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 10.5,
                                fontFamily: 'Menlo',
                                color: AppColors.secondaryLabel(context),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _MonitorOverview extends ConsumerWidget {
  const _MonitorOverview({
    required this.serverId,
    required this.websiteId,
    required this.range,
    required this.onRangeChanged,
  });

  final int serverId;
  final int websiteId;
  final MonitorRange range;
  final ValueChanged<MonitorRange> onRangeChanged;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(monitorOverviewProvider((serverId, websiteId)));
    final trendAsync = ref.watch(
      monitorTrendProvider((serverId, websiteId, range)),
    );
    return async.when(
      loading: () => const Padding(
        padding: EdgeInsets.symmetric(vertical: 60),
        child: Center(child: CupertinoActivityIndicator()),
      ),
      error: (error, _) => ProError(
        error: error,
        onRetry: () =>
            ref.invalidate(monitorOverviewProvider((serverId, websiteId))),
      ),
      data: (data) {
        final locations = [...data.locations]
          ..sort((a, b) => b.value.compareTo(a.value));
        final total = locations.fold<int>(0, (sum, item) => sum + item.value);
        final blue = CupertinoColors.activeBlue.resolveFrom(context);
        final purple = CupertinoColors.systemPurple.resolveFrom(context);
        final orange = CupertinoColors.systemOrange.resolveFrom(context);
        final red = CupertinoColors.systemRed.resolveFrom(context);
        final teal = CupertinoColors.systemTeal.resolveFrom(context);
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _LiveHero(status: data.status, qps: data.qps),
            ProCard(
              title: proText(context, zh: '今日累计', en: 'Today'),
              child: ProMetricGrid(
                columns: 2,
                metrics: [
                  ProMetricData(
                    label: 'PV',
                    value: formatProValue(data.today.pv, context: context),
                    icon: TablerIcons.eye,
                    color: blue,
                  ),
                  ProMetricData(
                    label: 'UV',
                    value: formatProValue(data.today.uv, context: context),
                    icon: TablerIcons.users,
                    color: purple,
                  ),
                  ProMetricData(
                    label: proText(context, zh: '独立 IP', en: 'IPs'),
                    value: formatProValue(data.today.ip, context: context),
                    icon: TablerIcons.map_pin,
                    color: teal,
                  ),
                  ProMetricData(
                    label: proText(context, zh: '流量', en: 'Traffic'),
                    value: formatProBytes(data.today.flow),
                    icon: TablerIcons.arrows_exchange,
                    color: CupertinoColors.systemGreen.resolveFrom(context),
                  ),
                  ProMetricData(
                    label: proText(context, zh: '蜘蛛', en: 'Spiders'),
                    value: formatProValue(data.today.spider, context: context),
                    icon: TablerIcons.bug,
                    color: orange,
                  ),
                  ProMetricData(
                    label: proText(context, zh: '请求', en: 'Requests'),
                    value: formatProValue(data.today.req, context: context),
                    icon: TablerIcons.world,
                    color: blue,
                  ),
                  ProMetricData(
                    label: '4xx',
                    value: formatProValue(
                      data.today.count4xx,
                      context: context,
                    ),
                    icon: TablerIcons.alert_triangle,
                    color: orange,
                  ),
                  ProMetricData(
                    label: '5xx',
                    value: formatProValue(
                      data.today.count5xx,
                      context: context,
                    ),
                    icon: TablerIcons.server_off,
                    color: red,
                  ),
                ],
              ),
            ),
            ProCard(
              title: proText(context, zh: '访客趋势', en: 'Visitors'),
              trailing: Text(
                proText(context, zh: 'PV / UV', en: 'PV / UV'),
                style: TextStyle(
                  fontSize: 10,
                  color: AppColors.tertiaryLabel(context),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Align(
                    alignment: Alignment.centerLeft,
                    child: SizedBox(
                      width: 168,
                      child: ProSegmented<MonitorRange>(
                        values: MonitorRange.values,
                        labels: [
                          for (final item in MonitorRange.values)
                            _rangeLabel(context, item),
                        ],
                        selected: range,
                        onChanged: onRangeChanged,
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),
                  trendAsync.when(
                    loading: () => const SizedBox(
                      height: 150,
                      child: Center(child: CupertinoActivityIndicator()),
                    ),
                    error: (error, _) => ProEmpty(
                      message: '$error',
                      icon: TablerIcons.alert_triangle,
                      compact: true,
                    ),
                    data: (points) => ProLineChart(
                      height: 160,
                      labels: [
                        for (final point in points) _shortDay(point.date),
                      ],
                      series: [
                        ProChartSeries(
                          spots: [
                            for (var i = 0; i < points.length; i++)
                              FlSpot(i.toDouble(), points[i].pv.toDouble()),
                          ],
                          color: blue,
                          label: 'PV',
                        ),
                        ProChartSeries(
                          spots: [
                            for (var i = 0; i < points.length; i++)
                              FlSpot(i.toDouble(), points[i].uv.toDouble()),
                          ],
                          color: purple,
                          label: 'UV',
                          showArea: false,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            ProCard(
              title: proText(context, zh: '访客来源', en: 'Visitor origins'),
              trailing: Text(
                proText(context, zh: '按国家 / 地区', en: 'By country/region'),
                style: TextStyle(
                  fontSize: 10,
                  color: AppColors.tertiaryLabel(context),
                ),
              ),
              child: ProRankList(
                items: [
                  for (final item in locations.take(10))
                    ProRankItem(
                      name: item.name,
                      count: item.value,
                      percent: total <= 0 ? 0 : item.value / total * 100,
                    ),
                ],
                maxItems: 10,
                accent: teal,
                emptyText: proText(
                  context,
                  zh: '还没有访客来源数据',
                  en: 'No visitor origin data yet',
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

class _LiveHero extends StatelessWidget {
  const _LiveHero({required this.status, required this.qps});

  final MonitorStatus status;
  final MonitorQps qps;

  @override
  Widget build(BuildContext context) {
    final blue = CupertinoColors.activeBlue.resolveFrom(context);
    final open = status.open && status.healthy;
    return ProCard(
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  proText(context, zh: '实时', en: 'Live'),
                  style: TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w600,
                    color: AppColors.secondaryLabel(context),
                  ),
                ),
              ),
              ProStatusPill(
                healthy: open,
                label: open
                    ? proText(context, zh: '监控中', en: 'Monitoring')
                    : proText(context, zh: '未运行', en: 'Stopped'),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Container(
            height: 0.5,
            color: AppColors.separator(context).withValues(alpha: 0.12),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _HeroValue(
                  label: proText(context, zh: '当前请求 / 秒', en: 'Requests/sec'),
                  value: qps.qps <= 0 ? '0' : qps.qps.toStringAsFixed(2),
                  color: blue,
                ),
              ),
              Container(
                width: 0.5,
                height: 34,
                color: AppColors.separator(context).withValues(alpha: 0.14),
              ),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.only(left: 14),
                  child: _HeroValue(
                    label: proText(context, zh: '当前流量', en: 'Traffic'),
                    value: formatProBytes(qps.flow),
                    color: CupertinoColors.systemTeal.resolveFrom(context),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _HeroValue extends StatelessWidget {
  const _HeroValue({
    required this.label,
    required this.value,
    required this.color,
  });

  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          value,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.w700,
            letterSpacing: -0.8,
            height: 1.05,
            color: color,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: TextStyle(
            fontSize: 10.5,
            color: AppColors.secondaryLabel(context),
          ),
        ),
      ],
    );
  }
}

class _MonitorStats extends ConsumerWidget {
  const _MonitorStats({
    required this.serverId,
    required this.websiteId,
    required this.range,
    required this.onRangeChanged,
  });

  final int serverId;
  final int websiteId;
  final MonitorRange range;
  final ValueChanged<MonitorRange> onRangeChanged;

  static const _sections = [
    ('uri', '热门 URL', 'Top URLs', TablerIcons.link),
    ('referer', '来源页面', 'Referrers', TablerIcons.external_link),
    ('os', '操作系统', 'Operating systems', TablerIcons.device_desktop),
    ('browser', '浏览器', 'Browsers', TablerIcons.browser),
    ('device', '设备', 'Devices', TablerIcons.device_mobile),
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(monitorRanksProvider((serverId, websiteId, range)));
    final accents = [
      CupertinoColors.activeBlue.resolveFrom(context),
      CupertinoColors.systemPurple.resolveFrom(context),
      CupertinoColors.systemOrange.resolveFrom(context),
      CupertinoColors.systemGreen.resolveFrom(context),
      CupertinoColors.systemTeal.resolveFrom(context),
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Text(
              proText(context, zh: '统计范围', en: 'Range'),
              style: TextStyle(
                fontSize: 11,
                color: AppColors.secondaryLabel(context),
              ),
            ),
            const Spacer(),
            SizedBox(
              width: 168,
              child: ProSegmented<MonitorRange>(
                values: MonitorRange.values,
                labels: [
                  for (final item in MonitorRange.values)
                    _rangeLabel(context, item),
                ],
                selected: range,
                onChanged: onRangeChanged,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        async.when(
          loading: () => const Padding(
            padding: EdgeInsets.symmetric(vertical: 60),
            child: Center(child: CupertinoActivityIndicator()),
          ),
          error: (error, _) => ProError(
            error: error,
            onRetry: () => ref.invalidate(
              monitorRanksProvider((serverId, websiteId, range)),
            ),
          ),
          data: (ranks) => Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              for (var i = 0; i < _sections.length; i++)
                _RankCard(
                  title: proText(
                    context,
                    zh: _sections[i].$2,
                    en: _sections[i].$3,
                  ),
                  icon: _sections[i].$4,
                  accent: accents[i],
                  items: ranks[_sections[i].$1] ?? const [],
                  onMore: () {
                    final items = ranks[_sections[i].$1] ?? const [];
                    _showRankSheet(
                      context,
                      title: proText(
                        context,
                        zh: _sections[i].$2,
                        en: _sections[i].$3,
                      ),
                      items: items,
                      accent: accents[i],
                    );
                  },
                ),
            ],
          ),
        ),
      ],
    );
  }
}

class _RankCard extends StatelessWidget {
  const _RankCard({
    required this.title,
    required this.icon,
    required this.accent,
    required this.items,
    required this.onMore,
  });

  final String title;
  final IconData icon;
  final Color accent;
  final List<MonitorRankItem> items;
  final VoidCallback onMore;

  @override
  Widget build(BuildContext context) {
    return ProCard(
      title: title,
      trailing: Icon(icon, size: 14, color: accent.withValues(alpha: 0.8)),
      child: ProRankList(
        items: [
          for (final item in items)
            ProRankItem(
              name: item.name,
              count: item.count,
              percent: item.percent,
            ),
        ],
        maxItems: 5,
        accent: accent,
        onMore: items.length > 5 ? onMore : null,
        emptyText: proText(context, zh: '暂无数据', en: 'No data'),
      ),
    );
  }
}

Future<void> _showRankSheet(
  BuildContext context, {
  required String title,
  required List<MonitorRankItem> items,
  required Color accent,
}) {
  return showActionSheet(
    context: context,
    builder: (_) => ActionSheetScaffold(
      title: title,
      child: ProRankList(
        items: [
          for (final item in items)
            ProRankItem(
              name: item.name,
              count: item.count,
              percent: item.percent,
            ),
        ],
        maxItems: items.length,
        accent: accent,
      ),
    ),
  );
}

class _MonitorLogs extends ConsumerWidget {
  const _MonitorLogs({
    required this.serverId,
    required this.websiteId,
    required this.range,
    required this.page,
    required this.pageSize,
    required this.onRangeChanged,
    required this.onPageChanged,
  });

  final int serverId;
  final int websiteId;
  final MonitorRange range;
  final int page;
  final int pageSize;
  final ValueChanged<MonitorRange> onRangeChanged;
  final ValueChanged<int> onPageChanged;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(
      monitorLogsProvider((serverId, websiteId, range, page)),
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Text(
              proText(context, zh: '时间范围', en: 'Range'),
              style: TextStyle(
                fontSize: 11,
                color: AppColors.secondaryLabel(context),
              ),
            ),
            const Spacer(),
            SizedBox(
              width: 168,
              child: ProSegmented<MonitorRange>(
                values: MonitorRange.values,
                labels: [
                  for (final item in MonitorRange.values)
                    _rangeLabel(context, item),
                ],
                selected: range,
                onChanged: onRangeChanged,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        async.when(
          loading: () => const Padding(
            padding: EdgeInsets.symmetric(vertical: 60),
            child: Center(child: CupertinoActivityIndicator()),
          ),
          error: (error, _) => ProError(
            error: error,
            onRetry: () => ref.invalidate(
              monitorLogsProvider((serverId, websiteId, range, page)),
            ),
          ),
          data: (data) {
            final totalPages = (data.total / pageSize).ceil().clamp(1, 9999);
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                ProCard(
                  title: proText(context, zh: '请求日志', en: 'Requests'),
                  trailing: Text(
                    '${data.total}',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: AppColors.secondaryLabel(context),
                    ),
                  ),
                  padding: const EdgeInsets.fromLTRB(8, 12, 8, 4),
                  child: data.items.isEmpty
                      ? ProEmpty(
                          message: proText(
                            context,
                            zh: '所选范围内没有请求',
                            en: 'No requests in this range',
                          ),
                          icon: TablerIcons.chart_line,
                        )
                      : Column(
                          children: [
                            for (var i = 0; i < data.items.length; i++) ...[
                              if (i > 0)
                                Container(
                                  height: 0.5,
                                  margin: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                  ),
                                  color: AppColors.separator(
                                    context,
                                  ).withValues(alpha: 0.1),
                                ),
                              _MonitorLogRow(entry: data.items[i]),
                            ],
                          ],
                        ),
                ),
                if (data.total > pageSize)
                  ProPager(
                    page: page,
                    totalPages: totalPages,
                    onPrevious: page > 1 ? () => onPageChanged(page - 1) : null,
                    onNext: page < totalPages
                        ? () => onPageChanged(page + 1)
                        : null,
                  ),
              ],
            );
          },
        ),
      ],
    );
  }
}

class _MonitorLogRow extends StatelessWidget {
  const _MonitorLogRow({required this.entry});

  final MonitorLogEntry entry;

  @override
  Widget build(BuildContext context) {
    final ok = entry.statusCode < 400;
    final warn = entry.statusCode < 500;
    final statusColor = ok
        ? AppColors.success
        : warn
        ? CupertinoColors.systemOrange.resolveFrom(context)
        : CupertinoColors.systemRed.resolveFrom(context);
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => showMonitorLogDetailSheet(context, entry: entry),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(8, 10, 8, 10),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 30,
              height: 18,
              margin: const EdgeInsets.only(top: 1),
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: CupertinoColors.activeBlue
                    .resolveFrom(context)
                    .withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(5),
              ),
              child: Text(
                entry.method.isEmpty ? '-' : entry.method,
                style: TextStyle(
                  fontSize: 8.5,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.1,
                  color: CupertinoColors.activeBlue.resolveFrom(context),
                ),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    entry.uri.isEmpty ? '/' : entry.uri,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 12,
                      fontFamily: 'Menlo',
                      height: 1.3,
                      color: AppColors.label(context),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          entry.ip,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 10,
                            fontFamily: 'Menlo',
                            color: AppColors.secondaryLabel(context),
                          ),
                        ),
                      ),
                      if (entry.ipLocation.isNotEmpty) ...[
                        Text(
                          ' · ',
                          style: TextStyle(
                            fontSize: 10,
                            color: AppColors.tertiaryLabel(context),
                          ),
                        ),
                        Flexible(
                          child: Text(
                            entry.ipLocation,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 10,
                              color: AppColors.secondaryLabel(context),
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  formatProTime(
                    entry.localtime,
                  ).replaceFirst(RegExp(r'^\d{4}-'), ''),
                  style: TextStyle(
                    fontSize: 9.5,
                    color: AppColors.tertiaryLabel(context),
                  ),
                ),
                const SizedBox(height: 3),
                ProTag(text: '${entry.statusCode}', color: statusColor),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

String _rangeLabel(BuildContext context, MonitorRange range) {
  return switch (range) {
    MonitorRange.today => proText(context, zh: '今天', en: 'Today'),
    MonitorRange.week => proText(context, zh: '7 天', en: '7d'),
    MonitorRange.month => proText(context, zh: '30 天', en: '30d'),
  };
}

String _shortDay(String raw) {
  final value = DateTime.tryParse(raw);
  if (value == null) return raw;
  return '${value.month}/${value.day}';
}
