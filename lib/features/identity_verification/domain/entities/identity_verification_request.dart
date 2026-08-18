enum IdentityVerificationStatus { pending, approved, rejected }

IdentityVerificationStatus identityVerificationStatusFromString(String raw) {
  switch (raw) {
    case 'approved':
      return IdentityVerificationStatus.approved;
    case 'rejected':
      return IdentityVerificationStatus.rejected;
    case 'pending':
    default:
      return IdentityVerificationStatus.pending;
  }
}

/// One row from `identityVerifications/{requestId}` (see
/// `functions/src/index.ts`'s `submitIdentityVerification`). Read-only
/// here — the client never writes this collection directly, only
/// through that same Cloud Function (see
/// [IdentityVerificationRepository.submit]). Deliberately carries no
/// image path/URL: nothing on the client ever needs them, and this
/// keeps that impossible to add by accident later.
class IdentityVerificationRequest {
  final String id;
  final IdentityVerificationStatus status;
  final String? rejectionReason;
  final DateTime? submittedAt;

  const IdentityVerificationRequest({
    required this.id,
    required this.status,
    this.rejectionReason,
    this.submittedAt,
  });
}
