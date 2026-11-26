import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/localization/l10n_x.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../domain/entities/dashboard.dart';
import '../../../../domain/entities/server.dart';
import '../../../common/components/frosted_scaffold.dart';
import '../../../common/components/sub_menu_page.dart';
import '../../servers/widgets/server_card_compact.dart';
import '../../servers/widgets/server_card_metrics.dart';
import '../../servers/widgets/server_card_simple.dart';
import '../../servers/widgets/server_card_terminal.dart';
import '../../servers/widgets/server_card_shared.dart';
import '../providers/app_settings_provider.dart';

class CardStyleSettingsPage extends ConsumerWidget {
  const CardStyleSettingsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settingsAsync = ref.watch(appSettingsControllerProvider);
    final selectedStyle =
        settingsAsync.valueOrNull?.serverCardStyle ?? ServerCardStyle.simple;
    final l10n = context.l10n;

    final mockServer = Server()
      ..name = 'Production Server'
      ..host = '1.2.3.4'
      ..port = 8888
      ..createdAt = DateTime.now();

    const mockStatus = ServerCardStatus(
      isLoading: false,
      hasData: true,
      hasRefreshError: false,
      latencyMs: 28,
    );
    const mockDashboard = _previewDashboard;

    return FrostedScaffold(
      title: l10n.settings_appearance_cardStyleTitle,
      body: CustomScrollView(
        physics: const AlwaysScrollableScrollPhysics(
          parent: BouncingScrollPhysics(),
        ),
        slivers: [
          SliverToBoxAdapter(
            child: SizedBox(
              height: FrostedScaffold.contentTopPadding(context) + 16,
            ),
          ),
          SliverPadding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            sliver: SliverList(
              delegate: SliverChildListDelegate([
                SubMenuCard(
                  title: l10n.settings_cardStyle_selectTitle,
                  children: ServerCardStyle.values.map((style) {
                    final isSelected = style == selectedStyle;
                    return CupertinoButton(
                      padding: EdgeInsets.zero,
                      onPressed: isSelected || settingsAsync.isLoading
                          ? null
                          : () => ref
                                .read(appSettingsControllerProvider.notifier)
                                .setServerCardStyle(style),
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    style.labelOf(l10n),
                                    style: TextStyle(
                                      fontSize: 17,
                                      fontWeight: FontWeight.w600,
                                      color: AppColors.label(context),
                                    ),
                                  ),
                                ),
                                if (isSelected)
                                  Icon(
                                    CupertinoIcons.checkmark_circle_fill,
                                    color: CupertinoColors.activeBlue
                                        .resolveFrom(context),
                                    size: 24,
                                  ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            // Preview
                            IgnorePointer(
                              child: switch (style) {
                                ServerCardStyle.terminal => TerminalServerCard(
                                  server: mockServer,
                                  status: mockStatus,
                                  dashboard: mockDashboard,
                                  onTap: () {},
                                  isSelected: false,
                                ),
                                ServerCardStyle.simple => SimpleServerCard(
                                  server: mockServer,
                                  status: mockStatus,
                                  dashboard: mockDashboard,
                                  onTap: () {},
                                  isSelected: false,
                                ),
                                ServerCardStyle.compact => CompactServerCard(
                                  server: mockServer,
                                  status: mockStatus,
                                  dashboard: mockDashboard,
                                  onTap: () {},
                                  isSelected: false,
                                ),
                                ServerCardStyle.metrics => MetricsServerCard(
                                  server: mockServer,
                                  status: mockStatus,
                                  dashboard: mockDashboard,
                                  onTap: () {},
                                  isSelected: false,
                                ),
                              },
                            ),
                          ],
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ]),
            ),
          ),
          const SliverToBoxAdapter(child: SizedBox(height: 100)),
        ],
      ),
    );
  }
}

/// 卡片样式设置里使用的示意数据，让预览能看到接近真实的信息层级。
const _previewDashboard = Dashboard(
  base: DashboardBase(
    hostname: 'production',
    ipV4Addr: '1.2.3.4',
    os: 'Ubuntu 24.04 LTS',
    platform: 'ubuntu',
    platformFamily: 'debian',
    platformVersion: '24.04',
    prettyDistro: 'Ubuntu 24.04 LTS',
    kernelArch: 'x86_64',
    kernelVersion: '6.8.0-45-generic',
    cpuCores: 4,
    cpuLogicalCores: 8,
    cpuMhz: 3600,
    cpuModelName: 'AMD Ryzen 7 5800X',
    virtualizationSystem: 'kvm',
    systemProxy: 'noProxy',
    websiteNumber: 12,
    databaseNumber: 3,
    cronjobNumber: 5,
    appInstalledNumber: 18,
    agentNumber: 2,
  ),
  current: DashboardCurrent(
    uptimeSeconds: 93784,
    timeSinceUptime: '1d 2h',
    shotTime: '',
    procs: 128,
    load1: 0.42,
    load5: 0.35,
    load15: 0.30,
    loadUsagePercent: 12,
    cpuTotal: 8,
    cpuUsed: 2.56,
    cpuUsedPercent: 32,
    cpuPercent: [32, 18, 20, 40, 25, 30, 22, 28],
    cpuDetailedPercent: [],
    memoryTotal: 16000000000,
    memoryUsed: 9760000000,
    memoryFree: 6240000000,
    memoryAvailable: 11000000000,
    memoryCache: 2000000000,
    memoryUsedPercent: 61,
    swapMemoryTotal: 4000000000,
    swapMemoryUsed: 1000000000,
    swapMemoryAvailable: 3000000000,
    swapMemoryUsedPercent: 25,
    netBytesSent: 0,
    netBytesRecv: 0,
    ioCount: 0,
    ioReadBytes: 0,
    ioReadTime: 0,
    ioWriteBytes: 0,
    ioWriteTime: 0,
    disks: [
      DiskUsage(
        path: '/',
        device: '/dev/sda1',
        fsType: 'ext4',
        total: 100000000000,
        used: 45000000000,
        free: 55000000000,
        usedPercent: 45,
        inodesTotal: 1000000,
        inodesUsed: 120000,
        inodesFree: 880000,
        inodesUsedPercent: 12,
      ),
    ],
    topCpuItems: [],
    topMemItems: [],
    gpus: [],
    xpus: [],
  ),
);
