import 'dart:convert';

/// 结构化的虚拟化信息，用于在主机详情里显示为标签，而不是整段原始字符串。
class VirtualizationInfo {
  const VirtualizationInfo({this.system, this.role, this.extraTags = const []});

  /// 已格式化的虚拟化系统名称，例如 `KVM`、`VMware`。
  final String? system;

  /// 角色代码：`host` / `guest` / `container`。
  final String? role;

  /// 无法识别但较短的附加标签。
  final List<String> extraTags;

  bool get isEmpty => system == null && role == null && extraTags.isEmpty;
}

const _knownSystems = <String, String>{
  'kvm': 'KVM',
  'qemu': 'QEMU',
  'vmware': 'VMware',
  'esxi': 'VMware ESXi',
  'xen': 'Xen',
  'hyper-v': 'Hyper-V',
  'hyperv': 'Hyper-V',
  'virtualbox': 'VirtualBox',
  'vbox': 'VirtualBox',
  'parallels': 'Parallels',
  'bhyve': 'bhyve',
  'openvz': 'OpenVZ',
  'docker': 'Docker',
  'podman': 'Podman',
  'containerd': 'containerd',
  'lxd': 'LXD',
  'lxc': 'LXC',
  'incus': 'Incus',
  'wsl': 'WSL',
};

const _ignoredTokens = {
  'none',
  'unknown',
  'n/a',
  'na',
  'null',
  'false',
  'true',
  '0',
};

/// 把 1Panel 返回的 `virtualizationSystem` 规范成便于阅读的标签。
///
/// 某些面板版本可能返回 JSON 或 `kvm (host)` 这类组合字符串；这里统一
/// 拆成系统名与角色，避免把原始 JSON 直接铺在界面上。
VirtualizationInfo parseVirtualizationInfo(String raw) {
  final value = raw.trim();
  if (value.isEmpty) return const VirtualizationInfo();
  if (_ignoredTokens.contains(value.toLowerCase())) {
    return const VirtualizationInfo();
  }

  if (value.startsWith('{') || value.startsWith('[')) {
    final parsed = _parseJson(value);
    // 合法 JSON 但没有可识别字段时返回空信息，避免把原始 JSON 当成标签。
    if (parsed != null) return parsed;
  }

  return _parseText(value);
}

VirtualizationInfo? _parseJson(String raw) {
  Object? decoded;
  try {
    decoded = jsonDecode(raw);
  } catch (_) {
    return null;
  }

  String? system;
  String? role;
  final extras = <String>[];

  void visit(Object? node, {int depth = 0}) {
    if (depth > 4) return;
    if (node is Map) {
      for (final entry in node.entries) {
        final key = entry.key.toString().toLowerCase();
        final item = entry.value;
        if (item is String) {
          final text = item.trim();
          if (text.isEmpty || _ignoredTokens.contains(text.toLowerCase())) {
            continue;
          }
          if (system == null &&
              (key.contains('system') ||
                  key.contains('hypervisor') ||
                  key.contains('virtual') ||
                  key.contains('type') ||
                  key.contains('platform') ||
                  key.contains('engine') ||
                  key == 'name')) {
            system = _prettySystem(text) ?? _short(text);
          } else if (role == null &&
              (key.contains('role') ||
                  key.contains('mode') ||
                  key.contains('scope'))) {
            role = _roleCode(text);
          } else if (key != 'id' &&
              !key.contains('id') &&
              _isExtraKey(key) &&
              text.length <= 16) {
            extras.add(_short(text));
          }
        } else {
          visit(item, depth: depth + 1);
        }
      }
    } else if (node is List) {
      for (final item in node) {
        visit(item, depth: depth + 1);
      }
    }
  }

  visit(decoded);
  return VirtualizationInfo(
    system: system,
    role: role,
    extraTags: extras.take(2).toList(growable: false),
  );
}

VirtualizationInfo _parseText(String raw) {
  final lower = raw.toLowerCase();
  if (_ignoredTokens.contains(lower)) return const VirtualizationInfo();

  final role = _roleCode(lower);
  final segments = raw
      .split(RegExp(r'[,;|/]+'))
      .map((segment) => segment.trim())
      .where((segment) => segment.isNotEmpty)
      .toList(growable: false);

  String? system;
  final extras = <String>[];
  for (final segment in segments) {
    final pretty = _prettySystem(segment);
    if (pretty != null && system == null) {
      system = pretty;
      continue;
    }
    final withoutRole = segment
        .replaceAll(RegExp(r'\(.*?\)'), '')
        .replaceAll(
          RegExp(r'\b(host|guest|container)\b', caseSensitive: false),
          '',
        )
        .trim();
    if (withoutRole.isEmpty ||
        _ignoredTokens.contains(withoutRole.toLowerCase())) {
      continue;
    }
    if (system == null) {
      system = _short(withoutRole);
    } else if (extras.length < 2) {
      extras.add(_short(withoutRole));
    }
  }

  if (system == null && role == null) {
    // 没有可识别的关键词时，保留一个截断后的原始值。
    return VirtualizationInfo(system: _short(raw));
  }

  return VirtualizationInfo(system: system, role: role, extraTags: extras);
}

/// JSON 中值得作为附加标签展示的键，避免把无关字段铺到界面上。
bool _isExtraKey(String key) {
  return key.contains('version') ||
      key.contains('vendor') ||
      key.contains('manufactur') ||
      key.contains('product') ||
      key.contains('model') ||
      key.contains('brand') ||
      key.contains('arch') ||
      key.contains('release');
}

String? _prettySystem(String value) {
  final lower = value.toLowerCase();
  for (final entry in _knownSystems.entries) {
    if (lower.contains(entry.key)) return entry.value;
  }
  return null;
}

String? _roleCode(String value) {
  final lower = value.toLowerCase();
  if (lower.contains('host')) return 'host';
  if (lower.contains('container') ||
      lower.contains('docker') ||
      lower.contains('lxc') ||
      lower.contains('podman')) {
    return 'container';
  }
  if (lower.contains('guest') ||
      RegExp(r'\bvm\b').hasMatch(lower) ||
      lower.contains('virtual machine')) {
    return 'guest';
  }
  return null;
}

String _short(String value) {
  final singleLine = value.replaceAll(RegExp(r'\s+'), ' ').trim();
  if (singleLine.length <= 24) return singleLine;
  return '${singleLine.substring(0, 23)}…';
}
