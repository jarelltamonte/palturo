import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:palturo/theme/theme.dart';
import 'package:palturo/widgets/app_skeleton.dart';

void main() {
  testWidgets('skeletons render in a compact phone without overflow', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(360, 640));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    for (final child in <Widget>[
      const ExploreGridSkeleton(),
      const ListRowsSkeleton(),
      const RequestCardsSkeleton(),
      const ProfileSkeleton(),
    ]) {
      await tester.pumpWidget(
        MaterialApp(theme: lightMode, home: Scaffold(body: child)),
      );
      await tester.pump(const Duration(milliseconds: 40));
      expect(
        tester.takeException(),
        isNull,
        reason: child.runtimeType.toString(),
      );
    }
  });
}
