import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shannon/app/app.dart';

void main() {
  testWidgets('Shannon app smoke test', (WidgetTester tester) async {
    await tester.pumpWidget(
      const ProviderScope(child: ShannonApp()),
    );
    expect(find.byType(MaterialApp), findsOneWidget);
  });
}
