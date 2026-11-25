import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';

import 'app_user_agent.dart';

class OnePanelAuth {
  const OnePanelAuth._();

  static Future<Map<String, String>> signedHeaders(
    String apiKey, {
    String nodeName = '',
  }) async {
    final timestamp = (DateTime.now().millisecondsSinceEpoch ~/ 1000)
        .toString();
    final token = sign(apiKey, timestamp);
    final userAgent = await AppUserAgent.value;
    return {
      '1Panel-Token': token,
      '1Panel-Timestamp': timestamp,
      // 1Panel Web 端对主节点也会显式发送 `CurrentNode: local`。部分
      // XPack 接口（例如 WAF 攻击统计）缺少该头时会返回空数据，因此这里
      // 只要知道节点名就发送，不能把 local 当作「不发送」。
      if (nodeName.trim().isNotEmpty)
        'CurrentNode': Uri.encodeComponent(nodeName.trim()),
      HttpHeaders.userAgentHeader: userAgent,
    };
  }

  static String sign(String apiKey, String timestamp) {
    return md5.convert(utf8.encode('1panel$apiKey$timestamp')).toString();
  }
}
