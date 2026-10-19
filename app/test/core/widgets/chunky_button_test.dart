import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:parkspot/core/widgets/chunky_button.dart';

import '../../helpers/pump_themed.dart';

void main() {
  testWidgets('calls onPressed on tap', (tester) async {
    var taps = 0;
    await tester.pumpThemed(
      ChunkyButton(label: 'Grab a spot', onPressed: () => taps++),
    );

    await tester.tap(find.text('Grab a spot'));
    expect(taps, 1);
  });

  testWidgets('ignores taps and shows a spinner while loading', (tester) async {
    var taps = 0;
    await tester.pumpThemed(
      ChunkyButton(label: 'Pay', loading: true, onPressed: () => taps++),
    );

    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    expect(find.text('Pay'), findsNothing);
    await tester.tap(find.byType(ChunkyButton));
    expect(taps, 0);
  });

  testWidgets('is announced as a disabled button without onPressed', (
    tester,
  ) async {
    final handle = tester.ensureSemantics();
    await tester.pumpThemed(const ChunkyButton(label: 'Pay', onPressed: null));

    expect(
      tester.getSemantics(find.byType(ChunkyButton)),
      matchesSemantics(label: 'Pay', isButton: true, hasEnabledState: true),
    );
    handle.dispose();
  });

  testWidgets('icon variant exposes its label to screen readers', (
    tester,
  ) async {
    final handle = tester.ensureSemantics();
    await tester.pumpThemed(
      ChunkyButton.icon(
        icon: Icons.near_me_rounded,
        semanticLabel: 'Directions',
        onPressed: () {},
      ),
    );

    expect(find.bySemanticsLabel('Directions'), findsOneWidget);
    handle.dispose();
  });
}
