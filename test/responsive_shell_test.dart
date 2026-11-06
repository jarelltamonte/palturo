import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:palturo/theme/theme.dart';
import 'package:palturo/widgets/responsive_shell.dart';

void main() {
  const key = ValueKey('shell-child');

  Future<double> pumpShell(WidgetTester tester, Size physicalSize) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = physicalSize;
    late double mediaWidth;

    await tester.pumpWidget(
      MaterialApp(
        theme: lightMode,
        home: ResponsiveShell(
          child: Builder(
            builder: (context) {
              mediaWidth = MediaQuery.sizeOf(context).width;
              return const SizedBox.expand(key: key);
            },
          ),
        ),
      ),
    );
    return mediaWidth;
  }

  testWidgets('wide surfaces get a 480 logical-width shell', (tester) async {
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final mediaWidth = await pumpShell(tester, const Size(1440, 900));

    expect(mediaWidth, 480);
    expect(tester.getSize(find.byKey(key)).width, closeTo(480, 3));
  });

  testWidgets('phone portrait passes through', (tester) async {
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final mediaWidth = await pumpShell(tester, const Size(390, 844));

    expect(mediaWidth, 390);
    expect(tester.getSize(find.byKey(key)).width, closeTo(390, 3));
  });

  testWidgets('phone landscape stays full width', (tester) async {
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final mediaWidth = await pumpShell(tester, const Size(844, 390));

    expect(mediaWidth, 844);
    expect(tester.getSize(find.byKey(key)).width, closeTo(844, 3));
  });
}
