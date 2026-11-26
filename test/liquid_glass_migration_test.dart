import 'package:flutter/cupertino.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:inspire_blur/inspire_blur.dart';
import 'package:liquid_glass_widgets/liquid_glass_widgets.dart';
import 'package:mono_dash/core/widgets/app_toggle_switch.dart';
import 'package:mono_dash/presentation/common/components/frosted_action_button.dart';
import 'package:mono_dash/presentation/common/components/frosted_header.dart';
import 'package:mono_dash/presentation/common/components/frosted_scaffold.dart';

void main() {
  testWidgets('frosted actions use a blurred backdrop', (tester) async {
    var tapped = false;

    await tester.pumpWidget(
      CupertinoApp(
        home: Center(
          child: FrostedActionButton(text: 'Save', onTap: () => tapped = true),
        ),
      ),
    );

    expect(
      find.descendant(
        of: find.byType(FrostedActionButton),
        matching: find.byType(BackdropFilter),
      ),
      findsOneWidget,
    );

    await tester.tap(find.text('Save'));
    expect(tapped, isTrue);

    await tester.pumpWidget(
      const CupertinoApp(
        home: Center(
          child: FrostedActionButton(text: '', icon: CupertinoIcons.add),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(
      tester.getSize(find.byType(FrostedActionButton)),
      const Size.square(34),
    );
  });

  testWidgets('header title suffix stays clear of trailing actions', (
    tester,
  ) async {
    final suffixKey = GlobalKey();
    final trailingKey = GlobalKey();

    await tester.pumpWidget(
      CupertinoApp(
        home: Align(
          alignment: Alignment.topLeft,
          child: SizedBox(
            width: 360,
            child: FrostedHeader(
              title: '清羽面板',
              titleSuffix: SizedBox(key: suffixKey, width: 100, height: 26),
              trailingBuilder: (isDark, isOverlapping) =>
                  SizedBox(key: trailingKey, width: 34, height: 34),
            ),
          ),
        ),
      ),
    );

    expect(tester.takeException(), isNull);
    final suffixRight = tester.getTopRight(find.byKey(suffixKey)).dx;
    final trailingLeft = tester.getTopLeft(find.byKey(trailingKey)).dx;
    expect(suffixRight, lessThanOrEqualTo(trailingLeft));
  });

  testWidgets('app toggles use blue premium glass switches', (tester) async {
    var value = false;

    await tester.pumpWidget(
      CupertinoApp(
        home: Center(
          child: AppToggleSwitch(
            value: value,
            onChanged: (next) => value = next,
          ),
        ),
      ),
    );

    final glass = tester.widget<GlassSwitch>(find.byType(GlassSwitch));
    final context = tester.element(find.byType(GlassSwitch));
    expect(glass.activeColor, CupertinoColors.systemBlue.resolveFrom(context));
    expect(glass.useOwnLayer, isTrue);
    expect(glass.quality, GlassQuality.premium);

    await tester.tap(find.byType(GlassSwitch));
    expect(value, isTrue);
  });

  testWidgets('headers use shader progressive backdrop blur', (tester) async {
    await tester.pumpWidget(
      const CupertinoApp(home: FrostedHeader(title: 'Mono Dash')),
    );

    expect(find.byType(InspireBackdropBlur), findsOneWidget);
    expect(find.byType(BackdropFilter), findsNothing);
  });

  testWidgets('large headers collapse into the centered title', (tester) async {
    await tester.pumpWidget(
      CupertinoApp(
        home: FrostedScaffold(
          title: 'Mono Dash',
          showBackButton: false,
          largeTitle: true,
          body: ListView(children: const [SizedBox(height: 1000)]),
        ),
      ),
    );

    final initialLargeTitleTop = tester.getTopLeft(find.text('Mono Dash').last);
    expect(
      tester
          .widget<Opacity>(find.byKey(const ValueKey('frosted-large-title')))
          .opacity,
      1,
    );
    expect(
      tester
          .widget<Opacity>(find.byKey(const ValueKey('frosted-small-title')))
          .opacity,
      0,
    );

    await tester.drag(find.byType(ListView), const Offset(0, -36));
    await tester.pump();

    final transitioningLargeTitle = tester.widget<Opacity>(
      find.byKey(const ValueKey('frosted-large-title')),
    );
    expect(transitioningLargeTitle.opacity, lessThan(1));
    expect(transitioningLargeTitle.opacity, greaterThan(0));
    expect(
      tester.getTopLeft(find.text('Mono Dash').last).dy,
      lessThan(initialLargeTitleTop.dy),
    );

    await tester.drag(find.byType(ListView), const Offset(0, -80));
    await tester.pump();

    expect(
      tester
          .widget<Opacity>(find.byKey(const ValueKey('frosted-large-title')))
          .opacity,
      0,
    );
    expect(
      tester
          .widget<Opacity>(find.byKey(const ValueKey('frosted-small-title')))
          .opacity,
      1,
    );
  });
}
