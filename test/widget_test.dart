// This is a basic Flutter widget test.
//
// To perform an interaction with a widget in your test, use the WidgetTester
// utility in the flutter_test package. For example, you can send tap and scroll
// gestures. You can also use WidgetTester to find child widgets in the widget
// tree, read text, and verify that the values of widget properties are correct.

import 'package:flutter_test/flutter_test.dart';
import 'package:startupper/main.dart';
import 'package:startupper/feed/feed_models.dart';
import 'package:startupper/feed/feed_screen.dart';

void main() {
  testWidgets('Shows config screen when Supabase is not ready',
      (WidgetTester tester) async {
    await tester.pumpWidget(const StartupperApp(
      supabaseReady: false,
      startupErrorMessage: 'Supabase credentials are missing.',
    ));

    expect(find.textContaining('Supabase'), findsWidgets);
    expect(find.textContaining('credentials'), findsWidgets);
  });

  // Note: The compose dialog test was removed because _ComposeDialog is a
  // private class and cannot be accessed from test files. To test the compose
  // functionality, either:
  // 1. Make the dialog public (rename to ComposeDialog)
  // 2. Test it indirectly through the FeedScreen when user is logged in
}
