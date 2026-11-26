import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../domain/repositories/server_repository.dart';
import '../../repositories_impl/server_repository_impl.dart';
import 'ssh_connection.dart';

/// 按服务器复用 SSH 连接，并在空闲一段时间后自动释放。
class SshConnectionManager {
  SshConnectionManager(this._repository);

  static const _idleTimeout = Duration(minutes: 10);

  final ServerRepository _repository;
  final Map<int, SshConnection> _connections = {};
  final Map<int, Future<SshConnection>> _connecting = {};
  final Map<int, Timer> _idleTimers = {};
  final Map<int, int> _generations = {};

  Future<SshConnection> get(int serverId) async {
    _resetIdleTimer(serverId);

    final current = _connections[serverId];
    if (current != null && !current.isClosed) return current;
    if (current != null) {
      _connections.remove(serverId);
      unawaited(current.close());
    }

    final generation = _generations[serverId] ?? 0;
    var future = _connecting[serverId];
    if (future == null) {
      future = _connect(serverId);
      _connecting[serverId] = future;
    }
    try {
      final connection = await future;
      if (generation != (_generations[serverId] ?? 0)) {
        unawaited(connection.close());
        throw const SshConnectionException('SSH 连接已失效，请重试');
      }
      _connections[serverId] = connection;
      _resetIdleTimer(serverId);
      return connection;
    } finally {
      if (identical(_connecting[serverId], future)) {
        _connecting.remove(serverId);
      }
    }
  }

  Future<SshConnection> _connect(int serverId) async {
    final server = await _repository.find(serverId);
    if (server == null) {
      throw const SshConnectionException('服务器不存在');
    }
    if (!server.isSshServer) {
      throw const SshConnectionException('该服务器不是 SSH 服务器');
    }
    final credentials = await _repository.getSshCredentials(serverId);
    if (credentials == null) {
      throw const SshConnectionException('未找到 SSH 登录凭据，请重新编辑服务器');
    }

    return SshConnection.connect(
      server: server,
      credentials: credentials,
      onPinHostKey: (fingerprint) async {
        server.sshHostKey = fingerprint;
        await _repository.update(server);
      },
    );
  }

  /// 主动断开并清空缓存，用于编辑/删除服务器后强制重连。
  void invalidate(int serverId) {
    _generations[serverId] = (_generations[serverId] ?? 0) + 1;
    _idleTimers.remove(serverId)?.cancel();
    _connecting.remove(serverId);
    final connection = _connections.remove(serverId);
    if (connection != null) unawaited(connection.close());
  }

  /// 读请求失败后尝试丢弃可能已失效的连接；终端正在使用时保持连接。
  bool invalidateIfIdle(int serverId) {
    final connection = _connections[serverId];
    if (connection == null || connection.isBusy) return false;
    invalidate(serverId);
    return true;
  }

  void _resetIdleTimer(int serverId) {
    _idleTimers.remove(serverId)?.cancel();
    _idleTimers[serverId] = Timer(_idleTimeout, () {
      final connection = _connections[serverId];
      if (connection == null) {
        _idleTimers.remove(serverId);
        return;
      }
      if (connection.isBusy) {
        _resetIdleTimer(serverId);
        return;
      }
      _connections.remove(serverId);
      _idleTimers.remove(serverId);
      unawaited(connection.close());
    });
  }

  void dispose() {
    for (final timer in _idleTimers.values) {
      timer.cancel();
    }
    _idleTimers.clear();
    for (final connection in _connections.values) {
      unawaited(connection.close());
    }
    _connections.clear();
  }
}

/// 全局 SSH 连接管理器。
final sshConnectionManagerProvider = Provider<SshConnectionManager>((ref) {
  final manager = SshConnectionManager(ref.watch(serverRepositoryProvider));
  ref.onDispose(manager.dispose);
  return manager;
});
