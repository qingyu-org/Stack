import 'dart:async';

import '../../../domain/entities/dashboard.dart';
import '../../../domain/entities/server.dart';
import 'ssh_connection.dart';

/// 一次 SSH 指标采样结果。
class SshMetricsResult {
  const SshMetricsResult({
    required this.dashboard,
    required this.fetchMs,
    required this.rxBytesPerSecond,
    required this.txBytesPerSecond,
  });

  final Dashboard dashboard;
  final int fetchMs;
  final double rxBytesPerSecond;
  final double txBytesPerSecond;
}

class _CpuSample {
  const _CpuSample(this.total, this.idle);

  final int total;
  final int idle;
}

class _MetricsHistory {
  _CpuSample? cpu;
  int? lastRx;
  int? lastTx;
  DateTime? lastNetAt;
}

final Expando<_MetricsHistory> _histories = Expando<_MetricsHistory>();

/// 通过 SSH 执行一段标准 Linux 采集脚本，并转换成 App 统一的 Dashboard。
///
/// 只依赖 /proc、df、ps、uname 等基础命令，不要求安装任何服务端组件。
class SshMetricsCollector {
  static const _script = '''export LC_ALL=C
echo '__FT_OS__'
cat /etc/os-release 2>/dev/null || true
echo '__FT_SYS__'
uname -s 2>/dev/null || true
echo '__FT_KERNEL__'
uname -r 2>/dev/null || true
echo '__FT_ARCH__'
uname -m 2>/dev/null || true
echo '__FT_HOST__'
hostname 2>/dev/null || true
echo '__FT_IP__'
(hostname -I 2>/dev/null || hostname -i 2>/dev/null || true)
echo '__FT_NPROC__'
(getconf _NPROCESSORS_ONLN 2>/dev/null || nproc 2>/dev/null || echo 0)
echo '__FT_PCORES__'
awk -F: '/^cpu cores/{gsub(/ /,"",\$2); print \$2; exit}' /proc/cpuinfo 2>/dev/null || true
echo '__FT_CPUMODEL__'
awk -F: '/^model name/{sub(/^ +/,"",\$2); print \$2; exit}' /proc/cpuinfo 2>/dev/null || true
echo '__FT_CPUMHZ__'
awk -F: '/^cpu MHz/{sub(/^ +/,"",\$2); print \$2; exit}' /proc/cpuinfo 2>/dev/null || true
echo '__FT_STAT__'
grep '^cpu ' /proc/stat 2>/dev/null || true
sleep 0.2 2>/dev/null || true
echo '__FT_STAT2__'
grep '^cpu ' /proc/stat 2>/dev/null || true
echo '__FT_MEM__'
cat /proc/meminfo 2>/dev/null || true
echo '__FT_UPTIME__'
cat /proc/uptime 2>/dev/null || true
echo '__FT_LOAD__'
cat /proc/loadavg 2>/dev/null || true
echo '__FT_DISK__'
(df -Pk -x tmpfs -x devtmpfs -x squashfs 2>/dev/null || df -Pk 2>/dev/null || true)
echo '__FT_NET__'
cat /proc/net/dev 2>/dev/null || true
echo '__FT_PS__'
(ps -eo pid=,user=,stat=,pcpu=,pmem=,rss=,nlwp=,args= --sort=-pcpu 2>/dev/null || ps -eo pid,user,stat,pcpu,pmem,rss,nlwp,args 2>/dev/null || true) | head -n 8
echo '__FT_PSMEM__'
(ps -eo pid=,user=,stat=,pcpu=,pmem=,rss=,nlwp=,args= --sort=-rss 2>/dev/null || ps -eo pid,user,stat,pcpu,pmem,rss,nlwp,args 2>/dev/null || true) | head -n 6
echo '__FT_VIRT__'
(systemd-detect-virt 2>/dev/null || true)
echo '__FT_PROXY__'
(printenv http_proxy https_proxy all_proxy 2>/dev/null | head -n 1 || true)
echo '__FT_END__'
''';

  Future<SshMetricsResult> fetch({
    required SshConnection connection,
    required Server server,
  }) async {
    final stopWatch = Stopwatch()..start();
    final result = await connection.run(
      _script,
      timeout: const Duration(seconds: 15),
    );
    final sections = _parseSections(result.stdout);
    if (!sections.containsKey('end')) {
      final detail = result.stderr.trim();
      throw SshConnectionException(
        detail.isEmpty ? '无法读取主机指标，请确认目标是 Linux 系统' : detail,
      );
    }
    final system = _text(sections, 'sys').trim();
    if (system.isNotEmpty && system.toLowerCase() != 'linux') {
      throw SshConnectionException('目前仅支持 Linux 主机（检测到 $system）');
    }

    final history = _histories[connection] ??= _MetricsHistory();
    final dashboard = _buildDashboard(
      sections: sections,
      server: server,
      history: history,
    );
    final netRates = _consumeNetRate(sections, history);
    stopWatch.stop();

    return SshMetricsResult(
      dashboard: dashboard,
      fetchMs: stopWatch.elapsedMilliseconds,
      rxBytesPerSecond: netRates.$1,
      txBytesPerSecond: netRates.$2,
    );
  }

  Map<String, List<String>> _parseSections(String raw) {
    final sections = <String, List<String>>{};
    var current = '';
    for (final line in raw.split('\n')) {
      final match = RegExp(r'^__FT_([A-Z0-9]+)__$').firstMatch(line.trim());
      if (match != null) {
        current = match.group(1)!.toLowerCase();
        sections.putIfAbsent(current, () => []);
        continue;
      }
      if (current.isNotEmpty) sections[current]!.add(line);
    }
    return sections;
  }

  String _text(Map<String, List<String>> sections, String key) {
    return sections[key]?.join('\n').trim() ?? '';
  }

  Dashboard _buildDashboard({
    required Map<String, List<String>> sections,
    required Server server,
    required _MetricsHistory history,
  }) {
    final osRelease = _parseKeyValues(_text(sections, 'os'));
    final logicalCores = int.tryParse(_text(sections, 'nproc')) ?? 0;
    final physicalCores =
        int.tryParse(_text(sections, 'pcores')) ?? logicalCores;
    final cores = logicalCores > 0 ? logicalCores : physicalCores;
    final kernel = _text(sections, 'kernel');
    final arch = _text(sections, 'arch');
    final hostname = _text(sections, 'host');
    final ips = _text(sections, 'ip').split(RegExp(r'\s+'));
    final ipv4 = ips
        .map((value) => value.trim())
        .where((value) => value.isNotEmpty && !value.contains(':'))
        .firstOrNull;
    final pretty = osRelease['PRETTY_NAME'] ?? osRelease['NAME'] ?? '';
    final osName = osRelease['NAME'] ?? pretty;
    final platform = osRelease['ID'] ?? '';
    final platformFamily =
        osRelease['ID_LIKE'] ?? (platform.isEmpty ? '' : platform);
    final cpuPercent = _cpuPercent(sections, history);
    final memory = _memory(sections);
    final uptime = _uptimeSeconds(_text(sections, 'uptime'));
    final load = _loadAverage(_text(sections, 'load'));
    final disks = _disks(sections);
    final net = _network(sections);
    final cpuItems = _processes(sections['ps'] ?? const []);
    final memItems = _processes(sections['psmem'] ?? const []);
    final cpuInfo = _parseCpuInfo(sections);

    final base = DashboardBase(
      hostname: hostname.isEmpty ? server.host : hostname,
      ipV4Addr: ipv4 ?? server.host,
      os: osName,
      platform: platform,
      platformFamily: platformFamily,
      platformVersion: osRelease['VERSION_ID'] ?? '',
      prettyDistro: pretty,
      kernelArch: arch,
      kernelVersion: kernel,
      cpuCores: physicalCores,
      cpuLogicalCores: logicalCores,
      cpuMhz: cpuInfo.$2,
      cpuModelName: cpuInfo.$1,
      virtualizationSystem: _text(sections, 'virt'),
      systemProxy: _text(sections, 'proxy').split('\n').firstOrNull ?? '',
      websiteNumber: 0,
      databaseNumber: 0,
      cronjobNumber: 0,
      appInstalledNumber: 0,
      agentNumber: 0,
    );

    final current = DashboardCurrent(
      uptimeSeconds: uptime,
      timeSinceUptime: '',
      shotTime: DateTime.now().toIso8601String(),
      procs: load.$4,
      load1: load.$1,
      load5: load.$2,
      load15: load.$3,
      loadUsagePercent: cores <= 0
          ? 0
          : (load.$1 / cores * 100).clamp(0, 100).toDouble(),
      cpuTotal: cores,
      cpuUsed: cpuPercent / 100 * cores,
      cpuUsedPercent: cpuPercent,
      cpuPercent: const [],
      cpuDetailedPercent: const [],
      memoryTotal: memory.total,
      memoryUsed: memory.used,
      memoryFree: memory.free,
      memoryAvailable: memory.available,
      memoryCache: memory.cache,
      memoryUsedPercent: memory.total <= 0
          ? 0
          : memory.used / memory.total * 100,
      swapMemoryTotal: memory.swapTotal,
      swapMemoryUsed: memory.swapUsed,
      swapMemoryAvailable: memory.swapFree,
      swapMemoryUsedPercent: memory.swapTotal <= 0
          ? 0
          : memory.swapUsed / memory.swapTotal * 100,
      netBytesSent: net.$2,
      netBytesRecv: net.$1,
      ioCount: 0,
      ioReadBytes: 0,
      ioReadTime: 0,
      ioWriteBytes: 0,
      ioWriteTime: 0,
      disks: disks,
      topCpuItems: cpuItems.take(6).toList(growable: false),
      topMemItems: memItems.take(6).toList(growable: false),
      gpus: const [],
      xpus: const [],
    );

    return Dashboard(base: base, current: current);
  }

  (String, double) _parseCpuInfo(Map<String, List<String>> sections) {
    final model = _text(sections, 'cpumodel');
    final mhz = double.tryParse(_text(sections, 'cpumhz')) ?? 0;
    return (model, mhz);
  }

  Map<String, String> _parseKeyValues(String raw) {
    final values = <String, String>{};
    for (final line in raw.split('\n')) {
      final index = line.indexOf('=');
      if (index <= 0) continue;
      final key = line.substring(0, index).trim();
      final value = line.substring(index + 1).trim();
      values[key] = _unquote(value);
    }
    return values;
  }

  String _unquote(String value) {
    if (value.length >= 2) {
      final first = value[0];
      final last = value[value.length - 1];
      if ((first == '"' && last == '"') || (first == "'" && last == "'")) {
        return value.substring(1, value.length - 1);
      }
    }
    return value;
  }

  double _cpuPercent(
    Map<String, List<String>> sections,
    _MetricsHistory history,
  ) {
    final first = _cpuSample(_text(sections, 'stat'));
    final second = _cpuSample(_text(sections, 'stat2'));

    // 同一次采集内间隔 200ms 的两个样本能直接得到当前占用率，
    // 不需要等待下一次轮询，也避免首次连接显示开机以来的平均值。
    if (first != null && second != null) {
      final previous = history.cpu;
      history.cpu = second;
      final value = _cpuDelta(first, second);
      if (value != null) return value;
      if (previous != null) return _cpuDelta(previous, second) ?? 0;
      return 0;
    }

    final current = second ?? first;
    if (current == null) return 0;
    final previous = history.cpu;
    history.cpu = current;
    if (previous == null) return 0;
    return _cpuDelta(previous, current) ?? 0;
  }

  _CpuSample? _cpuSample(String raw) {
    final parts = raw
        .trim()
        .split(RegExp(r'\s+'))
        .skip(1)
        .map(int.tryParse)
        .whereType<int>()
        .toList();
    if (parts.length < 4) return null;
    final idle = parts[3] + (parts.length > 4 ? parts[4] : 0);
    final total = parts.take(8).fold<int>(0, (sum, value) => sum + value);
    return _CpuSample(total, idle);
  }

  double? _cpuDelta(_CpuSample previous, _CpuSample current) {
    final totalDelta = current.total - previous.total;
    final idleDelta = current.idle - previous.idle;
    if (totalDelta <= 0 || idleDelta < 0) return null;
    return ((totalDelta - idleDelta) / totalDelta * 100).clamp(0, 100);
  }

  ({
    int total,
    int used,
    int free,
    int available,
    int cache,
    int swapTotal,
    int swapUsed,
    int swapFree,
  })
  _memory(Map<String, List<String>> sections) {
    final values = <String, int>{};
    for (final line in (sections['mem'] ?? const [])) {
      final match = RegExp(r'^(\w+):\s+(\d+)').firstMatch(line.trim());
      if (match == null) continue;
      values[match.group(1)!] = int.parse(match.group(2)!) * 1024;
    }
    final total = values['MemTotal'] ?? 0;
    final free = values['MemFree'] ?? 0;
    final cache =
        (values['Buffers'] ?? 0) +
        (values['Cached'] ?? 0) +
        (values['SReclaimable'] ?? 0);
    final available = values['MemAvailable'] ?? (free + cache);
    final used = (total - available).clamp(0, total);
    final swapTotal = values['SwapTotal'] ?? 0;
    final swapFree = values['SwapFree'] ?? 0;
    return (
      total: total,
      used: used,
      free: free,
      available: available,
      cache: cache,
      swapTotal: swapTotal,
      swapUsed: (swapTotal - swapFree).clamp(0, swapTotal),
      swapFree: swapFree,
    );
  }

  int _uptimeSeconds(String raw) {
    final first = raw.split(RegExp(r'\s+')).firstOrNull;
    final seconds = double.tryParse(first ?? '');
    return seconds?.round() ?? 0;
  }

  (double, double, double, int) _loadAverage(String raw) {
    final parts = raw.trim().split(RegExp(r'\s+'));
    final load1 = double.tryParse(parts.elementAtOrNull(0) ?? '') ?? 0;
    final load5 = double.tryParse(parts.elementAtOrNull(1) ?? '') ?? 0;
    final load15 = double.tryParse(parts.elementAtOrNull(2) ?? '') ?? 0;
    var procs = 0;
    final processCount = parts.elementAtOrNull(3) ?? '';
    if (processCount.contains('/')) {
      procs = int.tryParse(processCount.split('/').last) ?? 0;
    }
    return (load1, load5, load15, procs);
  }

  List<DiskUsage> _disks(Map<String, List<String>> sections) {
    final disks = <DiskUsage>[];
    for (final line in (sections['disk'] ?? const [])) {
      final parts = line.trim().split(RegExp(r'\s+'));
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
      final percent = double.tryParse(parts[4].replaceAll('%', ''));
      if (totalKb == null || usedKb == null || availableKb == null) continue;
      final mount = parts.sublist(5).join(' ');
      disks.add(
        DiskUsage(
          path: mount,
          device: device,
          fsType: '',
          total: totalKb * 1024,
          used: usedKb * 1024,
          free: availableKb * 1024,
          usedPercent: percent ?? (totalKb <= 0 ? 0 : usedKb / totalKb * 100),
          inodesTotal: 0,
          inodesUsed: 0,
          inodesFree: 0,
          inodesUsedPercent: 0,
        ),
      );
    }
    disks.sort((a, b) {
      if (a.path == '/' && b.path != '/') return -1;
      if (b.path == '/' && a.path != '/') return 1;
      return a.path.compareTo(b.path);
    });
    return disks.take(8).toList(growable: false);
  }

  (int, int) _network(Map<String, List<String>> sections) {
    var rx = 0;
    var tx = 0;
    for (final line in (sections['net'] ?? const [])) {
      final index = line.lastIndexOf(':');
      if (index <= 0) continue;
      final iface = line.substring(0, index).trim();
      if (iface == 'lo') continue;
      final fields = line.substring(index + 1).trim().split(RegExp(r'\s+'));
      if (fields.length < 9) continue;
      rx += int.tryParse(fields[0]) ?? 0;
      tx += int.tryParse(fields[8]) ?? 0;
    }
    return (rx, tx);
  }

  (double, double) _consumeNetRate(
    Map<String, List<String>> sections,
    _MetricsHistory history,
  ) {
    final net = _network(sections);
    final now = DateTime.now();
    final previousAt = history.lastNetAt;
    final lastRx = history.lastRx;
    final lastTx = history.lastTx;
    history
      ..lastRx = net.$1
      ..lastTx = net.$2
      ..lastNetAt = now;

    if (previousAt == null || lastRx == null || lastTx == null) {
      return (0, 0);
    }
    final seconds = now.difference(previousAt).inMilliseconds / 1000;
    if (seconds < 0.2 || net.$1 < lastRx || net.$2 < lastTx) return (0, 0);
    return ((net.$1 - lastRx) / seconds, (net.$2 - lastTx) / seconds);
  }

  List<ProcessUsage> _processes(List<String> lines) {
    final items = <ProcessUsage>[];
    for (final line in lines) {
      final parts = line.trim().split(RegExp(r'\s+'));
      if (parts.length < 7) continue;
      final pid = int.tryParse(parts[0]);
      if (pid == null) continue;
      final user = parts[1];
      final cpu = double.tryParse(parts[3]) ?? 0;
      final rssKb = int.tryParse(parts[5]) ?? 0;
      final args = parts.length > 7 ? parts.sublist(7).join(' ') : '';
      final command = args.split(RegExp(r'\s+')).firstOrNull ?? '';
      final name = command.split('/').last;
      items.add(
        ProcessUsage(
          pid: pid,
          name: name.isEmpty ? 'PID $pid' : name,
          user: user,
          cmd: args,
          percent: cpu,
          memory: rssKb * 1024,
        ),
      );
    }
    return items;
  }

  String statusFromStat(String stat) {
    if (stat.isEmpty) return 'unknown';
    return switch (stat[0]) {
      'R' => 'running',
      'S' || 'I' => 'sleep',
      'D' => 'wait',
      'T' => 'stop',
      'Z' => 'zombie',
      _ => 'unknown',
    };
  }
}

/// 解析采集脚本输出，便于在没有真实 SSH 连接时做单元测试。
Dashboard parseSshMetricsOutput(String output, Server server) {
  final collector = SshMetricsCollector();
  final sections = collector._parseSections(output);
  return collector._buildDashboard(
    sections: sections,
    server: server,
    history: _MetricsHistory(),
  );
}
