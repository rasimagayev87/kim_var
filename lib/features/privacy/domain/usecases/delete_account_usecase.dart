import '../repositories/account_repository.dart';

class DeleteAccountUseCase {
  const DeleteAccountUseCase(this._repository);

  final AccountRepository _repository;

  Future<void> call() {
    return _repository.deleteAccount();
  }
}
