import 'package:flutter/cupertino.dart';
import 'package:mono_dash/core/utils/app_haptics.dart';

/// 滑动操作按钮的数据。
class SwipeAction {
  const SwipeAction({
    required this.label,
    required this.icon,
    required this.color,
    required this.onTap,
    this.foregroundColor = CupertinoColors.white,
  });

  final String label;
  final IconData icon;
  final Color color;
  final Color foregroundColor;
  final VoidCallback onTap;
}

/// 列表行左滑显示一列圆形操作按钮。
///
/// - 只接管水平拖拽，纵向滚动仍交给外层列表；
/// - 松手后按位移与速度吸附到打开/关闭；
/// - 不使用整块彩色背景，避免破坏卡片的圆角；圆形按钮带文字标签，
///   颜色与图标对应操作。
class SwipeActionCell extends StatefulWidget {
  const SwipeActionCell({
    super.key,
    required this.child,
    required this.actions,
    this.actionWidth = 58,
  }) : assert(actions.length > 0);

  final Widget child;
  final List<SwipeAction> actions;

  /// 右侧操作栏宽度，也是卡片完全打开时的位移距离。
  final double actionWidth;

  @override
  State<SwipeActionCell> createState() => _SwipeActionCellState();
}

class _SwipeActionCellState extends State<SwipeActionCell>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _animation;

  double get _maxOffset => widget.actionWidth;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 220),
      value: 0,
    );
    _animation = CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOutCubic,
      reverseCurve: Curves.easeInCubic,
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _open() {
    AppHaptics.selectionClick();
    _controller.forward();
  }

  void _close() {
    _controller.reverse();
  }

  void _handleDragStart(DragStartDetails details) {
    _controller.stop();
  }

  void _handleDragUpdate(DragUpdateDetails details) {
    if (_maxOffset <= 0) return;
    final delta = details.primaryDelta ?? 0;
    _controller.value = (_controller.value - delta / _maxOffset).clamp(
      0.0,
      1.0,
    );
  }

  void _handleDragEnd(DragEndDetails details) {
    final velocity = details.primaryVelocity ?? 0;
    final shouldOpen =
        velocity < -250 || (velocity < 250 && _controller.value > 0.3);
    if (shouldOpen) {
      _open();
    } else {
      _close();
    }
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _animation,
      builder: (context, child) {
        final offset = _maxOffset * _animation.value;
        final isOpen = _animation.value > 0.02;
        return Stack(
          children: [
            Positioned.fill(
              child: IgnorePointer(
                ignoring: !isOpen,
                child: Align(
                  alignment: Alignment.centerRight,
                  child: SizedBox(
                    width: widget.actionWidth,
                    child: LayoutBuilder(
                      builder: (context, constraints) {
                        final count = widget.actions.length;
                        final available = constraints.maxHeight;
                        // 间距同时受卡片高度约束，动作数量很多时也不会把
                        // 整列撑出卡片。
                        final idealGap = available >= 140 ? 10.0 : 8.0;
                        final gapLimit = count > 1
                            ? available / (count * 4)
                            : 0.0;
                        final gap = available >= 40
                            ? (idealGap < gapLimit ? idealGap : gapLimit)
                            : 0.0;
                        // 卡片高度不足时自动缩小按钮，避免竖向排布溢出。
                        final perSlot = available.isFinite
                            ? (available - gap * (count - 1)) / count
                            : 56.0;
                        final showLabel = perSlot >= 46;
                        final size = showLabel
                            ? (perSlot - 14).clamp(24.0, 40.0)
                            : (perSlot - 2).clamp(0.0, 40.0);

                        return Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            for (var i = 0; i < count; i++) ...[
                              if (i > 0) SizedBox(height: gap),
                              _SwipeActionButton(
                                action: widget.actions[i],
                                size: size,
                                showLabel: showLabel,
                                onTap: () {
                                  AppHaptics.lightImpact();
                                  _close();
                                  widget.actions[i].onTap();
                                },
                              ),
                            ],
                          ],
                        );
                      },
                    ),
                  ),
                ),
              ),
            ),
            Transform.translate(
              key: const ValueKey('swipe-action-content'),
              offset: Offset(-offset, 0),
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onHorizontalDragStart: _handleDragStart,
                onHorizontalDragUpdate: _handleDragUpdate,
                onHorizontalDragEnd: _handleDragEnd,
                child: child,
              ),
            ),
            // 打开时轻点卡片本身先收起，而不是触发卡片内容。
            if (isOpen)
              Positioned(
                left: 0,
                right: offset,
                top: 0,
                bottom: 0,
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: _close,
                  onHorizontalDragStart: _handleDragStart,
                  onHorizontalDragUpdate: _handleDragUpdate,
                  onHorizontalDragEnd: _handleDragEnd,
                ),
              ),
          ],
        );
      },
      child: widget.child,
    );
  }
}

class _SwipeActionButton extends StatelessWidget {
  const _SwipeActionButton({
    required this.action,
    required this.onTap,
    required this.size,
    required this.showLabel,
  });

  final SwipeAction action;
  final VoidCallback onTap;
  final double size;
  final bool showLabel;

  @override
  Widget build(BuildContext context) {
    final labelStyle = TextStyle(
      fontSize: size < 34 ? 8.5 : 9.5,
      fontWeight: FontWeight.w600,
      color: action.color,
      height: 1.1,
      decoration: TextDecoration.none,
    );

    return Semantics(
      button: true,
      label: action.label,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: size,
              height: size,
              decoration: BoxDecoration(
                color: action.color,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: CupertinoColors.black.withValues(alpha: 0.14),
                    blurRadius: 6,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Icon(
                action.icon,
                size: size * 0.45,
                color: action.foregroundColor,
              ),
            ),
            if (showLabel) ...[
              const SizedBox(height: 3),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 1),
                child: Text(
                  action.label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                  style: labelStyle,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
