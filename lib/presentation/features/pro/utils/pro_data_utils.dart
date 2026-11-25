import 'package:flutter/widgets.dart';

import '../../../../core/localization/l10n_x.dart';

String proText(BuildContext context, {required String zh, required String en}) {
  return Localizations.localeOf(context).languageCode == 'zh' ? zh : en;
}

/// 把常见字段名映射成可读的指标标题。
String proMetricLabel(BuildContext context, String key) {
  final l10n = context.l10n;
  final normalized = key.toLowerCase().replaceAll('_', '').replaceAll('-', '');
  if (RegExp(r'attack').hasMatch(normalized)) {
    return l10n.pro_metric_attacks;
  }
  if (RegExp(r'block|intercept|deny|4xx|5xx').hasMatch(normalized)) {
    return l10n.pro_metric_blocked;
  }
  if (RegExp(r'visitor|uv|ipcount').hasMatch(normalized)) {
    return l10n.pro_metric_visitors;
  }
  if (RegExp(r'qps').hasMatch(normalized)) {
    return l10n.pro_metric_qps;
  }
  if (RegExp(
    r'bandwidth|traffic|flow|bytes|sent|received',
  ).hasMatch(normalized)) {
    return l10n.pro_metric_bandwidth;
  }
  if (RegExp(r'request|reqcount|count|total|pv').hasMatch(normalized)) {
    return l10n.pro_metric_requests;
  }
  return _prettifyKey(key);
}

String _prettifyKey(String key) {
  if (key.isEmpty) return '-';
  final spaced = key
      .replaceAll('_', ' ')
      .replaceAllMapped(
        RegExp(r'([a-z])([A-Z])'),
        (match) => '${match.group(1)} ${match.group(2)}',
      )
      .trim();
  if (spaced.isEmpty) return key;
  return spaced[0].toUpperCase() + spaced.substring(1);
}

/// 展平对象里的标量字段，用于未知 schema 的兜底展示。
Map<String, dynamic> flattenProScalars(dynamic data, {int depth = 2}) {
  final result = <String, dynamic>{};
  void visit(dynamic value, String prefix, int level) {
    if (value is Map) {
      for (final entry in value.entries) {
        final key = entry.key.toString();
        final nextPrefix = prefix.isEmpty ? key : '$prefix.$key';
        visit(entry.value, nextPrefix, level + 1);
      }
      return;
    }
    if (value is List || value == null) return;
    if (value is num || value is String || value is bool) {
      result[prefix] = value;
    }
  }

  if (data is Map) {
    for (final entry in data.entries) {
      final key = entry.key.toString();
      final value = entry.value;
      if (value is Map && depth > 0) {
        visit(value, key, 0);
      } else if (value is num || value is String || value is bool) {
        result[key] = value;
      }
    }
  }
  return result;
}

/// 从任意响应里找出可展示为表格的列表。
List<Map<String, dynamic>> extractProRows(dynamic data, {int depth = 0}) {
  if (data is List) {
    return [
      for (final item in data)
        if (item is Map) Map<String, dynamic>.from(item),
    ];
  }
  if (data is Map && depth < 3) {
    for (final key in const [
      'items',
      'list',
      'records',
      'rows',
      'logs',
      'data',
      'children',
      'websites',
      'visitors',
    ]) {
      final value = data[key];
      if (value is List) return extractProRows(value, depth: depth + 1);
      if (value is Map) {
        final rows = extractProRows(value, depth: depth + 1);
        if (rows.isNotEmpty) return rows;
      }
    }
  }
  return const [];
}

String formatProValue(Object? value, {BuildContext? context}) {
  if (value == null) return '-';
  if (value is double) {
    if (value.isNaN || value.isInfinite) return '-';
  }
  if (value is num) {
    final language = context == null
        ? null
        : Localizations.localeOf(context).languageCode;
    return _formatNumber(value, zh: language == null || language == 'zh');
  }
  final text = value.toString();
  return text.length > 80 ? '${text.substring(0, 77)}...' : text;
}

String _formatNumber(num value, {required bool zh}) {
  final magnitude = value.abs();
  if (zh) {
    if (magnitude >= 100000000) {
      return '${(value / 100000000).toStringAsFixed(2)}亿';
    }
    if (magnitude >= 10000) {
      return '${(value / 10000).toStringAsFixed(2)}万';
    }
  } else {
    if (magnitude >= 1000000000) {
      return '${(value / 1000000000).toStringAsFixed(2)}B';
    }
    if (magnitude >= 1000000) {
      return '${(value / 1000000).toStringAsFixed(2)}M';
    }
    if (magnitude >= 1000) {
      return '${(value / 1000).toStringAsFixed(2)}K';
    }
  }
  if (value is double) {
    if (value == value.roundToDouble()) return value.round().toString();
    return value.toStringAsFixed(2);
  }
  return value.toString();
}

/// 把字节数格式化成可读大小（1024 进制）。
String formatProBytes(Object? value, {int decimals = 1}) {
  var size = value is num
      ? value.toDouble()
      : double.tryParse(value?.toString() ?? '') ?? 0;
  if (!size.isFinite || size <= 0) return '0 B';
  const units = ['B', 'KB', 'MB', 'GB', 'TB', 'PB'];
  var unit = 0;
  while (size >= 1024 && unit < units.length - 1) {
    size /= 1024;
    unit++;
  }
  final digits = unit == 0 || size >= 100 ? 0 : decimals;
  return '${size.toStringAsFixed(digits)} ${units[unit]}';
}

/// 统一格式化后端时间，兼容带时区的 ISO 与本地时间字符串。
String formatProTime(String raw, {bool withSeconds = false}) {
  if (raw.isEmpty) return '-';
  final value = DateTime.tryParse(raw);
  if (value == null) return raw;
  final local = value.toLocal();
  String two(int n) => n.toString().padLeft(2, '0');
  final date = '${local.year}-${two(local.month)}-${two(local.day)}';
  final time = '${two(local.hour)}:${two(local.minute)}';
  return withSeconds ? '$date $time:${two(local.second)}' : '$date $time';
}

/// 列表行里可读的标题字段。
String proRowTitle(Map<String, dynamic> row) {
  for (final key in const [
    'name',
    'website',
    'domain',
    'host',
    'ip',
    'uri',
    'url',
    'path',
    'title',
    'websiteName',
    'template',
  ]) {
    final value = row[key];
    if (value != null && value.toString().trim().isNotEmpty) {
      return value.toString();
    }
  }
  for (final entry in row.entries) {
    final value = entry.value;
    if (value is String && value.trim().isNotEmpty) return value;
  }
  return '-';
}

String proRowSubtitle(
  Map<String, dynamic> row, {
  int maxParts = 4,
  BuildContext? context,
}) {
  final parts = <String>[];
  for (final entry in row.entries) {
    if (parts.length >= maxParts) break;
    final value = entry.value;
    if (value is Map || value is List || value == null) continue;
    if (value is String && value.trim().isEmpty) continue;
    final key = entry.key.toString();
    if (key == 'name' || key == 'website' || key == 'domain') continue;
    parts.add('$key: ${formatProValue(value, context: context)}');
  }
  return parts.join(' · ');
}
