import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_tabler_icons/flutter_tabler_icons.dart';

import '../../../../core/localization/l10n_x.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../common/components/floating_tab_bar.dart';
import '../../../common/components/frosted_header.dart';
import '../../../common/components/frosted_scaffold.dart';
import '../../servers/providers/servers_provider.dart';
import '../tabs/ssh_files_tab.dart';
import '../tabs/ssh_overview_tab.dart';
import '../tabs/ssh_processes_tab.dart';
import '../tabs/ssh_terminal_tab.dart';

/// 纯 SSH 服务器详情页。
///
/// 与 1Panel 面板详情页分开，只保留主机本身适用的能力：
/// 概览、终端、SFTP 文件和进程。
class SshServerDetailPage extends ConsumerStatefulWidget {
  const SshServerDetailPage({super.key, required this.serverId});

  final int serverId;

  @override
  ConsumerState<SshServerDetailPage> createState() =>
      _SshServerDetailPageState();
}

class _SshServerDetailPageState extends ConsumerState<SshServerDetailPage> {
  int _selectedIndex = 0;
  final Set<int> _mountedTabs = {0};

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final servers = ref.watch(serversNotifierProvider).valueOrNull;
    String title = 'SSH';
    if (servers != null) {
      for (final server in servers) {
        if (server.id == widget.serverId) {
          title = server.displayName;
          break;
        }
      }
    }

    final tabItems = [
      FloatingTabItemData(
        icon: TablerIcons.chart_line,
        activeIcon: TablerIcons.chart_line,
        label: l10n.ssh_tabOverview,
      ),
      FloatingTabItemData(
        icon: TablerIcons.terminal_2,
        activeIcon: TablerIcons.terminal_2,
        label: l10n.ssh_tabTerminal,
      ),
      FloatingTabItemData(
        icon: TablerIcons.folder,
        activeIcon: TablerIcons.folder,
        label: l10n.ssh_tabFiles,
      ),
      FloatingTabItemData(
        icon: TablerIcons.cpu,
        activeIcon: TablerIcons.cpu,
        label: l10n.ssh_tabProcesses,
      ),
    ];
    // 键盘打开时隐藏标签栏，把空间留给终端输入与快捷键栏。
    final showTabBar = MediaQuery.viewInsetsOf(context).bottom == 0;

    return CupertinoPageScaffold(
      backgroundColor: AppColors.background(context),
      child: Stack(
        children: [
          Padding(
            padding: EdgeInsets.only(
              top: FrostedScaffold.contentTopPadding(context) + 4,
            ),
            child: Column(
              children: [
                Expanded(
                  child: IndexedStack(
                    index: _selectedIndex,
                    children: [
                      if (_mountedTabs.contains(0))
                        TickerMode(
                          enabled: _selectedIndex == 0,
                          child: SshOverviewTab(
                            serverId: widget.serverId,
                            isActive: _selectedIndex == 0,
                          ),
                        )
                      else
                        const SizedBox.shrink(),
                      if (_mountedTabs.contains(1))
                        TickerMode(
                          enabled: _selectedIndex == 1,
                          child: SshTerminalTab(
                            serverId: widget.serverId,
                            isActive: _selectedIndex == 1,
                          ),
                        )
                      else
                        const SizedBox.shrink(),
                      if (_mountedTabs.contains(2))
                        SshFilesTab(
                          serverId: widget.serverId,
                          isActive: _selectedIndex == 2,
                        )
                      else
                        const SizedBox.shrink(),
                      if (_mountedTabs.contains(3))
                        SshProcessesTab(
                          serverId: widget.serverId,
                          isActive: _selectedIndex == 3,
                        )
                      else
                        const SizedBox.shrink(),
                    ],
                  ),
                ),
                if (showTabBar)
                  FloatingTabBar(
                    items: tabItems,
                    selectedIndex: _selectedIndex,
                    expandItems: true,
                    horizontalMargin: 16,
                    contentHorizontalPadding: 8,
                    onTabSelected: (index) {
                      if (index == _selectedIndex) return;
                      setState(() {
                        _selectedIndex = index;
                        _mountedTabs.add(index);
                      });
                    },
                  ),
              ],
            ),
          ),
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: FrostedHeader(
              title: title,
              onBack: () => Navigator.of(context).maybePop(),
            ),
          ),
        ],
      ),
    );
  }
}
