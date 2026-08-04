import '../repositories/account_repository.dart';

/// Phase 3 — see the phase-plan note on data export: what "their data"
/// covers (profile doc only, or also messages/events they're part of)
/// and how it's delivered (share sheet, save-to-file, emailed link) is
/// an open decision, not assumed here. [AccountRepository.exportUserData]
/// currently returns the payload as a String (e.g. JSON) — the caller
/// decides what to do with it.
class ExportUserDataUseCase {
  const ExportUserDataUseCase(this._repository);

  final AccountRepository _repository;

  Future<String> call() {
    return _repository.exportUserData();
  }
}
