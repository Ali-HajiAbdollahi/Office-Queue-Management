import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/core/enums/ticket_status.dart';
import 'package:frontend/features/customer/presentation/blocs/customer_cubit.dart';
import 'package:frontend/features/customer/presentation/blocs/customer_state.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../helpers/fake_customer_repository.dart';
import '../../helpers/stub_dio.dart';

const _savedTicketKey = 'active_ticket_id';
const _pollInterval = Duration(seconds: 5);

Future<int?> _savedTicketId() async => (await SharedPreferences.getInstance()).getInt(_savedTicketKey);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late FakeCustomerRepository repository;
  late CustomerCubit cubit;
  late List<CustomerState> states;

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    repository = FakeCustomerRepository();
    cubit = CustomerCubit(repository: repository);
    states = [];
    cubit.stream.listen(states.add);
  });

  // Closing is not awaited: in testWidgets the cubit lives in the fake clock zone
  // and its close would never complete outside of it.
  tearDown(() => unawaited(cubit.close()));

  group('loadInitialData', () {
    test('shows loading, then the services without a ticket', () async {
      await cubit.loadInitialData();

      expect(states.first, isA<CustomerLoading>());
      final loaded = cubit.state as CustomerLoaded;
      expect(loaded.services.map((s) => s.tag), ['Shipping', 'Deposit']);
      expect(loaded.activeTicket, isNull);
    });

    test('restores the customer ticket that is still active', () async {
      repository.activeTicket = customerTicket(code: 'S-0004');

      await cubit.loadInitialData();

      expect((cubit.state as CustomerLoaded).activeTicket?.code, 'S-0004');
    });

    test('shows an error when the services cannot be loaded', () async {
      repository.servicesError = Exception('offline');

      await cubit.loadInitialData();

      expect(cubit.state, isA<CustomerError>());
      expect((cubit.state as CustomerError).message, contains('offline'));
    });
  });

  group('getNewTicket', () {
    test('issues a ticket for the chosen service, shows it and saves its id', () async {
      await cubit.loadInitialData();

      await cubit.getNewTicket(2);

      expect(repository.issuedFor, [2]);
      final loaded = cubit.state as CustomerLoaded;
      expect(loaded.activeTicket?.code, 'S-0001');
      expect(loaded.services, hasLength(2), reason: 'the services stay available');
      expect(await _savedTicketId(), 7);
    });

    test('does nothing before the services are loaded', () async {
      await cubit.getNewTicket(1);

      expect(repository.issuedFor, isEmpty);
    });

    test('does not issue a second ticket while one is active', () async {
      repository.activeTicket = customerTicket();
      await cubit.loadInitialData();

      await cubit.getNewTicket(1);

      expect(repository.issuedFor, isEmpty);
    });

    test('two quick taps issue a single ticket', () async {
      await cubit.loadInitialData();
      repository.issueCompleter = Completer();

      final first = cubit.getNewTicket(1);
      final second = cubit.getNewTicket(1);
      repository.issueCompleter!.complete(customerTicket());
      await Future.wait([first, second]);

      expect(repository.issuedFor, [1]);
    });

    test('when the server rejects the request it shows an error and saves nothing', () async {
      await cubit.loadInitialData();
      repository.issueError = httpError(409);

      await cubit.getNewTicket(1);

      expect(cubit.state, isA<CustomerError>());
      expect(await _savedTicketId(), isNull);
    });
  });

  group('ticket refresh every 5 seconds', () {
    // testWidgets uses a fake clock: tester.pump(duration) fires the timer immediately.
    // The cubit is created inside the test so that its timer also uses the fake clock.
    Future<void> issueTicket(WidgetTester tester) async {
      unawaited(cubit.close());
      repository = FakeCustomerRepository();
      cubit = CustomerCubit(repository: repository);
      await cubit.loadInitialData();
      await cubit.getNewTicket(1);
      await tester.pump();
    }

    // Note: the real backend sends is_active = false as soon as the ticket is called (see test/e2e);
    // this only checks that a ticket that is still active is updated with the server data.
    testWidgets('a ticket that is still active is updated with the server data', (tester) async {
      await issueTicket(tester);
      repository.statusResponses.add(customerTicket(status: TicketStatus.called, counterId: 2));

      await tester.pump(_pollInterval);

      final ticket = (cubit.state as CustomerLoaded).activeTicket;
      expect(ticket?.status, TicketStatus.called);
      expect(ticket?.counterId, 2);
      await cubit.close();
    });

    testWidgets('no request before 5 seconds', (tester) async {
      await issueTicket(tester);
      repository.statusResponses.add(customerTicket());

      await tester.pump(const Duration(seconds: 4));
      expect(repository.statusCalls, 0);
      await tester.pump(const Duration(seconds: 1));
      expect(repository.statusCalls, 1);
      await cubit.close();
    });

    testWidgets('when the ticket is no longer active it is removed and forgotten', (tester) async {
      await issueTicket(tester);
      repository.statusResponses.add(customerTicket(isActive: false, status: TicketStatus.completed));

      await tester.pump(_pollInterval);
      await tester.pump();

      expect((cubit.state as CustomerLoaded).activeTicket, isNull);
      expect(await _savedTicketId(), isNull);

      await tester.pump(_pollInterval * 2);
      expect(repository.statusCalls, 1, reason: 'afterwards the refresh stops');
      await cubit.close();
    });

    testWidgets('when the server no longer finds the ticket (404) it is removed and forgotten', (tester) async {
      await issueTicket(tester);
      repository.statusResponses.add(httpError(404));

      await tester.pump(_pollInterval);
      await tester.pump();

      expect((cubit.state as CustomerLoaded).activeTicket, isNull);
      expect(await _savedTicketId(), isNull);
      await cubit.close();
    });

    testWidgets('a temporary network error does not remove the ticket', (tester) async {
      await issueTicket(tester);
      repository.statusResponses
        ..add(httpError(500))
        ..add(customerTicket(status: TicketStatus.called, counterId: 1));

      await tester.pump(_pollInterval);
      expect((cubit.state as CustomerLoaded).activeTicket?.code, 'S-0001');
      expect(await _savedTicketId(), 7);

      await tester.pump(_pollInterval);
      expect((cubit.state as CustomerLoaded).activeTicket?.status, TicketStatus.called,
          reason: 'it retries on the next round');
      await cubit.close();
    });

    testWidgets('closing the page stops the refresh', (tester) async {
      await issueTicket(tester);
      repository.statusResponses.add(customerTicket());

      await cubit.close();
      await tester.pump(_pollInterval * 3);

      expect(repository.statusCalls, 0);
    });
  });
}
