import 'package:flutter/material.dart';
import '../../../../../core/constants/app_colors.dart';
import '../../../../../core/services/pricing_service.dart';
import '../../../domain/models/vehicle.dart';
import '../../../../payment/domain/models/payment_method_model.dart';

class VehicleSelectionSheet extends StatelessWidget {
  final List<Vehicle> vehicles;
  final Vehicle? selectedVehicle;
  final ValueChanged<Vehicle> onVehicleSelected;
  final VoidCallback onConfirm;
  final double distanceKm;
  final PaymentMethod? selectedPaymentMethod;
  final VoidCallback? onPaymentMethodTap;

  const VehicleSelectionSheet({
    super.key,
    required this.vehicles,
    required this.selectedVehicle,
    required this.onVehicleSelected,
    required this.onConfirm,
    this.distanceKm = 5.0,
    this.selectedPaymentMethod,
    this.onPaymentMethodTap,
  });

  @override
  Widget build(BuildContext context) {
    final estimatedTime = PricingService.estimateTripMinutes(distanceKm);

    return Container(
      padding: const EdgeInsets.all(24),
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
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey[300],
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Choose a ride',
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                  fontSize: 18,
                ),
              ),
              Text(
                '${distanceKm.toStringAsFixed(1)} km • ~$estimatedTime min',
                style: const TextStyle(color: Colors.grey, fontSize: 14),
              ),
            ],
          ),
          const SizedBox(height: 16),
          // Scrollable vehicle list
          Flexible(
            child: SingleChildScrollView(
              child: Column(
                children:
                    vehicles.map((vehicle) {
                      final price = PricingService.calculatePrice(
                        vehicle.id,
                        distanceKm,
                      );
                      return GestureDetector(
                        onTap: () => onVehicleSelected(vehicle),
                        child: _buildVehicleOption(
                          vehicle.name,
                          vehicle.description,
                          PricingService.formatPrice(price),
                          vehicle.imageAsset,
                          selectedVehicle == vehicle,
                        ),
                      );
                    }).toList(),
              ),
            ),
          ),

          const SizedBox(height: 16),
          // Payment Method Selector
          if (selectedPaymentMethod != null)
            GestureDetector(
              onTap: onPaymentMethodTap,
              child: Row(
                children: [
                  Icon(
                    selectedPaymentMethod!.type == PaymentType.cash
                        ? Icons.money
                        : Icons.credit_card,
                    color: Colors.black,
                  ),
                  const SizedBox(width: 12),
                  Text(
                    selectedPaymentMethod!.name,
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  const Spacer(),
                  const Icon(Icons.keyboard_arrow_right, color: Colors.grey),
                ],
              ),
            ),

          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: onConfirm,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.black,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
              child: Text(
                'Confirm ${selectedVehicle?.name ?? 'Ride'}',
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildVehicleOption(
    String name,
    String description,
    String price,
    String asset,
    bool isSelected,
  ) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
      decoration: BoxDecoration(
        color: isSelected ? AppColors.background : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border:
            isSelected
                ? Border.all(color: Colors.black, width: 2)
                : Border.all(color: Colors.grey[300]!),
      ),
      child: Row(
        children: [
          // Vehicle icon
          Container(
            width: 60,
            height: 40,
            decoration: BoxDecoration(
              color: Colors.grey[200],
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(
              name == 'Black' ? Icons.local_taxi : Icons.directions_car,
              color: Colors.black87,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
                Text(
                  description,
                  style: const TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                price,
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
