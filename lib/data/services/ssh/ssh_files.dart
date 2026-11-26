import 'dart:io';
import 'dart:typed_data';

import 'package:dartssh2/dartssh2.dart';

import 'ssh_connection.dart';

class SshRemoteFile {
  const SshRemoteFile({
    required this.name,
    required this.path,
    required this.isDirectory,
    required this.isSymlink,
    required this.size,
    required this.modifiedAt,
    required this.permissions,
  });

  final String name;
  final String path;
  final bool isDirectory;
  final bool isSymlink;
  final int size;
  final DateTime? modifiedAt;
  final String permissions;
}

String sshJoinPath(String base, String name) {
  if (base.isEmpty || base == '.') return name;
  if (base == '/') return '/$name';
  return '${base.replaceAll(RegExp(r'/+$'), '')}/$name';
}

String sshParentPath(String path) {
  if (path.isEmpty || path == '/' || path == '.') return '/';
  final normalized = path.replaceAll(RegExp(r'/+$'), '');
  final index = normalized.lastIndexOf('/');
  if (index <= 0) return '/';
  return normalized.substring(0, index);
}

List<String> sshPathSegments(String path) {
  return path
      .split('/')
      .where((segment) => segment.isNotEmpty)
      .toList(growable: false);
}

/// 文件浏览器中新建/重命名时只接受单个文件名，防止跳出当前目录。
bool isValidSshEntryName(String name) {
  final value = name.trim();
  return value.isNotEmpty &&
      value != '.' &&
      value != '..' &&
      !value.contains('/') &&
      !value.contains(r'\');
}

class SshFileService {
  static const int maxEditBytes = 2 * 1024 * 1024;

  Future<String> home(SshConnection connection) async {
    try {
      final result = await connection.run(
        'pwd',
        timeout: const Duration(seconds: 8),
      );
      final paths = result.stdout
          .split('\n')
          .map((line) => line.trim())
          .where((line) => line.startsWith('/'))
          .toList(growable: false);
      if (paths.isNotEmpty) return paths.last;
    } catch (_) {
      // 无法读取时退回 SFTP 相对路径。
    }
    return '.';
  }

  Future<List<SshRemoteFile>> list(
    SshConnection connection,
    String path,
  ) async {
    final sftp = await connection.sftp();
    final entries = await sftp.listdir(path);
    final files = <SshRemoteFile>[];
    for (final entry in entries) {
      if (entry.filename == '.' || entry.filename == '..') continue;
      final attrs = entry.attr;
      final entryPath = sshJoinPath(path, entry.filename);
      var isDirectory = attrs.isDirectory;
      if (attrs.isSymbolicLink) {
        // listdir 只返回链接本身的属性，跟随一次以识别链接目录。
        try {
          isDirectory = (await sftp.stat(entryPath)).isDirectory;
        } catch (_) {
          // 失效链接按普通文件处理。
        }
      }
      files.add(
        SshRemoteFile(
          name: entry.filename,
          path: entryPath,
          isDirectory: isDirectory,
          isSymlink: attrs.isSymbolicLink,
          size: attrs.size ?? 0,
          modifiedAt: attrs.modifyTime == null
              ? null
              : DateTime.fromMillisecondsSinceEpoch(attrs.modifyTime! * 1000),
          permissions: _permissions(attrs.mode),
        ),
      );
    }
    files.sort((a, b) {
      if (a.isDirectory != b.isDirectory) return a.isDirectory ? -1 : 1;
      return a.name.toLowerCase().compareTo(b.name.toLowerCase());
    });
    return files;
  }

  Future<Uint8List> readBytes(
    SshConnection connection,
    String path, {
    int maxBytes = maxEditBytes,
  }) {
    return connection.trackOperation(() async {
      final sftp = await connection.sftp();
      final file = await sftp.open(path);
      try {
        final attrs = await file.stat();
        final size = attrs.size ?? 0;
        if (size > maxBytes) {
          throw const SshConnectionException('文件过大，无法在线编辑（上限 2 MB）');
        }
        return await file.readBytes();
      } finally {
        await file.close();
      }
    });
  }

  Future<void> writeBytes(
    SshConnection connection,
    String path,
    List<int> bytes,
  ) {
    return connection.trackOperation(() async {
      final sftp = await connection.sftp();
      final file = await sftp.open(
        path,
        mode:
            SftpFileOpenMode.write |
            SftpFileOpenMode.create |
            SftpFileOpenMode.truncate,
      );
      try {
        await file.writeBytes(Uint8List.fromList(bytes));
      } finally {
        await file.close();
      }
    });
  }

  Future<void> delete(SshConnection connection, SshRemoteFile file) async {
    final sftp = await connection.sftp();
    if (file.isDirectory) {
      await sftp.rmdir(file.path);
    } else {
      await sftp.remove(file.path);
    }
  }

  Future<void> rename(SshConnection connection, String from, String to) async {
    final sftp = await connection.sftp();
    await sftp.rename(from, to);
  }

  Future<void> createDirectory(SshConnection connection, String path) async {
    final sftp = await connection.sftp();
    await sftp.mkdir(path);
  }

  Future<void> downloadTo(
    SshConnection connection,
    String remotePath,
    String localPath,
  ) {
    return connection.trackOperation(() async {
      final sftp = await connection.sftp();
      final sink = File(localPath).openWrite();
      try {
        await sftp.download(remotePath, sink);
      } finally {
        await sink.close();
      }
    });
  }

  Future<void> uploadBytes(
    SshConnection connection,
    List<int> bytes,
    String remotePath,
  ) {
    return connection.trackOperation(() async {
      final sftp = await connection.sftp();
      final remote = await sftp.open(
        remotePath,
        mode:
            SftpFileOpenMode.write |
            SftpFileOpenMode.create |
            SftpFileOpenMode.truncate,
      );
      try {
        await remote.writeBytes(Uint8List.fromList(bytes));
      } finally {
        await remote.close();
      }
    });
  }

  Future<void> uploadFrom(
    SshConnection connection,
    String localPath,
    String remotePath,
  ) {
    return connection.trackOperation(() async {
      final localFile = File(localPath);
      if (!await localFile.exists()) {
        throw const SshConnectionException('本地文件不存在');
      }
      final sftp = await connection.sftp();
      final remote = await sftp.open(
        remotePath,
        mode:
            SftpFileOpenMode.write |
            SftpFileOpenMode.create |
            SftpFileOpenMode.truncate,
      );
      try {
        final writer = remote.write(
          localFile.openRead().map(Uint8List.fromList),
        );
        await writer.done;
      } finally {
        await remote.close();
      }
    });
  }

  String _permissions(SftpFileMode? mode) {
    if (mode == null) return '---------';
    final type = switch (mode.type) {
      SftpFileType.directory => 'd',
      SftpFileType.symbolicLink => 'l',
      _ => '-',
    };
    String flags(bool read, bool write, bool execute) {
      return '${read ? 'r' : '-'}${write ? 'w' : '-'}${execute ? 'x' : '-'}';
    }

    return '$type'
        '${flags(mode.userRead, mode.userWrite, mode.userExecute)}'
        '${flags(mode.groupRead, mode.groupWrite, mode.groupExecute)}'
        '${flags(mode.otherRead, mode.otherWrite, mode.otherExecute)}';
  }
}
