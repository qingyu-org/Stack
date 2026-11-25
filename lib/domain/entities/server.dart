import 'panel_node.dart';

/// 用户对面板版本的覆盖设置。
///
/// 1Panel 专业版才有 `/core/nodes/list` 等接口；自动探测失败时，用户可以
/// 手动强制显示专业版入口（接口不可用时页面会给出明确提示）。
enum PanelEditionOverride {
  auto('auto'),
  pro('pro'),
  community('community');

  const PanelEditionOverride(this.storageName);

  final String storageName;

  static PanelEditionOverride fromName(String? name) {
    return values.firstWhere(
      (value) => value.storageName == name,
      orElse: () => PanelEditionOverride.auto,
    );
  }
}

class Server {
  int id = 0;

  String syncId = '';

  String? name;

  late String host;

  late int port;

  bool isHttps = false;

  bool allowInsecureConnections = false;

  int sortIndex = 0;

  /// 最近一次探测是否确认面板为 1Panel 专业版。
  bool isPro = false;

  /// 用户手动覆盖面板版本；默认自动探测。
  PanelEditionOverride editionOverride = PanelEditionOverride.auto;

  /// 专业版面板下的节点缓存。非专业版通常只有 `local`。
  List<PanelNode> nodes = const [];

  DateTime? proCheckedAt;

  String panelVersion = '';

  DateTime? createdAt;

  DateTime? updatedAt;

  DateTime? lastUsedAt;

  /// 当前是否按专业版展示。
  bool get isProActive {
    return switch (editionOverride) {
      PanelEditionOverride.pro => true,
      PanelEditionOverride.community => false,
      PanelEditionOverride.auto => isPro,
    };
  }

  bool get hasChildNodes => nodes.any((node) => !node.isLocal);

  PanelNode? nodeByName(String name) {
    for (final node in nodes) {
      if (node.name == name) return node;
    }
    return null;
  }

  String get displayName {
    if (name != null && name!.isNotEmpty) {
      return name!;
    }
    return '$host:$port';
  }

  Uri get baseUrl {
    final scheme = isHttps ? 'https' : 'http';
    return Uri.parse('$scheme://$host:$port');
  }

  Map<String, Object?> toJson() {
    return {
      'id': id,
      'syncId': syncId,
      'name': name,
      'host': host,
      'port': port,
      'isHttps': isHttps,
      'allowInsecureConnections': allowInsecureConnections,
      'sortIndex': sortIndex,
      'isPro': isPro,
      'editionOverride': editionOverride.storageName,
      'nodes': [for (final node in nodes) node.toJson()],
      'proCheckedAt': proCheckedAt?.toIso8601String(),
      'panelVersion': panelVersion,
      'createdAt': createdAt?.toIso8601String(),
      'updatedAt': updatedAt?.toIso8601String(),
      'lastUsedAt': lastUsedAt?.toIso8601String(),
    };
  }

  static Server fromJson(Map<String, Object?> json) {
    return Server()
      ..id = _intValue(json['id'])
      ..syncId = json['syncId'] as String? ?? ''
      ..name = json['name'] as String?
      ..host = json['host'] as String
      ..port = _intValue(json['port'])
      ..isHttps = json['isHttps'] == true
      ..allowInsecureConnections = json['allowInsecureConnections'] == true
      ..sortIndex = _intValue(json['sortIndex'])
      ..isPro = json['isPro'] == true
      ..editionOverride = PanelEditionOverride.fromName(
        json['editionOverride'] as String?,
      )
      ..nodes = _nodesValue(json['nodes'])
      ..proCheckedAt = _dateTimeValue(json['proCheckedAt'])
      ..panelVersion = json['panelVersion'] as String? ?? ''
      ..createdAt = _dateTimeValue(json['createdAt'])
      ..updatedAt = _dateTimeValue(json['updatedAt'])
      ..lastUsedAt = _dateTimeValue(json['lastUsedAt']);
  }

  static List<PanelNode> _nodesValue(Object? value) {
    if (value is! List) return const [];
    return [
      for (final item in value)
        if (item is Map) PanelNode.fromJson(Map<String, Object?>.from(item)),
    ];
  }

  static int _intValue(Object? value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    if (value is String) return int.tryParse(value) ?? 0;
    return 0;
  }

  static DateTime? _dateTimeValue(Object? value) {
    if (value is! String || value.isEmpty) return null;
    return DateTime.tryParse(value);
  }
}
