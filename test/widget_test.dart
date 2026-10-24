import 'package:flutter_test/flutter_test.dart';
import 'package:ration_safe/main.dart';

void main() {
  testWidgets('GrainTrustMobileApp smoke test', (WidgetTester tester) async {
    await tester.pumpWidget(const GrainTrustMobileApp());
    expect(find.byType(GrainTrustMobileApp), findsOneWidget);
  });
}
