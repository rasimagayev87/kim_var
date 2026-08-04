import '../safety_repository.dart';

class UnblockUserUseCase {
  const UnblockUserUseCase(this._repository);

  final SafetyRepository _repository;

  Future<void> call({required String myUid, required String blockedUid}) {
    return _repository.unblockUser(myUid: myUid, blockedUid: blockedUid);
  }
}
