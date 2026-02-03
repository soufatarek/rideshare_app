import 'package:flutter/material.dart';
// import '../../../../../core/constants/app_colors.dart';

class TripCompletedSheet extends StatefulWidget {
  final double price;
  final Function(double) onSubmitRating;

  const TripCompletedSheet({
    super.key,
    required this.price,
    required this.onSubmitRating,
  });

  @override
  State<TripCompletedSheet> createState() => _TripCompletedSheetState();
}

class _TripCompletedSheetState extends State<TripCompletedSheet> {
  double _rating = 0;

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
        children: [
          const CircleAvatar(
            radius: 30,
            backgroundColor: Colors.green,
            child: Icon(Icons.check, color: Colors.white, size: 30),
          ),
          const SizedBox(height: 16),
          Text(
            'You arrived!',
            style: Theme.of(
              context,
            ).textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Text(
            'Total: \$${widget.price.toStringAsFixed(2)}',
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 24),
          const Text('How was your trip?'),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(5, (index) {
              final startValue = index + 1;
              return IconButton(
                onPressed: () {
                  setState(() {
                    _rating = startValue.toDouble();
                  });
                },
                icon: Icon(
                  index < _rating ? Icons.star : Icons.star_border,
                  size: 32,
                  color: Colors.amber,
                ),
              );
            }),
          ),
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () => widget.onSubmitRating(_rating),
              child: const Text('Submit Rating'),
            ),
          ),
        ],
      ),
    );
  }
}
