import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter/foundation.dart';

import 'core/theme/app_theme.dart';
import 'features/counter_officer/data/datasources/remote_counter_officer_data_source.dart';
import 'features/counter_officer/data/repositories/counter_officer_repository_impl.dart';
import 'features/counter_officer/domain/repositories/counter_officer_repository.dart';
import 'features/counter_officer/presentation/pages/counter_selection_page.dart';
import 'features/customer/data/repositories/customer_repository_impl.dart';
import 'features/customer/domain/repositories/customer_repository.dart';
import 'features/customer/presentation/pages/customer_page.dart';
import 'features/role_selection/presentation/pages/role_selection_page.dart';

void main() {
  const apiBaseUrl = String.fromEnvironment(
    'API_URL',
    defaultValue: kIsWeb ? 'http://localhost:3000' : 'http://10.0.2.2:3000',
  );

  final dio = Dio(
    BaseOptions(
      baseUrl: apiBaseUrl,
      connectTimeout: const Duration(seconds: 10),
      receiveTimeout: const Duration(seconds: 10),
    ),
  );

  final customerRepository = CustomerRepositoryImpl(dio: dio);
  final counterOfficerRepository = CounterOfficerRepositoryImpl(
    RemoteCounterOfficerDataSource(
      Dio(BaseOptions(baseUrl: '$apiBaseUrl/api')),
    ),
  );

  runApp(
    MyApp(
      repository: customerRepository,
      counterOfficerRepository: counterOfficerRepository,
    ),
  );
}

class MyApp extends StatelessWidget {
  const MyApp({
    super.key,
    required this.repository,
    required this.counterOfficerRepository,
  });

  final CustomerRepository repository;
  final CounterOfficerRepository counterOfficerRepository;

  static final _navigatorKey = GlobalKey<NavigatorState>();

  // This widget is the root of your application.
  @override
  Widget build(BuildContext context) {
    return RepositoryProvider<CounterOfficerRepository>.value(
      value: counterOfficerRepository,
      child: MaterialApp(
        title: 'Executive Queue Hub',
        theme: AppTheme.light,
        navigatorKey: _navigatorKey,
        home: RoleSelectionPage(
          onRoleSelected: (role) {
            if (role == 'Customer') {
              _navigatorKey.currentState!.push(
                MaterialPageRoute<void>(
                  builder: (_) => CustomerPage(repository: repository),
                ),
              );
            } else if (role == 'Counter Officer') {
              _navigatorKey.currentState!.push(
                MaterialPageRoute<void>(
                  builder: (_) => const CounterSelectionPage(),
                ),
              );
            }
          },
        ),
      ),
    );
  }
}
