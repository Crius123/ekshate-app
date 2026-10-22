import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ekshate_app/app.dart';

void main() {
  testWidgets('EkshateApp loads smoke test', (WidgetTester tester) async {
    await tester.pumpWidget(
      const ProviderScope(
        child: EkshateApp(),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Ekshate'), findsOneWidget);
  });
}
