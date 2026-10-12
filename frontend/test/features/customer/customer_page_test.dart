import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/core/enums/ticket_status.dart';
import 'package:frontend/features/customer/domain/entities/ticket_entity.dart';
import 'package:frontend/features/customer/presentation/pages/customer_page.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../helpers/fake_customer_repository.dart';
import '../../helpers/stub_dio.dart';

void main() {
  late FakeCustomerRepository repository;

  Future<void> pumpPage(WidgetTester tester) async {
    SharedPreferences.setMockInitialValues({});
    await tester.pumpWidget(
      MaterialApp(home: CustomerPage(repository: repository)),
    );
    await tester.pump();
  }

  // Removes the page: the cubit closes and stops the refresh timer.
  Future<void> disposePage(WidgetTester tester) =>
      tester.pumpWidget(const SizedBox());

  setUp(() => repository = FakeCustomerRepository());

  testWidgets('shows the services with their service time', (tester) async {
    await pumpPage(tester);

    expect(find.text('Get a New Ticket'), findsOneWidget);
    expect(find.text('Shipping'), findsOneWidget);
    expect(find.text('Deposit'), findsOneWidget);
    expect(find.text('5m wait'), findsOneWidget);
    expect(find.text('8m wait'), findsOneWidget);
    expect(find.text('Get Ticket'), findsNWidgets(2));
  });

  testWidgets('choosing a service gives the customer a ticket', (tester) async {
    repository.issuedTicket = customerTicket(code: 'D-0001', serviceId: 2);
    await pumpPage(tester);

    await tester.tap(find.text('Get Ticket').last);
    await tester.pump();
    await tester.pump();

    expect(repository.issuedFor, [2]);
    expect(find.text('D-0001'), findsOneWidget);
    expect(find.text('WAITING'), findsOneWidget);
    expect(
      find.text('Get a New Ticket'),
      findsNothing,
      reason: 'with an active ticket no other ticket can be taken',
    );
    await disposePage(tester);
  });

  // Note: with the real backend a called ticket arrives with is_active = false and disappears (see test/e2e);
  // this only checks that the page shows the updated status of a ticket that is still active.
  testWidgets('the ticket status refreshes by itself every 5 seconds', (
    tester,
  ) async {
    await pumpPage(tester);
    await tester.tap(find.text('Get Ticket').first);
    await tester.pump();
    await tester.pump();
    repository.statusResponses.add(
      customerTicket(status: TicketStatus.called, counterId: 2),
    );

    await tester.pump(const Duration(seconds: 5));
    await tester.pump();

    expect(find.text('CALLED'), findsOneWidget);
    await disposePage(tester);
  });

  testWidgets(
    'a customer who already has a ticket finds it again when reopening the app',
    (tester) async {
      repository.activeTicket = customerTicket(code: 'S-0004');
      repository.statusResponses.add(customerTicket(code: 'S-0004'));
      await pumpPage(tester);
      await tester.pump();

      expect(find.text('S-0004'), findsOneWidget);
      expect(find.text('Get Ticket'), findsNothing);
      await disposePage(tester);
    },
  );

  testWidgets(
    'the cancel ticket action is disabled until the backend endpoint exists',
    (tester) async {
      repository.issuedTicket = customerTicket(code: 'D-0001', serviceId: 2);
      await pumpPage(tester);

      await tester.tap(find.text('Get Ticket').last);
      await tester.pump();
      await tester.pump();

      final button = tester.widget<TextButton>(
        find.widgetWithText(TextButton, 'Cancel Ticket'),
      );
      expect(button.onPressed, isNull);
      await disposePage(tester);
    },
  );

  testWidgets(
    'the active ticket shows real service, queue position, and issue time',
    (tester) async {
      repository.activeTicket = TicketEntity(
        id: 7,
        code: 'S-0004',
        serviceId: 2,
        status: TicketStatus.waiting,
        issuedAt: DateTime(2026, 10, 11, 10, 42),
        queueLength: 3,
      );
      repository.statusResponses.add(
        TicketEntity(
          id: 7,
          code: 'S-0004',
          serviceId: 2,
          status: TicketStatus.waiting,
          issuedAt: DateTime(2026, 10, 11, 10, 42),
          queueLength: 3,
        ),
      );
      await pumpPage(tester);
      await tester.pump();

      expect(find.text('Deposit'), findsOneWidget);
      final queueText = tester
          .widgetList<RichText>(find.byType(RichText))
          .map((widget) => widget.text.toPlainText())
          .join(' ');
      expect(queueText, contains('3rd in line'));
      expect(find.text('Checked-in at 10:42 AM'), findsOneWidget);
      expect(find.textContaining('mins'), findsNothing);
      expect(find.textContaining('~8'), findsNothing);
      await disposePage(tester);
    },
  );

  testWidgets('shows the error when the services cannot be loaded', (
    tester,
  ) async {
    repository.servicesError = Exception('server offline');
    await pumpPage(tester);
    await tester.pump();

    expect(
      find.text(
        'Cannot reach the office. Check your connection and try again.',
      ),
      findsOneWidget,
    );
    expect(find.text('Get Ticket'), findsNothing);
  });

  testWidgets('shows the error when the ticket cannot be issued', (
    tester,
  ) async {
    repository.issueError = httpError(409);
    await pumpPage(tester);

    await tester.tap(find.text('Get Ticket').first);
    await tester.pump();
    await tester.pump();

    expect(
      find.text('Something went wrong. Please try again.'),
      findsOneWidget,
    );
    expect(find.text('S-0001'), findsNothing);
  });
}
