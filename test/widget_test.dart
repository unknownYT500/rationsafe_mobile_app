import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:ration_safe/main.dart';
import 'package:ration_safe/providers/app_state_provider.dart';

void main() {
  testWidgets('GrainTrustMobileApp smoke test', (WidgetTester tester) async {
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider(create: (_) => AppStateProvider()),
        ],
        child: const GrainTrustMobileApp(),
      ),
    );
    expect(find.byType(GrainTrustMobileApp), findsOneWidget);
  });
}
