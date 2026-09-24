import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:palturo/main.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() {
    const MethodChannel channel = MethodChannel('flutter_native_splash');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (MethodCall methodCall) async {
      return null;
    });
  });

  testWidgets('Counter increments smoke test', (WidgetTester tester) async {
    await tester.pumpWidget(const MyApp(isOnboardingDone: false));

    expect(find.text('0'), findsOneWidget);
    expect(find.text('1'), findsNothing);

    await tester.tap(find.byIcon(Icons.add));
    await tester.pump();

    expect(find.text('0'), findsNothing);
    expect(find.text('1'), findsOneWidget);
  });
}
