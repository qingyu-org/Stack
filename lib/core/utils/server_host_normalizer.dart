/// 从用户输入中解析出的面板地址。
///
/// 支持：
/// - `https://[2409:8a00::1]:10000/path`
/// - `[2409:8a00::1]:10000`
/// - `2409:8a00::1`
/// - `panel.example.com:10000`
/// - `http://192.168.1.10:10000`
class ServerAddressInput {
  const ServerAddressInput({
    required this.host,
    this.port,
    this.isHttps,
    this.isPortInvalid = false,
  });

  /// 纯主机名或 IP（IPv6 不带方括号，便于持久化与比较）。
  final String host;

  /// 输入中显式写出的端口；没有则为 null。
  final int? port;

  /// 输入中显式写出的协议；没有则为 null。
  final bool? isHttps;

  /// 输入里带了端口段，但端口不是 1–65535 的整数。
  final bool isPortInvalid;

  bool get isEmpty => host.isEmpty;
}

final _schemePattern = RegExp(r'^([a-zA-Z][a-zA-Z0-9+.\-]*)://');
final _pathPattern = RegExp(r'[/?#]');

/// 解析用户输入的服务器地址，智能识别协议、IPv6 方括号与端口。
ServerAddressInput parseServerAddressInput(String input) {
  var value = input.trim().replaceAll('：', ':');
  if (value.isEmpty) {
    return const ServerAddressInput(host: '');
  }

  bool? isHttps;
  final schemeMatch = _schemePattern.firstMatch(value);
  if (schemeMatch != null) {
    final scheme = schemeMatch.group(1)!.toLowerCase();
    if (scheme == 'http') isHttps = false;
    if (scheme == 'https') isHttps = true;
    value = value.substring(schemeMatch.end);
  }
  if (value.startsWith('//')) value = value.substring(2);

  // 去掉路径、查询串与锚点后再解析主机/端口。
  value = value.split(_pathPattern).first.trim();
  if (value.isEmpty) {
    return ServerAddressInput(host: '', isHttps: isHttps);
  }

  // [IPv6]:port 或 [IPv6]
  if (value.startsWith('[')) {
    final bracketEnd = value.indexOf(']');
    if (bracketEnd > 0) {
      final host = value.substring(1, bracketEnd).trim();
      final rest = value.substring(bracketEnd + 1).trim();
      if (rest.startsWith(':')) {
        final portText = rest.substring(1).trim();
        final port = _parseValidPort(portText);
        return ServerAddressInput(
          host: host,
          port: port,
          isHttps: isHttps,
          isPortInvalid: port == null,
        );
      }
      return ServerAddressInput(host: host, isHttps: isHttps);
    }
  }

  // 未加方括号的 IPv6（两个以上冒号）整体视为主机，无法再拆分端口。
  if (_looksLikeIpv6(value)) {
    return ServerAddressInput(host: value, isHttps: isHttps);
  }

  final portSeparator = value.lastIndexOf(':');
  if (portSeparator > 0) {
    final portText = value.substring(portSeparator + 1).trim();
    final port = _parseValidPort(portText);
    return ServerAddressInput(
      host: value.substring(0, portSeparator).trim(),
      port: port,
      isHttps: isHttps,
      isPortInvalid: port == null,
    );
  }

  return ServerAddressInput(host: value, isHttps: isHttps);
}

int? _parseValidPort(String value) {
  final port = int.tryParse(value);
  if (port == null || port < 1 || port > 65535) return null;
  return port;
}

/// 仅取主机部分，供旧调用方使用。
String normalizeServerHostInput(String input) {
  return parseServerAddressInput(input).host;
}

/// 组装面板根地址。IPv6 字面量会自动补上方括号。
String buildServerBaseUrl({
  required String host,
  required int port,
  required bool isHttps,
}) {
  final scheme = isHttps ? 'https' : 'http';
  var value = host.trim();
  if (value.startsWith('[') && value.endsWith(']')) {
    value = value.substring(1, value.length - 1);
  }
  try {
    // Uri.host 会自动为 IPv6 添加方括号，也能正确处理域名与 IPv4。
    return Uri(scheme: scheme, host: value, port: port).toString();
  } on FormatException {
    // 非法主机名（例如误把端口写进域名的输入）不应让整个请求流程崩溃。
    return Uri(
      scheme: scheme,
      host: Uri.encodeComponent(value),
      port: port,
    ).toString();
  }
}

bool _looksLikeIpv6(String value) {
  if (!value.contains(':')) return false;
  if (value.contains('::')) return true;
  return ':'.allMatches(value).length >= 2;
}
