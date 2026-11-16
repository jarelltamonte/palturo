import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:palturo/screen/card/skills_card.dart';
import 'package:palturo/services/profile_service.dart';
import 'package:palturo/theme/theme.dart';

Widget _host(Widget child) {
  return MaterialApp(
    theme: lightMode,
    home: Scaffold(body: SingleChildScrollView(child: child)),
  );
}

void main() {
  test('showcase video detection follows the file extension', () {
    expect(ProfileService.isShowcaseVideo('https://x.test/a/b.mp4'), isTrue);
    expect(
      ProfileService.isShowcaseVideo('https://x.test/a/b.MOV?t=1'),
      isTrue,
    );
    expect(ProfileService.isShowcaseVideo('https://x.test/a/b.webm'), isTrue);
    expect(ProfileService.isShowcaseVideo('https://x.test/a/b.m4v'), isTrue);
    expect(ProfileService.isShowcaseVideo('https://x.test/a/b.jpg'), isFalse);
    expect(ProfileService.isShowcaseVideo('user-id/proof_1.jpg'), isFalse);
  });

  testWidgets('an empty teaching row explains the discovery showcase', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    var attachCalls = 0;
    await tester.pumpWidget(
      _host(
        SkillsCard.toTeach(
          isEditing: true,
          initialSkillIds: const ['Cooking Pinakbet'],
          onAttachFile: (_) => attachCalls++,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Add a skill showcase'), findsOneWidget);
    expect(find.text('FOR DISCOVERY'), findsOneWidget);
    expect(
      find.text('A photo or short video that appears on your discovery card.'),
      findsOneWidget,
    );

    await tester.tap(find.text('Add a skill showcase'));
    await tester.pumpAndSettle();
    expect(attachCalls, 1);
    expect(tester.takeException(), isNull);
  });

  testWidgets('an attached showcase names the skill and the discovery card', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    var removed = 0;
    await tester.pumpWidget(
      _host(
        SkillsCard.toTeach(
          isEditing: true,
          initialSkillIds: const ['Cooking Pinakbet'],
          attachments: const {
            'Cooking Pinakbet':
                'https://x.test/storage/v1/object/public/skill-showcases/a.mp4',
          },
          onRemoveAttachment: (_) => removed++,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Showcase for Cooking Pinakbet'), findsOneWidget);
    expect(
      find.text('Shown on your card in For You and Browse'),
      findsOneWidget,
    );
    expect(find.text('Add a skill showcase'), findsNothing);

    await tester.tap(find.bySemanticsLabel('Remove showcase'));
    await tester.pumpAndSettle();
    expect(removed, 1);
    expect(tester.takeException(), isNull);
  });
}
