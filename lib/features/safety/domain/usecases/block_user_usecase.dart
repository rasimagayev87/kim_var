import '../safety_repository.dart';

class BlockUserUseCase {
  const BlockUserUseCase(this._repository);

  final SafetyRepository _repository;

  Future<void> call({required String myUid, required String blockedUid}) {
    if (myUid == blockedUid) return Future.value();
    return _repository.blockUser(myUid: myUid, blockedUid: blockedUid);
  }
}
