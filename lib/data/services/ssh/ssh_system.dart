import 'ssh_connection.dart';

/// 一条 systemd 服务单元。
class SshServiceInfo {
  const SshServiceInfo({
    required this.unit,
    required this.loadState,
    required this.activeState,
    required this.subState,
    required this.description,
  });

  final String unit;
  final String loadState;
  final String activeState;
  final String subState;
  final String description;

  bool get isRunning => activeState == 'active' && subState == 'running';
  bool get isFailed => activeState == 'failed';
}

/// 一个正在监听的端口。
class SshPortInfo {
  const SshPortInfo({
    required this.protocol,
    required this.address,
    required this.port,
    required this.process,
    required this.pid,
  });

  final String protocol;
  final String address;
  final int port;
  final String process;
  final int? pid;

  String get endpoint =>
      address.contains(':') ? '[$address]:$port' : '$address:$port';
}

/// 一个本地文件系统。
class SshDiskInfo {
  const SshDiskInfo({
    required this.device,
    required this.mount,
    required this.totalBytes,
    required this.usedBytes,
    required this.availableBytes,
    required this.usedPercent,
  });

  final String device;
  final String mount;
  final int totalBytes;
  final int usedBytes;
  final int availableBytes;
  final double usedPercent;
}

/// 无法读取某项系统信息（命令不存在或平台不支持）。
class SshSystemUnsupportedException extends SshConnectionException {
  const SshSystemUnsupportedException(super.message, [super.cause]);
}

class SshSystemService {
  static const _servicesCommand = '''
if ! command -v systemctl >/dev/null 2>&1; then
  printf '__FT_NO_SYSTEMD__\\n' >&2
  exit 127
fi
systemctl list-units --type=service --all --no-pager --no-legend --plain
''';

  static const _portsCommand = '''
if command -v ss >/dev/null 2>&1; then
  ss -tulpnH
elif command -v netstat >/dev/null 2>&1; then
  netstat -tulpn
else
  printf '__FT_NO_PORT_TOOL__\\n' >&2
  exit 127
fi
''';

  static const _diskCommand = '''
if command -v df >/dev/null 2>&1; then
  df -Pk -x tmpfs -x devtmpfs -x squashfs 2>/dev/null || df -Pk
else
  printf '__FT_NO_DF__\\n' >&2
  exit 127
fi
''';

  Future<List<SshServiceInfo>> services(SshConnection connection) async {
    final result = await connection.run(
      _servicesCommand,
      timeout: const Duration(seconds: 20),
    );
    if (!result.isSuccess) {
      final detail = _detail(result);
      if (detail.contains('__FT_NO_SYSTEMD__')) {
        throw const SshSystemUnsupportedException('该主机未使用 systemd');
      }
      throw SshSystemUnsupportedException(detail.isEmpty ? '读取服务列表失败' : detail);
    }
    return parseSshServices(result.stdout);
  }

  Future<String> serviceStatus(
    SshConnection connection,
    SshServiceInfo service,
  ) async {
    final unit = _safeUnit(service.unit);
    final result = await connection.run(
      'systemctl status $unit --no-pager -l --full 2>&1',
      timeout: const Duration(seconds: 15),
    );
    return [
      result.stdout,
      result.stderr,
    ].where((value) => value.trim().isNotEmpty).join('\n').trim();
  }

  Future<String> serviceLogs(
    SshConnection connection,
    SshServiceInfo service, {
    int lines = 200,
  }) async {
    final unit = _safeUnit(service.unit);
    final tail = lines.clamp(20, 1000);
    final result = await connection.run(
      'journalctl -u $unit -n $tail --no-pager 2>&1',
      timeout: const Duration(seconds: 20),
    );
    final output = [
      result.stdout,
      result.stderr,
    ].where((value) => value.trim().isNotEmpty).join('\n').trim();
    if (!result.isSuccess && output.isEmpty) {
      throw const SshSystemUnsupportedException('读取服务日志失败');
    }
    return output;
  }

  Future<List<SshPortInfo>> listeningPorts(SshConnection connection) async {
    final result = await connection.run(
      _portsCommand,
      timeout: const Duration(seconds: 15),
    );
    if (!result.isSuccess) {
      final detail = _detail(result);
      if (detail.contains('__FT_NO_PORT_TOOL__')) {
        throw const SshSystemUnsupportedException('主机缺少 ss 或 netstat 命令');
      }
      throw SshSystemUnsupportedException(detail.isEmpty ? '读取监听端口失败' : detail);
    }
    return parseSshPorts(result.stdout);
  }

  Future<List<SshDiskInfo>> disks(SshConnection connection) async {
    final result = await connection.run(
      _diskCommand,
      timeout: const Duration(seconds: 15),
    );
    if (!result.isSuccess) {
      final detail = _detail(result);
      if (detail.contains('__FT_NO_DF__')) {
        throw const SshSystemUnsupportedException('主机缺少 df 命令');
      }
      throw SshSystemUnsupportedException(detail.isEmpty ? '读取磁盘信息失败' : detail);
    }
    return parseSshDisks(result.stdout);
  }

  String _safeUnit(String unit) {
    final value = unit.trim();
    if (!RegExp(r'^[A-Za-z0-9_.@:-]+\.service$').hasMatch(value)) {
      throw const SshSystemUnsupportedException('服务名称不合法');
    }
    return value;
  }

  String _detail(SshCommandResult result) {
    return result.stderr.trim().isEmpty
        ? result.stdout.trim()
        : result.stderr.trim();
  }
}

List<SshServiceInfo> parseSshServices(String output) {
  final services = <SshServiceInfo>[];
  for (var line in output.split('\n')) {
    line = line.trim();
    if (line.isEmpty || line.startsWith('UNIT ')) continue;
    if (line.startsWith('●')) line = line.substring(1).trim();
    final parts = line.split(RegExp(r'\s+'));
    if (parts.length < 4) continue;
    final unit = parts[0];
    if (!unit.endsWith('.service')) continue;
    services.add(
      SshServiceInfo(
        unit: unit,
        loadState: parts[1],
        activeState: parts[2],
        subState: parts[3],
        description: parts.length > 4 ? parts.sublist(4).join(' ') : '',
      ),
    );
  }
  services.sort((a, b) {
    final aFailed = a.isFailed ? 0 : 1;
    final bFailed = b.isFailed ? 0 : 1;
    if (aFailed != bFailed) return aFailed.compareTo(bFailed);
    final aRunning = a.isRunning ? 0 : 1;
    final bRunning = b.isRunning ? 0 : 1;
    if (aRunning != bRunning) return aRunning.compareTo(bRunning);
    return a.unit.compareTo(b.unit);
  });
  return services;
}

List<SshPortInfo> parseSshPorts(String output) {
  final ports = <SshPortInfo>[];
  final processPattern = RegExp(r'users:\(\("([^"]+)",pid=(\d+)');
  final netstatProcessPattern = RegExp(r'(\d+)/(\S+)$');
  for (final raw in output.split('\n')) {
    final line = raw.trim();
    if (line.isEmpty) continue;
    final parts = line.split(RegExp(r'\s+'));
    if (parts.length < 6) continue;
    final protocol = parts.first.toLowerCase();
    if (!const {'tcp', 'tcp6', 'udp', 'udp6'}.contains(protocol)) continue;

    // ss 的第二列是 LISTEN/UNCONN 等状态，netstat 的第二列是数字 Recv-Q。
    // 用这一点区分两种输出，避免把没有进程信息的 ss 行误当成 netstat 跳过，
    // 也兼容 netstat UDP 没有 State 列（只有 6 列）的情况。
    final isSs = int.tryParse(parts[1]) == null;
    String local;
    String? process;
    int? pid;
    if (isSs) {
      local = parts[4];
      final match = processPattern.firstMatch(line);
      process = match?.group(1);
      pid = int.tryParse(match?.group(2) ?? '');
    } else {
      local = parts[3];
      final match = netstatProcessPattern.firstMatch(parts.last);
      if (match != null) {
        pid = int.tryParse(match.group(1) ?? '');
        process = match.group(2);
      }
    }
    final separator = local.lastIndexOf(':');
    if (separator <= 0) continue;
    var address = local.substring(0, separator);
    // ss 对 IPv6 输出 "[::]:80"，去掉方括号后由 endpoint 统一补齐。
    if (address.startsWith('[') && address.endsWith(']')) {
      address = address.substring(1, address.length - 1);
    }
    final port = int.tryParse(local.substring(separator + 1));
    if (port == null) continue;
    ports.add(
      SshPortInfo(
        protocol: protocol.replaceAll('6', ''),
        address: address,
        port: port,
        process: process ?? '',
        pid: pid,
      ),
    );
  }
  ports.sort((a, b) => a.port.compareTo(b.port));
  return ports;
}

List<SshDiskInfo> parseSshDisks(String output) {
  final disks = <SshDiskInfo>[];
  for (final raw in output.split('\n')) {
    final parts = raw.trim().split(RegExp(r'\s+'));
    if (parts.length < 6) continue;
    final device = parts[0];
    if (device == 'Filesystem' ||
        device == 'tmpfs' ||
        device == 'devtmpfs' ||
        device == 'squashfs' ||
        device == 'none') {
      continue;
    }
    final totalKb = int.tryParse(parts[1]);
    final usedKb = int.tryParse(parts[2]);
    final availableKb = int.tryParse(parts[3]);
    if (totalKb == null || usedKb == null || availableKb == null) continue;
    final percent = double.tryParse(parts[4].replaceAll('%', ''));
    disks.add(
      SshDiskInfo(
        device: device,
        mount: parts.sublist(5).join(' '),
        totalBytes: totalKb * 1024,
        usedBytes: usedKb * 1024,
        availableBytes: availableKb * 1024,
        usedPercent: percent ?? (totalKb <= 0 ? 0 : usedKb / totalKb * 100),
      ),
    );
  }
  disks.sort((a, b) => a.mount.compareTo(b.mount));
  return disks;
}
