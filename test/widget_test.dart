import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:myapp/main.dart';

void main() {
  testWidgets('App starts, displays initial tasks, and allows adding a new one',
      (WidgetTester tester) async {
    // Build our app and trigger a frame.
    await tester.pumpWidget(const MyApp());

    // Verify that the app bar title is correct.
    expect(find.text('To-Do List'), findsOneWidget);

    // Verify that the initial tasks from the provider are displayed.
    expect(find.byType(ListTile), findsNWidgets(3)); // 3 initial tasks
    expect(find.text('Design the app logo'), findsOneWidget);
    expect(find.text('Create a wireframe for the main screen'), findsOneWidget);

    // Tap the floating action button to open the add task dialog.
    await tester.tap(find.byType(FloatingActionButton));
    await tester.pumpAndSettle(); // Wait for the dialog to appear

    // Verify the dialog is open.
    expect(find.text('Add New Task'), findsOneWidget);

    // Enter a new task title.
    await tester.enterText(find.byType(TextField), 'Write a widget test');

    // Tap the 'Add' button.
    await tester.tap(find.text('Add'));
    await tester
        .pumpAndSettle(); // Wait for the dialog to close and UI to update

    // Verify the new task is now in the list.
    expect(find.byType(ListTile), findsNWidgets(4));
    expect(find.text('Write a widget test'), findsOneWidget);
  });
}
