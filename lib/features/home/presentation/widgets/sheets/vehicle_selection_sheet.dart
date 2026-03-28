import 'package:flutter/material.dart';
import '../../../../../core/services/pricing_service.dart';
import '../../../domain/models/vehicle.dart';
import '../../../../payment/domain/models/payment_method_model.dart';

class VehicleSelectionSheet extends StatefulWidget {
  final List<Vehicle> vehicles;
  final Vehicle? selectedVehicle;
  final ValueChanged<Vehicle> onVehicleSelected;
  final VoidCallback onConfirm;
  final double distanceKm;
  final PaymentMethod? selectedPaymentMethod;
  final VoidCallback? onPaymentMethodTap;
  final Function(String)? onQuickDestTap;

  const VehicleSelectionSheet({
    super.key,
    required this.vehicles,
    required this.selectedVehicle,
    required this.onVehicleSelected,
    required this.onConfirm,
    this.distanceKm = 5.0,
    this.selectedPaymentMethod,
    this.onPaymentMethodTap,
    this.onQuickDestTap,
  });

  @override
  State<VehicleSelectionSheet> createState() => _VehicleSelectionSheetState();
}

class _VehicleSelectionSheetState extends State<VehicleSelectionSheet> {
  // Cache server prices by vehicle name
  Map<String, PriceEstimate> _serverPrices = {};
  bool _isLoadingPrices = true;

  @override
  void initState() {
    super.initState();
    _fetchAllPrices();
  }

  @override
  void didUpdateWidget(VehicleSelectionSheet oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.distanceKm != widget.distanceKm) {
      _fetchAllPrices();
    }
  }

  Future<void> _fetchAllPrices() async {
    if (widget.distanceKm <= 0) {
      setState(() => _isLoadingPrices = false);
      return;
    }

    setState(() => _isLoadingPrices = true);

    final futures = <String, Future<PriceEstimate>>{};
    for (final vehicle in widget.vehicles) {
      futures[vehicle.name] = PricingService.fetchServerPrice(
        vehicle.name,
        widget.distanceKm,
      );
    }

    final results = <String, PriceEstimate>{};
    for (final entry in futures.entries) {
      results[entry.key] = await entry.value;
    }

    if (mounted) {
      setState(() {
        _serverPrices = results;
        _isLoadingPrices = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.5,
      minChildSize: 0.35,
      maxChildSize: 0.85,
      expand: false,
      builder: (context, scrollController) {
        return Container(
          padding: const EdgeInsets.only(
            top: 12,
            left: 16,
            right: 16,
            bottom: 24,
          ),
          decoration: BoxDecoration(
            color: const Color(0xFF1C242E),
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(20),
              topRight: Radius.circular(20),
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.3),
                blurRadius: 15,
                spreadRadius: 5,
              ),
            ],
          ),
          child: CustomScrollView(
            controller: scrollController,
            slivers: [
              SliverToBoxAdapter(
                child: Column(
                  children: [
                    Center(
                      child: Container(
                        width: 48,
                        height: 4,
                        decoration: BoxDecoration(
                          color: Colors.grey[600],
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                    // Quick Destinations
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        GestureDetector(
                          onTap: () => widget.onQuickDestTap?.call('Home'),
                          child: _buildQuickDest(
                            context,
                            Icons.home,
                            'Home',
                            'Saved',
                            true,
                          ),
                        ),
                        GestureDetector(
                          onTap: () => widget.onQuickDestTap?.call('Work'),
                          child: _buildQuickDest(
                            context,
                            Icons.work,
                            'Work',
                            'Saved',
                            false,
                          ),
                        ),
                        GestureDetector(
                          onTap: () => widget.onQuickDestTap?.call('Gym'),
                          child: _buildQuickDest(
                            context,
                            Icons.history,
                            'Gym',
                            'Saved',
                            false,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Choose a ride',
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 18,
                          ),
                        ),
                        // Surge indicator
                        if (_serverPrices.isNotEmpty &&
                            _serverPrices.values.any((p) => p.hasSurge))
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.orange.withOpacity(0.2),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                color: Colors.orange.withOpacity(0.5),
                              ),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(
                                  Icons.bolt,
                                  color: Colors.orange,
                                  size: 14,
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  '${_serverPrices.values.first.surgeLabel} Surge',
                                  style: const TextStyle(
                                    color: Colors.orange,
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 16),
                  ],
                ),
              ),
              SliverList(
                delegate: SliverChildBuilderDelegate((context, index) {
                  final vehicle = widget.vehicles[index];

                  // Use server price if available, otherwise fall back to local
                  final serverEstimate = _serverPrices[vehicle.name];
                  final price = serverEstimate?.estimatedPrice ??
                      PricingService.calculatePrice(
                        vehicle.id,
                        widget.distanceKm,
                      );
                  final hasSurge = serverEstimate?.hasSurge ?? false;

                  // Dynamic ETA calculation
                  final baseEta = vehicle.etaMinutes;
                  final routeEta =
                      widget.distanceKm > 0
                          ? (widget.distanceKm * 2.0).round()
                          : 0;
                  final totalEta = baseEta + routeEta;
                  final now = DateTime.now();
                  final arrivalTime = now.add(Duration(minutes: totalEta));
                  final formattedTime =
                      '${arrivalTime.hour.toString().padLeft(2, '0')}:${arrivalTime.minute.toString().padLeft(2, '0')}';
                  final dynamicDescription =
                      widget.distanceKm > 0
                          ? '$totalEta min away • $formattedTime arrival'
                          : vehicle.description;

                  return GestureDetector(
                    onTap: () => widget.onVehicleSelected(vehicle),
                    child: _buildVehicleOption(
                      context,
                      vehicle.name,
                      dynamicDescription,
                      PricingService.formatPrice(price),
                      vehicle.imageAsset,
                      widget.selectedVehicle == vehicle,
                      hasSurge: hasSurge,
                      baseFare: serverEstimate != null
                          ? PricingService.formatPrice(
                              serverEstimate.baseFare)
                          : null,
                    ),
                  );
                }, childCount: widget.vehicles.length),
              ),
              SliverToBoxAdapter(
                child: Column(
                  children: [
                    const SizedBox(height: 16),
                    if (widget.selectedPaymentMethod != null) ...[
                      Container(
                        height: 1,
                        color: Colors.white.withOpacity(0.05),
                        margin: const EdgeInsets.symmetric(vertical: 8),
                      ),
                      GestureDetector(
                        onTap: widget.onPaymentMethodTap,
                        child: Row(
                          children: [
                            Icon(
                              widget.selectedPaymentMethod!.type ==
                                      PaymentType.cash
                                  ? Icons.money
                                  : Icons.credit_card,
                              color: Colors.white70,
                              size: 20,
                            ),
                            const SizedBox(width: 12),
                            const Text(
                              'Personal • ',
                              style: TextStyle(
                                color: Colors.white70,
                                fontSize: 13,
                              ),
                            ),
                            Text(
                              widget.selectedPaymentMethod!.name,
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 14,
                              ),
                            ),
                            const Spacer(),
                            const Icon(
                              Icons.keyboard_arrow_right,
                              color: Colors.grey,
                            ),
                          ],
                        ),
                      ),
                    ],
                    const SizedBox(height: 16),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: _isLoadingPrices ? null : widget.onConfirm,
                        style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 16),
                        ),
                        child: _isLoadingPrices
                            ? const SizedBox(
                                height: 20,
                                width: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : Text(
                                'Confirm ${widget.selectedVehicle?.name ?? 'Ride'}',
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildQuickDest(
    BuildContext context,
    IconData icon,
    String title,
    String eta,
    bool isSelected,
  ) {
    return Container(
      width: 72,
      padding: const EdgeInsets.symmetric(vertical: 12),
      decoration: BoxDecoration(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(40),
        border: Border.all(
          color: isSelected ? const Color(0xFF2b8cee) : Colors.white12,
          width: 1,
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color:
                  isSelected
                      ? const Color(0xFF2b8cee).withOpacity(0.2)
                      : Colors.white12,
              shape: BoxShape.circle,
            ),
            child: Icon(
              icon,
              color: isSelected ? const Color(0xFF2b8cee) : Colors.white,
              size: 22,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            title,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
              fontSize: 14,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 2),
          Text(
            eta,
            style: const TextStyle(color: Colors.grey, fontSize: 12),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildVehicleOption(
    BuildContext context,
    String name,
    String description,
    String price,
    String asset,
    bool isSelected, {
    bool hasSurge = false,
    String? baseFare,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
      decoration: BoxDecoration(
        color:
            isSelected
                ? const Color(0xFF2b8cee).withOpacity(0.1)
                : Colors.transparent,
        borderRadius: BorderRadius.circular(12),
        border:
            isSelected
                ? Border.all(color: const Color(0xFF2b8cee), width: 1.5)
                : Border.all(color: Colors.transparent),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // Vehicle icon
          Image.asset(
            asset,
            width: 60,
            height: 40,
            fit: BoxFit.contain,
            errorBuilder: (context, error, stackTrace) {
              return Icon(
                name == 'Comfort' ? Icons.local_taxi : Icons.directions_car,
                color: Colors.white,
                size: 40,
              );
            },
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      name,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(width: 8),
                    const Icon(Icons.person, color: Colors.grey, size: 14),
                    const SizedBox(width: 4),
                    Text(
                      name == 'XL' ? '6' : '4',
                      style: const TextStyle(color: Colors.grey, fontSize: 13),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  description,
                  style: const TextStyle(color: Colors.grey, fontSize: 12),
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                price,
                style: TextStyle(
                  color: isSelected ? const Color(0xFF2b8cee) : Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
              // Show base fare as strikethrough when surge is active
              if (hasSurge && baseFare != null)
                Text(
                  baseFare,
                  style: const TextStyle(
                    color: Colors.grey,
                    fontSize: 12,
                    decoration: TextDecoration.lineThrough,
                  ),
                ),
              // Show surge badge
              if (hasSurge)
                Container(
                  margin: const EdgeInsets.only(top: 2),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 4,
                    vertical: 1,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.orange.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.bolt, color: Colors.orange, size: 10),
                      SizedBox(width: 2),
                      Text(
                        'Surge',
                        style: TextStyle(
                          color: Colors.orange,
                          fontSize: 9,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}
