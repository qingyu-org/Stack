import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/localization/l10n_x.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../data/api/pro_api.dart';
import '../../../../domain/entities/panel_node.dart';
import '../../../../domain/entities/server.dart';
import '../../servers/providers/node_providers.dart';
import '../../servers/providers/node_selection_provider.dart';
import '../../servers/providers/servers_provider.dart';
import '../providers/pro_providers.dart';
import '../utils/pro_data_utils.dart';
import '../widgets/pro_page_scaffold.dart';
import '../widgets/pro_snapshot_view.dart';

class ProFeaturePage extends ConsumerWidget {
  const ProFeaturePage({
    super.key,
    required this.serverId,
    required this.feature,
    required this.baseTitle,
    required this.sectionTitles,
    required this.sectionOrder,
  });

  final int serverId;
  final ProFeature feature;
  final String baseTitle;
  final Map<String, String> Function(BuildContext context) sectionTitles;
  final List<String> sectionOrder;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final server = _findServer(ref, serverId);
    final activeNode =
        ref.watch(activeNodeControllerProvider(serverId)).valueOrNull ??
        PanelNode.localName;
    final nodeLabel = activeNode == PanelNode.localName
        ? l10n.nodes_local
        : activeNode;
    final title = '$baseTitle · $nodeLabel';
    final async = ref.watch(proSnapshotProvider((serverId, feature)));
    final nodes = (server?.isProActive ?? false)
        ? (ref.watch(serverNodesProvider(serverId)).valueOrNull ??
              server?.nodes ??
              const <PanelNode>[])
        : const <PanelNode>[];

    return ProPageScaffold(
      title: title,
      onRefresh: () async {
        ref.invalidate(proSnapshotProvider((serverId, feature)));
        try {
          await ref.read(proSnapshotProvider((serverId, feature)).future);
        } catch (_) {
          // 错误由页面状态展示。
        }
      },
      trailingBuilder: (isDark, isOverlapping) {
        if (server == null || !server.isProActive || nodes.length < 2) {
          return const SizedBox.shrink();
        }
        return _ProNodeChip(
          server: server,
          nodes: nodes,
          activeNode: activeNode,
          onSelected: (nodeName) async {
            await ref
                .read(activeNodeControllerProvider(serverId).notifier)
                .select(nodeName);
            ref.invalidate(proSnapshotProvider((serverId, feature)));
          },
        );
      },
      children: [
        if (server != null && !server.isProActive)
          ProUnavailableView(description: l10n.pro_unavailableDescription),
        async.when(
          data: (snapshot) => ProSnapshotView(
            snapshot: snapshot,
            sectionTitles: sectionTitles(context),
            sectionOrder: sectionOrder,
            onRetry: () {
              ref.invalidate(proSnapshotProvider((serverId, feature)));
            },
          ),
          loading: () => ProSnapshotView(
            snapshot: null,
            sectionTitles: sectionTitles(context),
            sectionOrder: sectionOrder,
            loading: true,
          ),
          error: (error, stack) => ProSnapshotView(
            snapshot: null,
            sectionTitles: sectionTitles(context),
            sectionOrder: sectionOrder,
            error: error,
            onRetry: () {
              ref.invalidate(proSnapshotProvider((serverId, feature)));
            },
          ),
        ),
      ],
    );
  }

  Server? _findServer(WidgetRef ref, int serverId) {
    final servers = ref.watch(serversNotifierProvider).valueOrNull;
    if (servers == null) return null;
    for (final server in servers) {
      if (server.id == serverId) return server;
    }
    return null;
  }
}

class _ProNodeChip extends StatelessWidget {
  const _ProNodeChip({
    required this.server,
    required this.nodes,
    required this.activeNode,
    required this.onSelected,
  });

  final Server server;
  final List<PanelNode> nodes;
  final String activeNode;
  final ValueChanged<String> onSelected;

  @override
  Widget build(BuildContext context) {
    return CupertinoButton(
      padding: EdgeInsets.zero,
      minimumSize: Size.zero,
      onPressed: () => _showPicker(context),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
        decoration: BoxDecoration(
          color: AppColors.secondaryBackground(context).withValues(alpha: 0.72),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: AppColors.separator(context).withValues(alpha: 0.24),
            width: 0.5,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              CupertinoIcons.arrow_left_right,
              size: 11,
              color: AppColors.secondaryLabel(context),
            ),
            const SizedBox(width: 4),
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 92),
              child: Text(
                activeNode == PanelNode.localName
                    ? context.l10n.nodes_local
                    : activeNode,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 11.5,
                  fontWeight: FontWeight.w600,
                  color: AppColors.label(context),
                ),
              ),
            ),
            const SizedBox(width: 2),
            Icon(
              CupertinoIcons.chevron_down,
              size: 9,
              color: AppColors.tertiaryLabel(context),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _showPicker(BuildContext context) async {
    final l10n = context.l10n;
    await showCupertinoModalPopup<void>(
      context: context,
      builder: (sheetContext) => CupertinoActionSheet(
        title: Text(l10n.nodes_switchTitle),
        message: Text(server.displayName),
        actions: [
          for (final node in nodes)
            CupertinoActionSheetAction(
              isDefaultAction: node.name == activeNode,
              onPressed: () {
                Navigator.of(sheetContext).pop();
                onSelected(node.name);
              },
              child: Text(node.isLocal ? l10n.nodes_local : node.displayName),
            ),
        ],
        cancelButton: CupertinoActionSheetAction(
          onPressed: () => Navigator.of(sheetContext).pop(),
          child: Text(l10n.common_cancel),
        ),
      ),
    );
  }
}

class WafPage extends StatelessWidget {
  const WafPage({super.key, required this.serverId});

  final int serverId;

  @override
  Widget build(BuildContext context) {
    return ProFeaturePage(
      serverId: serverId,
      feature: ProFeature.waf,
      baseTitle: context.l10n.pro_waf_title,
      sectionTitles: (context) => {
        'status': proText(context, zh: '运行状态', en: 'Status'),
        'attack': proText(context, zh: '攻击统计', en: 'Attack stats'),
        'relation': proText(context, zh: '拦截关系', en: 'Block relation'),
        'stat': proText(context, zh: 'WAF 统计', en: 'WAF stats'),
        'websites': proText(context, zh: '站点配置', en: 'Website config'),
        'logs': proText(context, zh: '拦截日志', en: 'Block logs'),
        'cdn': 'CDN',
      },
      sectionOrder: const [
        'status',
        'attack',
        'relation',
        'stat',
        'websites',
        'logs',
        'cdn',
      ],
    );
  }
}

class WebsiteMonitorPage extends StatelessWidget {
  const WebsiteMonitorPage({super.key, required this.serverId});

  final int serverId;

  @override
  Widget build(BuildContext context) {
    return ProFeaturePage(
      serverId: serverId,
      feature: ProFeature.monitor,
      baseTitle: context.l10n.pro_monitor_title,
      sectionTitles: (context) => {
        'status': proText(context, zh: '运行状态', en: 'Status'),
        'stat': proText(context, zh: '实时统计', en: 'Live stats'),
        'visitors': proText(context, zh: '访客趋势', en: 'Visitors'),
        'locations': proText(context, zh: '访客地区', en: 'Locations'),
        'qps': 'QPS',
        'trend': proText(context, zh: '访问趋势', en: 'Traffic trend'),
        'rank': proText(context, zh: '排行', en: 'Ranking'),
        'websites': proText(context, zh: '网站', en: 'Websites'),
        'logs': proText(context, zh: '请求日志', en: 'Request logs'),
        'logStat': proText(context, zh: '日志统计', en: 'Log stats'),
      },
      sectionOrder: const [
        'status',
        'stat',
        'visitors',
        'locations',
        'qps',
        'trend',
        'rank',
        'websites',
        'logs',
        'logStat',
      ],
    );
  }
}

class OpsReportPage extends StatelessWidget {
  const OpsReportPage({super.key, required this.serverId});

  final int serverId;

  @override
  Widget build(BuildContext context) {
    return ProFeaturePage(
      serverId: serverId,
      feature: ProFeature.opsReport,
      baseTitle: context.l10n.pro_opsReport_title,
      sectionTitles: (context) => {
        'context': proText(context, zh: '节点状态', en: 'Node context'),
        'snapshot': proText(context, zh: '当前报表', en: 'Current report'),
        'runs': proText(context, zh: '历史报表', en: 'Report history'),
      },
      sectionOrder: const ['context', 'snapshot', 'runs'],
    );
  }
}

class TamperPage extends StatelessWidget {
  const TamperPage({super.key, required this.serverId});

  final int serverId;

  @override
  Widget build(BuildContext context) {
    return ProFeaturePage(
      serverId: serverId,
      feature: ProFeature.tamper,
      baseTitle: context.l10n.pro_tamper_title,
      sectionTitles: (context) => {
        'templates': proText(context, zh: '防护模板', en: 'Templates'),
        'items': proText(context, zh: '防护项', en: 'Protected items'),
        'logs': proText(context, zh: '防篡改日志', en: 'Tamper logs'),
      },
      sectionOrder: const ['templates', 'items', 'logs'],
    );
  }
}

class ResourceSyncPage extends StatelessWidget {
  const ResourceSyncPage({super.key, required this.serverId});

  final int serverId;

  @override
  Widget build(BuildContext context) {
    return ProFeaturePage(
      serverId: serverId,
      feature: ProFeature.resourceSync,
      baseTitle: context.l10n.pro_sync_title,
      sectionTitles: (context) => {
        'file': proText(context, zh: '文件', en: 'Files'),
        'image': proText(context, zh: '镜像', en: 'Images'),
        'ssl': proText(context, zh: '证书', en: 'Certificates'),
        'app': proText(context, zh: '应用', en: 'Apps'),
      },
      sectionOrder: const ['file', 'image', 'app', 'ssl'],
    );
  }
}
