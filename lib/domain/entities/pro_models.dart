/// 1Panel Pro（XPack）只读数据模型。
///
/// 这些字段来自 1Panel v2.5.x 官方 Web 端实际请求，解析时仍保持容错：
/// 缺失字段返回 0/空字符串，页面按空态处理。
library;

int proInt(Object? value) {
  if (value is int) return value;
  if (value is num) return value.toInt();
  if (value is String) return int.tryParse(value) ?? 0;
  return 0;
}

double proDouble(Object? value) {
  if (value is double) return value;
  if (value is num) return value.toDouble();
  if (value is String) return double.tryParse(value) ?? 0;
  return 0;
}

String proString(Object? value) => value?.toString() ?? '';

bool proBool(Object? value) {
  if (value is bool) return value;
  if (value is num) return value != 0;
  return proString(value).toLowerCase() == 'true';
}

List<Map<String, dynamic>> proMapList(Object? value) {
  if (value is! List) return const [];
  return [
    for (final item in value)
      if (item is Map) Map<String, dynamic>.from(item),
  ];
}

class WafStatus {
  const WafStatus({
    required this.healthy,
    required this.open,
    required this.openrestyVersion,
  });

  final bool healthy;
  final bool open;
  final String openrestyVersion;

  factory WafStatus.fromJson(Map<String, dynamic> json) {
    return WafStatus(
      healthy: proBool(json['healthy']),
      open: proBool(json['open']),
      openrestyVersion: proString(json['openrestyVersion']),
    );
  }
}

class WafTodayStat {
  const WafTodayStat({
    required this.reqCount,
    required this.attackCount,
    required this.count4xx,
    required this.count5xx,
  });

  final int reqCount;
  final int attackCount;
  final int count4xx;
  final int count5xx;

  factory WafTodayStat.fromJson(Map<String, dynamic> json) {
    return WafTodayStat(
      reqCount: proInt(json['reqCount']),
      attackCount: proInt(json['attackCount']),
      count4xx: proInt(json['count4xx']),
      count5xx: proInt(json['count5xx']),
    );
  }
}

class WafDailyPoint {
  const WafDailyPoint({
    required this.day,
    required this.reqCount,
    required this.attackCount,
  });

  final String day;
  final int reqCount;
  final int attackCount;

  factory WafDailyPoint.fromJson(Map<String, dynamic> json) {
    return WafDailyPoint(
      day: proString(json['day']),
      reqCount: proInt(json['reqCount']),
      attackCount: proInt(json['attackCount']),
    );
  }
}

class WafLocationItem {
  const WafLocationItem({required this.name, required this.value});

  final String name;
  final int value;

  factory WafLocationItem.fromJson(Map<String, dynamic> json) {
    return WafLocationItem(
      name: proString(json['name']),
      value: proInt(json['value']),
    );
  }
}

class WafLogEntry {
  const WafLogEntry({
    required this.id,
    required this.ip,
    required this.action,
    required this.uri,
    required this.execRule,
    required this.ruleType,
    required this.host,
    required this.localtime,
    required this.ipLocation,
    required this.isBlack,
    required this.isWhite,
    required this.isWhiteUrl,
    required this.matchValueContent,
    required this.method,
    required this.userAgent,
    required this.remotePort,
    required this.statusCode,
    this.nginxLog = '',
  });

  final int id;
  final String ip;
  final String action;
  final String uri;
  final String execRule;
  final String ruleType;
  final String host;
  final String localtime;
  final String ipLocation;
  final bool isBlack;
  final bool isWhite;
  final bool isWhiteUrl;
  final String matchValueContent;
  final String method;
  final String userAgent;
  final String remotePort;
  final String statusCode;
  final String nginxLog;

  bool get denied =>
      action.toLowerCase() == 'deny' || action.toLowerCase() == 'block';

  factory WafLogEntry.fromJson(Map<String, dynamic> json) {
    return WafLogEntry(
      id: proInt(json['id']),
      ip: proString(json['ip']),
      action: proString(json['action']),
      uri: proString(json['uri']),
      execRule: proString(json['execRule']),
      ruleType: proString(json['ruleType']),
      host: proString(json['host']),
      localtime: proString(json['localtime']),
      ipLocation: proString(json['ipLocation']),
      isBlack: proBool(json['isBlack']),
      isWhite: proBool(json['isWhite']),
      isWhiteUrl: proBool(json['isWhiteUrl']),
      matchValueContent: proString(json['matchValueContent']),
      method: proString(json['method']),
      userAgent: proString(json['userAgent']),
      remotePort: proString(json['remotePort']),
      statusCode: proString(json['statusCode']),
      nginxLog: proString(json['nginxLog']),
    );
  }
}

class WafLogPage {
  const WafLogPage({required this.total, required this.items});

  final int total;
  final List<WafLogEntry> items;

  factory WafLogPage.fromJson(Map<String, dynamic> json) {
    return WafLogPage(
      total: proInt(json['total']),
      items: [
        for (final item in proMapList(json['items']))
          WafLogEntry.fromJson(item),
      ],
    );
  }
}

class WafBlockEntry {
  const WafBlockEntry({
    required this.ip,
    required this.ipLocation,
    required this.execRule,
    required this.isBlock,
    required this.blockingTime,
    required this.createDate,
    required this.attackLogID,
  });

  final String ip;
  final String ipLocation;
  final String execRule;
  final int isBlock;
  final int blockingTime;
  final String createDate;
  final int attackLogID;

  bool get blocked => isBlock == 1;

  factory WafBlockEntry.fromJson(Map<String, dynamic> json) {
    return WafBlockEntry(
      ip: proString(json['ip']),
      ipLocation: proString(json['ipLocation']),
      execRule: proString(json['execRule']),
      isBlock: proInt(json['isBlock']),
      blockingTime: proInt(json['blockingTime']),
      createDate: proString(json['createDate']),
      attackLogID: proInt(json['attackLogID']),
    );
  }
}

class WafBlockPage {
  const WafBlockPage({required this.total, required this.items});

  final int total;
  final List<WafBlockEntry> items;

  factory WafBlockPage.fromJson(Map<String, dynamic> json) {
    return WafBlockPage(
      total: proInt(json['total']),
      items: [
        for (final item in proMapList(json['items']))
          WafBlockEntry.fromJson(item),
      ],
    );
  }
}

class MonitorStatus {
  const MonitorStatus({
    required this.healthy,
    required this.open,
    required this.openrestyVersion,
  });

  final bool healthy;
  final bool open;
  final String openrestyVersion;

  factory MonitorStatus.fromJson(Map<String, dynamic> json) {
    return MonitorStatus(
      healthy: proBool(json['healthy']),
      open: proBool(json['open']),
      openrestyVersion: proString(json['openrestyVersion']),
    );
  }
}

class MonitorTodayStat {
  const MonitorTodayStat({
    required this.pv,
    required this.uv,
    required this.ip,
    required this.flow,
    required this.spider,
    required this.req,
    required this.count4xx,
    required this.count5xx,
  });

  final int pv;
  final int uv;
  final int ip;
  final int flow;
  final int spider;
  final int req;
  final int count4xx;
  final int count5xx;

  factory MonitorTodayStat.fromJson(Map<String, dynamic> json) {
    return MonitorTodayStat(
      pv: proInt(json['pv']),
      uv: proInt(json['uv']),
      ip: proInt(json['ip']),
      flow: proInt(json['flow']),
      spider: proInt(json['spider']),
      req: proInt(json['req']),
      count4xx: proInt(json['count4xx']),
      count5xx: proInt(json['count5xx']),
    );
  }
}

class MonitorQps {
  const MonitorQps({required this.qps, required this.flow});

  final double qps;
  final double flow;

  factory MonitorQps.fromJson(Map<String, dynamic> json) {
    return MonitorQps(
      qps: proDouble(json['qps']),
      flow: proDouble(json['flow']),
    );
  }
}

class MonitorTrendPoint {
  const MonitorTrendPoint({
    required this.date,
    required this.pv,
    required this.uv,
    required this.flow,
    required this.req,
  });

  final String date;
  final int pv;
  final int uv;
  final int flow;
  final int req;

  factory MonitorTrendPoint.fromJson(Map<String, dynamic> json) {
    return MonitorTrendPoint(
      date: proString(json['date']),
      pv: proInt(json['pv']),
      uv: proInt(json['uv']),
      flow: proInt(json['flow']),
      req: proInt(json['req']),
    );
  }
}

class MonitorRankItem {
  const MonitorRankItem({
    required this.name,
    required this.count,
    required this.percent,
  });

  final String name;
  final int count;
  final double percent;

  factory MonitorRankItem.fromJson(Map<String, dynamic> json) {
    return MonitorRankItem(
      name: proString(json['name']),
      count: proInt(json['count']),
      percent: proDouble(json['percent']),
    );
  }
}

class MonitorLocationItem {
  const MonitorLocationItem({required this.name, required this.value});

  final String name;
  final int value;

  factory MonitorLocationItem.fromJson(Map<String, dynamic> json) {
    return MonitorLocationItem(
      name: proString(json['name']),
      value: proInt(json['value']),
    );
  }
}

class MonitorWebsite {
  const MonitorWebsite({
    required this.id,
    required this.primaryDomain,
    required this.alias,
    required this.remark,
  });

  final int id;
  final String primaryDomain;
  final String alias;
  final String remark;

  String get displayName {
    if (alias.trim().isNotEmpty && alias != primaryDomain) return alias;
    if (remark.trim().isNotEmpty) return remark;
    return primaryDomain;
  }

  factory MonitorWebsite.fromJson(Map<String, dynamic> json) {
    return MonitorWebsite(
      id: proInt(json['id']),
      primaryDomain: proString(json['primaryDomain']),
      alias: proString(json['alias']),
      remark: proString(json['remark']),
    );
  }
}

class MonitorLogEntry {
  const MonitorLogEntry({
    required this.id,
    required this.ip,
    required this.ipLocation,
    required this.host,
    required this.uri,
    required this.method,
    required this.referer,
    required this.userAgent,
    required this.spider,
    required this.statusCode,
    required this.requestTime,
    required this.sendBytes,
    required this.receiveBytes,
    required this.os,
    required this.browser,
    required this.device,
    required this.localtime,
    required this.remotePort,
    required this.contentType,
    required this.serverName,
  });

  final int id;
  final String ip;
  final String ipLocation;
  final String host;
  final String uri;
  final String method;
  final String referer;
  final String userAgent;
  final String spider;
  final int statusCode;
  final int requestTime;
  final int sendBytes;
  final int receiveBytes;
  final String os;
  final String browser;
  final String device;
  final String localtime;
  final String remotePort;
  final String contentType;
  final String serverName;

  factory MonitorLogEntry.fromJson(Map<String, dynamic> json) {
    return MonitorLogEntry(
      id: proInt(json['id']),
      ip: proString(json['ip']),
      ipLocation: proString(json['ipLocation']),
      host: proString(json['host']),
      uri: proString(json['uri']),
      method: proString(json['method']),
      referer: proString(json['referer']),
      userAgent: proString(json['userAgent']),
      spider: proString(json['spider']),
      statusCode: proInt(json['statusCode']),
      requestTime: proInt(json['requestTime']),
      sendBytes: proInt(json['sendBytes']),
      receiveBytes: proInt(json['receiveBytes']),
      os: proString(json['os']),
      browser: proString(json['browser']),
      device: proString(json['device']),
      localtime: proString(json['localtime']),
      remotePort: proString(json['remotePort']),
      contentType: proString(json['contentType']),
      serverName: proString(json['serverName']),
    );
  }
}

class MonitorLogPage {
  const MonitorLogPage({required this.total, required this.items});

  final int total;
  final List<MonitorLogEntry> items;

  factory MonitorLogPage.fromJson(Map<String, dynamic> json) {
    return MonitorLogPage(
      total: proInt(json['total']),
      items: [
        for (final item in proMapList(json['items']))
          MonitorLogEntry.fromJson(item),
      ],
    );
  }
}
