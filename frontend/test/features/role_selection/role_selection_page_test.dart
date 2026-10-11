import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/features/role_selection/presentation/pages/role_selection_page.dart';
import 'package:frontend/main.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../helpers/fake_counter_officer_repository.dart';
import '../../helpers/fake_customer_repository.dart';

void main() {
  group('RoleSelectionPage', () {
    testWidgets('shows the available roles', (tester) async {
      await tester.pumpWidget(const MaterialApp(home: RoleSelectionPage()));

      expect(find.text('Customer'), findsOneWidget);
      expect(find.text('Counter Officer'), findsOneWidget);
      expect(find.text('Manager / Admin'), findsOneWidget);
    });

    for (final role in ['Customer', 'Counter Officer']) {
      testWidgets('tapping "$role" selects that role', (tester) async {
        final chosen = <String>[];
        await tester.pumpWidget(MaterialApp(home: RoleSelectionPage(onRoleSelected: chosen.add)));

        await tester.tap(find.text(role));

        expect(chosen, [role]);
      });
    }
  });

  group('app navigation', () {
    Future<void> pumpApp(WidgetTester tester) async {
      SharedPreferences.setMockInitialValues({});
      await tester.pumpWidget(MyApp(
        repository: FakeCustomerRepository(),
        counterOfficerRepository: FakeCounterOfficerRepository(),
      ));
    }

    testWidgets('the customer reaches the service selection', (tester) async {
      await pumpApp(tester);

      await tester.tap(find.text('Customer'));
      await tester.pumpAndSettle();

      expect(find.text('Get a New Ticket'), findsOneWidget);
      expect(find.text('Shipping'), findsOneWidget);
    });

    testWidgets('the officer reaches the counter selection', (tester) async {
      await pumpApp(tester);

      await tester.tap(find.text('Counter Officer'));
      await tester.pumpAndSettle();

      expect(find.text('Select Counter'), findsOneWidget);
      expect(find.text('Counter 1'), findsOneWidget);
    });
  });
}
