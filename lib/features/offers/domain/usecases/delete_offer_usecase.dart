import '../repositories/offer_repository.dart';

class DeleteOfferUseCase {
  const DeleteOfferUseCase(this._repository);

  final OfferRepository _repository;

  Future<void> call(String offerId) => _repository.deleteOffer(offerId);
}
