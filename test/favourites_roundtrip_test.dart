import 'package:flutter_test/flutter_test.dart';
import 'package:nexus_images/models/nexus_image.dart';

void main() {
  test('NexusImage survives toJson/fromJson round-trip', () {
    final a = NexusImage(
      id: '42', name: 'shot', title: 'T', caption: 'C', description: 'D',
      url: 'u', thumbnailUrl: 't', views: 5, rating: 3, createdAt: '2026',
      siteUrl: 's', categoryName: 'cat', gameName: 'game', gameDomain: 'dom',
      ownerName: 'me', ownerAvatar: 'av', ownerMemberId: 7, adult: true,
    );
    final b = NexusImage.fromJson(a.toJson());
    expect(b.id, a.id);
    expect(b.categoryName, a.categoryName);
    expect(b.gameName, a.gameName);
    expect(b.gameDomain, a.gameDomain);
    expect(b.ownerName, a.ownerName);
    expect(b.ownerMemberId, a.ownerMemberId);
    expect(b.adult, a.adult);
    expect(b.views, a.views);
    expect(b.siteUrl, a.siteUrl);
  });
}
