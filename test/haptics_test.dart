import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:palturo/services/haptics.dart';
import 'package:palturo/services/preferences_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late List<MethodCall> calls;

  setUp(() {
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    PreferencesService.instance.vibrationEnabled = true;
    Haptics.resetThrottle();
    calls = [];
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, (call) async {
          calls.add(call);
          return null;
        });
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, null);
    debugDefaultTargetPlatformOverride = null;
    PreferencesService.instance.vibrationEnabled = true;
    Haptics.resetThrottle();
  });

  test('selection uses the platform haptic channel', () async {
    await Haptics.selection();

    expect(calls, hasLength(1));
    expect(calls.single.method, 'HapticFeedback.vibrate');
    expect(calls.single.arguments, 'HapticFeedbackType.selectionClick');
  });

  test('disabled vibration produces no platform calls', () async {
    PreferencesService.instance.vibrationEnabled = false;

    await Haptics.success();

    expect(calls, isEmpty);
  });

  test('same intent is throttled inside the gap', () async {
    await Haptics.selection();
    await Haptics.selection();

    expect(calls, hasLength(1));
  });

  test('match plays a distinct two-step pattern', () async {
    await Haptics.match();

    expect(calls, hasLength(2));
    expect(calls[0].arguments, 'HapticFeedbackType.heavyImpact');
    expect(calls[1].arguments, 'HapticFeedbackType.mediumImpact');
  });
}
