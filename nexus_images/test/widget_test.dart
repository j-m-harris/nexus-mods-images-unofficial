import 'package:flutter_test/flutter_test.dart';
import 'package:nexus_images/main.dart';

void main() {
  testWidgets('App renders', (WidgetTester tester) async {
    await tester.pumpWidget(const NexusImagesApp());
    expect(find.text('Nexus Mods Image Browser'), findsOneWidget);
  });
}
