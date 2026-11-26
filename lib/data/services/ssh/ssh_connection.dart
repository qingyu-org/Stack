import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:dartssh2/dartssh2.dart';

import '../../../domain/entities/server.dart';
import '../../../domain/entities/ssh_credentials.dart';

/// SSH 连接或命令执行失败。
class SshConnectionException implements Exception {
  const SshConnectionException(this.message, [this.cause]);

  final String message;
  final Object? cause;

  @override
  String toString() {
    if (cause == null) return message;
    return '$message: $cause';
  }
}

/// 服务器主机密钥与首次连接时记录的不一致。
class SshHostKeyMismatchException extends SshConnectionException {
  const SshHostKeyMismatchException({
    required this.expected,
    required this.observed,
  }) : super('主机密钥已变化，连接已中止');

  final String expected;
  final String observed;
}

class SshCommandResult {
  const SshCommandResult({
    required this.stdout,
    required this.stderr,
    required this.exitCode,
  });

  final String stdout;
  final String stderr;
  final int? exitCode;

  bool get isSuccess => exitCode == null || exitCode == 0;
}

/// 把 dartssh2 的主机密钥信息格式化为可持久化的字符串。
///
/// dartssh2 传入的 [fingerprint] 已经是 UTF-8 编码的
/// `SHA256:<base64>` 文本（无填充），直接拼接即可，不能再做一次 base64。
String formatSshHostKeyFingerprint(String type, Uint8List fingerprint) {
  return '$type ${utf8.decode(fingerprint, allowMalformed: true)}';
}

/// 一条已建立的 SSH 连接。
///
/// 连接由 [SshConnectionManager] 复用；终端 shell 会保持连接活跃，
/// 普通命令与 SFTP 共用同一个底层会话。
class SshConnection {
  SshConnection._(this._client, this.server);

  final SSHClient _client;
  final Server server;
  SftpClient? _sftp;
  int _activeShells = 0;
  int _activeOperations = 0;

  bool get isClosed => _client.isClosed;

  bool get hasActiveShells => _activeShells > 0;

  bool get isBusy => _activeShells > 0 || _activeOperations > 0;

  /// 在命令或传输执行期间保持连接不被空闲回收。
  Future<T> trackOperation<T>(Future<T> Function() action) async {
    _activeOperations++;
    try {
      return await action();
    } finally {
      _activeOperations--;
    }
  }

  static Future<SshConnection> connect({
    required Server server,
    required SshCredentials credentials,
    Future<void> Function(String fingerprint)? onPinHostKey,
    Duration timeout = const Duration(seconds: 15),
  }) async {
    if (server.host.trim().isEmpty) {
      throw const SshConnectionException('服务器地址为空');
    }
    if (server.sshUsername.trim().isEmpty) {
      throw const SshConnectionException('SSH 用户名为空');
    }

    final expectedHostKey = server.sshHostKey.trim();
    String? observedHostKey;
    var hostKeyRejected = false;

    bool verifyHostKey(String type, Uint8List fingerprint) {
      observedHostKey = formatSshHostKeyFingerprint(type, fingerprint);
      if (expectedHostKey.isEmpty) return true;
      if (expectedHostKey != observedHostKey) {
        hostKeyRejected = true;
        return false;
      }
      return true;
    }

    List<SSHKeyPair>? identities;
    if (server.sshAuthType == SshAuthType.privateKey) {
      final pem = credentials.privateKey.trim();
      if (pem.isEmpty) {
        throw const SshConnectionException('未填写 SSH 私钥');
      }
      try {
        identities = SSHKeyPair.fromPem(
          pem,
          credentials.passphrase.isEmpty ? null : credentials.passphrase,
        );
      } catch (error) {
        throw SshConnectionException('SSH 私钥解析失败，请检查格式或私钥口令', error);
      }
    } else if (credentials.password.isEmpty) {
      throw const SshConnectionException('未填写 SSH 密码');
    }

    SSHSocket? socket;
    SSHClient? client;
    try {
      socket = await SSHSocket.connect(
        server.host,
        server.port,
        timeout: timeout,
      ).timeout(timeout);
      client = SSHClient(
        socket,
        username: server.sshUsername,
        onVerifyHostKey: verifyHostKey,
        identities: identities,
        onPasswordRequest: server.sshAuthType == SshAuthType.password
            ? () => credentials.password
            : null,
        // 不少服务器只提供 keyboard-interactive 登录，常见形式就是
        // 单个 Password: 提示；用同一密码完成认证。
        onUserInfoRequest: server.sshAuthType == SshAuthType.password
            ? (request) => [
                for (final prompt in request.prompts)
                  prompt.echo ? server.sshUsername : credentials.password,
              ]
            : null,
        keepAliveInterval: const Duration(seconds: 20),
        handshakeTimeout: timeout,
        authTimeout: timeout,
      );
      await client.authenticated.timeout(timeout);
    } on SshHostKeyMismatchException {
      rethrow;
    } catch (error) {
      client?.close();
      socket?.destroy();
      if (hostKeyRejected) {
        throw SshHostKeyMismatchException(
          expected: expectedHostKey,
          observed: observedHostKey ?? '',
        );
      }
      throw SshConnectionException('SSH 连接失败', error);
    }

    if (expectedHostKey.isEmpty &&
        observedHostKey != null &&
        onPinHostKey != null) {
      try {
        await onPinHostKey(observedHostKey!);
        server.sshHostKey = observedHostKey!;
      } catch (error) {
        await client.close();
        throw SshConnectionException('保存主机密钥失败', error);
      }
    }

    return SshConnection._(client, server);
  }

  Future<SshCommandResult> run(
    String command, {
    Duration timeout = const Duration(seconds: 12),
  }) {
    return trackOperation(() => _run(command, timeout: timeout));
  }

  Future<SshCommandResult> _run(
    String command, {
    Duration timeout = const Duration(seconds: 12),
  }) async {
    if (isClosed) {
      throw const SshConnectionException('SSH 连接已断开');
    }

    SSHSession? session;
    final stopwatch = Stopwatch()..start();
    Duration remaining() {
      final left = timeout - stopwatch.elapsed;
      return left.isNegative ? Duration.zero : left;
    }

    try {
      session = await _client.execute(command).timeout(remaining());
      final stdoutFuture = session.stdout
          .cast<List<int>>()
          .transform(const Utf8Decoder(allowMalformed: true))
          .join();
      final stderrFuture = session.stderr
          .cast<List<int>>()
          .transform(const Utf8Decoder(allowMalformed: true))
          .join();
      // 若 stdout 先报错，避免未被 await 的 stderr 再抛出未处理异常。
      unawaited(stderrFuture.catchError((Object _) => ''));
      final stdout = await stdoutFuture.timeout(remaining());
      final stderr = await stderrFuture.timeout(remaining());
      await session.done.timeout(remaining());
      return SshCommandResult(
        stdout: stdout,
        stderr: stderr,
        exitCode: session.exitCode,
      );
    } on TimeoutException catch (error) {
      session?.close();
      throw SshConnectionException('SSH 命令执行超时', error);
    } on SshConnectionException {
      rethrow;
    } catch (error) {
      session?.close();
      throw SshConnectionException('SSH 命令执行失败', error);
    }
  }

  Future<SSHSession> openShell({int columns = 80, int rows = 24}) async {
    if (isClosed) {
      throw const SshConnectionException('SSH 连接已断开');
    }
    final session = await _client.shell(
      pty: SSHPtyConfig(width: columns, height: rows),
    );
    _activeShells++;
    unawaited(
      session.done.whenComplete(() {
        _activeShells--;
      }),
    );
    return session;
  }

  Future<SftpClient> sftp() async {
    if (isClosed) {
      throw const SshConnectionException('SSH 连接已断开');
    }
    final existing = _sftp;
    if (existing != null) return existing;
    final client = await _client.sftp();
    _sftp = client;
    return client;
  }

  Future<void> close() async {
    if (isClosed) return;
    try {
      await _sftp?.close();
    } catch (_) {
      // 关闭过程中的错误不影响后续释放。
    }
    _sftp = null;
    try {
      await _client.close();
    } catch (_) {
      // 连接可能已被网络层终止；关闭失败无需再向调用方抛出。
    }
  }
}
