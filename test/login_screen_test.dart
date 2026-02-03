import 'package:flutter_test/flutter_test.dart';
import 'package:rideshare_app/features/auth/presentation/screens/login_screen.dart';
import 'package:flutter/material.dart';

void main() {
  testWidgets('Login screen has phone number input', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const MaterialApp(home: LoginScreen()));

    expect(find.text('Enter your mobile number'), findsOneWidget);
    expect(find.byType(TextField), findsOneWidget);
  });
}
