import 'package:flutter/material.dart';
import 'package:frontend/core/constants/app_colors.dart';
import 'package:frontend/core/constants/app_radius.dart';
import 'package:frontend/core/constants/app_spacing.dart';
import 'package:frontend/core/utils/context_extensions.dart';

import '../../domain/entities/counter.dart';

class CounterTile extends StatelessWidget {
  final Counter counter;
  final bool selected;
  final VoidCallback onTap;

  const CounterTile({
    super.key,
    required this.counter,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final text = context.textTheme;
    final shape = BorderRadius.circular(AppRadius.lg);

    return Material(
      color: AppColors.surface,
      shape: RoundedRectangleBorder(
        borderRadius: shape,
        side: BorderSide(
          color: selected ? AppColors.primary : AppColors.border,
          width: selected ? 2 : 1,
        ),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: shape,
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: selected ? AppColors.primary : AppColors.iconNeutral,
                  borderRadius: BorderRadius.circular(AppRadius.sm),
                ),
                child: Text(
                  '${counter.number}',
                  style: text.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: selected ? Colors.white : null,
                  ),
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(counter.name, style: text.titleMedium),
                      if (counter.description.isNotEmpty)
                      Text(
                        counter.description,
                        style:
                            text.bodyMedium?.copyWith(color: AppColors.muted),
                      ),
                  ],
                ),
              ),
              Icon(
                selected ? Icons.check_circle : Icons.radio_button_unchecked,
                size: 28,
                color: selected ? AppColors.primary : AppColors.border,
              ),
            ],
          ),
        ),
      ),
    );
  }
}