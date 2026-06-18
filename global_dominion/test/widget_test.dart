import 'package:flutter_test/flutter_test.dart';

import 'package:global_dominion/main.dart';

void main() {
  // ──────────────────────────────────────────────────────────────────────────
  // SMOKE TEST — verifies the app boots without throwing
  // ──────────────────────────────────────────────────────────────────────────
  testWidgets('GlobalDominion app renders without crashing',
      (WidgetTester tester) async {
    await tester.pumpWidget(const GlobalDominion());
    // A single pump is enough to confirm no exceptions during build
    expect(tester.takeException(), isNull);
  });

  // ──────────────────────────────────────────────────────────────────────────
  // SPLASH SCREEN — verifies the splash screen is the initial route
  // ──────────────────────────────────────────────────────────────────────────
  testWidgets('SplashScreen is shown on startup',
      (WidgetTester tester) async {
    await tester.pumpWidget(const GlobalDominion());
    await tester.pump(); // allow first frame to settle

    // The splash screen renders a "TAP TO CONTINUE" prompt
    expect(find.text('TAP TO CONTINUE'), findsOneWidget);
  });

  // ──────────────────────────────────────────────────────────────────────────
  // SPLASH → HOME NAVIGATION — tap skips the splash and shows the main menu
  // ──────────────────────────────────────────────────────────────────────────
  testWidgets('Tapping splash screen navigates to HomeScreen',
      (WidgetTester tester) async {
    await tester.pumpWidget(const GlobalDominion());
    await tester.pump();

    // Tap anywhere on the splash to skip
    await tester.tap(find.text('TAP TO CONTINUE'));
    await tester.pumpAndSettle(); // wait for fade transition to finish

    // Home screen menu buttons should now be visible
    expect(find.text('START GAME'), findsOneWidget);
    expect(find.text('SETTINGS'),   findsOneWidget);
    expect(find.text('QUIT'),       findsOneWidget);
  });

  // ──────────────────────────────────────────────────────────────────────────
  // HOME → GAME NAVIGATION — START GAME button pushes the GameScreen
  // ──────────────────────────────────────────────────────────────────────────
  testWidgets('START GAME button navigates to GameScreen',
      (WidgetTester tester) async {
    await tester.pumpWidget(const GlobalDominion());
    await tester.pump();

    // Skip splash
    await tester.tap(find.text('TAP TO CONTINUE'));
    await tester.pumpAndSettle();

    // Tap the START GAME button
    await tester.tap(find.text('START GAME'));
    await tester.pumpAndSettle();

    // GameScreen shows the empire headline
    expect(find.text('YOUR EMPIRE AWAITS'), findsOneWidget);
  });

  // ──────────────────────────────────────────────────────────────────────────
  // HOME → SETTINGS NAVIGATION — SETTINGS button pushes the SettingsScreen
  // ──────────────────────────────────────────────────────────────────────────
  testWidgets('SETTINGS button navigates to SettingsScreen',
      (WidgetTester tester) async {
    await tester.pumpWidget(const GlobalDominion());
    await tester.pump();

    // Skip splash
    await tester.tap(find.text('TAP TO CONTINUE'));
    await tester.pumpAndSettle();

    // Tap SETTINGS
    await tester.tap(find.text('SETTINGS'));
    await tester.pumpAndSettle();

    // SettingsScreen renders its header label
    expect(find.text('SETTINGS'), findsWidgets);
    expect(find.text('AUDIO'),    findsOneWidget);
    expect(find.text('DISPLAY'),  findsOneWidget);
  });

  // ──────────────────────────────────────────────────────────────────────────
  // QUIT DIALOG — QUIT button shows a confirmation dialog
  // ──────────────────────────────────────────────────────────────────────────
  testWidgets('QUIT button shows quit confirmation dialog',
      (WidgetTester tester) async {
    await tester.pumpWidget(const GlobalDominion());
    await tester.pump();

    // Skip splash
    await tester.tap(find.text('TAP TO CONTINUE'));
    await tester.pumpAndSettle();

    // Tap QUIT
    await tester.tap(find.text('QUIT'));
    await tester.pumpAndSettle();

    // Confirmation dialog must appear
    expect(find.text('QUIT GAME?'), findsOneWidget);
    expect(find.text('CANCEL'),     findsOneWidget);
  });

  // ──────────────────────────────────────────────────────────────────────────
  // QUIT DIALOG CANCEL — tapping CANCEL dismisses the dialog
  // ──────────────────────────────────────────────────────────────────────────
  testWidgets('CANCEL button dismisses quit dialog and returns to home',
      (WidgetTester tester) async {
    await tester.pumpWidget(const GlobalDominion());
    await tester.pump();

    // Skip splash → open quit dialog
    await tester.tap(find.text('TAP TO CONTINUE'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('QUIT'));
    await tester.pumpAndSettle();

    // Dismiss with CANCEL
    await tester.tap(find.text('CANCEL'));
    await tester.pumpAndSettle();

    // Dialog gone, home menu still visible
    expect(find.text('QUIT GAME?'), findsNothing);
    expect(find.text('START GAME'), findsOneWidget);
  });
}