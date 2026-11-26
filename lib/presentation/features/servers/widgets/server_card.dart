import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_tabler_icons/flutter_tabler_icons.dart';

import '../../../../domain/entities/server.dart';
import '../../settings/providers/app_settings_provider.dart';
import '../../../common/components/app_meta_chip.dart';
import '../providers/servers_provider.dart';
import '../providers/ssh_servers_provider.dart';
import 'server_card_compact.dart';
import 'server_card_metrics.dart';
import 'server_card_shared.dart';
import 'server_card_simple.dart';
import 'server_card_terminal.dart';

class ServerCard extends ConsumerWidget {
  const ServerCard({
    super.key,
    required this.server,
    this.onTap,
    this.isSelected = false,
    this.style = ServerCardStyle.simple,
  });

  final Server server;
  final VoidCallback? onTap;
  final bool isSelected;
  final ServerCardStyle style;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final snapshot = server.isSshServer
        ? ref.watch(sshDashboardSnapshotProvider(server.id))
        : ref.watch(serverDashboardSnapshotProvider(server.id));
    final snapshotData = snapshot.valueOrNull;
    final dashboard = snapshotData?.dashboard;
    final status = ServerCardStatus.fromSnapshot(
      isLoading: snapshot.isLoading,
      hasData: dashboard != null,
      hasError: snapshot.hasError,
      latencyMs: snapshotData?.fetchMs,
    );
    final titleBadge = server.isSshServer
        ? AppMetaChip(
            icon: TablerIcons.terminal_2,
            label: 'SSH',
            color: CupertinoColors.systemTeal.resolveFrom(context),
            height: 18,
            fontSize: 9,
            iconSize: 10,
            horizontalPadding: 5,
          )
        : null;

    return switch (style) {
      ServerCardStyle.simple => SimpleServerCard(
        server: server,
        dashboard: dashboard,
        status: status,
        onTap: onTap,
        isSelected: isSelected,
        loading: status.isLoading && !status.hasData,
        showCounts: !server.isSshServer,
        titleBadge: titleBadge,
      ),
      ServerCardStyle.terminal => TerminalServerCard(
        server: server,
        dashboard: dashboard,
        status: status,
        onTap: onTap,
        isSelected: isSelected,
        loading: status.isLoading && !status.hasData,
        titleBadge: titleBadge,
      ),
      ServerCardStyle.compact => CompactServerCard(
        server: server,
        dashboard: dashboard,
        status: status,
        onTap: onTap,
        isSelected: isSelected,
        loading: status.isLoading && !status.hasData,
        titleBadge: titleBadge,
      ),
      ServerCardStyle.metrics => MetricsServerCard(
        server: server,
        dashboard: dashboard,
        status: status,
        onTap: onTap,
        isSelected: isSelected,
        loading: status.isLoading && !status.hasData,
        titleBadge: titleBadge,
      ),
    };
  }
}
