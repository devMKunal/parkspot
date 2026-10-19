import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:parkspot/core/widgets/app_text_field.dart';

import '../../helpers/pump_themed.dart';

void main() {
  bool obscured(WidgetTester tester) =>
      tester.widget<TextField>(find.byType(TextField)).obscureText;

  testWidgets('password field toggles visibility', (tester) async {
    await tester.pumpThemed(
      const AppTextField(label: 'Password', obscure: true),
    );

    expect(obscured(tester), isTrue);
    await tester.tap(find.byTooltip('Show password'));
    await tester.pump();
    expect(obscured(tester), isFalse);
    expect(find.byTooltip('Hide password'), findsOneWidget);
  });

  testWidgets('shows the label and the error text', (tester) async {
    await tester.pumpThemed(
      const AppTextField(label: 'Email', errorText: 'Enter a valid email'),
    );

    expect(find.text('Email'), findsOneWidget);
    expect(find.text('Enter a valid email'), findsOneWidget);
    expect(find.byType(IconButton), findsNothing);
  });
}
