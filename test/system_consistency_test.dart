import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:palturo/theme/theme.dart';
import 'package:palturo/widgets/app_skeleton.dart';

void main() {
  testWidgets('data-heavy route skeletons render before data', (tester) async {
    for (final skeleton in <Widget>[
      const BlockedListSkeleton(),
      const ActivitySkeleton(),
      const MatchesSkeleton(),
      const ChatRoomMessageSkeleton(),
    ]) {
      await tester.pumpWidget(
        MaterialApp(theme: lightMode, home: Scaffold(body: skeleton)),
      );
      expect(find.byType(SkeletonBox), findsWidgets);
    }
  });
}
