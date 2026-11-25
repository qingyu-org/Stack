import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:dio/dio.dart';

import '../../utils/app_logger.dart';

/// 1Panel MD5 鉴权拦截器。
///
/// 规则：`MD5("1panel" + apiKey + unixSecondTimestamp)`
/// 注意：时间戳必须是**秒级**，毫秒级会 401。
class AuthInterceptor extends Interceptor {
  AuthInterceptor(this._apiKey, {String nodeName = ''}) : _nodeName = nodeName;

  static const _tag = 'network.auth';
  static const _prefix = '1panel';
  static const _headerToken = '1Panel-Token';
  static const _headerTimestamp = '1Panel-Timestamp';
  static const _headerNode = 'CurrentNode';

  String _apiKey;
  String _nodeName;

  /// 切换 API Key（服务器切换时调用）。
  void updateApiKey(String apiKey) {
    _apiKey = apiKey;
  }

  /// 切换节点（1Panel 专业版多机管理）。
  ///
  /// 1Panel 主面板代理 `/api/v2/*`（`/core/*` 除外）时读取 `CurrentNode`
  /// 头，并按 URL 解码后的节点名把请求转发到对应子节点。
  void updateNodeName(String nodeName) {
    _nodeName = nodeName;
  }

  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    if (_apiKey.isEmpty) {
      AppLogger.w(_tag, 'API Key 为空，跳过鉴权');
      return handler.next(options);
    }

    final timestamp = (DateTime.now().millisecondsSinceEpoch ~/ 1000)
        .toString();
    final token = _sign(_apiKey, timestamp);

    options.headers[_headerToken] = token;
    options.headers[_headerTimestamp] = timestamp;

    // 节点路由统一由 CurrentNode 头决定。业务层历史代码里遗留的
    // `operateNode=local` 会优先于请求头，导致切到子节点后仍访问主节点。
    options.queryParameters.remove('operateNode');

    final nodeName = _nodeName.trim();
    if (nodeName.isNotEmpty) {
      // 主节点也要显式发送 `local`：1Panel Web 端同样如此，部分 XPack
      // 接口（WAF 攻击统计等）缺少该头会返回空数据。
      options.headers[_headerNode] = Uri.encodeComponent(nodeName);
    } else {
      options.headers.remove(_headerNode);
    }
    handler.next(options);
  }

  static String _sign(String apiKey, String timestamp) {
    final raw = '$_prefix$apiKey$timestamp';
    return md5.convert(utf8.encode(raw)).toString();
  }
}
