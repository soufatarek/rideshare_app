import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_places_flutter/google_places_flutter.dart';
import 'package:google_places_flutter/model/prediction.dart';
import '../../../../core/constants/app_colors.dart';
import '../../domain/models/place_result.dart';
import '../../../places/presentation/providers/places_provider.dart';
import '../../../places/domain/models/place_model.dart';

class DestinationSearchScreen extends ConsumerStatefulWidget {
  const DestinationSearchScreen({super.key});

  @override
  ConsumerState<DestinationSearchScreen> createState() =>
      _DestinationSearchScreenState();
}

class _DestinationSearchScreenState
    extends ConsumerState<DestinationSearchScreen> {
  final _startController = TextEditingController(text: 'Current Location');
  final _destinationController = TextEditingController();
  final _destinationFocus = FocusNode();
  // Google Places API Key
  final _apiKey = 'AIzaSyCnMEavjs7z_wLKztyeHm2Vkfx-r1AmLRk';

  @override
  void initState() {
    super.initState();
    // Auto-focus the destination field
    WidgetsBinding.instance.addPostFrameCallback((_) {
      FocusScope.of(context).requestFocus(_destinationFocus);
    });
  }

  @override
  void dispose() {
    _startController.dispose();
    _destinationController.dispose();
    _destinationFocus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Watch saved places
    final savedPlacesAsync = ref.watch(savedPlacesProvider);

    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Column(
          children: [
            // Header with Back Button
            Padding(
              padding: const EdgeInsets.only(top: 16, left: 16, bottom: 8),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.1),
                        blurRadius: 8,
                      ),
                    ],
                  ),
                  child: IconButton(
                    icon: const Icon(Icons.arrow_back),
                    onPressed: () => context.pop(),
                  ),
                ),
              ),
            ),

            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                children: [
                  // Inputs
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Padding(
                        padding: const EdgeInsets.only(top: 12),
                        child: Column(
                          children: [
                            const Icon(
                              Icons.my_location,
                              size: 16,
                              color: Colors.grey,
                            ),
                            Container(
                              height: 30,
                              width: 2,
                              color: Colors.grey[300],
                              margin: const EdgeInsets.symmetric(vertical: 4),
                            ),
                            const Icon(
                              Icons.location_on,
                              size: 16,
                              color: AppColors.primary,
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          children: [
                            TextField(
                              controller: _startController,
                              readOnly: true,
                              decoration: InputDecoration(
                                filled: true,
                                fillColor: AppColors.background,
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(8),
                                  borderSide: BorderSide.none,
                                ),
                                contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 8,
                                ),
                                prefixIcon: const Icon(
                                  Icons.my_location,
                                  size: 18,
                                ),
                              ),
                              style: const TextStyle(fontSize: 14),
                            ),
                            const SizedBox(height: 12),
                            // Google Places Autocomplete
                            GooglePlaceAutoCompleteTextField(
                              textEditingController: _destinationController,
                              googleAPIKey: _apiKey,
                              inputDecoration: InputDecoration(
                                hintText: 'Search destination...',
                                filled: true,
                                fillColor: Colors.grey[100],
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(8),
                                  borderSide: BorderSide.none,
                                ),
                                contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 8,
                                ),
                                prefixIcon: const Icon(Icons.search, size: 18),
                                // Add suffix icon to clear text
                                suffixIcon:
                                    _destinationController.text.isNotEmpty
                                        ? IconButton(
                                          icon: const Icon(
                                            Icons.clear,
                                            size: 18,
                                          ),
                                          onPressed: () {
                                            _destinationController.clear();
                                            setState(
                                              () {},
                                            ); // Rebuild to hide X
                                          },
                                        )
                                        : null,
                              ),
                              debounceTime: 400,
                              countries: const ['eg'], // Egypt
                              isLatLngRequired: true,
                              getPlaceDetailWithLatLng: (
                                Prediction prediction,
                              ) {
                                final lat =
                                    double.tryParse(prediction.lat ?? '0') ?? 0;
                                final lng =
                                    double.tryParse(prediction.lng ?? '0') ?? 0;

                                print(
                                  'DEBUG: Selected prediction: ${prediction.description}, Lat: $lat, Lng: $lng',
                                );

                                context.pop(
                                  PlaceResult(
                                    address: prediction.description ?? '',
                                    lat: lat,
                                    lng: lng,
                                  ),
                                );
                              },

                              itemClick: (Prediction prediction) {
                                _destinationController.text =
                                    prediction.description ?? '';
                                _destinationFocus.unfocus();
                              },
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            // Saved Places List
            const Divider(thickness: 1, height: 1),
            Expanded(
              child: savedPlacesAsync.when(
                data: (places) {
                  if (places.isEmpty) {
                    return Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.bookmark_outline,
                            size: 48,
                            color: Colors.grey[300],
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'No saved places yet',
                            style: TextStyle(color: Colors.grey[400]),
                          ),
                        ],
                      ),
                    );
                  }
                  return ListView.separated(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    itemCount: places.length,
                    separatorBuilder:
                        (context, index) => const Divider(height: 1),
                    itemBuilder: (context, index) {
                      final place = places[index];
                      IconData icon = Icons.place;
                      if (place.name.toLowerCase() == 'home') icon = Icons.home;
                      if (place.name.toLowerCase() == 'work') icon = Icons.work;

                      return ListTile(
                        leading: CircleAvatar(
                          backgroundColor: AppColors.background,
                          child: Icon(
                            icon,
                            color: AppColors.textPrimary,
                            size: 20,
                          ),
                        ),
                        title: Text(
                          place.name,
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                        subtitle: Text(
                          place.address,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        onTap: () {
                          // Return the saved place as result
                          context.pop(
                            PlaceResult(
                              address: place.address,
                              lat: place.location.latitude,
                              lng: place.location.longitude,
                            ),
                          );
                        },
                      );
                    },
                  );
                },
                error: (err, stack) => Center(child: Text('Error: $err')),
                loading: () => const Center(child: CircularProgressIndicator()),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
