import 'dart:async';

import 'package:flutter/material.dart';
import 'package:frontend/core/theme/app_colors.dart';

import '../../domain/entities/ticket.dart';

class NowServingCard extends StatelessWidget {
  final Ticket? ticket;
  final bool canComplete;
  final VoidCallback onComplete;

  const NowServingCard({
    super.key,
    required this.ticket,
    required this.canComplete,
    required this.onComplete,
  });

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final t = ticket;

    return Material(
      color: AppColors.surface,
      borderRadius: BorderRadius.circular(16),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          Container(height: 4, color: AppColors.primary),
          Padding(
            padding: const EdgeInsets.all(16),
            child: t == null ? _empty(text) : _content(text, t),
          ),
        ],
      ),
    );
  }

  Widget _empty(TextTheme text) => SizedBox(
        width: double.infinity,
        child: Column(
          children: [
            const SizedBox(height: 16),
            const Icon(Icons.hourglass_empty,
                size: 40, color: AppColors.textSecondary),
            const SizedBox(height: 12),
            Text('No ticket being served',
                style: text.titleMedium?.copyWith(fontWeight: FontWeight.w600)),
            Text('Call the next ticket to start',
                style: text.bodyMedium
                    ?.copyWith(color: AppColors.textSecondary)),
            const SizedBox(height: 16),
          ],
        ),
      );

  Widget _content(TextTheme text, Ticket t) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _Chip(
                icon: Icons.record_voice_over_outlined,
                label: 'NOW SERVING',
                color: AppColors.primary,
                background: AppColors.primarySoft,
              ),
              if (t.calledAt != null) _ElapsedTimer(since: t.calledAt!),
            ],
          ),
          const SizedBox(height: 16),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 24),
            decoration: BoxDecoration(
              color: AppColors.background,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              t.code,
              textAlign: TextAlign.center,
              style: text.displayMedium?.copyWith(fontWeight: FontWeight.w800),
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(child: _InfoBox(label: 'Service Type', value: t.serviceType)),
              const SizedBox(width: 12),
              Expanded(
                  child: _InfoBox(
                      label: 'Arrival Time', value: _formatTime(t.arrivalTime))),
            ],
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            height: 52,
            child: FilledButton.icon(
              onPressed: canComplete ? onComplete : null,
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.success,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8)),
              ),
              icon: const Icon(Icons.check_circle_outline),
              label: const Text('Done / Complete',
                  style: TextStyle(fontWeight: FontWeight.w600)),
            ),
          ),
        ],
      );
}

String _formatTime(DateTime d) {
  final h = d.hour % 12 == 0 ? 12 : d.hour % 12;
  final m = d.minute.toString().padLeft(2, '0');
  return '$h:$m ${d.hour >= 12 ? 'PM' : 'AM'}';
}

class _Chip extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final Color background;

  const _Chip({
    required this.icon,
    required this.label,
    required this.color,
    required this.background,
  });

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: background,
          borderRadius: BorderRadius.circular(6),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 16, color: color),
            const SizedBox(width: 6),
            Text(label,
                style: Theme.of(context).textTheme.labelMedium?.copyWith(
                    color: color,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.8)),
          ],
        ),
      );
}

class _InfoBox extends StatelessWidget {
  final String label;
  final String value;
  const _InfoBox({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label,
              style: text.labelMedium?.copyWith(color: AppColors.textSecondary)),
          const SizedBox(height: 4),
          Text(value,
              style: text.titleSmall?.copyWith(fontWeight: FontWeight.w700)),
        ],
      ),
    );
  }
}

class _ElapsedTimer extends StatefulWidget {
  final DateTime since;
  const _ElapsedTimer({required this.since});

  @override
  State<_ElapsedTimer> createState() => _ElapsedTimerState();
}

class _ElapsedTimerState extends State<_ElapsedTimer> {
  late final Timer _timer;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _timer.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final d = DateTime.now().difference(widget.since);
    final mm = d.inMinutes.toString().padLeft(2, '0');
    final ss = (d.inSeconds % 60).toString().padLeft(2, '0');
    return _Chip(
      icon: Icons.timer_outlined,
      label: '$mm:$ss',
      color: AppColors.textSecondary,
      background: AppColors.surfaceMuted,
    );
  }
}