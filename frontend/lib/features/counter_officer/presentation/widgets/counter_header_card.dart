import 'package:flutter/material.dart';
import 'package:frontend/core/constants/app_colors.dart';
import 'package:frontend/core/constants/app_radius.dart';
import 'package:frontend/core/constants/app_spacing.dart';
import 'package:frontend/core/utils/context_extensions.dart';

import '../../domain/entities/counter.dart';

class CounterHeaderCard extends StatelessWidget {
  final Counter counter;
  const CounterHeaderCard({super.key, required this.counter});

  @override
  Widget build(BuildContext context) {
    final text = context.textTheme;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.iconNeutral,
        borderRadius: BorderRadius.circular(AppRadius.lg),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.sm,
              vertical: AppSpacing.xs,
            ),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(AppRadius.sm),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.circle, size: 10, color: AppColors.success),
                const SizedBox(width: AppSpacing.xs),
                Text(
                  'ACTIVE & ONLINE',
                  style: text.labelSmall?.copyWith(
                    color: AppColors.success,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.8,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(counter.name, style: text.headlineSmall),
          Text(
            counter.description,
            style: text.bodyMedium?.copyWith(color: AppColors.muted),
          ),
        ],
      ),
    );
  }
}