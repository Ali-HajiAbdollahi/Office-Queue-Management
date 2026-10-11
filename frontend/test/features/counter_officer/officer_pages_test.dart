import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/features/counter_officer/domain/repositories/counter_officer_repository.dart';
import 'package:frontend/features/counter_officer/presentation/pages/counter_selection_page.dart';
import 'package:frontend/features/counter_officer/presentation/pages/officer_dashboard_page.dart';

import '../../helpers/fake_counter_officer_repository.dart';

void main() {
  late FakeCounterOfficerRepository repository;

  setUp(() => repository = FakeCounterOfficerRepository());

  Future<void> pumpWithRepository(WidgetTester tester, Widget home) async {
    await tester.pumpWidget(RepositoryProvider<CounterOfficerRepository>.value(
      value: repository,
      child: MaterialApp(home: home),
    ));
    await tester.pump();
    await tester.pump();
  }

  // Removes the page so that its timers stop (snackbar, elapsed time).
  Future<void> disposePage(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 10));
  }

  FilledButton button(WidgetTester tester, String label) =>
      tester.widget<FilledButton>(find.ancestor(of: find.text(label), matching: find.byWidgetPredicate((w) => w is FilledButton)));

  group('counter selection', () {
    testWidgets('shows the counters and cannot continue without a choice', (tester) async {
      await pumpWithRepository(tester, const CounterSelectionPage());

      expect(find.text('Counter 1'), findsOneWidget);
      expect(find.text('Counter 2'), findsOneWidget);
      expect(button(tester, 'Select a counter').onPressed, isNull);
    });

    testWidgets('choosing a counter opens its desk', (tester) async {
      await pumpWithRepository(tester, const CounterSelectionPage());

      await tester.tap(find.text('Counter 2'));
      await tester.pump();
      expect(find.text('Continue to Counter 2'), findsOneWidget);

      await tester.tap(find.text('Continue to Counter 2'));
      await tester.pumpAndSettle();

      expect(find.text('MY DESK'), findsOneWidget);
      expect(find.text('No ticket being served'), findsOneWidget);
      await disposePage(tester);
    });

    testWidgets('can retry when the counters cannot be loaded', (tester) async {
      repository.countersError = Exception('offline');
      await pumpWithRepository(tester, const CounterSelectionPage());

      expect(find.text('Could not load counters'), findsOneWidget);

      repository.countersError = null;
      await tester.tap(find.text('Retry'));
      await tester.pump();
      await tester.pump();

      expect(find.text('Counter 1'), findsOneWidget);
    });
  });

  group('officer desk', () {
    Future<void> pumpDashboard(WidgetTester tester) =>
        pumpWithRepository(tester, OfficerDashboardPage(counter: demoCounters[1]));

    testWidgets('Call Next shows the called ticket', (tester) async {
      repository.nextResults.add(officerTicket(code: 'D-0001', serviceType: 'Deposit'));
      await pumpDashboard(tester);

      await tester.tap(find.text('Call Next Ticket'));
      await tester.pump();
      await tester.pump();

      expect(repository.calledFrom, ['2']);
      expect(find.text('NOW SERVING'), findsOneWidget);
      expect(find.text('D-0001'), findsOneWidget);
      expect(find.text('Deposit'), findsOneWidget);
      await disposePage(tester);
    });

    testWidgets('cannot call another ticket while serving one', (tester) async {
      repository.nextResults.add(officerTicket());
      await pumpDashboard(tester);

      await tester.tap(find.text('Call Next Ticket'));
      await tester.pump();
      await tester.pump();

      expect(button(tester, 'Call Next Ticket').onPressed, isNull);
      expect(find.text('Complete the current ticket to call the next one.'), findsOneWidget);
      await disposePage(tester);
    });

    testWidgets('Done / Complete closes the ticket and frees the counter', (tester) async {
      repository.nextResults.add(officerTicket(id: '3'));
      await pumpDashboard(tester);
      await tester.tap(find.text('Call Next Ticket'));
      await tester.pump();
      await tester.pump();

      await tester.tap(find.text('Done / Complete'));
      await tester.pump();
      await tester.pump();

      expect(repository.completed, ['3']);
      expect(find.text('No ticket being served'), findsOneWidget);
      expect(button(tester, 'Call Next Ticket').onPressed, isNotNull);
      await disposePage(tester);
    });

    testWidgets('with empty queues it says there are no tickets', (tester) async {
      repository.nextResults.add(null);
      await pumpDashboard(tester);

      await tester.tap(find.text('Call Next Ticket'));
      await tester.pump();
      await tester.pump();

      expect(find.text('No tickets available'), findsOneWidget);
      expect(find.text('No ticket being served'), findsOneWidget);
      await disposePage(tester);
    });

    testWidgets('shows an error when the call fails', (tester) async {
      repository.nextResults.add(Exception('offline'));
      await pumpDashboard(tester);

      await tester.tap(find.text('Call Next Ticket'));
      await tester.pump();
      await tester.pump();

      expect(find.text('Could not call next'), findsOneWidget);
      await disposePage(tester);
    });
  });
}
