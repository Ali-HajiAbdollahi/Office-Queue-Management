import 'package:flutter/material.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_radius.dart';

class RoleOptionCard extends StatelessWidget {
  const RoleOptionCard({
    required this.title,
    required this.icon,
    required this.onTap,
    this.isPrimary = false,
    super.key,
  });

  final String title;
  final IconData icon;
  final VoidCallback onTap;
  final bool isPrimary;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.surface,
      elevation: 1,
      shadowColor: Colors.black.withValues(alpha: 0.05),
      borderRadius: BorderRadius.circular(AppRadius.md),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadius.md),
        child: SizedBox(
          height: 96,
          child: Stack(
            children: [
              Padding(
                padding: const EdgeInsets.all(24),
                child: Row(
                  children: [
                    _IconContainer(icon: icon, isPrimary: isPrimary),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Text(
                        title,
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                    ),
                    const Icon(
                      Icons.arrow_forward_ios_rounded,
                      size: 14,
                      color: AppColors.muted,
                    ),
                  ],
                ),
              ),
              if (isPrimary)
                Positioned.fill(
                  left: 0,
                  right: null,
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: Container(
                      width: 6,
                      height: 48,
                      decoration: const BoxDecoration(
                        color: AppColors.primary,
                        borderRadius: BorderRadius.horizontal(
                          right: Radius.circular(3),
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _IconContainer extends StatelessWidget {
  const _IconContainer({required this.icon, required this.isPrimary});

  final IconData icon;
  final bool isPrimary;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 48,
      height: 48,
      decoration: BoxDecoration(
        color: isPrimary ? AppColors.primaryTint : AppColors.iconNeutral,
        borderRadius: BorderRadius.circular(AppRadius.sm),
      ),
      child: Icon(
        icon,
        size: 22,
        color: isPrimary ? AppColors.primary : AppColors.secondary,
      ),
    );
  }
}
