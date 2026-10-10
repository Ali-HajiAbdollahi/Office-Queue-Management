import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:frontend/core/theme/app_colors.dart';

import '../../domain/entities/counter.dart';
import '../../domain/repositories/counter_officer_repository.dart';
import '../../domain/usecases/call_next_ticket.dart';
import '../../domain/usecases/complete_ticket.dart';
import '../blocs/officer_dashboard/officer_dashboard_cubit.dart';
import '../blocs/officer_dashboard/officer_dashboard_state.dart';
import '../widgets/counter_header_card.dart';
import '../widgets/error_view.dart';
import '../widgets/now_serving_card.dart';
import '../widgets/up_next_card.dart';

class OfficerDashboardPage extends StatelessWidget {
  final Counter counter;
  const OfficerDashboardPage({super.key, required this.counter});

  @override
  Widget build(BuildContext context) {
    final repo = context.read<CounterOfficerRepository>();
    return BlocProvider(
      create: (_) => OfficerDashboardCubit(
        counter: counter,
        repository: repo,
        callNextTicket: CallNextTicket(repo),
        completeTicket: CompleteTicket(repo),
      )..start(),
      child: const _OfficerDashboardView(),
    );
  }
}

class _OfficerDashboardView extends StatelessWidget {
  const _OfficerDashboardView();

  /// Messaggio usato dal Cubit quando la coda è vuota.
  /// Non è un errore tecnico, quindi lo mostriamo con un colore neutro.
  static const _noTicketsMessage = 'No tickets available';

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;

    return BlocConsumer<OfficerDashboardCubit, OfficerDashboardState>(
      // La snackbar serve per gli errori delle azioni (Call Next / Done).
      // Se la connessione è caduta (status failure) c'è già ErrorView.
      listenWhen: (prev, curr) =>
          prev.errorMessage != curr.errorMessage &&
          curr.errorMessage != null &&
          curr.status != OfficerDashboardStatus.failure,
      listener: (context, state) {
        final isNoTickets = state.errorMessage == _noTicketsMessage;
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(
            SnackBar(
              content: Text(state.errorMessage!),
              backgroundColor:
                  isNoTickets ? null : Theme.of(context).colorScheme.error,
            ),
          );
      },
      builder: (context, state) {
        final cubit = context.read<OfficerDashboardCubit>();
        return Scaffold(
          appBar: AppBar(
            leading: BackButton(onPressed: () => Navigator.maybePop(context)),
            title: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('QueueFlow',
                    style:
                        text.titleLarge?.copyWith(fontWeight: FontWeight.w700)),
                Text('MY DESK',
                    style: text.labelSmall?.copyWith(
                        color: AppColors.textSecondary, letterSpacing: 1.2)),
              ],
            ),
          ),
          body: switch (state.status) {
            OfficerDashboardStatus.loading =>
              const Center(child: CircularProgressIndicator()),
            OfficerDashboardStatus.failure => ErrorView(
                message: state.errorMessage ?? 'Something went wrong',
                onRetry: cubit.start,
              ),
            OfficerDashboardStatus.ready => ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  CounterHeaderCard(counter: state.counter),
                  const SizedBox(height: 16),
                  NowServingCard(
                    ticket: state.currentTicket,
                    canComplete: state.canComplete,
                    onComplete: cubit.complete,
                  ),
                  const SizedBox(height: 16),
                  UpNextCard(
                    queue: state.queue,
                    canCallNext: state.canCallNext,
                    isServing: state.isServing,
                    isBusy: state.isBusy,
                    onCallNext: cubit.callNext,
                  ),
                ],
              ),
          },
        );
      },
    );
  }
}