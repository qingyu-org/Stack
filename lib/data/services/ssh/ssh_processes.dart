import 'ssh_connection.dart';

/// 一条 SSH 进程信息。
class SshProcessInfo {
  const SshProcessInfo({
    required this.pid,
    required this.user,
    required this.stat,
    required this.cpuPercent,
    required this.memPercent,
    required this.rssBytes,
    required this.threads,
    required this.args,
  });

  final int pid;
  final String user;
  final String stat;
  final double cpuPercent;
  final double memPercent;
  final int rssBytes;
  final int threads;
  final String args;

  String get name {
    final command = args.trim().split(RegExp(r'\s+')).firstOrNull ?? '';
    if (command.isEmpty) return 'PID $pid';
    final basename = command.split('/').last.replaceAll(RegExp(r':$'), '');
    return basename.isEmpty ? command : basename;
  }

  String get status => switch (stat.isEmpty ? '' : stat[0]) {
    'R' => 'running',
    'S' || 'I' => 'sleep',
    'D' => 'wait',
    'T' => 'stop',
    'Z' => 'zombie',
    _ => 'unknown',
  };

  Map<String, dynamic> toProcessItemMap() => {
    'PID': pid,
    'name': name,
    'status': status,
    'cpuPercent': '${cpuPercent.toStringAsFixed(1)}%',
    'rss': _formatBytes(rssBytes),
    'username': user,
    'cpuValue': cpuPercent,
    'rssValue': rssBytes,
    'numThreads': threads < 0 ? null : threads,
  };

  static String _formatBytes(int bytes) {
    if (bytes <= 0) return '0 B';
    const units = ['B', 'KB', 'MB', 'GB', 'TB'];
    var value = bytes.toDouble();
    var unit = 0;
    while (value >= 1024 && unit < units.length - 1) {
      value /= 1024;
      unit++;
    }
    final digits = value >= 100 || unit == 0 ? 0 : 1;
    return '${value.toStringAsFixed(digits)} ${units[unit]}';
  }
}

class SshProcessService {
  static const _listCommand = '''
(ps -eo pid=,user=,stat=,pcpu=,pmem=,rss=,nlwp=,args= --sort=-pcpu 2>/dev/null || ps -eo pid,user,stat,pcpu,pmem,rss,nlwp,args 2>/dev/null) | head -n 600
''';

  Future<List<SshProcessInfo>> list(SshConnection connection) async {
    final result = await connection.run(_listCommand);
    return parseSshProcessList(result.stdout);
  }

  Future<void> kill(
    SshConnection connection,
    int pid, {
    bool force = false,
  }) async {
    if (pid <= 1) {
      throw const SshConnectionException('拒绝结束系统关键进程');
    }
    final signal = force ? 'KILL' : 'TERM';
    final result = await connection.run(
      'kill -$signal $pid 2>&1',
      timeout: const Duration(seconds: 8),
    );
    if (!result.isSuccess) {
      final detail = result.stderr.trim().isEmpty
          ? result.stdout.trim()
          : result.stderr.trim();
      throw SshConnectionException('结束进程失败', detail.isEmpty ? null : detail);
    }
  }
}

/// 解析 `ps` 输出，便于单元测试。
List<SshProcessInfo> parseSshProcessList(String output) {
  final items = <SshProcessInfo>[];
  for (final line in output.split('\n')) {
    final parts = line.trim().split(RegExp(r'\s+'));
    if (parts.length < 7) continue;
    final pid = int.tryParse(parts[0]);
    if (pid == null) continue;
    final rssKb = int.tryParse(parts[5]) ?? 0;
    items.add(
      SshProcessInfo(
        pid: pid,
        user: parts[1],
        stat: parts[2],
        cpuPercent: double.tryParse(parts[3]) ?? 0,
        memPercent: double.tryParse(parts[4]) ?? 0,
        rssBytes: rssKb * 1024,
        threads: int.tryParse(parts[6]) ?? 0,
        args: parts.length > 7 ? parts.sublist(7).join(' ') : '',
      ),
    );
  }
  return items;
}
