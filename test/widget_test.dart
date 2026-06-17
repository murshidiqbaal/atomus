import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:atomus/widgets/neu_box.dart';

void main() {
  testWidgets('NeuBox renders child and handles onTap', (WidgetTester tester) async {
    bool tapped = false;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: NeuBox(
            onTap: () {
              tapped = true;
            },
            child: const Text('Test Child'),
          ),
        ),
      ),
    );

    // Verify child is rendered
    expect(find.text('Test Child'), findsOneWidget);

    // Verify tapping triggers callback
    await tester.tap(find.text('Test Child'));
    await tester.pump();

    expect(tapped, isTrue);
  });
}
