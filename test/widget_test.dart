import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:garba_song_manager/main.dart';

void main() {
  testWidgets('App starts and renders', (WidgetTester tester) async {
    await tester.pumpWidget(
      const ProviderScope(
        child: GarbaSongManagerApp(),
      ),
    );

    // Verify the app title is rendered somewhere.
    expect(find.text('Garba Song Manager'), findsOneWidget);
  });
}
