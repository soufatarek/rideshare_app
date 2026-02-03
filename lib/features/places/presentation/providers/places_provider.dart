import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/repositories/places_repository.dart';
import '../../domain/models/place_model.dart';
import '../../../auth/presentation/providers/auth_provider.dart';

final placesRepositoryProvider = Provider((ref) => PlacesRepository());

final savedPlacesProvider = StreamProvider.autoDispose<List<PlaceModel>>((ref) {
  final user = ref.watch(authProvider).user;
  if (user == null) {
    return Stream.value([]);
  }
  final repository = ref.watch(placesRepositoryProvider);
  return repository.getSavedPlaces(user.id);
});
