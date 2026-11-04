import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:palturo/services/connectivity_service.dart';
import 'package:palturo/theme/theme.dart';
import 'package:palturo/widgets/offline_banner.dart';

void main() {
  tearDown(() => ConnectivityService.instance.debugSetOnline(true));

  testWidgets('offline banner appears only while offline', (tester) async {
    ConnectivityService.instance.debugSetOnline(true);

    await tester.pumpWidget(
      MaterialApp(
        theme: lightMode,
        home: const OfflineBannerHost(child: Scaffold(body: Text('content'))),
      ),
    );

    expect(find.textContaining('You are offline'), findsNothing);

    ConnectivityService.instance.debugSetOnline(false);
    await tester.pump();

    expect(find.textContaining('You are offline'), findsOneWidget);
    expect(find.byIcon(Icons.wifi_off), findsOneWidget);

    ConnectivityService.instance.debugSetOnline(true);
    await tester.pump();

    expect(find.textContaining('You are offline'), findsNothing);
  });

  testWidgets('offline strip does not cover the app bar', (tester) async {
    ConnectivityService.instance.debugSetOnline(false);
    var tapped = 0;

    await tester.pumpWidget(
      MaterialApp(
        theme: lightMode,
        home: OfflineBannerHost(
          child: Scaffold(
            appBar: AppBar(
              title: const Text('Chats'),
              actions: [
                IconButton(
                  tooltip: 'Search',
                  onPressed: () => tapped++,
                  icon: const Icon(Icons.search),
                ),
              ],
            ),
            body: const Text('content'),
          ),
        ),
      ),
    );
    await tester.pump();

    expect(find.text('Chats'), findsOneWidget);
    await tester.tap(find.byTooltip('Search'));
    expect(tapped, 1);
  });
}
