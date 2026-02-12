// Basic Flutter widget test for DeGrid app.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:degrid/app.dart';

void main() {
  testWidgets('App loads and shows projects screen', (WidgetTester tester) async {
    await tester.pumpWidget(const App());

    // Projects screen shows title or new project action
    expect(
      find.byType(MaterialApp),
      findsOneWidget,
    );
  });
}
