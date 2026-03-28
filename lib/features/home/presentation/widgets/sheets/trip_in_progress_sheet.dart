import 'package:flutter/material.dart';
import '../../../../../core/constants/app_colors.dart';

class TripInProgressSheet extends StatelessWidget {
  final VoidCallback onPanic; // Safety feature
  final VoidCallback onShareTrip;
  final String? destinationAddress;
  final String? remainingTime;

  const TripInProgressSheet({
    super.key,
    required this.onPanic,
    required this.onShareTrip,
    this.destinationAddress,
    this.remainingTime,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      width: double.infinity,
      decoration: BoxDecoration(
        color: AppColors.background,
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(16),
          topRight: Radius.circular(16),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.3),
            blurRadius: 10,
            spreadRadius: 2,
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Heading to Destination',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'On Trip${remainingTime != null ? ' · $remainingTime remaining' : ''}',
                      style: const TextStyle(
                        color: Colors.green,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    if (destinationAddress != null) ...[
                      const SizedBox(height: 4),
                      Text(
                        destinationAddress!,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: AppColors.textSecondary,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ],
                ),
              ),
              CircleAvatar(
                radius: 24,
                backgroundColor: AppColors.secondary,
                child: const Icon(Icons.shield, color: AppColors.primary),
              ),
            ],
          ),
          const SizedBox(height: 24),
          const LinearProgressIndicator(value: null), // Indeterminate progress
          const SizedBox(height: 24),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildActionIcon(
                context,
                Icons.share,
                'Share Status',
                onShareTrip,
              ),
              _buildActionIcon(
                context,
                Icons.warning_amber,
                'Emergency',
                onPanic,
                isEmergency: true,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildActionIcon(
    BuildContext context,
    IconData icon,
    String label,
    VoidCallback onTap, {
    bool isEmergency = false,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        children: [
          CircleAvatar(
            radius: 24,
            backgroundColor:
                isEmergency
                    ? Colors.red.withValues(alpha: 0.2)
                    : AppColors.secondary,
            child: Icon(
              icon,
              color: isEmergency ? Colors.redAccent : AppColors.primary,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            label,
            style: const TextStyle(
              fontSize: 12,
              color: AppColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}
