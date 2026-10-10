import 'package:flutter/material.dart';
import 'package:frontend/core/theme/app_colors.dart';

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
    final text = Theme.of(context).textTheme;
    return Material(
      color: AppColors.surface,
      borderRadius: BorderRadius.circular(16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text('Up Next',
                    style:
                        text.titleLarge?.copyWith(fontWeight: FontWeight.w600)),
                const SizedBox(width: 10),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppColors.primarySoft,
                    borderRadius: BorderRadius.circular(20),
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
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              height: 56,
              child: FilledButton(
                onPressed: canCallNext ? onCallNext : null,
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  disabledBackgroundColor:
                      isBusy ? AppColors.primary : const Color(0xFFE1E2E4),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8)),
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
                          const SizedBox(width: 12),
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
              const SizedBox(height: 8),
              Text('Complete the current ticket to call the next one.',
                  style: text.bodySmall
                      ?.copyWith(color: AppColors.textSecondary)),
            ] else if (queue.isEmpty) ...[
              const SizedBox(height: 8),
              Text('The queue is empty.',
                  style: text.bodySmall
                      ?.copyWith(color: AppColors.textSecondary)),
            ],
          ],
        ),
      ),
    );
  }
}