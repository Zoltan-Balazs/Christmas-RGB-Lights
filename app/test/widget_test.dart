import 'package:flutter_test/flutter_test.dart';

import 'package:christmas_light/main.dart';

void main() {
  testWidgets('App starts on the home screen', (WidgetTester tester) async {
    await tester.pumpWidget(const ChristmasLightApp());

    expect(find.text('Actuel RGB Light'), findsOneWidget);
    expect(find.text('Disconnected'), findsOneWidget);
    expect(find.text('Connect'), findsOneWidget);
  });
}
