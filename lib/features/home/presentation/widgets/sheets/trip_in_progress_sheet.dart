import 'package:flutter/material.dart';
import '../../../../../core/constants/app_colors.dart';

class TripInProgressSheet extends StatelessWidget {
  final VoidCallback onPanic; // Safety feature
  final VoidCallback onShareTrip;

  const TripInProgressSheet({
    super.key,
    required this.onPanic,
    required this.onShareTrip,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      width: double.infinity,
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(16),
          topRight: Radius.circular(16),
        ),
        boxShadow: [
          BoxShadow(color: Colors.black12, blurRadius: 10, spreadRadius: 2),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Heading to Destination',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'On Trip · 15 min remaining',
                    style: TextStyle(
                      color: Colors.green,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              const CircleAvatar(
                radius: 24,
                backgroundColor: AppColors.background,
                child: Icon(Icons.shield, color: Colors.blue), // Safety icon
              ),
            ],
          ),
          const SizedBox(height: 24),
          const LinearProgressIndicator(value: 0.4), // Mock progress
          const SizedBox(height: 24),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildActionIcon(Icons.share, 'Share Status', onShareTrip),
              _buildActionIcon(
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
                isEmergency ? Colors.red[50] : AppColors.background,
            child: Icon(icon, color: isEmergency ? Colors.red : Colors.black),
          ),
          const SizedBox(height: 8),
          Text(label, style: const TextStyle(fontSize: 12)),
        ],
      ),
    );
  }
}
