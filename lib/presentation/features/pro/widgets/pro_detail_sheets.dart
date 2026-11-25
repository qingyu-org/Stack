import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_tabler_icons/flutter_tabler_icons.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../domain/entities/pro_models.dart';
import '../../../common/app_toast.dart';
import '../../../common/components/action_sheet_launcher.dart';
import '../../../common/components/action_sheet_scaffold.dart';
import '../providers/waf_providers.dart';
import '../utils/pro_data_utils.dart';
import 'pro_ui.dart';

Future<void> showWafLogDetailSheet(
  BuildContext context, {
  required int serverId,
  required WafLogEntry entry,
}) {
  return showActionSheet(
    context: context,
    builder: (sheetContext) =>
        _WafLogDetailSheet(serverId: serverId, entry: entry),
  );
}

class _WafLogDetailSheet extends ConsumerWidget {
  const _WafLogDetailSheet({required this.serverId, required this.entry});

  final int serverId;
  final WafLogEntry entry;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final detail = ref.watch(wafLogDetailProvider((serverId, entry.id)));
    final data = detail.valueOrNull ?? entry;
    final headers = _parseHeaders(data.nginxLog);

    return ActionSheetScaffold(
      title: proText(context, zh: '拦截详情', en: 'Blocked request'),
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 28),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _DetailHero(entry: data),
            const SizedBox(height: 12),
            ProCard(
              title: proText(context, zh: '请求信息', en: 'Request'),
              child: Column(
                children: [
                  _InfoRow(
                    label: proText(context, zh: '来源 IP', en: 'Source IP'),
                    value: data.ip,
                    monospace: true,
                  ),
                  _InfoRow(
                    label: proText(context, zh: '归属地', en: 'Location'),
                    value: data.ipLocation,
                  ),
                  _InfoRow(label: 'Host', value: data.host, monospace: true),
                  _InfoRow(
                    label: proText(context, zh: 'URL', en: 'URL'),
                    value: data.uri,
                    monospace: true,
                  ),
                  _InfoRow(
                    label: proText(context, zh: '方法', en: 'Method'),
                    value: data.method,
                  ),
                  _InfoRow(
                    label: proText(context, zh: '状态码', en: 'Status'),
                    value: data.statusCode,
                  ),
                  _InfoRow(
                    label: proText(context, zh: '时间', en: 'Time'),
                    value: _formatTime(data.localtime),
                  ),
                  _InfoRow(
                    label: proText(context, zh: '远程端口', en: 'Remote port'),
                    value: data.remotePort,
                  ),
                ],
              ),
            ),
            ProCard(
              title: proText(context, zh: '命中规则', en: 'Matched rule'),
              child: Column(
                children: [
                  _InfoRow(
                    label: proText(context, zh: '规则', en: 'Rule'),
                    value: data.execRule,
                    monospace: true,
                  ),
                  _InfoRow(
                    label: proText(context, zh: '类型', en: 'Type'),
                    value: data.ruleType,
                  ),
                  _InfoRow(
                    label: proText(context, zh: '匹配内容', en: 'Matched value'),
                    value: data.matchValueContent,
                    monospace: true,
                  ),
                  _InfoRow(
                    label: 'User-Agent',
                    value: data.userAgent,
                    monospace: true,
                  ),
                ],
              ),
            ),
            if (headers.isNotEmpty)
              ProCard(
                title: proText(context, zh: '请求头', en: 'Headers'),
                child: Column(
                  children: [
                    for (final header in headers)
                      _InfoRow(
                        label: header.key,
                        value: header.value,
                        monospace: true,
                      ),
                  ],
                ),
              ),
            if (detail.isLoading)
              const Padding(
                padding: EdgeInsets.only(top: 4),
                child: Center(child: CupertinoActivityIndicator(radius: 8)),
              ),
            if (detail.hasError)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(
                  '${detail.error}',
                  style: TextStyle(
                    fontSize: 11,
                    color: AppColors.secondaryLabel(context),
                  ),
                ),
              ),
            const SizedBox(height: 8),
            CupertinoButton(
              padding: const EdgeInsets.symmetric(vertical: 12),
              onPressed: () async {
                await Clipboard.setData(ClipboardData(text: data.ip));
                if (context.mounted) {
                  showAppSuccessToast(
                    proText(context, zh: 'IP 已复制', en: 'IP copied'),
                  );
                }
              },
              child: Text(proText(context, zh: '复制 IP', en: 'Copy IP')),
            ),
          ],
        ),
      ),
    );
  }

  static List<MapEntry<String, String>> _parseHeaders(String raw) {
    final entries = <MapEntry<String, String>>[];
    for (final line in raw.split('\n')) {
      final trimmed = line.trim();
      if (trimmed.isEmpty) continue;
      final index = trimmed.indexOf(':');
      if (index <= 0) continue;
      entries.add(
        MapEntry(
          trimmed.substring(0, index).trim(),
          trimmed.substring(index + 1).trim(),
        ),
      );
    }
    return entries;
  }

  static String _formatTime(String raw) {
    if (raw.isEmpty) return '-';
    final value = DateTime.tryParse(raw);
    if (value == null) return raw;
    final local = value.toLocal();
    String two(int n) => n.toString().padLeft(2, '0');
    return '${local.year}-${two(local.month)}-${two(local.day)} '
        '${two(local.hour)}:${two(local.minute)}:${two(local.second)}';
  }
}

class _DetailHero extends StatelessWidget {
  const _DetailHero({required this.entry});

  final WafLogEntry entry;

  @override
  Widget build(BuildContext context) {
    final red = CupertinoColors.systemRed.resolveFrom(context);
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 13, 14, 13),
      decoration: BoxDecoration(
        color: red.withValues(alpha: 0.07),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: red.withValues(alpha: 0.12), width: 0.6),
      ),
      child: Row(
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: red.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(11),
            ),
            child: Icon(TablerIcons.shield_x, size: 19, color: red),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  entry.execRule.isEmpty ? '-' : entry.execRule,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: AppColors.label(context),
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  '${entry.ip} · ${entry.ipLocation}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 11,
                    color: AppColors.secondaryLabel(context),
                  ),
                ),
              ],
            ),
          ),
          ProStatusPill(
            healthy: false,
            label: proText(context, zh: '已拦截', en: 'Blocked'),
          ),
        ],
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({
    required this.label,
    required this.value,
    this.monospace = false,
  });

  final String label;
  final String value;
  final bool monospace;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 92,
            child: Text(
              label,
              style: TextStyle(
                fontSize: 11,
                color: AppColors.secondaryLabel(context),
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              value.isEmpty ? '-' : value,
              style: TextStyle(
                fontSize: 11,
                height: 1.4,
                fontFamily: monospace ? 'Menlo' : null,
                color: AppColors.label(context),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

Future<void> showMonitorLogDetailSheet(
  BuildContext context, {
  required MonitorLogEntry entry,
}) {
  return showActionSheet(
    context: context,
    builder: (_) => _MonitorLogDetailSheet(entry: entry),
  );
}

class _MonitorLogDetailSheet extends StatelessWidget {
  const _MonitorLogDetailSheet({required this.entry});

  final MonitorLogEntry entry;

  @override
  Widget build(BuildContext context) {
    final ok = entry.statusCode < 400;
    return ActionSheetScaffold(
      title: proText(context, zh: '请求日志', en: 'Request log'),
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 28),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _DetailHeroMonitor(entry: entry, ok: ok),
            const SizedBox(height: 12),
            ProCard(
              title: proText(context, zh: '请求信息', en: 'Request'),
              child: Column(
                children: [
                  _InfoRow(
                    label: proText(context, zh: '来源 IP', en: 'Source IP'),
                    value: entry.ip,
                    monospace: true,
                  ),
                  _InfoRow(
                    label: proText(context, zh: '归属地', en: 'Location'),
                    value: entry.ipLocation,
                  ),
                  _InfoRow(label: 'Host', value: entry.host, monospace: true),
                  _InfoRow(
                    label: proText(context, zh: 'URL', en: 'URL'),
                    value: entry.uri,
                    monospace: true,
                  ),
                  _InfoRow(
                    label: proText(context, zh: '方法', en: 'Method'),
                    value: entry.method,
                  ),
                  _InfoRow(
                    label: proText(context, zh: '状态码', en: 'Status'),
                    value: '${entry.statusCode}',
                  ),
                  _InfoRow(
                    label: proText(context, zh: '耗时', en: 'Time'),
                    value: '${entry.requestTime} ms',
                  ),
                  _InfoRow(
                    label: proText(context, zh: '发送/接收', en: 'Sent/Recv'),
                    value:
                        '${_fmtBytes(entry.sendBytes)} / '
                        '${_fmtBytes(entry.receiveBytes)}',
                  ),
                  _InfoRow(
                    label: proText(context, zh: '时间', en: 'Time'),
                    value: entry.localtime,
                  ),
                ],
              ),
            ),
            ProCard(
              title: proText(context, zh: '客户端', en: 'Client'),
              child: Column(
                children: [
                  _InfoRow(label: 'OS', value: entry.os),
                  _InfoRow(
                    label: proText(context, zh: '浏览器', en: 'Browser'),
                    value: entry.browser,
                  ),
                  _InfoRow(
                    label: proText(context, zh: '设备', en: 'Device'),
                    value: entry.device,
                  ),
                  _InfoRow(
                    label: proText(context, zh: '蜘蛛', en: 'Spider'),
                    value: entry.spider,
                  ),
                  _InfoRow(
                    label: proText(context, zh: '来源', en: 'Referer'),
                    value: entry.referer,
                    monospace: true,
                  ),
                  _InfoRow(
                    label: 'User-Agent',
                    value: entry.userAgent,
                    monospace: true,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  static String _fmtBytes(int value) {
    if (value <= 0) return '0 B';
    const units = ['B', 'KB', 'MB', 'GB', 'TB'];
    var size = value.toDouble();
    var unit = 0;
    while (size >= 1024 && unit < units.length - 1) {
      size /= 1024;
      unit++;
    }
    return '${size.toStringAsFixed(size >= 100 ? 0 : 1)} ${units[unit]}';
  }
}

class _DetailHeroMonitor extends StatelessWidget {
  const _DetailHeroMonitor({required this.entry, required this.ok});

  final MonitorLogEntry entry;
  final bool ok;

  @override
  Widget build(BuildContext context) {
    final color = ok ? AppColors.success : AppColors.error;
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 13, 14, 13),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.07),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withValues(alpha: 0.12), width: 0.6),
      ),
      child: Row(
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(11),
            ),
            child: Icon(
              ok ? TablerIcons.arrow_up_right : TablerIcons.alert_circle,
              size: 19,
              color: color,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  entry.uri.isEmpty ? '-' : entry.uri,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w700,
                    color: AppColors.label(context),
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  '${entry.method} · ${entry.ip} · ${entry.ipLocation}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 11,
                    color: AppColors.secondaryLabel(context),
                  ),
                ),
              ],
            ),
          ),
          ProStatusPill(healthy: ok, label: '${entry.statusCode}'),
        ],
      ),
    );
  }
}
