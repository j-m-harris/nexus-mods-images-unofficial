import 'package:flutter_test/flutter_test.dart';
import 'package:nexus_images/services/adult_reveal_session.dart';
import 'package:nexus_images/services/settings_service.dart';

void main() {
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
}
