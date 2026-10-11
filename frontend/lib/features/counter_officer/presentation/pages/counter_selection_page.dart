import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:frontend/core/constants/app_colors.dart';
import 'package:frontend/core/constants/app_radius.dart';
import 'package:frontend/core/constants/app_spacing.dart';
import 'package:frontend/core/utils/context_extensions.dart';

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
    final text = context.textTheme;

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
                  padding: const EdgeInsets.fromLTRB(
                    AppSpacing.md,
                    AppSpacing.xs,
                    AppSpacing.md,
                    AppSpacing.md,
                  ),
                  children: [
                    Text('Select Counter', style: text.headlineLarge),
                    const SizedBox(height: AppSpacing.xxs),
                    Text(
                      'Choose your counter to sign in',
                      style: text.bodyLarge?.copyWith(color: AppColors.muted),
                    ),
                    const SizedBox(height: AppSpacing.md),
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
            padding: EdgeInsets.only(top: AppSpacing.xxl),
            child: Center(child: CircularProgressIndicator()),
          ),
        ];
      case CounterSelectionStatus.failure:
        return [
          const SizedBox(height: AppSpacing.xxl),
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
            const SizedBox(height: AppSpacing.sm),
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
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.surface,
        boxShadow: [
          BoxShadow(
            color: AppColors.secondary.withValues(alpha: 0.1),
            blurRadius: 16,
            offset: const Offset(0, -4),
          ),
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
                borderRadius: BorderRadius.circular(AppRadius.md),
              ),
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
                  const SizedBox(width: AppSpacing.xs),
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