import 'package:flutter/cupertino.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mono_dash/presentation/common/components/swipe_action_cell.dart';

void main() {
  testWidgets('swiping left reveals actions and tapping one runs it', (
    tester,
  ) async {
    var started = false;
    var deleted = false;

    await tester.pumpWidget(
      CupertinoApp(
        home: Center(
          child: SizedBox(
            width: 340,
            child: SwipeActionCell(
              actions: [
                SwipeAction(
                  label: 'Start',
                  icon: CupertinoIcons.play_fill,
                  color: CupertinoColors.systemGreen,
                  onTap: () => started = true,
                ),
                SwipeAction(
                  label: 'Delete',
                  icon: CupertinoIcons.delete,
                  color: CupertinoColors.systemRed,
                  onTap: () => deleted = true,
                ),
              ],
              child: Container(
                height: 100,
                color: CupertinoColors.white,
                alignment: Alignment.center,
                child: const Text('card'),
              ),
            ),
          ),
        ),
      ),
    );

    await tester.drag(find.text('card'), const Offset(-160, 0));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Start'));
    await tester.pumpAndSettle();
    expect(started, isTrue);
    expect(deleted, isFalse);

    await tester.drag(find.text('card'), const Offset(-160, 0));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Delete'));
    await tester.pumpAndSettle();
    expect(deleted, isTrue);
  });

  testWidgets('tapping the card while open only closes the actions', (
    tester,
  ) async {
    await tester.pumpWidget(
      CupertinoApp(
        home: Center(
          child: SizedBox(
            width: 340,
            child: SwipeActionCell(
              actions: [
                SwipeAction(
                  label: 'Delete',
                  icon: CupertinoIcons.delete,
                  color: CupertinoColors.systemRed,
                  onTap: () {},
                ),
              ],
              child: const SizedBox(
                key: ValueKey('swipe-test-card'),
                width: 340,
                height: 100,
                child: ColoredBox(color: CupertinoColors.white),
              ),
            ),
          ),
        ),
      ),
    );

    await tester.drag(
      find.byKey(const ValueKey('swipe-test-card')),
      const Offset(-100, 0),
    );
    await tester.pumpAndSettle();

    Transform content = tester.widget<Transform>(
      find.byKey(const ValueKey('swipe-action-content')),
    );
    expect(content.transform.storage[12], lessThan(-40));

    // 点卡片左侧区域应收起，而不是触发卡片自身的操作。
    await tester.tapAt(const Offset(300, 300));
    await tester.pumpAndSettle();

    content = tester.widget<Transform>(
      find.byKey(const ValueKey('swipe-action-content')),
    );
    expect(content.transform.storage[12], moreOrLessEquals(0, epsilon: 0.5));
  });
}
