import '../../../l10n/app_localizations.dart';
import '../domain/storage_failure.dart';

/// Maps a [StorageFailure] to a localized, user-facing message.
///
/// [StorageException.message] itself is never shown to users — it's
/// English/AZ debug detail (sometimes wrapping a raw Firebase error) meant
/// for logs, not translation. The UI always displays this instead, keyed
/// off the stable [StorageFailure] enum.
String localizedStorageFailureMessage(AppLocalizations loc, StorageFailure type) {
  switch (type) {
    case StorageFailure.fileTooLarge:
      return loc.storageErrorFileTooLarge;
    case StorageFailure.invalidContentType:
      return loc.storageErrorInvalidContentType;
    case StorageFailure.uploadFailed:
      return loc.storageErrorUploadFailed;
    case StorageFailure.downloadUrlFailed:
      return loc.storageErrorDownloadUrlFailed;
    case StorageFailure.deleteFailed:
      return loc.storageErrorDeleteFailed;
    case StorageFailure.permissionDenied:
      return loc.storageErrorPermissionDenied;
    case StorageFailure.unauthenticated:
      return loc.storageErrorUnauthenticated;
    case StorageFailure.unknown:
      return loc.storageErrorUnknown;
  }
}
