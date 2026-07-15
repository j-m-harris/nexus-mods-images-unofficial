import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nexus_images/models/feed_layout.dart';
import 'package:nexus_images/services/adult_reveal_session.dart';
import 'package:nexus_images/services/settings_service.dart';
import 'package:nexus_images/widgets/adult_confirmation_dialog.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test('reveals are per-image and clearable', () {
    AdultRevealSession.instance.clear();
    expect(AdultRevealSession.instance.isRevealed('a'), isFalse);
    AdultRevealSession.instance.reveal('a');
    expect(AdultRevealSession.instance.isRevealed('a'), isTrue);
    expect(AdultRevealSession.instance.isRevealed('b'), isFalse);
    AdultRevealSession.instance.clear();
    expect(AdultRevealSession.instance.isRevealed('a'), isFalse);
  });

  test('modes drive the feed filter and the veil', () async {
    final settings = SettingsService.instance;

    await settings.setAdultMode(AdultContentMode.hide);
    expect(settings.includeAdultInFeed, isFalse);
    expect(settings.blurAdult, isTrue);

    await settings.setAdultMode(AdultContentMode.blur);
    expect(settings.includeAdultInFeed, isTrue);
    expect(settings.blurAdult, isTrue);

    await settings.setAdultMode(AdultContentMode.show);
    expect(settings.includeAdultInFeed, isTrue);
    expect(settings.blurAdult, isFalse);
  });

  test('changing mode re-veils previously revealed images', () async {
    final settings = SettingsService.instance;
    await settings.setAdultMode(AdultContentMode.blur);

    AdultRevealSession.instance.reveal('a');
    expect(AdultRevealSession.instance.isRevealed('a'), isTrue);

    // A no-op set (same mode) must NOT wipe reveals.
    await settings.setAdultMode(AdultContentMode.blur);
    expect(AdultRevealSession.instance.isRevealed('a'), isTrue);

    await settings.setAdultMode(AdultContentMode.show);
    expect(AdultRevealSession.instance.isRevealed('a'), isFalse);
  });

  // The 18+ dialog tests share the singleton's in-memory flag, so they run in
  // order: decline first (flag must still be unset), then accept.
  Widget confirmationHarness(void Function(bool) onResult) {
    return MaterialApp(
      home: Builder(
        builder: (context) => TextButton(
          onPressed: () async => onResult(await ensureAdultConfirmed(context)),
          child: const Text('go'),
        ),
      ),
    );
  }

  testWidgets('declining the 18+ dialog reveals nothing and asks again',
      (tester) async {
    bool? result;
    await tester.pumpWidget(confirmationHarness((r) => result = r));
    await tester.tap(find.text('go'));
    await tester.pumpAndSettle();
    expect(find.text('I am 18 or older'), findsOneWidget);

    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(result, isFalse);
    expect(SettingsService.instance.adultConfirmed, isFalse);

    // Declining is not remembered: the next attempt asks again.
    await tester.tap(find.text('go'));
    await tester.pumpAndSettle();
    expect(find.text('I am 18 or older'), findsOneWidget);
  });

  testWidgets('accepting the 18+ dialog is one-shot', (tester) async {
    bool? result;
    await tester.pumpWidget(confirmationHarness((r) => result = r));
    await tester.tap(find.text('go'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('I am 18 or older'));
    await tester.pumpAndSettle();
    expect(result, isTrue);
    expect(SettingsService.instance.adultConfirmed, isTrue);

    // Once confirmed, no dialog: the gate answers true immediately.
    result = null;
    await tester.tap(find.text('go'));
    await tester.pump();
    expect(find.text('I am 18 or older'), findsNothing);
    expect(result, isTrue);
  });

  // Runs last: init() reads preferences exactly once per process, so this is
  // the only test that may call it.
  test('settings load from and persist to preferences', () async {
    SharedPreferences.setMockInitialValues({
      'settings.adultContentMode': 'hide',
      'settings.adultConfirmed': false,
      'settings.feedLayout': 'sphere',
    });
    final settings = SettingsService.instance;
    await settings.init();
    expect(settings.adultMode, AdultContentMode.hide);
    expect(settings.adultConfirmed, isFalse);
    expect(settings.feedLayout, FeedLayout.sphere);

    await settings.confirmAdult();
    await settings.setAdultMode(AdultContentMode.blur);
    await settings.setFeedLayout(FeedLayout.grid);
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getBool('settings.adultConfirmed'), isTrue);
    expect(prefs.getString('settings.adultContentMode'), 'blur');
    expect(prefs.getString('settings.feedLayout'), 'grid');
  });
}
