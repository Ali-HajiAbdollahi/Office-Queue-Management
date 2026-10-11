// End-to-end test: the real app talks to the real backend, which uses a test database.
// Run it from the backend with `npm run test:frontend-e2e` (it seeds demo data and passes E2E_API_URL).
// When run with a plain `flutter test`, it is skipped.
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/features/counter_officer/data/datasources/remote_counter_officer_data_source.dart';
import 'package:frontend/features/counter_officer/data/repositories/counter_officer_repository_impl.dart';
import 'package:frontend/features/counter_officer/domain/repositories/counter_officer_repository.dart';
import 'package:frontend/features/counter_officer/presentation/pages/counter_selection_page.dart';
import 'package:frontend/features/customer/data/repositories/customer_repository_impl.dart';
import 'package:frontend/features/customer/presentation/pages/customer_page.dart';
import 'package:frontend/main.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _apiUrl = String.fromEnvironment('E2E_API_URL');
const _skip = _apiUrl == ''
    ? 'E2E_API_URL is not set: run npm run test:frontend-e2e'
    : null;

CustomerRepositoryImpl _customerRepository() =>
    CustomerRepositoryImpl(dio: Dio(BaseOptions(baseUrl: _apiUrl)));

CounterOfficerRepository _officerRepository() => CounterOfficerRepositoryImpl(
  RemoteCounterOfficerDataSource(Dio(BaseOptions(baseUrl: '$_apiUrl/api'))),
);

/// Waits until [finder] appears. Responses come from the real network (runAsync),
/// but Dio also uses timers of the test's fake clock, so that clock is advanced too.
Future<void> _waitFor(
  WidgetTester tester,
  Finder finder, {
  Duration timeout = const Duration(seconds: 10),
}) async {
  final end = DateTime.now().add(timeout);
  while (DateTime.now().isBefore(end)) {
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 50)),
    );
    await tester.pump(const Duration(milliseconds: 50));
    if (finder.evaluate().isNotEmpty) return;
  }
  final onScreen = find
      .byType(Text)
      .evaluate()
      .map((e) => (e.widget as Text).data)
      .whereType<String>();
  throw TestFailure(
    'Not found after ${timeout.inSeconds}s: $finder\nOn screen: ${onScreen.join(' | ')}',
  );
}

/// Removes the app and lets the remaining timers expire (polling and counters).
Future<void> _closeApp(WidgetTester tester) async {
  await tester.pumpWidget(const SizedBox());
  await tester.pump(const Duration(seconds: 10));
}

void main() {
  setUp(() {
    // flutter_test blocks the network by default: here the real one is needed.
    HttpOverrides.global = null;
    SharedPreferences.setMockInitialValues({});
  });

  testWidgets(
    'from the role selection the customer sees the backend services',
    (tester) async {
      await tester.pumpWidget(
        MyApp(
          repository: _customerRepository(),
          counterOfficerRepository: _officerRepository(),
        ),
      );

      await tester.tap(find.text('Customer'));
      await _waitFor(tester, find.text('Shipping'));

      expect(find.text('Deposit'), findsOneWidget);
      expect(find.text('5m wait'), findsOneWidget);
      expect(find.text('8m wait'), findsOneWidget);
      await _closeApp(tester);
    },
    skip: _skip != null,
  );

  testWidgets(
    'the customer takes a ticket and the officer calls it to their counter',
    (tester) async {
      final screens = await _pumpCustomerAndOfficer(tester);

      // 1. The customer chooses Deposit and gets the first ticket of the day.
      await _waitFor(tester, screens.customer(find.text('Deposit')));
      await tester.tap(screens.customer(find.text('Get Ticket')).at(1));
      await _waitFor(tester, screens.customer(find.text('D-0001')));
      expect(screens.customer(find.text('WAITING')), findsOneWidget);

      // 2. The officer opens Counter 2 (which serves only Deposit) and calls the next one: D-0001.
      await _openCounter2AndCallNext(tester, screens);
      await _waitFor(tester, screens.officer(find.text('D-0001')));
      expect(screens.officer(find.text('Deposit')), findsOneWidget);

      // 3. The officer completes the ticket; with an empty queue, Call Next finds nobody.
      await tester.tap(screens.officer(find.text('Done / Complete')));
      await _waitFor(
        tester,
        screens.officer(find.text('No ticket being served')),
      );
      await tester.tap(screens.officer(find.text('Call Next Ticket')));
      await _waitFor(
        tester,
        screens.officer(find.text('No tickets available')),
      );

      await _closeApp(tester);
    },
    skip: _skip != null,
  );

  // KNOWN ISSUE (story "Call customer", not in this sprint): as soon as the ticket is called
  // the backend answers is_active = false and the customer app treats it as finished, so it removes it
  // instead of showing CALLED. Remove `skip: true` when the story is implemented.
  testWidgets('the customer sees that their ticket has been called', (
    tester,
  ) async {
    final screens = await _pumpCustomerAndOfficer(tester);
    await _waitFor(tester, screens.customer(find.text('Deposit')));
    await tester.tap(screens.customer(find.text('Get Ticket')).at(1));
    await _waitFor(tester, screens.customer(find.text('D-0002')));

    await _openCounter2AndCallNext(tester, screens);
    await _waitFor(tester, screens.officer(find.text('D-0002')));

    await tester.pump(
      const Duration(seconds: 5),
    ); // the phone refreshes every 5 seconds
    await _waitFor(tester, screens.customer(find.text('CALLED')));
    await _closeApp(tester);
  }, skip: true);
}

typedef _Screens = ({
  Finder Function(Finder) customer,
  Finder Function(Finder) officer,
});

/// Two screens side by side: the customer's phone on the left, the officer's desk on the right.
Future<_Screens> _pumpCustomerAndOfficer(WidgetTester tester) async {
  tester.view.physicalSize = const Size(2000, 1400);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);

  const customerKey = ValueKey('customer');
  const officerKey = ValueKey('officer');

  await tester.pumpWidget(
    Directionality(
      textDirection: TextDirection.ltr,
      child: Row(
        children: [
          Expanded(
            child: KeyedSubtree(
              key: customerKey,
              child: MaterialApp(
                home: CustomerPage(repository: _customerRepository()),
              ),
            ),
          ),
          Expanded(
            child: KeyedSubtree(
              key: officerKey,
              child: RepositoryProvider<CounterOfficerRepository>.value(
                value: _officerRepository(),
                child: const MaterialApp(home: CounterSelectionPage()),
              ),
            ),
          ),
        ],
      ),
    ),
  );

  return (
    customer: (f) => find.descendant(of: find.byKey(customerKey), matching: f),
    officer: (f) => find.descendant(of: find.byKey(officerKey), matching: f),
  );
}

Future<void> _openCounter2AndCallNext(
  WidgetTester tester,
  _Screens screens,
) async {
  await _waitFor(tester, screens.officer(find.text('Counter 2')));
  await tester.tap(screens.officer(find.text('Counter 2')));
  await tester.pump();
  await tester.tap(screens.officer(find.text('Continue to Counter 2')));
  await _waitFor(tester, screens.officer(find.text('Call Next Ticket')));
  await tester.tap(screens.officer(find.text('Call Next Ticket')));
}
