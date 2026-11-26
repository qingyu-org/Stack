import 'dart:convert';

import 'ssh_connection.dart';

/// 一台 SSH 主机上的 Docker 容器。
class SshContainer {
  const SshContainer({
    required this.id,
    required this.name,
    required this.image,
    required this.state,
    required this.status,
    required this.runningFor,
    required this.ports,
    required this.composeProject,
    required this.composeService,
  });

  final String id;
  final String name;
  final String image;
  final String state;
  final String status;
  final String runningFor;
  final String ports;
  final String composeProject;
  final String composeService;

  bool get isRunning => state.toLowerCase() == 'running';
  bool get isPaused => state.toLowerCase() == 'paused';

  /// Docker 生成的短 ID，便于展示。
  String get shortId => id.length > 12 ? id.substring(0, 12) : id;
}

/// Docker 不存在或当前 SSH 用户无权访问 Docker。
class SshDockerUnavailableException extends SshConnectionException {
  const SshDockerUnavailableException(super.message, [super.cause]);
}

class SshContainerService {
  static const _listCommand = '''
if ! command -v docker >/dev/null 2>&1; then
  printf '__FT_DOCKER_MISSING__\n' >&2
  exit 127
fi
docker ps -a --format '{{json .}}'
''';

  Future<List<SshContainer>> list(SshConnection connection) async {
    final result = await connection.run(
      _listCommand,
      timeout: const Duration(seconds: 20),
    );
    if (!result.isSuccess) {
      final detail = result.stderr.trim().isEmpty
          ? result.stdout.trim()
          : result.stderr.trim();
      if (detail.contains('__FT_DOCKER_MISSING__')) {
        throw const SshDockerUnavailableException('该主机未安装 Docker');
      }
      if (detail.toLowerCase().contains('permission denied') ||
          detail.toLowerCase().contains('got permission denied')) {
        throw SshDockerUnavailableException(
          '当前 SSH 用户无权访问 Docker，请将用户加入 docker 组或使用有权限的账号',
          detail,
        );
      }
      throw SshContainerException(detail.isEmpty ? '读取容器失败' : detail);
    }
    return parseSshContainerList(result.stdout);
  }

  Future<void> operate(
    SshConnection connection,
    SshContainer container,
    String action,
  ) async {
    if (!const {'start', 'stop', 'restart'}.contains(action)) {
      throw const SshContainerException('不支持的容器操作');
    }
    final reference = _safeReference(container.id);
    final result = await connection.run(
      'docker $action $reference',
      timeout: const Duration(seconds: 25),
    );
    if (!result.isSuccess) {
      final detail = result.stderr.trim().isEmpty
          ? result.stdout.trim()
          : result.stderr.trim();
      throw SshContainerException(detail.isEmpty ? '容器操作失败' : detail, detail);
    }
  }

  Future<String> logs(
    SshConnection connection,
    SshContainer container, {
    int lines = 300,
  }) async {
    final reference = _safeReference(container.id);
    final tail = lines.clamp(20, 2000);
    final result = await connection.run(
      'docker logs --tail $tail --timestamps $reference',
      timeout: const Duration(seconds: 20),
    );
    final output = [
      result.stdout,
      if (result.stderr.trim().isNotEmpty) result.stderr,
    ].join('\n').trim();
    if (!result.isSuccess && output.isEmpty) {
      throw const SshContainerException('读取容器日志失败');
    }
    return output;
  }

  String _safeReference(String value) {
    final reference = value.trim();
    if (!RegExp(r'^[A-Za-z0-9][A-Za-z0-9_.-]*$').hasMatch(reference)) {
      throw const SshContainerException('容器标识不合法');
    }
    return reference;
  }
}

class SshContainerException extends SshConnectionException {
  const SshContainerException(super.message, [super.cause]);
}

/// 解析 `docker ps --format '{{json .}}'` 输出，便于单元测试。
List<SshContainer> parseSshContainerList(String output) {
  final containers = <SshContainer>[];
  for (final line in output.split('\n')) {
    final raw = line.trim();
    if (!raw.startsWith('{')) continue;
    try {
      final json = jsonDecode(raw);
      if (json is! Map) continue;
      final labels = _labels(json['Labels']);
      final id = _text(json['ID']);
      if (id.isEmpty) continue;
      containers.add(
        SshContainer(
          id: id,
          name: _text(json['Names']).replaceFirst(RegExp(r'^/'), ''),
          image: _text(json['Image']),
          state: _text(json['State']),
          status: _text(json['Status']),
          runningFor: _text(json['RunningFor']),
          ports: _text(json['Ports']),
          composeProject: labels['com.docker.compose.project'] ?? '',
          composeService: labels['com.docker.compose.service'] ?? '',
        ),
      );
    } on FormatException {
      // Docker 偶尔会在 JSON 前输出警告，跳过无法解析的行。
    }
  }
  return containers;
}

String _text(Object? value) => value is String ? value : '';

Map<String, String> _labels(Object? value) {
  final raw = _text(value);
  if (raw.isEmpty) return const {};
  final labels = <String, String>{};
  for (final pair in raw.split(',')) {
    final index = pair.indexOf('=');
    if (index <= 0) continue;
    labels[pair.substring(0, index)] = pair.substring(index + 1);
  }
  return labels;
}
