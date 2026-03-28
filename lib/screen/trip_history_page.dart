import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

class TripHistoryPage extends StatelessWidget {
  final String driverId;

  const TripHistoryPage({super.key, required this.driverId});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F1519),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1C242E),
        title: const Text(
          'Trip History',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        elevation: 0,
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('trips')
            .where('driverId', isEqualTo: driverId)
            .orderBy('date', descending: true)
            .limit(50)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
              child: CircularProgressIndicator(color: Color(0xFF2b8cee)),
            );
          }

          if (snapshot.hasError) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.error_outline, color: Colors.red, size: 48),
                  const SizedBox(height: 16),
                  Text(
                    'Error loading trips:\n${snapshot.error}',
                    style: const TextStyle(color: Colors.white70),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            );
          }

          final docs = snapshot.data?.docs ?? [];

          if (docs.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.directions_car_outlined,
                    color: Colors.white.withOpacity(0.3),
                    size: 64,
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'No completed trips yet',
                    style: TextStyle(
                      color: Colors.white70,
                      fontSize: 16,
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Your completed trips will appear here.',
                    style: TextStyle(color: Colors.grey, fontSize: 13),
                  ),
                ],
              ),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: docs.length,
            itemBuilder: (context, index) {
              final data = docs[index].data() as Map<String, dynamic>;
              return _buildTripCard(data);
            },
          );
        },
      ),
    );
  }

  Widget _buildTripCard(Map<String, dynamic> data) {
    final pickupAddress = data['pickupAddress'] ?? 'Unknown pickup';
    final dropoffAddress = data['dropoffAddress'] ?? 'Unknown dropoff';
    final cost = (data['cost'] as num?)?.toDouble() ?? 0.0;
    final vehicleType = data['vehicleType'] ?? '';
    final riderName = data['riderName'] ?? 'Rider';
    final surgeMultiplier = (data['surgeMultiplier'] as num?)?.toDouble() ?? 1.0;
    final distanceKm = (data['distanceKm'] as num?)?.toDouble() ?? 0.0;

    // Format date
    String dateStr = '';
    final timestamp = data['date'];
    if (timestamp is Timestamp) {
      final date = timestamp.toDate();
      dateStr = DateFormat('MMM d, yyyy • h:mm a').format(date);
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF1C242E),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withOpacity(0.05)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header row: rider name + earnings
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  const Icon(Icons.person, color: Colors.white70, size: 16),
                  const SizedBox(width: 6),
                  Text(
                    riderName,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
              Row(
                children: [
                  if (surgeMultiplier > 1.0) ...[
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 4,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.orange.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.bolt, color: Colors.orange, size: 10),
                          const SizedBox(width: 2),
                          Text(
                            '${surgeMultiplier}×',
                            style: const TextStyle(
                              color: Colors.orange,
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                  ],
                  Text(
                    'EGP ${cost.toStringAsFixed(0)}',
                    style: const TextStyle(
                      color: Colors.greenAccent,
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                ],
              ),
            ],
          ),

          const SizedBox(height: 12),

          // Pickup
          Row(
            children: [
              Container(
                width: 8,
                height: 8,
                decoration: const BoxDecoration(
                  color: Colors.greenAccent,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  pickupAddress,
                  style: const TextStyle(color: Colors.white70, fontSize: 13),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),

          // Dotted line
          Padding(
            padding: const EdgeInsets.only(left: 3.5),
            child: Container(
              width: 1,
              height: 16,
              color: Colors.white24,
            ),
          ),

          // Dropoff
          Row(
            children: [
              Container(
                width: 8,
                height: 8,
                decoration: const BoxDecoration(
                  color: Colors.redAccent,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  dropoffAddress,
                  style: const TextStyle(color: Colors.white70, fontSize: 13),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),

          const SizedBox(height: 12),

          // Footer: date + distance + vehicle
          Row(
            children: [
              if (dateStr.isNotEmpty)
                Text(
                  dateStr,
                  style: const TextStyle(color: Colors.grey, fontSize: 11),
                ),
              const Spacer(),
              if (distanceKm > 0)
                Text(
                  '${distanceKm.toStringAsFixed(1)} km',
                  style: const TextStyle(color: Colors.grey, fontSize: 11),
                ),
              if (vehicleType.isNotEmpty) ...[
                const SizedBox(width: 8),
                Text(
                  vehicleType,
                  style: const TextStyle(color: Colors.grey, fontSize: 11),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }
}
