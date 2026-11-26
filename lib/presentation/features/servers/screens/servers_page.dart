import 'dart:async';

import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/localization/l10n_x.dart';
import '../../../../core/router/app_router.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../domain/entities/panel_node.dart';
import '../../../../domain/entities/server.dart';
import '../../../common/components/floating_tab_bar.dart';
import '../../../common/components/frosted_action_button.dart';
import '../../../common/components/frosted_scaffold.dart';
import '../../settings/providers/app_settings_provider.dart';
import '../providers/node_providers.dart';
import '../providers/node_selection_provider.dart';
import '../providers/servers_provider.dart';
import '../widgets/add_server_sheet.dart';
import '../widgets/server_context_menu.dart';
import '../widgets/server_group_card.dart';
import '../widgets/server_memo_curl_card.dart';
import 'servers_settings_tab.dart';

class ServersPage extends ConsumerStatefulWidget {
  const ServersPage({super.key});

  @override
  ConsumerState<ServersPage> createState() => _ServersPageState();
}

class _ServersPageState extends ConsumerState<ServersPage>
    with RouteAware, WidgetsBindingObserver {
  List<FloatingTabItemData> _tabItems(BuildContext context) => [
    FloatingTabItemData(
      icon: CupertinoIcons.rectangle_stack,
      activeIcon: CupertinoIcons.rectangle_stack_fill,
      label: context.l10n.nav_servers,
      nativeSymbol: 'rectangle.stack.fill',
    ),
    FloatingTabItemData(
      icon: CupertinoIcons.gear,
      activeIcon: CupertinoIcons.gear_solid,
      label: context.l10n.nav_settings,
      nativeSymbol: 'gearshape.fill',
    ),
  ];

  int _selectedIndex = 0;
  Timer? _refreshTimer;
  Timer? _popRefreshTimer;
  ProviderSubscription<AsyncValue<AppSettings>>? _settingsSubscription;
  bool _autoRefreshEnabled = true;
  int _refreshIntervalSeconds =
      AppSettingsController.defaultServersRefreshIntervalSeconds;
  bool _isCurrentRoute = true;
  bool _isForeground = true;
  DateTime? _lastNodeRefreshAt;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _settingsSubscription = ref.listenManual<AsyncValue<AppSettings>>(
      appSettingsControllerProvider,
      (_, next) => _applyRefreshSettings(next.valueOrNull),
      fireImmediately: true,
    );
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final isForeground = state == AppLifecycleState.resumed;
    if (isForeground == _isForeground) return;
    _isForeground = isForeground;
    if (!isForeground) {
      _stopTimer();
      _popRefreshTimer?.cancel();
      return;
    }
    if (_isCurrentRoute) {
      _syncTimerWithSettings();
      _refreshServerSnapshots();
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    routeObserver.subscribe(this, ModalRoute.of(context)!);
  }

  @override
  void didPushNext() {
    _isCurrentRoute = false;
    _popRefreshTimer?.cancel();
    _stopTimer();
  }

  @override
  void didPopNext() {
    _isCurrentRoute = true;
    _syncTimerWithSettings();
    // 等返回动画结束再刷新卡片快照，避免在转场期间同时重建整页列表
    // 与发起网络请求，造成退出页面时的掉帧。
    _popRefreshTimer?.cancel();
    _popRefreshTimer = Timer(const Duration(milliseconds: 320), () {
      if (mounted) _refreshServerSnapshots();
    });
  }

  void _applyRefreshSettings(AppSettings? settings) {
    _autoRefreshEnabled = settings?.serversAutoRefreshEnabled ?? true;
    _refreshIntervalSeconds =
        settings?.serversRefreshIntervalSeconds ??
        AppSettingsController.defaultServersRefreshIntervalSeconds;
    _syncTimerWithSettings();
  }

  void _syncTimerWithSettings() {
    if (!_isCurrentRoute || !_isForeground || !_autoRefreshEnabled) {
      _stopTimer();
      return;
    }
    _startTimer(Duration(seconds: _refreshIntervalSeconds));
  }

  void _startTimer(Duration interval) {
    _stopTimer();
    _refreshTimer = Timer.periodic(interval, (_) => _refreshServerSnapshots());
  }

  void _stopTimer() {
    _refreshTimer?.cancel();
    _refreshTimer = null;
  }

  @override
  void dispose() {
    routeObserver.unsubscribe(this);
    WidgetsBinding.instance.removeObserver(this);
    _settingsSubscription?.close();
    _popRefreshTimer?.cancel();
    _stopTimer();
    super.dispose();
  }

  void _selectTab(int index) {
    setState(() => _selectedIndex = index);
    if (index == 0) {
      _refreshServerSnapshots();
    }
  }

  void _refreshServerSnapshots() {
    if (!mounted || _selectedIndex != 0) return;
    final servers = ref.read(serversNotifierProvider).valueOrNull;
    if (servers == null || servers.isEmpty) return;
    final now = DateTime.now();
    final shouldRefreshNodes =
        _lastNodeRefreshAt == null ||
        now.difference(_lastNodeRefreshAt!) >= const Duration(seconds: 30);
    if (shouldRefreshNodes) {
      _lastNodeRefreshAt = now;
    }
    for (final server in servers) {
      ref.invalidate(serverDashboardSnapshotProvider(server.id));
      if (server.isProActive && shouldRefreshNodes) {
        ref.invalidate(serverNodesProvider(server.id));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final tabItems = _tabItems(context);

    return CupertinoPageScaffold(
      backgroundColor: AppColors.background(context),
      child: Stack(
        children: [
          IndexedStack(
            index: _selectedIndex,
            children: [
              _ServerListTab(onAddServer: _handleAddServer),
              const ServersSettingsTab(),
            ],
          ),
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: FloatingTabBar(
              items: tabItems,
              selectedIndex: _selectedIndex,
              onTabSelected: _selectTab,
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _handleAddServer() async {
    await AddServerSheet.show(context);
  }
}

class _ServerListTab extends ConsumerStatefulWidget {
  final VoidCallback onAddServer;

  const _ServerListTab({required this.onAddServer});

  @override
  ConsumerState<_ServerListTab> createState() => _ServerListTabState();
}

class _ServerListTabState extends ConsumerState<_ServerListTab> {
  List<Server>? _orderedServers;
  List<int> _sourceIds = const [];
  bool _isSorting = false;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final serversAsync = ref.watch(serversNotifierProvider);
    final cardStyle =
        ref.watch(appSettingsControllerProvider).valueOrNull?.serverCardStyle ??
        ServerCardStyle.simple;

    return FrostedScaffold(
      title: _greeting(context),
      showBackButton: false,
      largeTitle: true,
      fadeOutDistance: 41,
      trailingBuilder: (isDark, isOverlapping) {
        if (_isSorting) {
          return FrostedActionButton(
            text: l10n.common_done,
            isDark: isDark,
            isOverlapping: isOverlapping,
            onTap: () => setState(() => _isSorting = false),
          );
        }
        return FrostedActionButton(
          text: '',
          icon: CupertinoIcons.add,
          isDark: isDark,
          isOverlapping: isOverlapping,
          onTap: widget.onAddServer,
        );
      },
      body: CustomScrollView(
        physics: const AlwaysScrollableScrollPhysics(
          parent: BouncingScrollPhysics(),
        ),
        slivers: [
          SliverToBoxAdapter(
            child: SizedBox(
              height: FrostedScaffold.contentTopPadding(context) + 60,
            ),
          ),
          if (_isSorting)
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 10,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.secondaryBackground(
                      context,
                    ).withValues(alpha: 0.72),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: AppColors.separator(
                        context,
                      ).withValues(alpha: 0.12),
                      width: 0.5,
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        CupertinoIcons.line_horizontal_3,
                        size: 18,
                        color: AppColors.secondaryLabel(context),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          l10n.servers_sortHint,
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: AppColors.secondaryLabel(context),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          serversAsync.when(
            data: (servers) {
              final orderedServers = _syncOrderedServers(servers);
              if (servers.isEmpty) {
                return SliverFillRemaining(
                  hasScrollBody: false,
                  child: Padding(
                    padding: const EdgeInsets.only(bottom: 120),
                    child: Center(
                      child: Text(
                        l10n.servers_empty,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: AppColors.secondaryLabel(context),
                        ),
                      ),
                    ),
                  ),
                );
              }

              return SliverPadding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 132),
                sliver: SliverReorderableList(
                  itemBuilder: (context, index) {
                    final server = orderedServers[index];
                    return Padding(
                      key: ValueKey(server.id),
                      padding: const EdgeInsets.only(bottom: 12),
                      child: Builder(
                        builder: (itemContext) {
                          return GestureDetector(
                            behavior: HitTestBehavior.opaque,
                            onLongPress: _isSorting
                                ? null
                                : () => _showServerMenu(itemContext, server),
                            child: _isSorting
                                ? ReorderableDragStartListener(
                                    index: index,
                                    child: _buildServerCard(
                                      server,
                                      cardStyle,
                                      interactive: false,
                                    ),
                                  )
                                : _buildServerCard(
                                    server,
                                    cardStyle,
                                    interactive: true,
                                  ),
                          );
                        },
                      ),
                    );
                  },
                  itemCount: orderedServers.length,
                  onReorder: _reorderServers,
                ),
              );
            },
            loading: () => const SliverFillRemaining(
              child: Center(child: CupertinoActivityIndicator()),
            ),
            error: (err, stack) => SliverFillRemaining(
              child: Center(child: Text(l10n.servers_loadFailed('$err'))),
            ),
          ),
        ],
      ),
    );
  }

  void _showServerMenu(BuildContext itemContext, Server server) {
    ServerContextMenu.show(
      itemContext,
      onSort: () => setState(() => _isSorting = true),
      onEdit: () => AddServerSheet.edit(context, server),
      onDelete: () => _confirmDelete(server),
    );
  }

  Widget _buildServerCard(
    Server server,
    ServerCardStyle cardStyle, {
    required bool interactive,
  }) {
    if (server.isProActive) {
      return _ProServerCardView(
        server: server,
        style: cardStyle,
        interactive: interactive,
        onOpenNode: (nodeName) => _openNode(server, nodeName),
        onLongPressNode: interactive
            ? (anchorContext, _) => _showServerMenu(anchorContext, server)
            : null,
        onLongPressHeader: interactive
            ? (anchorContext) => _showServerMenu(anchorContext, server)
            : null,
      );
    }
    return ServerMemoCurlCard(
      server: server,
      style: cardStyle,
      onTap: interactive
          ? () => _openServer(server, PanelNode.localName)
          : null,
    );
  }

  Future<void> _openServer(Server server, String nodeName) async {
    await ref
        .read(activeNodeControllerProvider(server.id).notifier)
        .select(nodeName);
    if (!mounted) return;
    context.push('/server/${server.id}');
  }

  Future<void> _openNode(Server server, String nodeName) {
    return _openServer(server, nodeName);
  }

  Future<void> _confirmDelete(Server server) async {
    final confirmed = await showCupertinoDialog<bool>(
      context: context,
      builder: (context) => CupertinoAlertDialog(
        title: Text(context.l10n.servers_deleteTitle),
        content: Text(context.l10n.servers_deleteContent(server.displayName)),
        actions: [
          CupertinoDialogAction(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(context.l10n.common_cancel),
          ),
          CupertinoDialogAction(
            isDestructiveAction: true,
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(context.l10n.common_delete),
          ),
        ],
      ),
    );

    if (confirmed != true) return;
    await ref.read(serversNotifierProvider.notifier).removeServer(server.id);
  }

  String _greeting(BuildContext context) {
    final hour = DateTime.now().hour;
    final l10n = context.l10n;
    if (hour < 5) return l10n.home_greeting_lateNight;
    if (hour < 11) return l10n.home_greeting_morning;
    if (hour < 13) return l10n.home_greeting_noon;
    if (hour < 18) return l10n.home_greeting_afternoon;
    return l10n.home_greeting_evening;
  }

  List<Server> _syncOrderedServers(List<Server> servers) {
    final ids = [for (final server in servers) server.id];
    if (_orderedServers == null || !_sameIds(ids, _sourceIds)) {
      _orderedServers = [...servers];
      _sourceIds = ids;
      return _orderedServers!;
    }

    final latestById = {for (final server in servers) server.id: server};
    final orderedIds = [for (final server in _orderedServers!) server.id];
    _orderedServers = [
      for (final id in orderedIds)
        if (latestById.containsKey(id)) latestById[id]!,
    ];
    return _orderedServers!;
  }

  void _reorderServers(int oldIndex, int newIndex) {
    final orderedServers = _orderedServers;
    if (orderedServers == null) return;

    setState(() {
      if (newIndex > oldIndex) newIndex -= 1;
      final moved = orderedServers.removeAt(oldIndex);
      orderedServers.insert(newIndex, moved);
      _sourceIds = [for (final server in orderedServers) server.id];
    });

    ref.read(serversNotifierProvider.notifier).reorderServers([
      for (final server in orderedServers) server.id,
    ]);
  }

  bool _sameIds(List<int> first, List<int> second) {
    if (first.length != second.length) return false;
    for (var i = 0; i < first.length; i++) {
      if (first[i] != second[i]) return false;
    }
    return true;
  }
}

/// 专业版面板卡片：拿到实时节点后再决定展示多机组卡还是普通单卡。
///
/// 添加面板时可能因网络抖动没拉到节点；这里在缓存为空时主动拉取一次，
/// 让「手动覆盖为专业版」或探测失败的场景也能自动出现分组。
class _ProServerCardView extends ConsumerWidget {
  const _ProServerCardView({
    required this.server,
    required this.style,
    required this.interactive,
    required this.onOpenNode,
    this.onLongPressNode,
    this.onLongPressHeader,
  });

  final Server server;
  final ServerCardStyle style;
  final bool interactive;
  final ValueChanged<String> onOpenNode;
  final void Function(BuildContext context, PanelNode node)? onLongPressNode;
  final void Function(BuildContext context)? onLongPressHeader;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // 探测阶段即使没拿到子节点，Server.nodes 也会被补成 [local]；因此不
    // 能以缓存为空作为「需要刷新」的条件，Pro 面板统一以实时列表为准。
    final nodes =
        ref.watch(serverNodesProvider(server.id)).valueOrNull ?? server.nodes;
    final hasChildren = nodes.any((node) => !node.isLocal);

    if (!hasChildren) {
      return ServerMemoCurlCard(
        server: server,
        style: style,
        onTap: interactive ? () => onOpenNode(PanelNode.localName) : null,
      );
    }

    // 组卡不再包 Memo Curl：备注卡会从组卡后面露出来，而且长按预览会
    // 变成一张满宽的单机卡。分组直接用自带交互的组卡，长按只显示遮罩
    // 与锚定菜单，原卡尺寸和边距保持不变。
    return ServerGroupCard(
      server: server,
      style: style,
      onOpenNode: interactive ? onOpenNode : (_) {},
      onLongPressNode: onLongPressNode,
      onLongPressHeader: onLongPressHeader,
    );
  }
}
