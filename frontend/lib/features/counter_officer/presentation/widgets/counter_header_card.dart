import 'package:flutter/material.dart';
import 'package:frontend/core/theme/app_colors.dart';

import '../../domain/entities/counter.dart';

class CounterHeaderCard extends StatelessWidget {
  final Counter counter;
  const CounterHeaderCard({super.key, required this.counter});

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surfaceMuted,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(6),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.circle, size: 10, color: AppColors.success),
                const SizedBox(width: 8),
                Text(
                  'ACTIVE & ONLINE',
                  style: text.labelMedium?.copyWith(
                    color: AppColors.success,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.8,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),
          Text(counter.name,
              style: text.headlineSmall?.copyWith(fontWeight: FontWeight.w700)),
          Text(counter.description,
              style: text.bodyMedium?.copyWith(color: AppColors.textSecondary)),
        ],
      ),
    );
  }
}