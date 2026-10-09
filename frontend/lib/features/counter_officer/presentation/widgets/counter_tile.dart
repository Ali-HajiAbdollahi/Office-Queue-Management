import 'package:flutter/material.dart';
import 'package:frontend/core/theme/app_colors.dart';

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
    final text = Theme.of(context).textTheme;
    return Material(
      color: AppColors.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: selected ? AppColors.primary : AppColors.border,
          width: selected ? 2 : 1,
        ),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: selected ? AppColors.primary : AppColors.surfaceMuted,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  '${counter.number}',
                  style: text.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: selected ? Colors.white : AppColors.textPrimary,
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(counter.name,
                        style: text.titleMedium
                            ?.copyWith(fontWeight: FontWeight.w600)),
                    Text(counter.description,
                        style: text.bodyMedium
                            ?.copyWith(color: AppColors.textSecondary)),
                  ],
                ),
              ),
              Icon(
                selected ? Icons.check_circle : Icons.radio_button_unchecked,
                size: 28,
                color: selected ? AppColors.primary : const Color(0xFFC5C6D0),
              ),
            ],
          ),
        ),
      ),
    );
  }
}