import '../repositories/venue_repository.dart';

class DeleteVenueUseCase {
  const DeleteVenueUseCase(this._repository);

  final VenueRepository _repository;

  Future<void> call(String venueId) => _repository.deleteVenue(venueId);
}
