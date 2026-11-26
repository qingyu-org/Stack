import 'dart:convert';

/// SSH 认证方式。
enum SshAuthType {
  password('password'),
  privateKey('privateKey');

  const SshAuthType(this.storageName);

  final String storageName;

  static SshAuthType fromName(String? name) {
    return values.firstWhere(
      (type) => type.storageName == name,
      orElse: () => SshAuthType.password,
    );
  }
}

/// SSH 登录凭据。仅保存在本机安全存储中，不参与服务器同步。
class SshCredentials {
  const SshCredentials({
    this.password = '',
    this.privateKey = '',
    this.passphrase = '',
  });

  final String password;
  final String privateKey;
  final String passphrase;

  bool get isEmpty =>
      password.isEmpty && privateKey.isEmpty && passphrase.isEmpty;

  Map<String, Object?> toJson() => {
    'password': password,
    'privateKey': privateKey,
    'passphrase': passphrase,
  };

  static SshCredentials fromJson(Map<String, Object?> json) {
    return SshCredentials(
      password: json['password'] as String? ?? '',
      privateKey: json['privateKey'] as String? ?? '',
      passphrase: json['passphrase'] as String? ?? '',
    );
  }

  String toJsonString() => jsonEncode(toJson());

  static SshCredentials fromJsonString(String? raw) {
    if (raw == null || raw.isEmpty) return const SshCredentials();
    try {
      final decoded = jsonDecode(raw);
      if (decoded is Map) {
        return SshCredentials.fromJson(Map<String, Object?>.from(decoded));
      }
    } catch (_) {
      // 旧版本或损坏的数据按空凭据处理。
    }
    return const SshCredentials();
  }
}
