import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:mono_dash/data/services/ssh/ssh_connection.dart';
import 'package:mono_dash/data/services/ssh/ssh_files.dart';
import 'package:mono_dash/data/services/ssh/ssh_metrics.dart';
import 'package:mono_dash/data/services/ssh/ssh_processes.dart';
import 'package:mono_dash/domain/entities/panel_type.dart';
import 'package:mono_dash/domain/entities/server.dart';

void main() {
  group('parseSshMetricsOutput', () {
    final server = Server()
      ..host = 'fallback.example.com'
      ..port = 22
      ..panelType = PanelType.bareMetal;

    test('parses Linux metrics into the dashboard model', () {
      final dashboard = parseSshMetricsOutput(_sampleMetrics, server);
      final base = dashboard.base;
      final current = dashboard.current;

      expect(base.hostname, 'prod');
      expect(base.ipV4Addr, '10.0.0.5');
      expect(base.prettyDistro, 'Ubuntu 24.04 LTS');
      expect(base.kernelVersion, '6.8.0-45-generic');
      expect(base.kernelArch, 'x86_64');
      expect(base.cpuCores, 4);
      expect(base.cpuLogicalCores, 8);
      expect(base.cpuMhz, 3600);
      expect(base.cpuModelName, 'AMD Ryzen 7 5800X');
      expect(base.virtualizationSystem, 'kvm');

      expect(current.uptimeSeconds, 93784);
      expect(current.procs, 128);
      expect(current.load1, 0.42);
      expect(current.load5, 0.35);
      expect(current.load15, 0.30);
      expect(current.cpuUsedPercent, closeTo(15, 0.01));
      expect(current.memoryTotal, 16000000 * 1024);
      expect(current.memoryAvailable, 11000000 * 1024);
      expect(current.memoryUsedPercent, closeTo(31.25, 0.01));
      expect(current.swapMemoryTotal, 4000000 * 1024);
      expect(current.swapMemoryUsed, 1000000 * 1024);
      expect(current.netBytesRecv, 5000);
      expect(current.netBytesSent, 7000);
      expect(current.disks, hasLength(1));
      expect(current.disks.single.path, '/');
      expect(current.disks.single.usedPercent, 45);
      expect(current.topCpuItems.single.name, 'python3');
      expect(current.topCpuItems.single.pid, 123);
    });

    test('falls back to the configured host when hostname is missing', () {
      final dashboard = parseSshMetricsOutput(
        '__FT_OS__\nNAME="Ubuntu"\n__FT_END__',
        server,
      );
      expect(dashboard.base.hostname, 'fallback.example.com');
      expect(dashboard.base.ipV4Addr, 'fallback.example.com');
    });

    test('does not present the since-boot average as current CPU usage', () {
      final dashboard = parseSshMetricsOutput(
        '__FT_STAT__\n'
        'cpu  100 0 50 800 50 0 0 0 0 0\n'
        '__FT_END__',
        server,
      );
      expect(dashboard.current.cpuUsedPercent, 0);
    });
  });

  group('parseSshProcessList', () {
    test('parses ps rows and derives display names', () {
      final items = parseSshProcessList(
        '  1 root Ss 0.0 0.1 1234 1 /sbin/init\n'
        '  42 www-data S 2.5 1.2 45678 8 nginx: worker process\n',
      );

      expect(items, hasLength(2));
      expect(items.first.pid, 1);
      expect(items.first.name, 'init');
      expect(items.first.status, 'sleep');
      expect(items.last.name, 'nginx');
      expect(items.last.cpuPercent, 2.5);
      expect(items.last.rssBytes, 45678 * 1024);
      expect(items.last.threads, 8);
    });
  });

  group('host key fingerprint', () {
    test('keeps dartssh2 SHA256 text without double base64 encoding', () {
      final fingerprint = Uint8List.fromList(
        utf8.encode('SHA256:47DEQpj8HBSa+/TImW+5JCeuQeRkm5NMpJWZG3hSuFU'),
      );
      expect(
        formatSshHostKeyFingerprint('ssh-ed25519', fingerprint),
        'ssh-ed25519 SHA256:47DEQpj8HBSa+/TImW+5JCeuQeRkm5NMpJWZG3hSuFU',
      );
    });
  });

  group('SFTP path helpers', () {
    test('joins and walks paths', () {
      expect(sshJoinPath('/', 'etc'), '/etc');
      expect(sshJoinPath('/etc', 'nginx.conf'), '/etc/nginx.conf');
      expect(sshJoinPath('.', 'file.txt'), 'file.txt');
      expect(sshParentPath('/etc/nginx'), '/etc');
      expect(sshParentPath('/etc'), '/');
      expect(sshParentPath('/'), '/');
      expect(sshPathSegments('/var/log/nginx'), ['var', 'log', 'nginx']);
    });

    test('rejects names that could escape the current directory', () {
      expect(isValidSshEntryName('nginx.conf'), isTrue);
      expect(isValidSshEntryName('我的 文件'), isTrue);
      expect(isValidSshEntryName(''), isFalse);
      expect(isValidSshEntryName('   '), isFalse);
      expect(isValidSshEntryName('.'), isFalse);
      expect(isValidSshEntryName('..'), isFalse);
      expect(isValidSshEntryName('../other'), isFalse);
      expect(isValidSshEntryName('a/b'), isFalse);
      expect(isValidSshEntryName(r'a\b'), isFalse);
    });
  });
}

const _sampleMetrics = '''
__FT_OS__
NAME="Ubuntu"
PRETTY_NAME="Ubuntu 24.04 LTS"
ID=ubuntu
ID_LIKE=debian
VERSION_ID="24.04"
__FT_SYS__
Linux
__FT_KERNEL__
6.8.0-45-generic
__FT_ARCH__
x86_64
__FT_HOST__
prod
__FT_IP__
10.0.0.5 2409:8a00::1
__FT_NPROC__
8
__FT_PCORES__
4
__FT_CPUMODEL__
AMD Ryzen 7 5800X
__FT_CPUMHZ__
3600.000
__FT_STAT__
cpu  100 0 50 800 50 0 0 0 0 0
__FT_STAT2__
cpu  115 0 50 885 50 0 0 0 0 0
__FT_MEM__
MemTotal:       16000000 kB
MemFree:         2000000 kB
MemAvailable:   11000000 kB
Buffers:          500000 kB
Cached:          3000000 kB
SReclaimable:     400000 kB
SwapTotal:       4000000 kB
SwapFree:        3000000 kB
__FT_UPTIME__
93784.12 200000.00
__FT_LOAD__
0.42 0.35 0.30 2/128 9999
__FT_DISK__
Filesystem 1024-blocks Used Available Capacity Mounted on
/dev/sda1 100000000 45000000 55000000 45% /
tmpfs 1000 10 990 1% /run
__FT_NET__
Inter-| Receive | Transmit
 face |bytes packets errs drop fifo frame compressed multicast|bytes packets errs drop fifo colls carrier compressed
    lo: 1000 1 0 0 0 0 0 0 1000 1 0 0 0 0 0 0
  eth0: 5000 10 0 0 0 0 0 0 7000 12 0 0 0 0 0 0
__FT_PS__
  123 root S 1.5 2.0 10240 4 /usr/bin/python3 app.py
__FT_PSMEM__
  123 root S 1.5 2.0 10240 4 /usr/bin/python3 app.py
__FT_VIRT__
kvm
__FT_PROXY__

__FT_END__
''';
