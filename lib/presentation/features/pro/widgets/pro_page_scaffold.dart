import 'package:flutter/cupertino.dart';

import '../../../common/components/frosted_scaffold.dart' as app;

class ProPageScaffold extends StatelessWidget {
  const ProPageScaffold({
    super.key,
    required this.title,
    required this.children,
    this.onRefresh,
    this.trailingBuilder,
  });

  final String title;
  final List<Widget> children;
  final Future<void> Function()? onRefresh;
  final Widget Function(bool isDark, bool isOverlapping)? trailingBuilder;

  @override
  Widget build(BuildContext context) {
    return app.FrostedScaffold(
      title: title,
      largeTitle: true,
      showBackButton: true,
      fadeOutDistance: 41,
      trailingBuilder: trailingBuilder,
      body: CustomScrollView(
        physics: const AlwaysScrollableScrollPhysics(
          parent: BouncingScrollPhysics(),
        ),
        slivers: [
          SliverToBoxAdapter(
            child: SizedBox(
              height: app.FrostedScaffold.contentTopPadding(context) + 60,
            ),
          ),
          if (onRefresh != null)
            CupertinoSliverRefreshControl(onRefresh: onRefresh!),
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 40),
            sliver: SliverList.list(children: children),
          ),
        ],
      ),
    );
  }
}
