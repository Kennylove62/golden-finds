import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:golden_finds/models/app_user.dart';
import 'package:golden_finds/screens/client/client_home_screen.dart';
import 'package:golden_finds/screens/seller/seller_dashboard_screen.dart';
import 'package:golden_finds/screens/visitor/home_screen.dart';

void main() {
  testWidgets('Visitor receives visitor interface', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: VisitorHomeScreen()));

    expect(find.text('VISITOR MODE'), findsOneWidget);

    expect(find.text('GOLDEN FINDS'), findsOneWidget);

    expect(find.text('Sign in'), findsWidgets);
  });

  testWidgets('Client receives client interface', (tester) async {
    const user = AppUser(
      uid: 'client-demo',
      name: 'Armand Test',
      email: 'armand@example.com',
      phone: '+25761903376',
      role: 'client',
    );

    await tester.pumpWidget(
      const MaterialApp(home: ClientHomeScreen(user: user)),
    );

    expect(find.text('CLIENT SPACE'), findsOneWidget);

    expect(find.text('Hello, Armand'), findsOneWidget);

    expect(find.text('SIGNED IN • CLIENT'), findsOneWidget);
  });

  testWidgets('Seller receives seller dashboard', (tester) async {
    const user = AppUser(
      uid: 'seller-demo',
      name: 'Kenny Seller',
      email: 'seller@example.com',
      phone: '+25761000000',
      role: 'seller',
      whatsappNumber: '+25761000000',
    );

    await tester.pumpWidget(
      const MaterialApp(home: SellerDashboardScreen(user: user)),
    );

    expect(find.text('SELLER STUDIO'), findsOneWidget);

    expect(find.text('Good day, Kenny'), findsOneWidget);

    expect(find.text('SELLER WORKSPACE'), findsOneWidget);

    expect(find.text('Dashboard'), findsOneWidget);

    expect(find.text('Products'), findsWidgets);

    expect(find.text('Categories'), findsWidgets);

    expect(find.text('Orders'), findsWidgets);

    expect(find.text('Profile'), findsWidgets);
  });
}
