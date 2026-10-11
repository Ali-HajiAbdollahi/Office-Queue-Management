import 'package:flutter/material.dart';
import 'package:frontend/core/constants/app_colors.dart';
import 'package:frontend/core/constants/app_radius.dart';
import 'package:frontend/core/constants/app_spacing.dart';
import 'package:frontend/core/utils/context_extensions.dart';

import '../../domain/entities/queue_summary.dart';

class UpNextCard extends StatelessWidget {
  final QueueSummary queue;
  final bool canCallNext;
  final bool isServing;
  final bool isBusy;
  final VoidCallback onCallNext;

  const UpNextCard({
    super.key,
    required this.queue,
    required this.canCallNext,
    required this.isServing,
    required this.isBusy,
    required this.onCallNext,
  });

  @override
  Widget build(BuildContext context) {
    final text = context.textTheme;
    return Material(
      color: AppColors.surface,
      borderRadius: BorderRadius.circular(AppRadius.lg),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text('Up Next', style: text.titleLarge),
                const SizedBox(width: AppSpacing.sm),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.sm,
                    vertical: AppSpacing.xxs,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.primaryTint,
                    borderRadius: BorderRadius.circular(AppRadius.pill),
                  ),
                  child: Text(
                    '${queue.waitingCount} in queue',
                    style: text.labelLarge?.copyWith(
                      color: AppColors.primary,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.md),
            SizedBox(
              width: double.infinity,
              height: 56,
              child: FilledButton(
                onPressed: canCallNext ? onCallNext : null,
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  // durante il caricamento il bottone resta blu
                  disabledBackgroundColor:
                      isBusy ? AppColors.primary : AppColors.border,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(AppRadius.md),
                  ),
                ),
                child: isBusy
                    ? const SizedBox(
                        width: 24,
                        height: 24,
                        child: CircularProgressIndicator(
                          strokeWidth: 2.5,
                          color: Colors.white,
                        ),
                      )
                    : Row(
                        children: [
                          const Icon(Icons.play_arrow_rounded, size: 28),
                          const SizedBox(width: AppSpacing.sm),
                          const Expanded(
                            child: Text(
                              'Call Next Ticket',
                              style: TextStyle(
                                  fontSize: 18, fontWeight: FontWeight.w600),
                            ),
                          ),
                          if (queue.nextTicketCode != null)
                            Text(
                              'Next: ${queue.nextTicketCode}',
                              style:
                                  const TextStyle(fontWeight: FontWeight.w600),
                            ),
                        ],
                      ),
              ),
            ),
            if (isServing) ...[
              const SizedBox(height: AppSpacing.xs),
              Text('Complete the current ticket to call the next one.',
                  style: text.labelSmall),
            ] else if (queue.isEmpty) ...[
              const SizedBox(height: AppSpacing.xs),
              Text('The queue is empty.', style: text.labelSmall),
            ],
          ],
        ),
      ),
    );
  }
}