import 'package:flutter_test/flutter_test.dart';
import 'package:nexus_images/services/review_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('requests a review once, on the fifth lifetime save', () async {
    SharedPreferences.setMockInitialValues({});
    final service = ReviewService.instance;
    await service.init();
    final prefs = await SharedPreferences.getInstance();

    // Saves 1-4 only count.
    for (var i = 1; i <= 4; i++) {
      await service.onFavouriteSaved();
      expect(prefs.getInt('review.favouriteSaves'), i);
      expect(prefs.getBool('review.requested'), isNull);
    }

    // The fifth save flips the one-shot flag. The platform channel is absent
    // in tests, so this also exercises the swallow-errors path.
    await service.onFavouriteSaved();
    expect(prefs.getBool('review.requested'), isTrue);
    expect(prefs.getInt('review.favouriteSaves'), 5);

    // Once requested, further saves are ignored entirely.
    await service.onFavouriteSaved();
    expect(prefs.getInt('review.favouriteSaves'), 5);
  });
}
