import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../core/storage/storage_service.dart';
import '../../domain/entities/panel_node.dart';
import '../../domain/entities/panel_probe_result.dart';
import '../../domain/entities/panel_type.dart';
import '../../domain/entities/server.dart';
import '../../domain/entities/ssh_credentials.dart';
import '../../domain/repositories/server_repository.dart';

part 'server_repository_impl.g.dart';

/// [ServerRepository] 的本地 JSON + SecureStorage 实现。
class ServerRepositoryImpl implements ServerRepository {
  ServerRepositoryImpl(this._storage);

  final StorageService _storage;

  @override
  Future<List<Server>> list() => _storage.getServers();

  @override
  Future<Server?> find(int id) => _storage.getServer(id);

  @override
  Future<String?> getApiKey(int id) => _storage.getApiKey(id);

  @override
  Future<Server> add({
    String? name,
    required String host,
    required int port,
    PanelType panelType = PanelType.onePanel,
    required bool isHttps,
    required bool allowInsecureConnections,
    required String apiKey,
    PanelProbeResult? probe,
  }) async {
    final existing = await _storage.getServers();
    final now = DateTime.now();
    final server = Server()
      ..name = name
      ..host = host
      ..port = port
      ..panelType = panelType
      ..isHttps = isHttps
      ..allowInsecureConnections = allowInsecureConnections
      ..isPro = probe?.isPro ?? false
      ..nodes = probe?.nodes ?? [PanelNode.local()]
      ..proCheckedAt = probe == null ? null : now
      ..createdAt = now
      ..sortIndex = existing.length;

    await _storage.saveServer(server);
    await _storage.saveApiKey(server.id, apiKey);
    return server;
  }

  @override
  Future<SshCredentials?> getSshCredentials(int id) =>
      _storage.getSshCredentials(id);

  @override
  Future<void> saveSshCredentials(int id, SshCredentials credentials) =>
      _storage.saveSshCredentials(id, credentials);

  @override
  Future<void> deleteSshCredentials(int id) =>
      _storage.deleteSshCredentials(id);

  @override
  Future<Server> addSsh({
    String? name,
    required String host,
    required int port,
    required String username,
    required SshAuthType authType,
    required SshCredentials credentials,
    String hostKey = '',
  }) async {
    final existing = await _storage.getServers();
    final now = DateTime.now();
    final server = Server()
      ..name = name
      ..host = host
      ..port = port
      ..panelType = PanelType.bareMetal
      ..sshUsername = username
      ..sshAuthType = authType
      ..sshHostKey = hostKey
      ..createdAt = now
      ..sortIndex = existing.length;

    await _storage.saveServer(server);
    await _storage.saveSshCredentials(server.id, credentials);
    return server;
  }

  @override
  Future<void> update(Server server, {String? apiKey}) async {
    await _storage.saveServer(server);
    if (apiKey != null) {
      await _storage.saveApiKey(server.id, apiKey);
    }
  }

  @override
  Future<void> remove(int id) => _storage.deleteServer(id);

  @override
  Future<void> reorder(List<int> orderedIds) async {
    for (var i = 0; i < orderedIds.length; i++) {
      final s = await _storage.getServer(orderedIds[i]);
      if (s == null) continue;
      s.sortIndex = i;
      await _storage.saveServer(s);
    }
  }
}

/// 仓库 Provider（注入接口，便于测试替换）。
@Riverpod(keepAlive: true)
ServerRepository serverRepository(Ref ref) {
  return ServerRepositoryImpl(ref.watch(storageServiceProvider));
}
