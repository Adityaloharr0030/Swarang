import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:garba_song_manager/core/constants/app_constants.dart';
import 'package:garba_song_manager/database/app_database.dart';
import 'package:garba_song_manager/features/people/presentation/providers/people_providers.dart';
import 'package:garba_song_manager/main.dart';

void main() {
  testWidgets('App starts and renders', (WidgetTester tester) async {
    final db = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(() => db.close());

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          databaseProvider.overrideWithValue(db),
        ],
        child: const GarbaSongManagerApp(),
      ),
    );
    await tester.pumpAndSettle();

    // Verify the app title is rendered somewhere.
    expect(find.text(AppConstants.appName), findsWidgets);

    // Unmount widget and flush stream timers
    await tester.pumpWidget(const SizedBox());
    await tester.pump(Duration.zero);
  });
}
