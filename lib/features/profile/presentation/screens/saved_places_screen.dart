import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:uuid/uuid.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../../places/data/repositories/places_repository.dart';
import '../../../places/domain/models/place_model.dart';
import '../../../home/domain/models/place_result.dart';

class SavedPlacesScreen extends ConsumerStatefulWidget {
  const SavedPlacesScreen({super.key});

  @override
  ConsumerState<SavedPlacesScreen> createState() => _SavedPlacesScreenState();
}

class _SavedPlacesScreenState extends ConsumerState<SavedPlacesScreen> {
  final PlacesRepository _repository = PlacesRepository();

  void _addNewPlace() async {
    print('DEBUG: Opening search screen');
    // Navigate to search screen and await result
    final result = await context.push('/search');
    print('DEBUG: Search result received: $result');

    if (result != null) {
      print('DEBUG: Result type: ${result.runtimeType}');
      if (result is PlaceResult) {
        print('DEBUG: Valid PlaceResult, showing dialog');
        _showNameDialog(result);
      } else {
        print('DEBUG: Result is NOT PlaceResult');
      }
    } else {
      print('DEBUG: Result is null');
    }
  }

  void _showNameDialog(PlaceResult locationData) {
    final nameController = TextEditingController();
    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            title: const Text('Name this place'),
            content: TextField(
              controller: nameController,
              decoration: const InputDecoration(hintText: 'e.g. Home, Gym'),
              textCapitalization: TextCapitalization.sentences,
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Cancel'),
              ),
              TextButton(
                onPressed: () {
                  if (nameController.text.isNotEmpty) {
                    _savePlace(nameController.text, locationData);
                    Navigator.pop(context);
                  }
                },
                child: const Text('Save'),
              ),
            ],
          ),
    );
  }

  Future<void> _savePlace(String name, PlaceResult locationData) async {
    final user = ref.read(authProvider).user;
    if (user == null) return;

    final place = PlaceModel(
      id: const Uuid().v4(),
      name: name,
      address: locationData.address,
      location: GeoPoint(locationData.lat, locationData.lng),
    );

    await _repository.addSavedPlace(user.id, place);
  }

  Future<void> _deletePlace(String placeId) async {
    final user = ref.read(authProvider).user;
    if (user == null) return;
    await _repository.deleteSavedPlace(user.id, placeId);
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(authProvider).user;
    if (user == null)
      return const Scaffold(body: Center(child: CircularProgressIndicator()));

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Saved Places',
          style: TextStyle(color: Colors.black),
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.black),
      ),
      body: StreamBuilder<List<PlaceModel>>(
        stream: _repository.getSavedPlaces(user.id),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          final places = snapshot.data ?? [];

          if (places.isEmpty) {
            return const Center(child: Text('No saved places yet'));
          }

          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: places.length,
            separatorBuilder: (context, index) => const Divider(),
            itemBuilder: (context, index) {
              final place = places[index];
              return _buildPlaceItem(place);
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: Colors.black,
        onPressed: _addNewPlace,
        child: const Icon(Icons.add, color: Colors.white),
      ),
    );
  }

  Widget _buildPlaceItem(PlaceModel place) {
    IconData icon = Icons.place;
    if (place.name.toLowerCase() == 'home') icon = Icons.home;
    if (place.name.toLowerCase() == 'work') icon = Icons.work;

    return ListTile(
      leading: CircleAvatar(
        backgroundColor: AppColors.background,
        child: Icon(icon, color: Colors.black54),
      ),
      title: Text(
        place.name,
        style: const TextStyle(fontWeight: FontWeight.w500),
      ),
      subtitle: Text(
        place.address,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(color: AppColors.textSecondary),
      ),
      trailing: IconButton(
        icon: const Icon(Icons.delete_outline, size: 20, color: Colors.red),
        onPressed: () => _deletePlace(place.id),
      ),
    );
  }
}
