// This is a basic Flutter widget test.
//
// To perform an interaction with a widget in your test, use the WidgetTester
// utility in the flutter_test package. For example, you can send tap and scroll
// gestures. You can also use WidgetTester to find child widgets in the widget
// tree, read text, and verify that the values of widget properties are correct.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:safewalk/main.dart';

void main() {
  testWidgets('Admin Dashboard smoke test', (WidgetTester tester) async {
// 1. Build our AdminMain app.
    await tester.pumpWidget(const AdminMain());

    // 2. Verify that the Dashboard text appears.
    // Since we fetch reports, we expect to see 'Pending Reports'
    expect(find.text('Pending Reports'), findsOneWidget);
    
    // 3. Verify that the Bottom Navigation is there.
    expect(find.byIcon(Icons.dashboard_outlined), findsOneWidget);
    expect(find.byIcon(Icons.analytics_outlined), findsOneWidget);

    // 4. Verify that the counter '0' is NOT there (since we deleted it).
    expect(find.text('You have pushed the button this many times:'), findsNothing);
  });
}
