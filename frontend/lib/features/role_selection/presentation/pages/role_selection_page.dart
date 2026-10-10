import 'package:flutter/material.dart';

import '../../../../core/constants/app_assets.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_spacing.dart';
import '../widgets/role_option_card.dart';

class RoleSelectionPage extends StatelessWidget {
  const RoleSelectionPage({super.key, this.onRoleSelected});

  final ValueChanged<String>? onRoleSelected;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.canvas,
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 448),
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.md,
                AppSpacing.md,
                AppSpacing.md,
                40,
              ),
              child: Column(
                children: [
                  const _RoleSelectionHeader(),
                  const SizedBox(height: 24),
                  Column(
                    children: [
                      RoleOptionCard(
                        title: 'Customer',
                        icon: Icons.confirmation_number_outlined,
                        isPrimary: true,
                        onTap: () => onRoleSelected?.call('Customer'),
                      ),
                      const SizedBox(height: 16),
                      RoleOptionCard(
                        title: 'Counter Officer',
                        icon: Icons.desktop_windows_outlined,
                        onTap: () => onRoleSelected?.call('Counter Officer'),
                      ),
                      const SizedBox(height: 16),
                      RoleOptionCard(
                        title: 'Manager / Admin',
                        icon: Icons.tune,
                        onTap: () => onRoleSelected?.call('Manager / Admin'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _RoleSelectionHeader extends StatelessWidget {
  const _RoleSelectionHeader();

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 224,
      child: Column(
        children: [
          _QueueFlowMark(),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
            decoration: BoxDecoration(
              color: AppColors.primaryTint,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 6,
                  height: 6,
                  decoration: const BoxDecoration(
                    color: AppColors.primary,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 6),
                Text(
                  'OPERATIONAL HUB',
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.55,
                    color: AppColors.muted,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'QueueFlow',
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
              fontSize: 28,
              height: 34 / 28,
              letterSpacing: -0.7,
              fontWeight: FontWeight.w600,
              color: AppColors.text,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Office Queue Management System',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              fontSize: 14,
              height: 20 / 14,
              color: AppColors.muted,
            ),
            textAlign: TextAlign.center,
          ),
          const Spacer(),
          Row(
            children: [
              const Expanded(child: Divider(color: AppColors.border)),
              Expanded(
                flex: 3,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(
                      'Select your role to continue',
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        fontWeight: FontWeight.w600,
                        letterSpacing: 0.48,
                        color: AppColors.secondary,
                      ),
                    ),
                  ),
                ),
              ),
              const Expanded(child: Divider(color: AppColors.border)),
            ],
          ),
        ],
      ),
    );
  }
}

class _QueueFlowMark extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Image.asset(
      AppAssets.queueFlowLogo,
      width: 96,
      height: 96,
      fit: BoxFit.contain,
    );
  }
}
