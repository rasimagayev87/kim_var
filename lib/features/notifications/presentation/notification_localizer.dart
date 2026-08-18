import '../../../l10n/app_localizations.dart';
import '../domain/entities/notification.dart';

/// The feed-rendered title/body for one notification, in the app's
/// currently selected language — see [localizeNotification].
class LocalizedNotificationText {
  final String title;
  final String body;

  const LocalizedNotificationText({required this.title, required this.body});
}

/// Renders [notification.type] + [notification.metadata] (the
/// structured `params` the Cloud Functions side now writes — see
/// `functions/src/index.ts`'s `notifyUser`) into localized text, live
/// in the app's current language, instead of trusting a pre-rendered
/// string baked into Firestore at creation time in whatever language
/// happened to be hardcoded server-side.
///
/// Returns `null` for a notification with no `metadata` — i.e. one
/// written BEFORE this migration, when the server still wrote
/// `title`/`body` directly. Callers should fall back to
/// [AppNotification.title]/[AppNotification.body] verbatim in that
/// case (old notifications intentionally stay in their original
/// Azerbaijani, per the "don't migrate history" decision — only new
/// ones render per-locale).
LocalizedNotificationText? localizeNotification(AppNotification notification, AppLocalizations loc) {
  final params = notification.metadata;
  if (params == null) return null;

  String str(String key) => (params[key] as String?)?.trim() ?? '';
  int intVal(String key) => (params[key] as num?)?.toInt() ?? 0;
  bool boolVal(String key) => params[key] == true;

  String bodyWithOptionalNote({
    required String name,
    required String Function(Object name, Object note) withNote,
    required String Function(Object name) noNote,
  }) {
    final note = str('note');
    return note.isEmpty ? noNote(name) : withNote(name, note);
  }

  switch (notification.type) {
    case NotificationType.newFollower:
      // The title is just the follower's name — already carried on
      // the top-level senderName field, no need to duplicate it into
      // params.
      return LocalizedNotificationText(title: notification.senderName ?? '', body: loc.notifNewFollowerBody);

    // "Hesab gizliliyi" — a follow request against a `private`
    // account (see `onFollowCreated`), and its own approval (see
    // `onFollowUpdated`). Same senderName-as-title shape as
    // [newFollower].
    case NotificationType.followRequest:
      return LocalizedNotificationText(title: notification.senderName ?? '', body: loc.notifFollowRequestBody);
    case NotificationType.followAccepted:
      return LocalizedNotificationText(title: notification.senderName ?? '', body: loc.notifFollowAcceptedBody);

    case NotificationType.likePost:
      return LocalizedNotificationText(title: notification.senderName ?? '', body: loc.notifLikePostBody);

    case NotificationType.venuePeakHour:
      final venueName = str('venueName');
      return LocalizedNotificationText(
        title: loc.notifVenuePeakHourTitle,
        body: venueName.isEmpty ? loc.notifVenuePeakHourBodyGeneric : loc.notifVenuePeakHourBody(venueName),
      );

    case NotificationType.birthdayMatch:
      return LocalizedNotificationText(
        title: loc.notifBirthdayMatchTitle,
        body: loc.notifBirthdayMatchBody(intVal('count')),
      );

    case NotificationType.replyComment:
      final preview = str('preview');
      return LocalizedNotificationText(
        title: notification.senderName ?? '',
        body: preview.isEmpty ? loc.notifReplyCommentBodyGeneric : preview,
      );

    case NotificationType.commentPost:
      final preview = str('preview');
      return LocalizedNotificationText(
        title: notification.senderName ?? '',
        body: preview.isEmpty ? loc.notifCommentPostBodyGeneric : preview,
      );

    case NotificationType.venueAdded:
      final venueName = str('venueName');
      return LocalizedNotificationText(
        title: loc.notifVenueAddedTitle,
        body: venueName.isEmpty ? loc.notifVenueAddedBodyGeneric : loc.notifVenueAddedBody(venueName),
      );

    case NotificationType.venueVerified:
      final venueName = str('venueName');
      return LocalizedNotificationText(
        title: loc.notifVenueVerifiedTitle,
        body: venueName.isEmpty ? loc.notifVenueVerifiedBodyGeneric : loc.notifVenueVerifiedBody(venueName),
      );

    case NotificationType.venueApproved:
      return LocalizedNotificationText(
        title: loc.notifVenueApprovedTitle,
        body: loc.notifVenueApprovedBody(str('name')),
      );

    case NotificationType.offerApproved:
      return LocalizedNotificationText(
        title: loc.notifOfferApprovedTitle,
        body: loc.notifOfferApprovedBody(str('name')),
      );

    case NotificationType.venueNeedsRevision:
      final body = bodyWithOptionalNote(
        name: str('name'),
        withNote: loc.notifVenueNeedsRevisionBodyWithNote,
        noNote: loc.notifVenueNeedsRevisionBodyNoNote,
      );
      return LocalizedNotificationText(
        title: loc.notifVenueNeedsRevisionTitle,
        body: body + (boolVal('hasPayment') ? loc.notifRevisionPaymentSuffix : ''),
      );

    case NotificationType.offerNeedsRevision:
      final body = bodyWithOptionalNote(
        name: str('name'),
        withNote: loc.notifOfferNeedsRevisionBodyWithNote,
        noNote: loc.notifOfferNeedsRevisionBodyNoNote,
      );
      return LocalizedNotificationText(
        title: loc.notifOfferNeedsRevisionTitle,
        body: body + (boolVal('hasPayment') ? loc.notifRevisionPaymentSuffix : ''),
      );

    case NotificationType.venueRejected:
      final body = bodyWithOptionalNote(
        name: str('name'),
        withNote: loc.notifVenueRejectedBodyWithNote,
        noNote: loc.notifVenueRejectedBodyNoNote,
      );
      return LocalizedNotificationText(
        title: loc.notifVenueRejectedTitle,
        body: body + (boolVal('hasPayment') ? loc.notifRefundSuffix : ''),
      );

    case NotificationType.offerRejected:
      final body = bodyWithOptionalNote(
        name: str('name'),
        withNote: loc.notifOfferRejectedBodyWithNote,
        noNote: loc.notifOfferRejectedBodyNoNote,
      );
      return LocalizedNotificationText(
        title: loc.notifOfferRejectedTitle,
        body: body + (boolVal('hasPayment') ? loc.notifRefundSuffix : ''),
      );

    case NotificationType.birthdayOffer:
      final venueName = str('venueName');
      return LocalizedNotificationText(
        title: loc.notifBirthdayOfferTitle,
        body: venueName.isEmpty ? loc.notifBirthdayOfferBodyGeneric : loc.notifBirthdayOfferBody(venueName),
      );

    case NotificationType.waitlistCalled:
      final venueName = str('venueName');
      return LocalizedNotificationText(
        title: loc.notifWaitlistCalledTitle,
        body: venueName.isEmpty ? loc.notifWaitlistCalledBodyGeneric : loc.notifWaitlistCalledBody(venueName),
      );

    case NotificationType.waitlistDisabled:
      final venueName = str('venueName');
      return LocalizedNotificationText(
        title: loc.notifWaitlistDisabledTitle,
        body: venueName.isEmpty ? loc.notifWaitlistDisabledBodyGeneric : loc.notifWaitlistDisabledBody(venueName),
      );

    case NotificationType.venueEvent:
      final venueName = str('venueName');
      return LocalizedNotificationText(
        title: venueName.isEmpty ? loc.notifVenueEventTitleGeneric : loc.notifVenueEventTitle(venueName),
        // The event's own title is raw owner content, never translated —
        // only the surrounding "X-də bu axşam" shell above is (mirrors
        // NotificationType.venueOffer's identical reasoning).
        body: str('eventTitle'),
      );

    case NotificationType.venueOffer:
      final venueName = str('venueName');
      return LocalizedNotificationText(
        title: venueName.isEmpty ? loc.notifVenueOfferTitleGeneric : loc.notifVenueOfferTitle(venueName),
        // The offer's own title is raw user content, never translated —
        // only the surrounding "X yaxınlığınızda" shell above is.
        body: str('offerTitle'),
      );

    case NotificationType.vipGranted:
      return LocalizedNotificationText(title: loc.notifVipGrantedTitle, body: loc.notifVipGrantedBody);

    // Every other type either has no server producer at all (mention,
    // system, security, promotion, warning, announcement) or is the
    // forward-compat fallback (other/follow) — none of these carry a
    // params contract to render from.
    case NotificationType.follow:
    case NotificationType.mention:
    case NotificationType.system:
    case NotificationType.security:
    case NotificationType.promotion:
    case NotificationType.warning:
    case NotificationType.announcement:
    case NotificationType.other:
      return null;
  }
}
