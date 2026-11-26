import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';

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

/// 列表行左滑显示操作按钮。
///
/// - 只接管水平拖拽，纵向滚动仍交给外层列表；
/// - 松手后按位移与速度吸附到打开/关闭；
/// - 性能开销低：仅一个 [Transform.translate] 与若干静态色块，无模糊。
class SwipeActionCell extends StatefulWidget {
  const SwipeActionCell({
    super.key,
    required this.child,
    required this.actions,
    this.actionWidth = 76,
    this.borderRadius = const BorderRadius.all(Radius.circular(16)),
  }) : assert(actions.length > 0);

  final Widget child;
  final List<SwipeAction> actions;
  final double actionWidth;
  final BorderRadius borderRadius;

  @override
  State<SwipeActionCell> createState() => _SwipeActionCellState();
}

class _SwipeActionCellState extends State<SwipeActionCell>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _animation;

  double get _maxOffset => widget.actionWidth * widget.actions.length;

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
    HapticFeedback.selectionClick();
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
        velocity < -250 || (velocity < 250 && _controller.value > 0.35);
    if (shouldOpen) {
      _open();
    } else {
      _close();
    }
  }

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: widget.borderRadius,
      child: AnimatedBuilder(
        animation: _animation,
        builder: (context, child) {
          final offset = _maxOffset * _animation.value;
          final isOpen = _animation.value > 0.02;
          return Stack(
            children: [
              Positioned.fill(
                child: IgnorePointer(
                  ignoring: !isOpen,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      for (final action in widget.actions)
                        _SwipeActionButton(
                          action: action,
                          width: widget.actionWidth,
                          onTap: () {
                            HapticFeedback.lightImpact();
                            _close();
                            action.onTap();
                          },
                        ),
                    ],
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
      ),
    );
  }
}

class _SwipeActionButton extends StatelessWidget {
  const _SwipeActionButton({
    required this.action,
    required this.width,
    required this.onTap,
  });

  final SwipeAction action;
  final double width;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Container(
        width: width,
        color: action.color,
        alignment: Alignment.center,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(action.icon, size: 20, color: action.foregroundColor),
            const SizedBox(height: 4),
            Text(
              action.label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: action.foregroundColor,
                decoration: TextDecoration.none,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
