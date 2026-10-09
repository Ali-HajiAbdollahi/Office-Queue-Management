import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:frontend/core/theme/app_colors.dart';

import '../../domain/repositories/counter_officer_repository.dart';
import '../../domain/usecases/get_counters.dart';
import '../blocs/counter_selection/counter_selection_cubit.dart';
import '../blocs/counter_selection/counter_selection_state.dart';
import '../widgets/counter_tile.dart';
import 'officer_dashboard_page.dart';

class CounterSelectionPage extends StatelessWidget {
  const CounterSelectionPage({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (ctx) => CounterSelectionCubit(
        GetCounters(ctx.read<CounterOfficerRepository>()),
      )..load(),
      child: const _CounterSelectionView(),
    );
  }
}

class _CounterSelectionView extends StatelessWidget {
  const _CounterSelectionView();

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;

    return Scaffold(
      appBar: AppBar(
        leading: BackButton(onPressed: () => Navigator.maybePop(context)),
        title: const Text('Back'),
        titleSpacing: 0,
      ),
      body: BlocBuilder<CounterSelectionCubit, CounterSelectionState>(
        builder: (context, state) {
          return Column(
            children: [
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                  children: [
                    Text('Select Counter',
                        style: text.headlineLarge
                            ?.copyWith(fontWeight: FontWeight.w800)),
                    const SizedBox(height: 4),
                    Text('Choose your counter to sign in',
                        style: text.titleMedium
                            ?.copyWith(color: AppColors.textSecondary)),
                    const SizedBox(height: 16),
                    ..._body(context, state),
                  ],
                ),
              ),
              _ContinueBar(state: state),
            ],
          );
        },
      ),
    );
  }

  List<Widget> _body(BuildContext context, CounterSelectionState state) {
    switch (state.status) {
      case CounterSelectionStatus.loading:
        return const [
          Padding(
            padding: EdgeInsets.only(top: 48),
            child: Center(child: CircularProgressIndicator()),
          ),
        ];
      case CounterSelectionStatus.failure:
        return [
          const SizedBox(height: 48),
          const Center(child: Text('Could not load counters')),
          Center(
            child: TextButton(
              onPressed: () => context.read<CounterSelectionCubit>().load(),
              child: const Text('Retry'),
            ),
          ),
        ];
      case CounterSelectionStatus.loaded:
        return [
          for (final c in state.counters) ...[
            CounterTile(
              counter: c,
              selected: state.selected?.id == c.id,
              onTap: () => context.read<CounterSelectionCubit>().select(c),
            ),
            const SizedBox(height: 12),
          ],
        ];
    }
  }
}

class _ContinueBar extends StatelessWidget {
  final CounterSelectionState state;
  const _ContinueBar({required this.state});

  @override
  Widget build(BuildContext context) {
    final selected = state.selected;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: const BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(color: Color(0x1A000000), blurRadius: 16, offset: Offset(0, -4)),
        ],
      ),
      child: SafeArea(
        top: false,
        child: SizedBox(
          width: double.infinity,
          height: 52,
          child: FilledButton(
            onPressed: selected == null
                ? null
                : () => Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => OfficerDashboardPage(counter: selected),
                      ),
                    ),
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.primary,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  selected == null
                      ? 'Select a counter'
                      : 'Continue to ${selected.name}',
                  style: const TextStyle(
                      fontSize: 16, fontWeight: FontWeight.w600),
                ),
                if (selected != null) ...[
                  const SizedBox(width: 8),
                  const Icon(Icons.arrow_forward, size: 20),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}