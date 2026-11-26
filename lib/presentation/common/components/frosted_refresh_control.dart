import 'package:flutter/cupertino.dart';

import 'frosted_scaffold.dart';

/// 顶部导航栏留白 + 下拉刷新控件。
///
/// 必须放在列表内容之前：刷新指示器会在留白下方展开，从而显示在
/// 毛玻璃导航栏的下方。若把控件放在留白之前，指示器会被导航栏遮住，
/// 只留下一个空白区域。
class FrostedRefreshControl extends StatelessWidget {
  const FrostedRefreshControl({
    super.key,
    required this.onRefresh,
    this.topSpacing,
  });

  final Future<void> Function() onRefresh;

  /// 顶部留白高度；默认使用 [FrostedScaffold.contentTopPadding]。
  final double? topSpacing;

  @override
  Widget build(BuildContext context) {
    return SliverMainAxisGroup(
      slivers: [
        SliverToBoxAdapter(
          child: SizedBox(
            height: topSpacing ?? FrostedScaffold.contentTopPadding(context),
          ),
        ),
        CupertinoSliverRefreshControl(onRefresh: onRefresh),
      ],
    );
  }
}
