import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_tabler_icons/flutter_tabler_icons.dart';

import '../../../../core/localization/l10n_x.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../domain/entities/panel_node.dart';
import '../../../../domain/entities/pro_models.dart';
import '../../servers/providers/node_providers.dart';
import '../../servers/providers/node_selection_provider.dart';
import '../providers/waf_providers.dart';
import '../utils/pro_data_utils.dart';
import '../widgets/pro_detail_sheets.dart';
import '../widgets/pro_page_scaffold.dart';
import '../widgets/pro_ui.dart';

enum _WafTab { overview, logs, blocks }

class WafPage extends ConsumerStatefulWidget {
  const WafPage({super.key, required this.serverId});

  final int serverId;

  @override
  ConsumerState<WafPage> createState() => _WafPageState();
}

class _WafPageState extends ConsumerState<WafPage> {
  _WafTab _tab = _WafTab.overview;
  int _logPage = 1;
  int _blockPage = 1;

  static const _pageSize = 20;

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
      title: '${l10n.pro_waf_title} · $nodeLabel',
      onRefresh: _refresh,
      children: [
        ProPageTabs<_WafTab>(
          values: _WafTab.values,
          labels: [
            proText(context, zh: '概览', en: 'Overview'),
            proText(context, zh: '拦截记录', en: 'Blocked'),
            proText(context, zh: '封锁记录', en: 'Bans'),
          ],
          selected: _tab,
          onChanged: (value) => setState(() => _tab = value),
        ),
        const SizedBox(height: 12),
        if (!nodeIsPro)
          ProCard(
            child: ProEmpty(
              message: proText(
                context,
                zh: '当前节点为社区版，没有 WAF 数据。请切换到主节点。',
                en:
                    'This node is Community Edition and has no WAF data. '
                    'Switch to the primary node.',
              ),
              icon: TablerIcons.shield_off,
            ),
          )
        else
          switch (_tab) {
            _WafTab.overview => _WafOverview(serverId: widget.serverId),
            _WafTab.logs => _WafLogs(
              serverId: widget.serverId,
              page: _logPage,
              pageSize: _pageSize,
              onPageChanged: (page) => setState(() => _logPage = page),
            ),
            _WafTab.blocks => _WafBlocks(
              serverId: widget.serverId,
              page: _blockPage,
              pageSize: _pageSize,
              onPageChanged: (page) => setState(() => _blockPage = page),
            ),
          },
      ],
    );
  }

  Future<void> _refresh() async {
    switch (_tab) {
      case _WafTab.overview:
        ref.invalidate(wafOverviewProvider(widget.serverId));
        try {
          await ref.read(wafOverviewProvider(widget.serverId).future);
        } catch (_) {}
      case _WafTab.logs:
        final key = (widget.serverId, _logPage);
        ref.invalidate(wafLogsProvider(key));
        try {
          await ref.read(wafLogsProvider(key).future);
        } catch (_) {}
      case _WafTab.blocks:
        final key = (widget.serverId, _blockPage);
        ref.invalidate(wafBlocksProvider(key));
        try {
          await ref.read(wafBlocksProvider(key).future);
        } catch (_) {}
    }
  }
}

class _WafOverview extends ConsumerWidget {
  const _WafOverview({required this.serverId});

  final int serverId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(wafOverviewProvider(serverId));
    return async.when(
      loading: () => const Padding(
        padding: EdgeInsets.symmetric(vertical: 60),
        child: Center(child: CupertinoActivityIndicator()),
      ),
      error: (error, _) => ProError(
        error: error,
        onRetry: () => ref.invalidate(wafOverviewProvider(serverId)),
      ),
      data: (data) => _WafOverviewBody(data: data),
    );
  }
}

class _WafOverviewBody extends StatelessWidget {
  const _WafOverviewBody({required this.data});

  final WafOverviewData data;

  @override
  Widget build(BuildContext context) {
    final red = CupertinoColors.systemRed.resolveFrom(context);
    final purple = CupertinoColors.systemPurple.resolveFrom(context);
    final weekLabels = [for (final item in data.week) _shortDay(item.day)];
    final locations = [...data.locations]
      ..sort((a, b) => b.value.compareTo(a.value));
    final totalAttacks = locations.fold<int>(
      0,
      (sum, item) => sum + item.value,
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ProCard(
          title: proText(context, zh: '运行状态', en: 'Status'),
          trailing: ProStatusPill(
            healthy: data.status.healthy && data.status.open,
            label: data.status.open
                ? proText(context, zh: '已开启', en: 'Enabled')
                : proText(context, zh: '未开启', en: 'Disabled'),
          ),
          child: Row(
            children: [
              Icon(
                TablerIcons.shield_check,
                size: 18,
                color: data.status.healthy && data.status.open
                    ? AppColors.success
                    : CupertinoColors.systemGrey.resolveFrom(context),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  data.status.openrestyVersion.isEmpty
                      ? '-'
                      : 'OpenResty ${data.status.openrestyVersion}',
                  style: TextStyle(
                    fontSize: 12,
                    color: AppColors.secondaryLabel(context),
                  ),
                ),
              ),
            ],
          ),
        ),
        ProCard(
          title: proText(context, zh: '今日状态', en: 'Today'),
          child: ProMetricGrid(
            columns: 2,
            metrics: [
              ProMetricData(
                label: proText(context, zh: '请求数', en: 'Requests'),
                value: formatProValue(data.today.reqCount, context: context),
                icon: TablerIcons.world,
                color: CupertinoColors.activeBlue.resolveFrom(context),
              ),
              ProMetricData(
                label: proText(context, zh: '拦截数', en: 'Blocked'),
                value: formatProValue(data.today.attackCount, context: context),
                icon: TablerIcons.shield_x,
                color: red,
              ),
              ProMetricData(
                label: '4xx',
                value: formatProValue(data.today.count4xx, context: context),
                icon: TablerIcons.alert_triangle,
                color: CupertinoColors.systemOrange.resolveFrom(context),
              ),
              ProMetricData(
                label: '5xx',
                value: formatProValue(data.today.count5xx, context: context),
                icon: TablerIcons.server_off,
                color: purple,
              ),
            ],
          ),
        ),
        ProCard(
          title: proText(context, zh: '请求趋势（7日）', en: 'Requests · 7 days'),
          child: ProLineChart(
            labels: weekLabels,
            showLegend: false,
            series: [
              ProChartSeries(
                spots: [
                  for (var i = 0; i < data.week.length; i++)
                    FlSpot(i.toDouble(), data.week[i].reqCount.toDouble()),
                ],
                color: CupertinoColors.activeBlue.resolveFrom(context),
                label: proText(context, zh: '请求', en: 'Requests'),
              ),
            ],
          ),
        ),
        ProCard(
          title: proText(context, zh: '拦截趋势（7日）', en: 'Blocked · 7 days'),
          child: ProLineChart(
            labels: weekLabels,
            showLegend: false,
            series: [
              ProChartSeries(
                spots: [
                  for (var i = 0; i < data.week.length; i++)
                    FlSpot(i.toDouble(), data.week[i].attackCount.toDouble()),
                ],
                color: red,
                label: proText(context, zh: '拦截', en: 'Blocked'),
              ),
            ],
          ),
        ),
        ProCard(
          title: proText(context, zh: '拦截来源（30日）', en: 'Sources · 30 days'),
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
                  percent: totalAttacks <= 0
                      ? 0
                      : item.value / totalAttacks * 100,
                ),
            ],
            maxItems: 10,
            accent: red,
            emptyText: proText(
              context,
              zh: '最近 30 天没有拦截记录',
              en: 'No blocks in the last 30 days',
            ),
          ),
        ),
      ],
    );
  }

  static String _shortDay(String raw) {
    final value = DateTime.tryParse(raw);
    if (value == null) return raw;
    return '${value.month}/${value.day}';
  }
}

class _WafLogs extends ConsumerWidget {
  const _WafLogs({
    required this.serverId,
    required this.page,
    required this.pageSize,
    required this.onPageChanged,
  });

  final int serverId;
  final int page;
  final int pageSize;
  final ValueChanged<int> onPageChanged;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(wafLogsProvider((serverId, page)));
    return async.when(
      loading: () => const Padding(
        padding: EdgeInsets.symmetric(vertical: 60),
        child: Center(child: CupertinoActivityIndicator()),
      ),
      error: (error, _) => ProError(
        error: error,
        onRetry: () => ref.invalidate(wafLogsProvider((serverId, page))),
      ),
      data: (data) {
        final totalPages = (data.total / pageSize).ceil().clamp(1, 9999);
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            ProCard(
              title: proText(context, zh: '拦截记录', en: 'Blocked requests'),
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
                        zh: '暂无拦截记录',
                        en: 'No blocked requests',
                      ),
                      icon: TablerIcons.shield_check,
                    )
                  : Column(
                      children: [
                        for (var i = 0; i < data.items.length; i++) ...[
                          if (i > 0)
                            Container(
                              height: 0.5,
                              margin: const EdgeInsets.symmetric(horizontal: 8),
                              color: AppColors.separator(
                                context,
                              ).withValues(alpha: 0.1),
                            ),
                          _WafLogRow(serverId: serverId, entry: data.items[i]),
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
    );
  }
}

class _WafLogRow extends StatelessWidget {
  const _WafLogRow({required this.serverId, required this.entry});

  final int serverId;
  final WafLogEntry entry;

  @override
  Widget build(BuildContext context) {
    final red = CupertinoColors.systemRed.resolveFrom(context);
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () =>
          showWafLogDetailSheet(context, serverId: serverId, entry: entry),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(8, 10, 8, 10),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: red.withValues(alpha: 0.09),
                borderRadius: BorderRadius.circular(9),
              ),
              child: Icon(TablerIcons.shield_x, size: 16, color: red),
            ),
            const SizedBox(width: 9),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          entry.host.isEmpty ? entry.ip : entry.host,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 12.5,
                            fontWeight: FontWeight.w600,
                            color: AppColors.label(context),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        formatProTime(
                          entry.localtime,
                        ).replaceFirst(RegExp(r'^\d{4}-'), ''),
                        style: TextStyle(
                          fontSize: 9.5,
                          color: AppColors.tertiaryLabel(context),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 3),
                  Text(
                    entry.uri.isEmpty ? '-' : entry.uri,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 11,
                      fontFamily: 'Menlo',
                      color: AppColors.secondaryLabel(context),
                    ),
                  ),
                  const SizedBox(height: 5),
                  Wrap(
                    spacing: 5,
                    runSpacing: 4,
                    children: [
                      ProTag(text: entry.ip, color: CupertinoColors.activeBlue),
                      if (entry.ipLocation.isNotEmpty)
                        ProTag(
                          text: entry.ipLocation,
                          color: CupertinoColors.systemGrey,
                        ),
                      if (entry.execRule.isNotEmpty)
                        ProTag(text: entry.execRule, color: red),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(width: 4),
            Icon(
              CupertinoIcons.chevron_right,
              size: 13,
              color: AppColors.tertiaryLabel(context),
            ),
          ],
        ),
      ),
    );
  }
}

class _WafBlocks extends ConsumerWidget {
  const _WafBlocks({
    required this.serverId,
    required this.page,
    required this.pageSize,
    required this.onPageChanged,
  });

  final int serverId;
  final int page;
  final int pageSize;
  final ValueChanged<int> onPageChanged;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(wafBlocksProvider((serverId, page)));
    return async.when(
      loading: () => const Padding(
        padding: EdgeInsets.symmetric(vertical: 60),
        child: Center(child: CupertinoActivityIndicator()),
      ),
      error: (error, _) => ProError(
        error: error,
        onRetry: () => ref.invalidate(wafBlocksProvider((serverId, page))),
      ),
      data: (data) {
        final totalPages = (data.total / pageSize).ceil().clamp(1, 9999);
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            ProCard(
              title: proText(context, zh: '封锁记录', en: 'Blocked IPs'),
              trailing: Text(
                '${data.total}',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: AppColors.secondaryLabel(context),
                ),
              ),
              padding: const EdgeInsets.fromLTRB(14, 12, 14, 4),
              child: data.items.isEmpty
                  ? ProEmpty(
                      message: proText(
                        context,
                        zh: '暂无封锁记录',
                        en: 'No blocked IPs',
                      ),
                      icon: TablerIcons.shield_check,
                    )
                  : Column(
                      children: [
                        for (var i = 0; i < data.items.length; i++) ...[
                          if (i > 0)
                            Container(
                              height: 0.5,
                              color: AppColors.separator(
                                context,
                              ).withValues(alpha: 0.1),
                            ),
                          _WafBlockRow(entry: data.items[i]),
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
    );
  }
}

class _WafBlockRow extends StatelessWidget {
  const _WafBlockRow({required this.entry});

  final WafBlockEntry entry;

  @override
  Widget build(BuildContext context) {
    final red = CupertinoColors.systemRed.resolveFrom(context);
    final green = AppColors.success;
    final active = entry.blocked;
    final color = active ? red : green;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 9),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.09),
              borderRadius: BorderRadius.circular(9),
            ),
            child: Icon(
              active ? TablerIcons.ban : TablerIcons.lock_open,
              size: 16,
              color: color,
            ),
          ),
          const SizedBox(width: 9),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        entry.ip,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w600,
                          fontFamily: 'Menlo',
                          color: AppColors.label(context),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    ProStatusPill(
                      healthy: !active,
                      label: active
                          ? proText(context, zh: '已封禁', en: 'Banned')
                          : proText(context, zh: '已解封', en: 'Unbanned'),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Wrap(
                  spacing: 5,
                  runSpacing: 4,
                  children: [
                    if (entry.ipLocation.isNotEmpty)
                      ProTag(
                        text: entry.ipLocation,
                        color: CupertinoColors.systemGrey,
                      ),
                    if (entry.execRule.isNotEmpty)
                      ProTag(text: entry.execRule, color: red),
                    if (entry.blockingTime > 0)
                      ProTag(
                        text: proText(
                          context,
                          zh: '${entry.blockingTime} 秒',
                          en: '${entry.blockingTime}s',
                        ),
                        color: CupertinoColors.systemOrange,
                      ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  formatProTime(entry.createDate),
                  style: TextStyle(
                    fontSize: 9.5,
                    color: AppColors.tertiaryLabel(context),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
