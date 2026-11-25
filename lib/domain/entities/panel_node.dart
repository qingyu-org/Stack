/// 1Panel 专业版多机管理中的节点。
///
/// 主节点（master）在 1Panel 里固定叫 `local`；其余节点是挂在主面板下的
/// 子节点。节点不是独立的 Server，不单独保存 API Key，所有请求都由主面板
/// 通过 `CurrentNode` 头代理。
class PanelNode {
  const PanelNode({
    required this.id,
    required this.name,
    this.status = '',
    this.version = '',
    this.isXpack = false,
    this.isBound = false,
    this.isLocal = false,
    this.address = '',
    this.groupId,
    this.groupBelong = '',
    this.isFavorite = false,
    this.cpuUsedPercent,
    this.cpuTotal,
    this.memoryTotal,
    this.memoryUsedPercent,
    this.description = '',
    this.systemVersion = '',
  });

  /// `local` 或数字 ID 的字符串形式。
  final String id;

  /// 节点名称，也是 `CurrentNode` 头里的值。
  final String name;

  /// 1Panel 返回的状态，常见为 `Healthy` / `UnHealthy`。
  final String status;

  final String version;
  final bool isXpack;
  final bool isBound;

  /// 主节点（master 自己）。
  final bool isLocal;

  final String address;
  final int? groupId;
  final String groupBelong;
  final bool isFavorite;

  /// 以下字段来自 `/core/nodes/simple/all`，用于组卡上的资源概览。
  final double? cpuUsedPercent;
  final int? cpuTotal;
  final int? memoryTotal;
  final double? memoryUsedPercent;

  final String description;
  final String systemVersion;

  static const localName = 'local';

  bool get isOnline {
    final normalized = status.trim().toLowerCase();
    if (normalized.isEmpty) return true;
    if (normalized.contains('unhealthy') || normalized.contains('offline')) {
      return false;
    }
    return normalized.contains('healthy') ||
        normalized.contains('online') ||
        normalized.contains('running');
  }

  bool get isPro => isXpack || isBound;

  String get displayName => name.isEmpty ? id : name;

  PanelNode copyWith({
    String? id,
    String? name,
    String? status,
    String? version,
    bool? isXpack,
    bool? isBound,
    bool? isLocal,
    String? address,
    int? groupId,
    String? groupBelong,
    bool? isFavorite,
    double? cpuUsedPercent,
    int? cpuTotal,
    int? memoryTotal,
    double? memoryUsedPercent,
    String? description,
    String? systemVersion,
  }) {
    return PanelNode(
      id: id ?? this.id,
      name: name ?? this.name,
      status: status ?? this.status,
      version: version ?? this.version,
      isXpack: isXpack ?? this.isXpack,
      isBound: isBound ?? this.isBound,
      isLocal: isLocal ?? this.isLocal,
      address: address ?? this.address,
      groupId: groupId ?? this.groupId,
      groupBelong: groupBelong ?? this.groupBelong,
      isFavorite: isFavorite ?? this.isFavorite,
      cpuUsedPercent: cpuUsedPercent ?? this.cpuUsedPercent,
      cpuTotal: cpuTotal ?? this.cpuTotal,
      memoryTotal: memoryTotal ?? this.memoryTotal,
      memoryUsedPercent: memoryUsedPercent ?? this.memoryUsedPercent,
      description: description ?? this.description,
      systemVersion: systemVersion ?? this.systemVersion,
    );
  }

  Map<String, Object?> toJson() {
    return {
      'id': id,
      'name': name,
      'status': status,
      'version': version,
      'isXpack': isXpack,
      'isBound': isBound,
      'isLocal': isLocal,
      'address': address,
      'groupId': groupId,
      'groupBelong': groupBelong,
      'isFavorite': isFavorite,
      'cpuUsedPercent': cpuUsedPercent,
      'cpuTotal': cpuTotal,
      'memoryTotal': memoryTotal,
      'memoryUsedPercent': memoryUsedPercent,
      'description': description,
      'systemVersion': systemVersion,
    };
  }

  factory PanelNode.fromJson(Map<String, Object?> json) {
    return PanelNode(
      id: _stringValue(json['id']) ?? localName,
      name: _stringValue(json['name']) ?? '',
      status: _stringValue(json['status']) ?? '',
      version: _stringValue(json['version']) ?? '',
      isXpack: json['isXpack'] == true,
      isBound: json['isBound'] == true,
      isLocal:
          json['isLocal'] == true ||
          (_stringValue(json['name']) ?? '').toLowerCase() == localName,
      address:
          _stringValue(json['address']) ?? _stringValue(json['addr']) ?? '',
      groupId: _intValue(json['groupID'] ?? json['groupId']),
      groupBelong: _stringValue(json['groupBelong']) ?? '',
      isFavorite: json['isFavorite'] == true,
      cpuUsedPercent: _doubleValue(json['cpuUsedPercent']),
      cpuTotal: _intValue(json['cpuTotal']),
      memoryTotal: _intValue(json['memoryTotal']),
      memoryUsedPercent: _doubleValue(json['memoryUsedPercent']),
      description: _stringValue(json['description']) ?? '',
      systemVersion: _stringValue(json['systemVersion']) ?? '',
    );
  }

  /// 主节点兜底数据。1Panel 的节点列表偶尔不返回 local，UI 始终需要它。
  factory PanelNode.local({
    bool isPro = false,
    String version = '',
    double? cpuUsedPercent,
    int? cpuTotal,
    int? memoryTotal,
    double? memoryUsedPercent,
  }) {
    return PanelNode(
      id: localName,
      name: localName,
      status: 'Healthy',
      version: version,
      isXpack: isPro,
      isBound: isPro,
      isLocal: true,
      address: '127.0.0.1',
      cpuUsedPercent: cpuUsedPercent,
      cpuTotal: cpuTotal,
      memoryTotal: memoryTotal,
      memoryUsedPercent: memoryUsedPercent,
    );
  }

  /// 合并 `/core/nodes/list` 与 `/core/nodes/simple/all` 的结果。
  static List<PanelNode> mergeSimpleMetrics(
    List<PanelNode> nodes,
    List<PanelNode> simpleNodes,
  ) {
    if (simpleNodes.isEmpty) return nodes;
    final byName = <String, PanelNode>{
      for (final node in nodes) node.name: node,
    };
    for (final simple in simpleNodes) {
      if (simple.name.isEmpty) continue;
      final existing = byName[simple.name];
      byName[simple.name] = (existing ?? simple).copyWith(
        status: simple.status.isNotEmpty ? simple.status : existing?.status,
        version: simple.version.isNotEmpty ? simple.version : existing?.version,
        isXpack: simple.isXpack || (existing?.isXpack ?? false),
        isBound: simple.isBound || (existing?.isBound ?? false),
        isLocal:
            simple.isLocal ||
            (existing?.isLocal ?? false) ||
            simple.name == localName,
        address: simple.address.isNotEmpty ? simple.address : existing?.address,
        cpuUsedPercent: simple.cpuUsedPercent,
        cpuTotal: simple.cpuTotal,
        memoryTotal: simple.memoryTotal,
        memoryUsedPercent: simple.memoryUsedPercent,
        description: simple.description.isNotEmpty
            ? simple.description
            : existing?.description,
        systemVersion: simple.systemVersion.isNotEmpty
            ? simple.systemVersion
            : existing?.systemVersion,
      );
    }
    return byName.values.toList(growable: false);
  }

  /// 把节点列表规整为「确保有 local、按主节点优先、名称去重」。
  static List<PanelNode> normalize(
    List<PanelNode> nodes, {
    bool isPro = false,
  }) {
    final byName = <String, PanelNode>{};
    for (final node in nodes) {
      if (node.name.isEmpty) continue;
      byName[node.name] = node;
    }
    final local = byName[localName];
    if (local == null) {
      byName[localName] = PanelNode.local(isPro: isPro);
    } else if (isPro && !local.isXpack) {
      byName[localName] = local.copyWith(isXpack: true, isBound: true);
    }
    final result = byName.values.toList(growable: false)
      ..sort((a, b) {
        if (a.isLocal != b.isLocal) return a.isLocal ? -1 : 1;
        final groupCompare = (a.groupId ?? 0).compareTo(b.groupId ?? 0);
        if (groupCompare != 0) return groupCompare;
        return a.displayName.toLowerCase().compareTo(
          b.displayName.toLowerCase(),
        );
      });
    return result;
  }

  static String? _stringValue(Object? value) {
    if (value == null) return null;
    if (value is String) return value;
    return value.toString();
  }

  static int? _intValue(Object? value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    if (value is String) return int.tryParse(value);
    return null;
  }

  static double? _doubleValue(Object? value) {
    if (value is double) return value;
    if (value is num) return value.toDouble();
    if (value is String) return double.tryParse(value);
    return null;
  }
}
