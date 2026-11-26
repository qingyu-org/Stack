/// 面板类型。
///
/// 目前只实现 1Panel；宝塔与「纯服务器（SSH）」先作为占位类型保留，
/// 以便后续接入时不需要迁移已保存的数据。
enum PanelType {
  onePanel('1panel', supported: true),
  baota('baota', supported: false),
  bareMetal('baremetal', supported: false);

  const PanelType(this.storageName, {required this.supported});

  final String storageName;

  /// 当前版本是否已经实现该类型的连接逻辑。
  final bool supported;

  static PanelType fromName(String? name) {
    return values.firstWhere(
      (type) => type.storageName == name,
      orElse: () => PanelType.onePanel,
    );
  }
}
