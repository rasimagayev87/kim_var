/**
 * Which notification preference key gates which notification type — and
 * which types are not gated at all.
 *
 * ── Why this file exists ───────────────────────────────────────────
 *
 * `notifyUser` takes `category` as a plain string argument, chosen
 * independently at each of its ~36 call sites. Nothing tied those
 * choices together, and the 2026-08-31 audit found the result: two
 * categories meant for CONTENT ("Məkan təklifləri", "Məkan
 * yenilikləri") were also gating seventeen TRANSACTIONAL messages.
 *
 * Concretely, before this file:
 *   - turning off "Məkan təklifləri" also silenced "ödənişiniz
 *     uğursuz oldu" and "sifarişiniz təsdiqləndi";
 *   - turning off "Məkan yenilikləri" also silenced "sıra sizindir"
 *     — while the person was physically waiting at the venue — plus
 *     the subscription-overdue, KYC-result and VIP-granted messages.
 *
 * A user turning off marketing is not consenting to miss a failed
 * charge. The axis was wrong, not the labels.
 *
 * No SDK imports on purpose: `tests/rules/notification-categories.test.ts`
 * imports this directly, and — more importantly — PARSES `index.ts` and
 * asserts every real `notifyUser` call matches the table below. A map
 * that can drift from its call sites would be documentation, not a
 * boundary.
 */

/**
 * Categories `notifyUser` does NOT gate.
 *
 * DO NOT "simplify" this by gating everything uniformly. The
 * asymmetry is the design:
 *
 *   - `security`  — new-device sign-in, credential changes. Someone
 *     who has taken over an account would otherwise silence the one
 *     message that reveals it.
 *   - `account`   — money, subscriptions, identity verification, and
 *     the queue entry the user joined minutes ago. Each follows an
 *     action the user (or the venue owner) actually took, so the
 *     notification is the expected consequence of that action, not an
 *     unsolicited message. Missing one costs the recipient money or a
 *     table they are standing in line for.
 *
 * `tests/rules/notification-categories.test.ts` asserts both that this
 * list is exactly these two AND that every transactional type maps
 * into it. Removing an entry breaks a test with an explanatory name,
 * which is the point.
 */
export const UNGATED_NOTIFICATION_CATEGORIES: readonly string[] = ["security", "account"];

/** Preference keys the client may toggle, i.e. every gated category.
 * Order matches the Settings screen top-to-bottom. */
export const GATED_NOTIFICATION_CATEGORIES: readonly string[] = [
  "messages",
  "followers",
  "likes",
  "comments",
  "venueOffers",
  "venueUpdates",
  "systemNotifications",
  "marketing",
];

/**
 * Every key that may appear in `notificationPreferences`, gated or not,
 * plus the master `pushEnabled` switch.
 *
 * `newUsers` and `emailEnabled` were REMOVED in the same pass. Neither
 * was read by a single line of server code — `newUsers` gated nothing
 * at all, and `emailEnabled` described an email service this project
 * has never had. A stored flag nothing consults is a promise to the
 * user that no code keeps.
 */
export const ALL_NOTIFICATION_PREFERENCE_KEYS: readonly string[] = [
  ...GATED_NOTIFICATION_CATEGORIES,
  ...UNGATED_NOTIFICATION_CATEGORIES,
  "pushEnabled",
];

/** Whether `notifyUser` consults `notificationPreferences[category]`. */
export function isGatedCategory(category: string): boolean {
  return !UNGATED_NOTIFICATION_CATEGORIES.includes(category);
}

/**
 * The declared category of every notification type `notifyUser` sends.
 *
 * Kept in sync with the call sites BY TEST, not by discipline — see
 * this file's own doc comment. A type sending under a category other
 * than the one named here fails `notification-categories.test.ts`.
 *
 * Types whose `type:` argument is a ternary appear under BOTH possible
 * values, since either can be sent.
 */
export const NOTIFICATION_CATEGORY_BY_TYPE: Readonly<Record<string, string>> = {
  // ── Ungated: security ────────────────────────────────────────────
  security: "security",

  // ── Ungated: account (money, identity, subscriptions, queue) ─────
  // A paid listing's moderation result. The owner paid a placement or
  // subscription fee; "your listing was rejected" is the outcome of
  // that purchase, not venue news they opted into. `needsRevision`
  // carries a deadline, so silencing it can cost the listing outright.
  //
  // These nine come from `moderationStatusNotification`, which builds
  // `${kind}${Outcome}` — the parity test resolves them from that
  // function rather than from a literal at the call site.
  venueApproved: "account",
  venueNeedsRevision: "account",
  venueRejected: "account",
  offerApproved: "account",
  offerNeedsRevision: "account",
  offerRejected: "account",
  pinboxApproved: "account",
  pinboxNeedsRevision: "account",
  pinboxRejected: "account",
  // Creation confirmations — same reasoning, both go to the OWNER
  // ("Qutunuz əlavə edildi" / "Məkanınız əlavə edildi"), never to a
  // nearby consumer.
  pinboxAdded: "account",
  venueAdded: "account",
  venueVerified: "account",
  // Real charges.
  offerPaymentConfirmed: "account",
  offerBoosted: "account",
  paymentFailed: "account",
  pinboxOrderConfirmed: "account",
  venuePaymentConfirmed: "account",
  venueSubscriptionRenewed: "account",
  venueSubscriptionDue: "account",
  venuePremiumActivated: "account",
  venuePremiumExpiringSoon: "account",
  // Identity and entitlement.
  identityVerificationApproved: "account",
  identityVerificationRejected: "account",
  vipGranted: "account",
  // The walk-in queue. `waitlistCalled` is the sharpest case in this
  // whole table: it is neither content nor a transaction but a
  // time-critical physical event — "your table is ready, come in 5
  // minutes" — sent to someone standing outside the venue. It sat
  // under a content toggle. The other two concern the same entry the
  // user created by hand: its confirmation, and its cancellation when
  // the venue turns the queue off.
  venueWaitlistJoined: "account",
  waitlistCalled: "account",
  waitlistDisabled: "account",

  // ── Gated: venueOffers — content pushed to CONSUMERS ─────────────
  // The daily digest. One notification per content type per day, in
  // place of the per-listing fan-out that used to send one per venue —
  // see `./digest`. Same category as the pushes they replace, so a user
  // who had already switched "Məkan təklifləri" off stays off.
  dailyOffersDigest: "venueOffers",
  dailyPinboxDigest: "venueOffers",
  dailyEventsDigest: "venueOffers",
  // The 13:00 birthday publication — one push naming up to three
  // venues, replacing the per-offer `birthdayOffer` push that fired at
  // each approval. See `publishBirthdayOffers`.
  birthdayVenues: "venueOffers",
  //
  // RETIRED: `birthdayOffer`. Nothing emits it any more — approval no
  // longer publishes, `publishBirthdayCampaigns` does, and it sends
  // `birthdayVenues` instead. Kept out of this map for the same reason
  // `venueOffer`/`pinboxNearby` are: the map describes what is sent
  // today. `notification_localizer.dart` still renders the old type so
  // notifications already in users' feeds do not turn blank.
  //
  // RETIRED: `venueOffer`, `venueEvent`, `pinboxNearby` and
  // `productionPost` are gone from this table because nothing sends
  // them any more — the three per-listing fan-outs that did were
  // replaced by the digest above. This map describes what `notifyUser`
  // emits today, so a type nobody emits does not belong in it.
  //
  // Documents already written with those types still sit in users'
  // feeds, and `notification_localizer.dart` keeps its cases for them.
  // Removing the client's rendering would turn old notifications into
  // blanks; removing the server's entry only stops claiming they are
  // still produced.

  // ── Gated: venueUpdates — nudges to the venue OWNER ──────────────
  // Suggestions, not obligations: post an offer now, someone had a
  // birthday, ask this visitor for a review. Silencing them costs the
  // owner nothing they are owed.
  venuePeakHour: "venueUpdates",
  birthdayMatch: "venueUpdates",
  reviewPrompt: "venueUpdates",

  // ── Gated: social ────────────────────────────────────────────────
  followRequest: "followers",
  newFollower: "followers",
  followAccepted: "followers",
  likePost: "likes",
  commentPost: "comments",
  replyComment: "comments",
  mention: "comments",
};
