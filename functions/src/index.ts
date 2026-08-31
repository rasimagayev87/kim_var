import { initializeApp } from "firebase-admin/app";
import { FieldPath, FieldValue, getFirestore, GeoPoint, Timestamp } from "firebase-admin/firestore";
import { getAuth } from "firebase-admin/auth";
import { getStorage } from "firebase-admin/storage";
import { BatchResponse, getMessaging } from "firebase-admin/messaging";
import { HttpsError, onCall, onRequest } from "firebase-functions/v2/https";
import { onDocumentCreated, onDocumentDeleted, onDocumentUpdated, onDocumentWritten } from "firebase-functions/v2/firestore";
import { onMessagePublished } from "firebase-functions/v2/pubsub";
import { onSchedule } from "firebase-functions/v2/scheduler";
import { beforeUserSignedIn } from "firebase-functions/v2/identity";
import { defineSecret } from "firebase-functions/params";
import * as logger from "firebase-functions/logger";
import { createHash, randomInt, randomUUID } from "crypto";
import {
  chargeEpointSavedCard,
  createEpointCardRegistration,
  createEpointCheckout,
  createEpointTokenWidget,
  decodeEpointData,
  getEpointCardStatus,
  reverseEpointTransaction,
  verifyEpointSignature,
} from "./epoint";
import { geohashForLocation } from "geofire-common";
import { verifyAppleNotification, verifyAppleTransaction, verifyGoogleSubscription } from "./iap";
import { CHAT_MEDIA_FOLDERS, chatMediaPathForMessage, isChatHiddenByEveryone, resizedVariantPath } from "./chat-media";
import { isCancellableOnListingDelete, isPaymentTargetMissing } from "./payment-targets";
import { venueSubscriptionFeeByCategory } from "./venue-fees";
import {
  bucketDistanceMeters,
  clampAudienceRadiusKm,
  haversineMeters,
  isAllowedVenueAudienceRadiusKm,
  isPlausibleMovement,
  quantizeOriginDegrees,
  reportableAudienceCount,
  VENUE_AUDIENCE_MIN_REPORTABLE_COUNT,
  VENUE_AUDIENCE_RADIUS_OPTIONS_KM,
} from "./geo";
import { InvalidPhoneNumberError, normalizePhoneNumber } from "./phone";
import { isGatedCategory } from "./notification-categories";
import {
  eventCoverPath,
  offerPhotoPath,
  pinboxPhotoPath,
  storyMediaPath,
  venuePhotoPath,
} from "./media-paths";
import { confinedStoragePath } from "./storage-path";
import { bakuDateKey, bakuHour, isBirthdayToday } from "./birthday";
import {
  BIRTHDAY_FEED_MAX,
  BIRTHDAY_HIGHLIGHT_COUNT,
  BirthdayVenueCandidate,
  pickDistinctCategoryVenues,
  rankCandidates,
} from "./birthday-ranking";
import {
  DIGEST_LOOKBACK_MS,
  DigestIntent,
  digestCountsFor,
  digestNotifications,
  INTENT_RETENTION_DAYS,
  IntentType,
} from "./digest";
// `isEventCategory` is deliberately absent: event creation is a direct
// client write with no callable, so `firestore.rules` is its only
// server gate. The constant still exists for the parity test.
import { isBirthdayCategory, isPinBoxCategory, isWaitlistCategory } from "./venue-categories";

// `enforceAppCheck: false` on every onCall function below — deliberately
// reverted from `true`. iOS release builds activate App Check via
// `AppleProvider.deviceCheck` (see main.dart), which is currently
// producing tokens the backend can't even decode as a JWT
// ("app-check/invalid-argument: Decoding App Check token failed" —
// confirmed in Cloud Logging against `resubmitVenue`, 2026-08-24), not
// just failing verification. With enforcement on, this silently blocked
// EVERY onCall function for real iOS users — e.g. a venue owner fixing
// a `needs_revision` listing and resubmitting had no visible error, the
// screen just popped as if it worked, and the venue stayed stuck.
// CURRENT STATE, and the condition for changing it: enforcement is
// deliberately `false` on every onCall in this file, waiting on iOS
// DeviceCheck registration. Turn it on only once Firebase Console →
// App Check shows a STEADY HIGH verification rate on BOTH platforms —
// not just Android looking healthy, and not re-flipped to `true` on
// faith. A partial rollout is the worst of the three states: it fails
// closed and silently, so the users it breaks see a screen that
// behaves as if the write succeeded.
//
// The per-function comments below used to say "KOD YAZILIB, DEPLOY
// EDİLMƏYİB" — written when the flag was `true` in source but not yet
// deployed. That has not been the situation since the revert above:
// `false` is what is in source AND what is deployed. They were
// rewritten to state the current condition instead, because a comment
// describing a state the code left months ago is worse than no comment
// — the next reader trusts it.
initializeApp();

const db = getFirestore();
const auth = getAuth();
const storage = getStorage();
const messaging = getMessaging();

// Mirrors FirebaseAccountRepository's client-side freshness check
// (`_freshSignInWindow`) — kept here too as defense-in-depth against a
// stale or modified client calling straight through without it.
const FRESH_SIGN_IN_WINDOW_SECONDS = 5 * 60;

const DELETED_SENDER_PLACEHOLDER = "Bu istifadəçi hesabını silib";

// Düzəliş Prompt 4 / K-1 — `users/{uid}` used to be fully world-readable
// (`firestore.rules`: `allow read: if request.auth != null`) and carried
// email, phoneNumber, birthDate, exact lat/lng, fcmTokens,
// knownDeviceSignatures, and every self-preference toggle directly on
// it — a single query against any uid handed over all of it. Those
// fields now live in this owner-only subcollection instead
// (`firestore.rules`' new `users/{uid}/private/{document}` block).
// Three fields deliberately did NOT move despite being sensitive-ish —
// each has a hard structural reason, not an oversight:
//   - `country` — `getDiscoverCandidates`/`findNearbyUsers` filter with
//     `db.collection("users").where("country", "==", ...)`, a top-level
//     query. Firestore cannot filter a parent collection by a
//     subcollection field, so this can't move without a much bigger
//     redesign (a collectionGroup index) that isn't justified yet.
//   - `blockedUsers` — `scrubFromOthersBlockLists` (account deletion)
//     queries `where("blockedUsers", "array-contains", uid)` the same
//     way; ALSO read cross-user by `firebase_chat_repository.dart`'s
//     own block-check before sending a message — moving it would need
//     Prompt 5's planned server-side block enforcement, not a half fix
//     here.
//   - `reportedCount` / `premiumExpiresAt` / `birthdayOffersOptIn` —
//     `reportedCount` per Düzəliş Prompt 12's own finding (the only
//     writer targets ANOTHER user's doc); `premiumExpiresAt` is
//     compound-queried alongside `premium` in `expireLapsedPremium`
//     (`where("premium","==",true).where("premiumExpiresAt","<=",now)`);
//     `birthdayOffersOptIn` is queried directly in
//     `computeBirthdayMatches`. Same "can't query across the split"
//     constraint as `country`.
function privateDataRef(uid: string): FirebaseFirestore.DocumentReference {
  return db.collection("users").doc(uid).collection("private").doc("data");
}

// Post-launch QA — `completeOnboarding`/`findNearbyUsers` diagnostics.
// The stuck-account incident that motivated the `completeOnboarding`
// `tx.create`→`tx.set(merge:true)` fix (see that function's own comment)
// took real effort to trace precisely BECAUSE neither function logged
// anything identifying WHO called them or WHEN — every clue had to be
// reconstructed after the fact from HTTP status/latency alone, with no
// way to confirm which invocations belonged to the same uid. This is a
// structured, one-line-per-call breadcrumb (uid, whether a request.auth
// was present at all, and a timestamp) so a similar incident is instantly
// traceable next time instead of requiring the same reconstruction.
// Deliberately minimal — not a general-purpose call logger for every
// function, just these two, which have already caused a real incident.
function logCallableInvocation(functionName: string, request: { auth?: { uid: string } | null | undefined }): void {
  logger.info(`${functionName}: invocation`, {
    functionName,
    uid: request.auth?.uid ?? null,
    authStatus: request.auth ? "present" : "missing",
    calledAt: new Date().toISOString(),
  });
}

// Düzəliş Prompt 11 / Y-1 — a deleted/banned account's Firebase ID
// token stays cryptographically valid (signature + expiry only) for up
// to its natural ~1h lifetime; neither `onCall`'s default auth context
// nor Firestore Rules check token-revocation status. This checks live
// Firestore state instead (independent of the token's own freshness),
// mirroring `firestore.rules`' own `isActiveUser()` — see that
// function's comment for why `bannedUsers/{uid}` exists as a separate
// tombstone rather than a field on `users/{uid}` itself. Every
// user-facing callable that creates/modifies content or money should
// call this right after its `uid` guard — `completeOnboarding` (creates
// the doc) and `deleteAccount` (self-deletion should work regardless of
// ban status) are the deliberate exceptions.
/**
 * Rejects a callable request, leaving a server-side trace first.
 *
 * `HttpsError` thrown from an `onCall` handler is returned to the
 * client as a structured error and is NOT logged by the runtime. That
 * is fine for the client and terrible for us: a user-visible failure
 * produces a Cloud Run request log with a status code and nothing
 * else, so "venue creation is broken" cannot be answered without
 * guessing which of several `throw` statements fired. This happened —
 * three 400s in the logs and no way to tell which check rejected them.
 *
 * `reason` is a stable machine-readable slug, not prose: it is what
 * gets grepped six months from now.
 */
function rejectRequest(
  code: "invalid-argument" | "failed-precondition" | "permission-denied" | "already-exists",
  reason: string,
  message: string,
  context: Record<string, unknown> = {},
): never {
  logger.warn(`reject reason=${reason} code=${code}`, context);
  // The slug travels to the client as `details` too. Callable error
  // CODES are a fixed, coarse set — `invalid-argument` covers both "a
  // required field is empty" and "that photo URL is not ours" — so a
  // client mapping codes to messages has to guess which one it is.
  // Mine guessed "photo" and was wrong, sending someone to re-pick a
  // photo when the real problem was a blank address. `details` is the
  // channel that removes the guess.
  throw new HttpsError(code, message, { reason });
}

async function assertActiveUser(uid: string): Promise<void> {
  const [userSnap, bannedSnap] = await Promise.all([
    db.collection("users").doc(uid).get(),
    db.collection("bannedUsers").doc(uid).get(),
  ]);
  if (!userSnap.exists) throw new HttpsError("permission-denied", "account-deleted");
  if (bannedSnap.exists) throw new HttpsError("permission-denied", "account-banned");
}

// Düzəliş Prompt 8 / K-7 — generic per-key rate limiter, reusable across
// any callable/HTTP function. Fixed-window counter (`{windowStart,
// count}`), not the old `enforceEmailLinkRateLimit`'s ever-growing
// sliding-window timestamp array (removed in 2742d8d) — cheaper (the
// doc never grows) at the cost of the well-known fixed-window trait of
// allowing up to ~2x the limit right at a window boundary, an accepted
// trade-off at this app's actual volume. `scope` groups related call
// sites under one shared counter (e.g. all 8 payment-checkout
// callables share `"checkout"`) so an attacker can't dodge the limit by
// spreading calls across functions that all do the same kind of thing.
//
// `HttpsError` is deliberately thrown AFTER the transaction resolves,
// never from inside the callback — same reasoning as `completeOnboarding`'s
// own doc comment: Admin SDK retries the callback on contention, and how
// a non-Firestore error interacts with that retry isn't something to
// rely on.
async function enforceRateLimit(scope: string, key: string, limit: number, windowSeconds: number): Promise<void> {
  const ref = db.collection("rateLimits").doc(`${scope}:${key}`);
  const now = Date.now();
  const windowMs = windowSeconds * 1000;
  let exceeded = false;
  await db.runTransaction(async (tx) => {
    const data = (await tx.get(ref)).data();
    const windowStart = data?.windowStart as number | undefined;
    const count = (data?.count as number | undefined) ?? 0;
    const windowActive = windowStart !== undefined && now - windowStart < windowMs;
    if (windowActive && count >= limit) {
      exceeded = true;
      return;
    }
    tx.set(ref, windowActive ? { windowStart, count: count + 1 } : { windowStart: now, count: 1 });
  });
  if (exceeded) {
    logger.warn(`rate-limit-exceeded scope=${scope} key=${key} limit=${limit}/${windowSeconds}s`);
    throw new HttpsError("resource-exhausted", "rate-limit-exceeded");
  }
}

// Cloudflare Realtime TURN key id + API token — set once via:
//   firebase functions:secrets:set CLOUDFLARE_TURN_KEY_ID
//   firebase functions:secrets:set CLOUDFLARE_TURN_API_TOKEN
// Never embedded in the Flutter app: anything shipped in a mobile client
// can be extracted, and this token can mint TURN credentials against
// the project's Cloudflare billing. getTurnCredentials below is the
// only thing allowed to hold it.
const cloudflareTurnKeyId = defineSecret("CLOUDFLARE_TURN_KEY_ID");
const cloudflareTurnApiToken = defineSecret("CLOUDFLARE_TURN_API_TOKEN");

// Resend API key — set once via: firebase functions:secrets:set RESEND_API_KEY
// Used only by sendPrivacyNotificationEmail below, to relay new user/event
// reports to privacy@peakpin.app as they come in (that inbox otherwise has
// no way to know about a report short of someone opening the admin panel).
const resendApiKey = defineSecret("RESEND_API_KEY");

// Epoint.az merchant credentials — set once via:
//   firebase functions:secrets:set EPOINT_PUBLIC_KEY
//   firebase functions:secrets:set EPOINT_PRIVATE_KEY
// Issued by Epoint when a merchant account is opened (epoint.az) — until
// then, submitOffer/retryOfferPayment below will fail at the Epoint HTTP
// call (createEpointCheckout throws on a non-success response), leaving
// the offer in 'awaiting_payment' rather than pretending to charge.
const epointPublicKey = defineSecret("EPOINT_PUBLIC_KEY");
const epointPrivateKey = defineSecret("EPOINT_PRIVATE_KEY");

// Fail-safe confirmation gate (see `resolveEpointBaseUrl`, epoint.ts) —
// must be set to exactly "production" in Secret Manager before any
// Epoint request is allowed to run at all. Epoint has no real
// sandbox host, so this doesn't select a URL the way an env var
// normally would; it exists purely so a missing/wrong value (an
// empty secret, a leftover "sandbox" from local dev) fails loudly
// instead of silently processing a real charge against
// not-yet-verified EPOINT_PUBLIC_KEY/EPOINT_PRIVATE_KEY credentials.
const epointEnv = defineSecret("EPOINT_ENV");

// `.value()` is used raw everywhere below — Secret Manager (and
// `firebase functions:secrets:set` piping a value in non-interactively)
// can silently carry a trailing newline the merchant's real key never
// had, which Epoint's exact-match lookup on `public_key` then rejects
// as an unrecognized merchant. Trimming once here, rather than at each
// of the 4 call sites, is what actually guarantees every one of them
// gets the same clean value.
function epointPublicKeyValue(): string {
  return epointPublicKey.value().trim();
}
function epointPrivateKeyValue(): string {
  return epointPrivateKey.value().trim();
}
function epointEnvValue(): string {
  return epointEnv.value().trim();
}

/**
 * Sends a plain notification email via Resend's REST API (not SMTP —
 * this is app-triggered mail, unrelated to Firebase Auth's own
 * CUSTOM_SMTP config for sign-in emails). Never throws: a failed send
 * shouldn't fail the report-creation write it's reacting to, since the
 * report itself is already safely in Firestore either way.
 */
/**
 * HTML-escapes one interpolated value for the report e-mails below
 * (P0, class-search finding A-3).
 *
 * Those templates interpolated `reason`, `reporter.name`,
 * `reported.name`, `eventTitle` and `reviewComment` raw — every one of
 * them free text an ordinary user types, `reason` up to the 1000
 * characters `firestore.rules` allows. The recipient is
 * privacy@peakpin.app, i.e. this project's own staff, so a report body
 * of `<a href="https://evil.test/reset">Hesabı bərpa et</a>` arrived as
 * a working link in an e-mail that genuinely came from PeakPin's own
 * sending domain — a phishing lure with our own DKIM signature on it.
 *
 * Escapes the five characters that matter for HTML text and attribute
 * context. Not a general-purpose sanitizer: everything here is
 * interpolated into element TEXT, never into a URL, a script, or an
 * unquoted attribute, so escaping is the correct and complete answer
 * for this call site rather than a stripping/allowlisting pass.
 */
function escapeHtml(value: string): string {
  return value
    .replace(/&/g, "&amp;")
    .replace(/</g, "&lt;")
    .replace(/>/g, "&gt;")
    .replace(/"/g, "&quot;")
    .replace(/'/g, "&#39;");
}

async function sendPrivacyNotificationEmail(subject: string, html: string): Promise<void> {
  try {
    const response = await fetch("https://api.resend.com/emails", {
      method: "POST",
      headers: {
        Authorization: `Bearer ${resendApiKey.value()}`,
        "Content-Type": "application/json",
      },
      body: JSON.stringify({
        from: "PeakPin <noreply@peakpin.app>",
        to: "privacy@peakpin.app",
        subject,
        html,
      }),
    });
    if (!response.ok) {
      logger.error("sendPrivacyNotificationEmail failed", { status: response.status, body: await response.text() });
    }
  } catch (e) {
    logger.error("sendPrivacyNotificationEmail threw", e);
  }
}

/**
 * Mints short-lived (1 hour) Cloudflare Realtime TURN credentials for
 * the CALLING signed-in user. The Flutter app calls this right before
 * starting or accepting a call and passes the returned `iceServers`
 * straight to its WebRTC PeerConnection config — this function is the
 * only place the actual Cloudflare API token ever touches.
 */
export const getTurnCredentials = onCall(
  { region: "us-central1", secrets: [cloudflareTurnKeyId, cloudflareTurnApiToken], enforceAppCheck: false },
  async (request) => {
    const uid = request.auth?.uid;
    if (!uid) {
      throw new HttpsError("unauthenticated", "Bu əməliyyat üçün daxil olmalısınız.");
    }
    // A banned account must not be able to mint paid relay credentials
    // (self-verification / d3). This was the ONE user-facing callable
    // without the check, and it happens to be the one whose comment
    // below calls itself a billing surface. A banned user's ID token
    // stays valid until it expires (`ACCEPTED_RISKS.md` — the ~1 hour
    // read-side window), which is exactly the window this closes here.
    await assertActiveUser(uid);
    // Düzəliş Prompt 8 / RT-15 — mints real Cloudflare TURN relay
    // credentials, a direct billing surface on the project's Cloudflare
    // account; no legitimate call flow needs this often.
    await enforceRateLimit("turn", uid, 30, 600);

    const keyId = cloudflareTurnKeyId.value();
    const apiToken = cloudflareTurnApiToken.value();
    const resp = await fetch(
      `https://rtc.live.cloudflare.com/v1/turn/keys/${keyId}/credentials/generate-ice-servers`,
      {
        method: "POST",
        headers: {
          Authorization: `Bearer ${apiToken}`,
          "Content-Type": "application/json",
        },
        body: JSON.stringify({ ttl: 3600 }),
      }
    );

    if (!resp.ok) {
      throw new HttpsError("internal", `Cloudflare TURN request failed: ${resp.status}`);
    }

    const json = (await resp.json()) as { iceServers: unknown };
    return { iceServers: json.iceServers };
  }
);

/**
 * Deletes the CALLING user's own account end-to-end, as a single
 * server-side operation — a disconnected or backgrounded client can't
 * leave this half-finished the way a client-side sequence of deletes
 * could. Only ever operates on request.auth.uid; there is no
 * "delete someone else" path.
 */
export const deleteAccount = onCall({ region: "us-central1", enforceAppCheck: false }, async (request) => {
  const uid = request.auth?.uid;
  if (!uid) {
    throw new HttpsError("unauthenticated", "Bu əməliyyat üçün daxil olmalısınız.");
  }

  const authTime = request.auth?.token.auth_time;
  if (!authTime || Date.now() / 1000 - authTime > FRESH_SIGN_IN_WINDOW_SECONDS) {
    throw new HttpsError("failed-precondition", "requires-recent-login");
  }

  // Revoked FIRST, before any of the deletion steps below run (Düzəliş
  // Prompt 11 / Y-1) — mirrors `removeAdmin`'s (admin-panel) own
  // "revoke before the destructive work" ordering. This alone doesn't
  // reject an already-issued ID token (Cloud Functions' `onCall`
  // runtime and Firestore Rules don't check revocation status by
  // default — see `assertActiveUser`'s comment for the mechanism that
  // actually closes that), but it does stop this account from minting
  // any NEW token from another signed-in device while this sequence of
  // ~15 non-transactional steps is still in flight.
  await auth.revokeRefreshTokens(uid);

  // Read before anything else is deleted — the phone number is only
  // available via the Auth record (deleted last, below), and this is
  // also the one place `getUser` is cheap to call.
  const authUser = await auth.getUser(uid);

  await replaceMessagesWithPlaceholder(uid);
  await archiveCreatedEvents(uid);
  await leaveJoinedEvents(uid);
  await deleteFollows(uid);
  await scrubFromOthersBlockLists(uid);
  await deleteStories(uid);
  await deleteUserPosts(uid);
  // Both run BEFORE `deleteUserVenues`: `anonymizeUserVenueEvents`
  // resolves events through the owner's venue ids, which stop existing
  // the moment those venue documents are deleted.
  await anonymizeUserPinBoxes(uid);
  await anonymizeUserVenueEvents(uid);
  await deleteUserVenues(uid);
  await deleteUserOffers(uid);
  await anonymizePinBoxOrders(uid);
  await releasePhoneNumberReservation(uid, authUser.phoneNumber);
  await releaseUsernameReservation(uid);
  await deleteIdentityVerifications(uid);
  await deleteUserDocAndSubcollections(uid);
  await deleteStoragePrefix(`profile_photos/${uid}/`);
  await deleteStoragePrefix(`stories/${uid}/`);
  await deleteStoragePrefix(`posts/${uid}/`);
  // F-4 — owner-scoped listing imagery. `deleteUserVenues`/
  // `deleteUserOffers` above delete `venue_photos/{venueId}.jpg` and
  // `offer_photos/{offerId}.jpg`, which is the PRE-Düzəliş-Prompt-3
  // flat layout; every upload since that migration writes
  // `{prefix}/{ownerUid}/{id}.jpg` instead, so those photos have in
  // practice survived every account deletion. `pinbox_photos/` and
  // `event_covers/` were never covered at all. This is a privacy
  // failure, not stray-file hygiene: it is data the user was told was
  // deleted, still in the bucket and still readable by anyone holding
  // its download URL (which needs no Firebase session — see
  // `extensions/storage-resize-images.env`'s own note on how those
  // tokens work). A prefix delete covers every object this uid owns
  // without needing individual ids; the per-id flat deletes above are
  // kept for objects still on the legacy paths (storage.rules'
  // transition block).
  await deleteStoragePrefix(`venue_photos/${uid}/`);
  await deleteStoragePrefix(`offer_photos/${uid}/`);
  await deleteStoragePrefix(`pinbox_photos/${uid}/`);
  await deleteStoragePrefix(`event_covers/${uid}/`);
  await db.collection("accountDeletions").add({ uid, deletedAt: FieldValue.serverTimestamp() });
  // Ban tombstone, removed LAST — after `users/{uid}` is already gone
  // (BACKLOG #14).
  //
  // Ordering is the whole point. `isActiveUser()` (firestore.rules) and
  // `assertActiveUser` (this file) both mean
  // `exists(users/{uid}) && !exists(bannedUsers/{uid})`. Deleting the
  // tombstone EARLY, while `users/{uid}` still exists, would flip a
  // banned account back to "active" for the rest of this ~15-step
  // sequence — long enough to send messages, place calls or file
  // reports. Deleting it here, after the user document is gone, cannot:
  // the first half of that condition already fails.
  //
  // Before `auth.deleteUser` rather than after, so a failure in that
  // final Auth call leaves no tombstone behind for a uid that will
  // never be used again.
  await db.collection("bannedUsers").doc(uid).delete();
  await auth.deleteUser(uid);

  return { success: true };
});

// Minimum age (whole years) to use PeakPin — see legal/child-safety-standards.html
// §2 and Terms of Service §2. This is the ONLY server-side enforcement point;
// the client-side date-picker bound in onboarding_screen.dart/edit_profile_screen.dart
// is UX only and can be bypassed by a modified client or a direct API call.
const MINIMUM_AGE_YEARS = 18;

/**
 * Computes whole-years-old age from a birth date, matching the same
 * "hasn't had this year's birthday yet" rule as the client's own
 * `lib/core/utils/age_calculator.dart` — kept in sync deliberately so
 * the two never disagree on ordinary calendar arithmetic.
 *
 * Deliberately uses UTC (`getUTCFullYear`/`getUTCMonth`/`getUTCDate`),
 * NOT the client's local time. Azerbaijan is UTC+4 — Baku's calendar
 * day begins 4 hours BEFORE UTC's. A UTC-based check can therefore
 * compute someone as still 17 for up to ~4 hours after their 18th
 * birthday has already passed in Baku local time, but it can NEVER
 * compute someone as 18 before they actually are, in any real-world
 * timezone. That asymmetry is intentional: for a minimum-age gate, a
 * few hours of extra caution around the exact birthday moment is the
 * safe failure mode — the alternative (admitting someone early) is not.
 */
function calculateAgeUtc(birthDate: Date, now: Date): number {
  let age = now.getUTCFullYear() - birthDate.getUTCFullYear();
  const hadBirthdayThisYear =
    now.getUTCMonth() > birthDate.getUTCMonth() ||
    (now.getUTCMonth() === birthDate.getUTCMonth() && now.getUTCDate() >= birthDate.getUTCDate());
  if (!hadBirthdayThisYear) age--;
  return age;
}

/**
 * Düzəliş Prompt 10 / AUTH-6 — handles obviously impersonation-prone
 * (support/admin/official-sounding) or structurally-reserved usernames
 * that were previously free for anyone to claim first. Kept in sync BY
 * HAND with the identical literal list in `firestore.rules`'
 * `usernames/{usernameId}` create rule — this is the same
 * "duplicate table, two runtimes" shape this codebase already accepts
 * elsewhere (e.g. `venueSubscriptionFeeByCategory`'s own doc comment),
 * since Cloud Functions (this file) and Firestore Rules can't share a
 * constant. Compared against the ALREADY-lowercased username, so this
 * list only needs lowercase entries.
 */
const RESERVED_USERNAMES = new Set([
  "admin",
  "administrator",
  "support",
  "help",
  "helpdesk",
  "peakpin",
  "moderator",
  "mod",
  "official",
  "team",
  "staff",
  "system",
  "root",
  "security",
  "info",
  "contact",
  "billing",
  "privacy",
  "legal",
  "abuse",
  "noreply",
  "null",
  "undefined",
]);

/**
 * Creates the CALLING user's `users/{uid}` profile document — the
 * ONLY path allowed to do so (`firestore.rules`'s `users` collection
 * `create` rule is `if false`; a raw client write can no longer create
 * this document at all). Replaces the Flutter client's former direct
 * `.set()` in `FirebaseAuthRepository.completeOnboarding` specifically
 * so the minimum-age check below runs somewhere a modified client
 * can't skip.
 *
 * Idempotent: if the document already exists (a retried call after a
 * dropped response, for instance), this returns success without
 * writing again rather than throwing — the caller can't tell the
 * difference between "just created" and "already existed" from a
 * dropped-response retry, and treating both as success is correct
 * either way, since the document this function would have written is
 * exactly the one already there.
 */
export const completeOnboarding = onCall({ region: "us-central1", enforceAppCheck: false }, async (request) => {
  logCallableInvocation("completeOnboarding", request);
  const uid = request.auth?.uid;
  if (!uid) {
    throw new HttpsError("unauthenticated", "unauthenticated");
  }
  // Düzəliş Prompt 8 / Y-3 — defense-in-depth against a scripted
  // account hammering onboarding attempts (the uid already exists —
  // this is AFTER Auth account creation, so it doesn't stop account
  // creation itself, only what happens once one exists).
  await enforceRateLimit("onboard", uid, 10, 600);

  const data = request.data ?? {};
  const username = typeof data.username === "string" ? data.username.trim() : "";
  const firstName = typeof data.firstName === "string" ? data.firstName.trim() : "";
  const lastName = typeof data.lastName === "string" ? data.lastName.trim() : "";
  const gender = typeof data.gender === "string" ? data.gender : "";
  const country = typeof data.country === "string" ? data.country : "";
  const city = typeof data.city === "string" ? data.city : "";
  const rawPhoneNumber = typeof data.phoneNumber === "string" ? data.phoneNumber.trim() : "";
  const businessStatus = typeof data.businessStatus === "string" ? data.businessStatus : "";
  const bio = typeof data.bio === "string" ? data.bio : "";
  const birthDateMs = data.birthDateMs;

  if (!username || !firstName || !lastName || !gender || !country || !city || !rawPhoneNumber || !businessStatus) {
    throw new HttpsError("invalid-argument", "missing-required-field");
  }
  // BACKLOG #8 — normalised here, not only on the client. This number is
  // written exactly once and there is no edit screen, so a malformed
  // value from an older build is permanent; every install currently in
  // the wild predates the client-side fix.
  let phoneNumber: string;
  try {
    phoneNumber = normalizePhoneNumber(rawPhoneNumber);
  } catch (e) {
    throw new HttpsError("invalid-argument", e instanceof InvalidPhoneNumberError ? e.reason : "invalid-phone-number");
  }
  if (typeof birthDateMs !== "number" || !Number.isFinite(birthDateMs)) {
    throw new HttpsError("invalid-argument", "invalid-birth-date");
  }

  const birthDate = new Date(birthDateMs);
  const now = new Date();
  if (birthDate.getTime() > now.getTime()) {
    throw new HttpsError("invalid-argument", "invalid-birth-date");
  }
  if (calculateAgeUtc(birthDate, now) < MINIMUM_AGE_YEARS) {
    throw new HttpsError("failed-precondition", "age-under-18");
  }

  const usernameLower = username.toLowerCase();
  if (RESERVED_USERNAMES.has(usernameLower)) {
    throw new HttpsError("invalid-argument", "Bu istifadəçi adı ayrılıb.");
  }
  const userRef = db.collection("users").doc(uid);
  const usernameRef = db.collection("usernames").doc(usernameLower);

  const existing = await userRef.get();
  if (existing.exists) {
    return { success: true, alreadyOnboarded: true };
  }

  const authUser = await auth.getUser(uid);
  // Mirrors `FirebaseAuthRepository._providerFrom` exactly — the client's
  // `LoginProvider` enum serializes as 'email'/'google'/'apple' (`.name`),
  // NOT the raw Firebase providerId strings ('google.com'/'apple.com'),
  // so this must produce the same three values or every existing reader
  // of `loginProvider` breaks.
  const loginProvider = authUser.providerData.some((p) => p.providerId === "google.com")
    ? "google"
    : authUser.providerData.some((p) => p.providerId === "apple.com")
      ? "apple"
      : "email";

  // Düzəliş Prompt 10 (əlavə) / AUTH-12 — Firebase Console-un "Link
  // accounts that use the same email" ayarı aktiv olduğu üçün provider
  // toqquşması (bax auth_screen.dart-ın `account-exists-with-different
  // -credential` tutması) artıq baş vermir, AMMA bu, e-poçt sahibliyinin
  // doğrulandığı demək DEYİL — password ilə qeydiyyatdan keçən istənilən
  // kəs, başqasının e-poçtunu yazıb (heç vaxt təsdiqləmədən) hesab
  // yarada, sonra bu hesabla tətbiqdən istifadə edə bilərdi (email
  // sahibinin özü sonra Google ilə "daxil olanda" artıq bu HƏMİN hesaba
  // bağlanacaq, amma bu ARADAKI pəncərədə saxta hesab funksionaldır).
  // Google/Apple email-i artıq provayderin özü tərəfindən doğrulanmış
  // sayılır (`request.auth.token.email_verified` bu 2 provayder üçün
  // demək olar həmişə `true`-dur) — yoxlama YALNIZ password provayderinə
  // aiddir. Client (`VerifyEmailScreen`) bu vəziyyəti onboarding-dən
  // ƏVVƏL tutur, bu, yalnız modifikasiya edilmiş/köhnə client dəfi-in-
  // depth-dir.
  if (loginProvider === "email" && request.auth?.token.email_verified !== true) {
    throw new HttpsError("permission-denied", "email-not-verified");
  }

  // `HttpsError` is deliberately never thrown from inside the
  // transaction callback below — Admin SDK's `runTransaction` retries
  // the callback on contention, and how a non-Firestore error thrown
  // mid-callback interacts with that retry is not something to rely
  // on. Instead the callback signals failure via a plain sentinel and
  // returns without writing; the HttpsError is thrown after the
  // transaction has resolved (successfully, with zero writes in the
  // taken-username case).
  let usernameTaken = false;
  await db.runTransaction(async (tx) => {
    const usernameSnap = await tx.get(usernameRef);
    if (usernameSnap.exists && usernameSnap.data()?.uid !== uid) {
      usernameTaken = true;
      return;
    }
    tx.set(usernameRef, { uid, createdAt: FieldValue.serverTimestamp() });
    // Split across two documents (Düzəliş Prompt 4 / K-1) — see
    // `privateDataRef`'s own doc comment for the full field-by-field
    // reasoning of what lives where. `country` (unlike `city`) stays
    // PUBLIC despite being personal-ish, not sensitive-vs-sensitive
    // classification: `getDiscoverCandidates`/`findNearbyUsers` filter
    // candidates with `db.collection("users").where("country", "==",
    // ...)` — a top-level Firestore query, which structurally CANNOT
    // filter across a parent/subcollection split. Same hard constraint
    // keeps `blockedUsers` (queried by `scrubFromOthersBlockLists`) and
    // `reportedCount` (see Düzəliş Prompt 12's own finding) here too.
    tx.create(userRef, {
      uid,
      username,
      nameLower: `${firstName} ${lastName}`.trim().toLowerCase(),
      firstName,
      lastName,
      bio,
      country,
      businessStatus,
      online: true,
      blockedUsers: [],
      reportedCount: 0,
      createdAt: FieldValue.serverTimestamp(),
      updatedAt: FieldValue.serverTimestamp(),
    });
    // `tx.set(..., {merge: true})`, NOT `tx.create()` — unlike `userRef`
    // right above (which genuinely never exists before onboarding),
    // this doc CAN already exist by the time onboarding runs: the
    // re-consent dialog (`consent_dialog.dart`'s `_accept()`) and other
    // "runs whenever a session exists, independent of onboarding
    // status" writers (location, profile-visit tracking — see this
    // function's own history) merge-write onto this exact path with no
    // idea whether onboarding has happened yet. `tx.create()` here used
    // to throw `ALREADY_EXISTS` the moment any of those raced ahead of
    // it, and — because that error was never caught — aborted the
    // WHOLE transaction, including the otherwise-fine `userRef` write
    // above, permanently stuck-in-onboarding (every retry hit the same
    // now-permanent conflict). `merge: true` makes this idempotent
    // with whatever partial state already got written, the same way
    // every other one of this doc's writers already treats it.
    tx.set(
      privateDataRef(uid),
      {
        loginProvider,
        ...(authUser.email ? { email: authUser.email } : {}),
        phoneNumber,
        birthDate: Timestamp.fromDate(birthDate),
        gender,
        city,
        consent: {
          termsAccepted: true,
          acceptedAt: FieldValue.serverTimestamp(),
          termsVersion: data.termsVersion ?? null,
          privacyVersion: data.privacyVersion ?? null,
        },
        updatedAt: FieldValue.serverTimestamp(),
      },
      { merge: true },
    );
  });

  if (usernameTaken) {
    throw new HttpsError("already-exists", "username-taken");
  }

  return { success: true };
});

/**
 * P0 / H-9 — the four write paths that had to move server-side when
 * `users/{uid}/private/data` stopped being fully client-writable.
 *
 * Düzəliş Prompt 4 moved `birthDate`, `email`, `phoneNumber`, `consent`,
 * `loginProvider`, `fcmTokens` and `knownDeviceSignatures` OFF the
 * public `users/{uid}` document (where `touchesLockedUserFields()`
 * guarded several of them) and INTO a subcollection whose only rule was
 * `allow read, write: if request.auth.uid == userId` — i.e. fully
 * client-writable. The rules-level lock did not travel with the fields;
 * `firestore.rules` still listed `'birthDate'` in a blocklist for a
 * document that no longer contains it. The practical effect was that
 * the 18+ gate `completeOnboarding` enforces could be undone with a
 * single `set(..., {birthDate}, {merge:true})` right afterwards.
 *
 * `firestore.rules`' `private/{document}` rule now rejects any write
 * touching those fields, so the legitimate client flows that DID write
 * some of them need a server entry point. Each one below takes its
 * value from a source the caller cannot forge rather than from
 * `request.data`, which is the actual improvement — not just relocation.
 *
 * NOT moved server-side (deliberate, revised from this fix's own
 * planning): `activeCheckinVenueId`. It looked server-only on paper,
 * but `FirebaseVenueRemoteDatasource.checkIn`/`checkOut` write it
 * inside a client transaction together with the
 * `venues/{id}/activeCheckins/{uid}` document it points at — locking it
 * would break check-in outright, and the field is a self-referential
 * pointer whose only consumer is the same user's own next check-out
 * (`onActiveCheckinCreated`/`onActiveCheckinDeleted` reconcile it
 * server-side anyway). Lying about it harms nobody but the liar.
 */

/** Registers this device's FCM token on the caller's own private doc.
 *
 * Was a direct client `arrayUnion` write. Moved here because
 * `fcmTokens` is the input to `messaging.sendEachForMulticast` — a
 * client-writable list of push targets meant an account could insert
 * ANOTHER user's token and have its own notifications delivered to that
 * person's device. That required knowing the victim's token, which is
 * why the audit rated it low; token strings do leak (logs, crash
 * reports, support transcripts), so the precondition is not one worth
 * relying on. Token rotation is rare (install, reinstall, occasional
 * refresh), so a callable costs effectively nothing here. */
export const registerFcmToken = onCall({ region: "us-central1", enforceAppCheck: false }, async (request) => {
  const uid = request.auth?.uid;
  if (!uid) throw new HttpsError("unauthenticated", "Bu əməliyyat üçün daxil olmalısınız.");
  await assertActiveUser(uid);
  await enforceRateLimit("fcm-token", uid, 20, 3600);

  const token = request.data?.token as string | undefined;
  // FCM registration tokens are long opaque strings; the bound is a
  // sanity cap against someone stuffing the array, not a format check
  // (Firebase itself is the only authority on what a valid token looks
  // like, and it rejects bad ones at send time).
  if (!token || typeof token !== "string" || token.length < 32 || token.length > 4096) {
    throw new HttpsError("invalid-argument", "token etibarsızdır.");
  }

  await privateDataRef(uid).set({ fcmTokens: FieldValue.arrayUnion(token) }, { merge: true });
  return { ok: true };
});

/** Removes this device's FCM token from the caller's own private doc —
 * called right before sign-out so a signed-out device stops receiving
 * pushes meant for whoever signs in next. Best-effort by design on the
 * client side; see `registerFcmToken` for why this moved server-side. */
export const unregisterFcmToken = onCall({ region: "us-central1", enforceAppCheck: false }, async (request) => {
  const uid = request.auth?.uid;
  if (!uid) throw new HttpsError("unauthenticated", "Bu əməliyyat üçün daxil olmalısınız.");
  // Deliberately NO `assertActiveUser` — a banned or just-deleted
  // account signing out should still be able to detach its device
  // token; refusing that would leave the token receiving pushes.
  const token = request.data?.token as string | undefined;
  if (!token || typeof token !== "string") {
    throw new HttpsError("invalid-argument", "token tələb olunur.");
  }

  await privateDataRef(uid).set({ fcmTokens: FieldValue.arrayRemove(token) }, { merge: true });
  return { ok: true };
});

/**
 * Records the caller's acceptance of the current Terms/Privacy
 * versions — the re-consent dialog's write path (`consent_dialog.dart`
 * `_accept()`), which used to write `consent` directly.
 *
 * The versions are read from `config/legal` HERE rather than taken from
 * `request.data`: `consent` is a legal record, and a client-supplied
 * version string meant the stored record could claim acceptance of a
 * version the user was never shown. `acceptedAt` is a server timestamp
 * for the same reason. Same "trust the server's own config, not the
 * client's claim" shape as `currentBusinessOffer()` and its callers.
 */
export const recordConsent = onCall({ region: "us-central1", enforceAppCheck: false }, async (request) => {
  const uid = request.auth?.uid;
  if (!uid) throw new HttpsError("unauthenticated", "Bu əməliyyat üçün daxil olmalısınız.");
  await enforceRateLimit("consent", uid, 20, 3600);

  const snap = await db.collection("config").doc("legal").get();
  const termsVersion = snap.data()?.currentTermsVersion as string | undefined;
  const privacyVersion = snap.data()?.currentPrivacyVersion as string | undefined;
  if (!termsVersion || !privacyVersion) {
    logger.error("recordConsent: config/legal is missing or incomplete");
    throw new HttpsError("failed-precondition", "legal-config-missing");
  }

  await privateDataRef(uid).set(
    {
      consent: {
        termsAccepted: true,
        acceptedAt: FieldValue.serverTimestamp(),
        termsVersion,
        privacyVersion,
      },
      updatedAt: FieldValue.serverTimestamp(),
    },
    { merge: true },
  );
  return { termsVersion, privacyVersion };
});

/**
 * Mirrors the caller's VERIFIED Firebase Auth email onto their private
 * doc — `FirebaseAccountRepository.syncEmailFromAuth`'s write half.
 *
 * Takes no arguments on purpose. The old client write passed
 * `auth.currentUser.email`, which is genuine in the real app but is
 * just a string a modified client chooses; the admin panel displays
 * this value and support/moderation act on it. Reading it from
 * `request.auth.token` instead makes it unforgeable — the same value,
 * from the one source that can't be tampered with.
 *
 * `email_verified` is required for the same reason
 * `completeOnboarding` requires it: Firebase's own
 * `verifyBeforeUpdateEmail` flow (the ONLY way the app changes this
 * address, see `updateEmail`) never lands an unverified address on the
 * Auth record, so demanding it here costs nothing and closes the
 * "changed but not confirmed" window.
 */
export const syncContactEmail = onCall({ region: "us-central1", enforceAppCheck: false }, async (request) => {
  const uid = request.auth?.uid;
  if (!uid) throw new HttpsError("unauthenticated", "Bu əməliyyat üçün daxil olmalısınız.");
  await assertActiveUser(uid);
  await enforceRateLimit("email-sync", uid, 20, 3600);

  const email = request.auth?.token.email as string | undefined;
  if (!email) throw new HttpsError("failed-precondition", "no-email-on-token");
  if (request.auth?.token.email_verified !== true) {
    throw new HttpsError("failed-precondition", "email-not-verified");
  }

  const current = (await privateDataRef(uid).get()).data()?.email as string | undefined;
  if (current === email) return { email, changed: false };

  await privateDataRef(uid).set({ email, updatedAt: FieldValue.serverTimestamp() }, { merge: true });
  return { email, changed: true };
});

// Mirrors the client's own `_countryCandidatesProvider`/
// `_worldCandidatesProvider` queries — kept in exact sync with
// `lib/features/location/presentation/providers/location_providers.dart`.
const DISCOVER_COUNTRY_CANDIDATES_LIMIT = 300;
const DISCOVER_WORLD_CANDIDATES_LIMIT = 500;

/**
 * Whole-years-old age from a Firestore `birthDate` — mirrors
 * `calculateAge` in `lib/core/utils/age_calculator.dart` exactly (same
 * "hasn't had this year's birthday yet" rule). Used instead of sending
 * raw `birthDate` back to another user's device — Düzəliş Prompt 4
 * moved `birthDate` to `users/{uid}/private/data` specifically because
 * it's PII a stranger has no legitimate reason to see in full; age
 * alone is what every candidate card actually shows.
 */
function ageYearsFromBirthDate(birthDate: unknown): number | null {
  if (!(birthDate instanceof Timestamp)) return null;
  const dob = birthDate.toDate();
  const now = new Date();
  let age = now.getFullYear() - dob.getFullYear();
  const hadBirthdayThisYear =
    now.getMonth() > dob.getMonth() || (now.getMonth() === dob.getMonth() && now.getDate() >= dob.getDate());
  if (!hadBirthdayThisYear) age -= 1;
  return age;
}

/**
 * ~100m fixed grid, applied identically to lat and lng (no
 * cosine/latitude correction — a deliberate simplification, see Düzəliş
 * Prompt 4's plan). Anti-averaging: unlike random jitter, the same
 * candidate always rounds to the exact same point, so querying
 * repeatedly and averaging the results reveals nothing beyond the
 * already-rounded point. Applied ONLY to the lat/lng returned for map
 * markers — [haversineMeters] distance calculations always use the raw,
 * unrounded coordinates internally, computed before this function is
 * ever called.
 */
const NEARBY_MARKER_GRID_STEP_DEG = 100 / 111320;
function roundToGrid(value: number): number {
  return Math.round(value / NEARBY_MARKER_GRID_STEP_DEG) * NEARBY_MARKER_GRID_STEP_DEG;
}

/**
 * P0 / H-1 (a) — quantizes the `distanceMeters` label to the SAME ~100 m
 * granularity [roundToGrid] already applies to the marker position.
 *
 * The two used to disagree, and the finer of the two is what actually
 * defined the privacy level: the marker was grid-rounded, but the exact
 * haversine distance rode along in the same response. Since a caller
 * also controls their own query origin (`private/data.lat`/`lng` is
 * written by the client, and locking it would achieve nothing — a
 * rooted device spoofs GPS below the app entirely), three calls from
 * three chosen origins trilaterate a target to sub-metre precision.
 * Bucketing collapses that to ~100 m, i.e. exactly what the rounded
 * marker already discloses — the anti-averaging property of
 * [roundToGrid] carries over, since the same true distance always
 * lands in the same bucket.
 *
 * Floored at 100 rather than allowed to reach 0: a literal "0 m" reads
 * as "standing next to you", which is both the most sensitive answer
 * and one this function should never give. Everything within ~150 m
 * therefore reports as 100 m. `formatDistance` (Dart) renders whole
 * metres below 1 km, so this shows as "100 m aralı", "200 m aralı" —
 * no client or localization change is needed.
 */
/** Implementation and tests live in `./geo`. */

/**
 * P0 / H-1 (b) — rejects a nearby query whose origin moved further
 * since the caller's previous query than any real journey could.
 *
 * Explicitly a PARTIAL mitigation, and stated as such rather than
 * dressed up: a client can always lie about its own GPS, and without
 * device attestation (App Check, currently off by deliberate decision —
 * see this file's top comment) the server cannot tell a spoofed fix
 * from a real one. What this does buy is time. Trilateration needs
 * several probes from origins separated by a meaningful baseline, taken
 * close enough together that the target hasn't moved; forcing a real
 * wait between those probes makes the target's own movement the
 * dominant error term, and makes city-scale automated scanning
 * expensive rather than instant. Bucketing (above) is the primary fix.
 *
 * 300 km/h is far above any ground vehicle and is only compared inside
 * a 15-minute window, so ordinary travel — including a long drive, and
 * including a flight once the caller has been offline through it —
 * never trips it. A cold GPS fix is wrong by hundreds of metres, not
 * hundreds of kilometres.
 *
 * Stored in its own server-only collection rather than on
 * `users/{uid}/private/data`, which is client-writable by design (an
 * attacker could otherwise reset their own last-known probe between
 * calls and disable the check).
 */

async function assertPlausibleMovement(uid: string, lat: number, lng: number): Promise<void> {
  const ref = db.collection("nearbyProbes").doc(uid);
  const now = Date.now();
  const previous = (await ref.get()).data();
  const prevLat = previous?.lat as number | undefined;
  const prevLng = previous?.lng as number | undefined;
  const prevAt = previous?.at as number | undefined;

  // The comparison itself is in `./geo` so it can be tested without
  // Firestore; this function keeps the read, the write and the log.
  const implausible = !isPlausibleMovement({ lat: prevLat, lng: prevLng, at: prevAt }, lat, lng, now);
  if (implausible) {
    logger.warn("findNearbyUsers: implausible movement between queries", {
      uid,
      movedKm: Math.round(haversineMeters(prevLat as number, prevLng as number, lat, lng) / 1000),
      elapsedSeconds: Math.round((now - (prevAt as number)) / 1000),
    });
  }

  // The probe is recorded even when rejected — otherwise an attacker
  // could alternate a rejected jump with an accepted one and keep the
  // stored origin conveniently stale.
  await ref.set({ lat, lng, at: now });
  if (implausible) {
    throw new HttpsError("failed-precondition", "implausible-movement");
  }
}

/** `'male'`/`'female'` map to this schema's existing free-text `gender`
 * values ('Kişi'/'Qadın', written by the profile edit screen) — any
 * other value (including undefined/'all') means no filter. */
function matchesGenderFilter(gender: unknown, filter: unknown): boolean {
  if (filter !== "male" && filter !== "female") return true;
  return gender === (filter === "male" ? "Kişi" : "Qadın");
}

interface PublicCandidatePayload {
  uid: string;
  username: string | null;
  firstName: string;
  lastName: string;
  bio: string;
  photoUrl: string | null;
  online: boolean;
  lastSeen: number | null;
  age: number | null;
  lat: number | null;
  lng: number | null;
}

/**
 * The ONLY fields ever sent to another user's device for a Discover/
 * nearby candidate — deliberately a fixed allowlist, not a spread of
 * `data`, precisely because `data` here is a merged public+private
 * object (see `withPrivateData`) that also carries `email`,
 * `phoneNumber`, `fcmTokens`, `knownDeviceSignatures`, `gender`,
 * `blockedUsers`, `ghostModeEnabled`, etc. — every one of those is
 * filtering/internal-use-only and must never round-trip to a stranger's
 * client, which a spread would silently do the moment any new private
 * field is added later. `gender` itself is applied as a SERVER-SIDE
 * filter ([matchesGenderFilter]) rather than returned, since it's no
 * longer a public field and no screen displays it anyway (confirmed:
 * neither `user_profile_screen.dart` nor the discover card shows it —
 * only a filter-selection sheet reads a separate, viewer-owned
 * [GenderFilter] value).
 */
function buildPublicCandidatePayload(id: string, data: FirebaseFirestore.DocumentData): PublicCandidatePayload {
  const lastSeen = data.lastSeen instanceof Timestamp ? data.lastSeen.toMillis() : null;
  const lat = typeof data.lat === "number" ? roundToGrid(data.lat) : null;
  const lng = typeof data.lng === "number" ? roundToGrid(data.lng) : null;
  return {
    uid: id,
    username: (data.username as string | undefined) ?? null,
    firstName: (data.firstName as string | undefined) ?? "",
    lastName: (data.lastName as string | undefined) ?? "",
    bio: (data.bio as string | undefined) ?? "",
    photoUrl: (data.photoUrl as string | undefined) ?? null,
    online: (data.online as boolean | undefined) ?? false,
    lastSeen,
    age: ageYearsFromBirthDate(data.birthDate),
    lat,
    lng,
  };
}

/**
 * Returns Ölkə üzrə/Dünya üzrə Discover candidates for the CALLING
 * user — the one place that mode's "VIP-only" rule is actually
 * enforced. The Flutter client used to run these two queries directly
 * against Firestore (`_countryCandidatesProvider`/
 * `_worldCandidatesProvider`); `firestore.rules` has no way to express
 * "only if requester.premium == true" for a `list` query shaped like
 * this without also blocking the always-free nearby/profile reads that
 * share the same `users/{uid}` read rule, so the check has to live
 * here instead, reading `premium` from the requester's OWN doc (never
 * client-supplied, so it can't be spoofed).
 *
 * Düzəliş Prompt 4: `lat`/`lng`/`visibilityRadiusMode`/`visibilityRadiusKm`/
 * `gender` moved to `users/{uid}/private/data`, so every candidate is
 * merged with its private doc ([withPrivateData]) before filtering —
 * but only [buildPublicCandidatePayload]'s fixed allowlist (plus
 * grid-rounded `lat`/`lng`, same anti-averaging treatment as
 * `findNearbyUsers`) is ever returned. This map is ALSO what
 * `discover_tab.dart` drops pins from for Ölkə/Dünya mode, so it has
 * the exact same raw-coordinate exposure `findNearbyUsers` was built to
 * close — rounding applies here too, not just to the distance-mode
 * feed.
 */
export const getDiscoverCandidates = onCall({ region: "us-central1", enforceAppCheck: false }, async (request) => {
  const uid = request.auth?.uid;
  if (!uid) {
    throw new HttpsError("unauthenticated", "Bu əməliyyat üçün daxil olmalısınız.");
  }
  await assertActiveUser(uid);
  // P0 — this was the ONLY collection-wide scan with no limiter at all,
  // and the most expensive one in the file: `world` mode reads 500
  // `users` documents plus a `private/data` document for each
  // (`withPrivateData`), so ~1000 reads per call. Unbounded, that is a
  // billing attack rather than a data-theft one — a VIP account
  // (a monthly subscription) could run it in a loop and burn real money
  // with nothing "breached". Shares the `nearby` counter with
  // `findNearbyUsers`/`previewVenueAudience` deliberately: all three
  // answer the same question over the same collection, so a separate
  // scope would just let an attacker spread the load across them.
  await enforceRateLimit("nearby", uid, 10, 60);

  const mode = request.data?.mode as string | undefined;
  if (mode !== "country" && mode !== "world") {
    throw new HttpsError("invalid-argument", "invalid-mode");
  }
  const genderFilter = request.data?.genderFilter;

  const [callerSnap, callerPrivateSnap] = await Promise.all([
    db.collection("users").doc(uid).get(),
    privateDataRef(uid).get(),
  ]);
  // Düzəliş Prompt 10 / Y-6 — rewritten from the equivalent
  // `callerSnap.data()?.premium !== true` (a "not-equal" optional-
  // chain comparison, the exact shape that pattern search flagged):
  // that phrasing already failed CLOSED (a missing `callerSnap` made
  // `undefined !== true` → `true` → correctly rejected), so this was
  // never exploitable — rewritten as a positive, explicit check purely
  // for readability/consistency with the rest of this sweep's fixes.
  if (!callerSnap.exists || callerSnap.data()?.premium !== true) {
    throw new HttpsError("permission-denied", "premium-required");
  }

  let query: FirebaseFirestore.Query = db.collection("users").where("online", "==", true);
  if (mode === "country") {
    const country = request.data?.country as string | undefined;
    if (!country) {
      throw new HttpsError("invalid-argument", "missing-country");
    }
    query = query.where("country", "==", country).limit(DISCOVER_COUNTRY_CANDIDATES_LIMIT);
  } else {
    query = query.limit(DISCOVER_WORLD_CANDIDATES_LIMIT);
  }

  // Quantized for the same reason as `findNearbyUsers` — see
  // [quantizeOriginDegrees] (`./geo`). This function returns no
  // distance at all, but `isWithinTargetVisibilityRadius` below is a
  // BOOLEAN computed from these coordinates, and a candidate blinking
  // in and out as the caller shifts their claimed position marks that
  // candidate's own visibility radius just as sharply as a number
  // would. A yes/no oracle is still an oracle.
  const rawViewerLat = callerPrivateSnap.data()?.lat as number | undefined;
  const rawViewerLng = callerPrivateSnap.data()?.lng as number | undefined;
  const viewerLat = typeof rawViewerLat === "number" ? quantizeOriginDegrees(rawViewerLat) : undefined;
  const viewerLng = typeof rawViewerLng === "number" ? quantizeOriginDegrees(rawViewerLng) : undefined;
  const viewerCountry = callerSnap.data()?.country as string | undefined;
  const myBlockedUsers = (callerSnap.data()?.blockedUsers as string[] | undefined) ?? [];

  const snap = await query.get();
  const merged = await withPrivateData(snap.docs);
  const candidates = merged
    .filter((c) => c.id !== uid)
    .filter((c) => !myBlockedUsers.includes(c.id))
    .filter((c) => !((c.data.blockedUsers as string[] | undefined) ?? []).includes(uid))
    // Banned accounts stay out of Discover too — see the identical
    // filter in `findNearbyUsers` for why this reads a mirror instead
    // of `bannedUsers`, and which one wins on disagreement.
    .filter((c) => c.data.banned !== true)
    // BACKLOG #20 — the same staleness gate `findNearbyUsers` applies.
    // The query above can only ask `online == true`, and that flag is
    // written by the client: a crash or force-quit before the
    // `online: false` write leaves it set forever. This function had
    // no second check, so anyone who ever force-quit stayed listed as
    // present indefinitely — see [isRecentlyOnlineServer]'s own
    // comment, which describes exactly the case its sibling was
    // already guarding against and this one was not.
    .filter((c) => isRecentlyOnlineServer(c.data.online, c.data.lastSeen))
    .filter((c) => isWithinTargetVisibilityRadius(c.data, viewerLat, viewerLng, viewerCountry))
    .filter((c) => matchesGenderFilter(c.data.gender, genderFilter))
    .map((c) => buildPublicCandidatePayload(c.id, c.data));

  return { candidates };
});

/** Matches `kOnlineStalenessThreshold` in
 * `lib/core/utils/presence_utils.dart` — a stale `online: true` write
 * (crash/force-quit before the client could write `online: false`)
 * must not leave someone looking permanently present. */
const NEARBY_ONLINE_STALENESS_MS = 90 * 1000;

function isRecentlyOnlineServer(online: unknown, lastSeen: unknown): boolean {
  if (online !== true || !(lastSeen instanceof Timestamp)) return false;
  return Date.now() - lastSeen.toMillis() <= NEARBY_ONLINE_STALENESS_MS;
}

/** Mirrors `_isWithinVisibilityRadius` in `location_providers.dart` —
 * the distance-mode nearby feed only ever understands a 'distance' cap;
 * 'country'/'world' visibility (like `discoverRadiusMode`) means no cap
 * for this feed. Distinct from [isWithinTargetVisibilityRadius], which
 * additionally understands 'country' mode for `getDiscoverCandidates`. */
/** Takes the two fields it actually reads rather than
 * `FirebaseFirestore.DocumentData`, so `computeAudienceCount`'s own
 * [AudienceUserDoc] can be passed straight in — an interface is not
 * assignable to an index-signature type, and widening it with a cast
 * at the call site would defeat the point of the shared check. */
function isWithinNearbyVisibility(
  data: { visibilityRadiusMode?: unknown; visibilityRadiusKm?: unknown },
  distanceMeters: number,
): boolean {
  if (data.visibilityRadiusMode !== "distance") return true;
  const radiusKm = data.visibilityRadiusKm as number | undefined;
  if (radiusKm === undefined) return true;
  return distanceMeters <= radiusKm * 1000;
}

// Matches `_nearbyCandidatesProvider`'s old raw-query bounds exactly
// (15-minute lastSeen window, 200-doc scan cap) — this callable
// replaces that direct client query, not just its data source.
const NEARBY_CANDIDATE_SCAN_LIMIT = 200;
const NEARBY_LAST_SEEN_WINDOW_MS = 15 * 60 * 1000;

// Server-side hard cap on how many candidates are ever returned,
// regardless of how many matched or what the client asked for (Düzəliş
// Prompt 4 qərarı: "nəticə sayı server-də sabitlənir, client-in
// göndərdiyi limit dəyərinə etibar edilmir"). Candidates are sorted by
// distance first, so a dense area's radius-count buttons (see
// `radiusUserCountsProvider`) can undercount past this many online
// users nearby — an accepted trade-off, not a bug, at this app's scale.
const NEARBY_RESULT_CAP = 50;

/**
 * Replaces the client's own direct `users` query (`_nearbyCandidatesProvider`)
 * — Düzəliş Prompt 4 / K-1, K-4's "Variant B". Ghost Mode, the
 * candidate's own visibility radius, and the gender filter are now
 * enforced HERE, server-side, using Admin SDK access to
 * `users/{uid}/private/data` — none of the three could actually be
 * bypassed before this (a modified client, or a direct Firestore REST
 * call, saw every candidate's raw fields regardless of any of these
 * "privacy" toggles). Raw coordinates of OTHER users never leave this
 * function: [buildPublicCandidatePayload] grid-rounds `lat`/`lng` for
 * the marker position; `distanceMeters` is computed from the raw,
 * unrounded coordinates before that rounding happens, so the label
 * itself stays precise.
 *
 * Rate-limited (`enforceRateLimit("nearby", ...)`) and gated on
 * `assertActiveUser` — this scans the whole `users` collection, the
 * same scraping vector K-1 itself was about, so it needs the same
 * volumetric guard Düzəliş Prompt 8 already established for other
 * collection-wide entry points.
 */
export const findNearbyUsers = onCall({ region: "us-central1", enforceAppCheck: false }, async (request) => {
  logCallableInvocation("findNearbyUsers", request);
  const uid = request.auth?.uid;
  if (!uid) {
    throw new HttpsError("unauthenticated", "Bu əməliyyat üçün daxil olmalısınız.");
  }
  await assertActiveUser(uid);
  await enforceRateLimit("nearby", uid, 10, 60);
  const genderFilter = request.data?.genderFilter;

  const [callerSnap, callerPrivateSnap, scanSnap] = await Promise.all([
    db.collection("users").doc(uid).get(),
    privateDataRef(uid).get(),
    db
      .collection("users")
      .where("lastSeen", ">", Timestamp.fromMillis(Date.now() - NEARBY_LAST_SEEN_WINDOW_MS))
      .limit(NEARBY_CANDIDATE_SCAN_LIMIT)
      .get(),
  ]);
  // Same source LocationController already keeps fresh via its own
  // 25m-distanceFilter live GPS stream — no need for the client to also
  // pass a fresh reading on every poll tick, and it keeps this
  // callable's request shape identical to `getDiscoverCandidates`
  // (which reads the caller's own position the same way).
  const rawLat = callerPrivateSnap.data()?.lat as number | undefined;
  const rawLng = callerPrivateSnap.data()?.lng as number | undefined;
  if (typeof rawLat !== "number" || typeof rawLng !== "number") {
    throw new HttpsError("failed-precondition", "no-position-on-file");
  }
  // P0 / H-1 (b) — see [assertPlausibleMovement]. Deliberately fed the
  // RAW claimed position: it is looking for a caller who teleports, and
  // the quantized origin below would blur exactly the evidence it needs.
  await assertPlausibleMovement(uid, rawLat, rawLng);
  // THE trilateration fix — see [quantizeOriginDegrees] (`./geo`) for
  // why the bucketed `distanceMeters` below is not, and for the
  // measurements. Everything downstream (the distance label, the
  // visibility-radius filter, the distance sort feeding
  // NEARBY_RESULT_CAP) reads these and never `rawLat`/`rawLng`, so all
  // three boundaries move onto the ~100 m grid together.
  const lat = quantizeOriginDegrees(rawLat);
  const lng = quantizeOriginDegrees(rawLng);
  const myBlockedUsers = (callerSnap.data()?.blockedUsers as string[] | undefined) ?? [];

  const candidates = await withPrivateData(scanSnap.docs);

  const results = candidates
    .filter((c) => c.id !== uid)
    .filter((c) => !myBlockedUsers.includes(c.id))
    .filter((c) => !((c.data.blockedUsers as string[] | undefined) ?? []).includes(uid))
    // Ban applies to visibility, not just to what the account can do.
    // `bannedUsers/{uid}` is the source of truth, but reading it per
    // candidate would add one document read for every one of the
    // hundreds scanned here — a ~50% increase on this app's most
    // expensive endpoint. `private/data.banned` is a mirror written by
    // `setUserBanned` in the same batch as the tombstone, and
    // `withPrivateData` above has already fetched that document, so
    // this filter is free. IF THE TWO EVER DISAGREE, `bannedUsers`
    // WINS: it is what `isActiveUser()`/`assertActiveUser()` enforce,
    // and a stale mirror can only make someone visible who should not
    // be — never the reverse. Never make an authorization decision
    // from this field; it exists to filter a list.
    .filter((c) => c.data.banned !== true)
    .filter((c) => c.data.ghostModeEnabled !== true)
    .filter((c) => isRecentlyOnlineServer(c.data.online, c.data.lastSeen))
    .filter((c) => typeof c.data.lat === "number" && typeof c.data.lng === "number")
    .filter((c) => matchesGenderFilter(c.data.gender, genderFilter))
    .map((c) => ({ candidate: c, distanceMeters: haversineMeters(lat, lng, c.data.lat as number, c.data.lng as number) }))
    .filter(({ candidate, distanceMeters }) => isWithinNearbyVisibility(candidate.data, distanceMeters))
    .sort((a, b) => a.distanceMeters - b.distanceMeters)
    .slice(0, NEARBY_RESULT_CAP)
    .map(({ candidate, distanceMeters }) => ({
      ...buildPublicCandidatePayload(candidate.id, candidate.data),
      // P0 / H-1 (a) — quantized to the same ~100 m as the marker
      // position above; the raw value never leaves this function. The
      // sort a few lines up still uses the exact distance, so ordering
      // stays correct within a bucket.
      distanceMeters: bucketDistanceMeters(distanceMeters),
    }));

  return { candidates: results };
});

/**
 * Owner-only "how many people would this reach" preview backing
 * `venueAudienceCountProvider` (`VenueProfileScreen`'s audience-radius
 * setting) — Düzəliş Prompt 4 moved `lat`/`lng`/`ghostModeEnabled` off
 * the public `users/{uid}` doc, so the client's old direct-Firestore
 * version of this count (reading `_nearbyCandidatesProvider`/
 * `_countryCandidatesProvider`/`_worldCandidatesProvider`) can no
 * longer see either field for anyone but itself. Mirrors those three
 * scans' exact original semantics (country/world: `online == true`
 * scoped scan, ghost-mode excluded, no visibility-radius check —
 * matching what `venueAudienceCountProvider` itself never applied for
 * those two modes either; distance: 15-minute `lastSeen` scan, ghost
 * mode AND [isWithinNearbyVisibility] both checked, same as
 * `nearbyUsersProvider`'s own distance-mode branch) — only the query
 * center moves from "the caller's own device" to a specific venue's
 * fixed coordinates, and only that venue's OWNER may call this for it.
 * Never shown to a non-owner viewing the venue (see
 * `venueAudienceCountProvider`'s own doc comment) — only a count is
 * ever returned, never which users matched.
 */
// P0 / H-2 — the smallest audience count this function will report
// precisely. Below it the answer collapses to 0.
//
// Without this, a venue owner had a yes/no presence oracle: pick a
// point, ask for a tiny radius, and a 0→1 transition confirms a
// specific person is standing there right now. Ghost Mode and each
// candidate's own visibility radius are both honoured by the filter
// below, but neither answers "is ANYONE within 50 m of this doorway",
// which is the question that makes it a physical-safety problem rather
// than an analytics one. A k of 5 keeps the feature's actual purpose
// (roughly how many people would this reach) intact — an owner
// choosing an audience radius does not need to distinguish 1 from 4.

/** Upper bound on a venue's audience radius, matching the largest
 * value `VenueProfileScreen`'s own radius picker offers. A cap is
 * needed regardless of the picker because `radiusKm` used to arrive
 * unbounded from the client. */

export const previewVenueAudience = onCall({ region: "us-central1", enforceAppCheck: false }, async (request) => {
  const uid = request.auth?.uid;
  if (!uid) {
    throw new HttpsError("unauthenticated", "Bu əməliyyat üçün daxil olmalısınız.");
  }
  await assertActiveUser(uid);

  const venueId = request.data?.venueId as string | undefined;
  if (!venueId) {
    throw new HttpsError("invalid-argument", "venueId tələb olunur.");
  }
  const venue = (await db.collection("venues").doc(venueId).get()).data();
  if (!venue) {
    throw new HttpsError("not-found", "Məkan tapılmadı.");
  }
  if (venue.ownerId !== uid) {
    throw new HttpsError("permission-denied", "not-owner");
  }

  await enforceRateLimit("nearby", uid, 10, 60);

  // P0 / H-2 — `mode` is now an explicit allowlist. It used to fall
  // through to the distance-shaped scan for ANY unrecognized value and
  // then, because the `mode === "distance"` branch below didn't match
  // either, return the raw count of every online user — a
  // platform-wide metric leaked by sending a typo.
  const mode = request.data?.mode as string | undefined;
  if (mode !== "distance" && mode !== "country" && mode !== "world") {
    throw new HttpsError("invalid-argument", "mode 'distance', 'country' və ya 'world' olmalıdır.");
  }

  let query: FirebaseFirestore.Query;
  if (mode === "country") {
    const country = request.data?.country as string | undefined;
    if (!country) throw new HttpsError("invalid-argument", "missing-country");
    query = db
      .collection("users")
      .where("online", "==", true)
      .where("country", "==", country)
      .limit(DISCOVER_COUNTRY_CANDIDATES_LIMIT);
  } else if (mode === "world") {
    query = db.collection("users").where("online", "==", true).limit(DISCOVER_WORLD_CANDIDATES_LIMIT);
  } else {
    query = db
      .collection("users")
      .where("lastSeen", ">", Timestamp.fromMillis(Date.now() - NEARBY_LAST_SEEN_WINDOW_MS))
      .limit(NEARBY_CANDIDATE_SCAN_LIMIT);
  }

  const snap = await query.get();
  const candidates = await withPrivateData(snap.docs);
  const nonGhost = candidates.filter((c) => c.data.ghostModeEnabled !== true);

  let count: number;
  if (mode === "distance") {
    // P0 / H-2 — the query centre is the VENUE's own stored position,
    // never `request.data.lat`/`lng`. The ownership check above only
    // ever proved "this venue is yours"; the scan then ran against
    // whatever coordinates the caller supplied, so owning one venue
    // anywhere licensed an audience-density probe at any point on
    // Earth. (A venue document exists from `submitVenue` onward, i.e.
    // BEFORE its first payment clears, so this didn't even cost
    // anything.) The client still sends lat/lng; they are ignored.
    const lat = venue.lat as number | undefined;
    const lng = venue.lng as number | undefined;
    if (typeof lat !== "number" || typeof lng !== "number") {
      throw new HttpsError("failed-precondition", "venue-has-no-position");
    }
    const requestedRadiusKm = request.data?.radiusKm as number | undefined;
    if (typeof requestedRadiusKm !== "number" || !Number.isFinite(requestedRadiusKm) || requestedRadiusKm <= 0) {
      throw new HttpsError("invalid-argument", "radiusKm müsbət ədəd olmalıdır.");
    }
    const radiusKm = clampAudienceRadiusKm(requestedRadiusKm);
    count = nonGhost.filter((c) => {
      if (typeof c.data.lat !== "number" || typeof c.data.lng !== "number") return false;
      const distanceMeters = haversineMeters(lat, lng, c.data.lat as number, c.data.lng as number);
      return distanceMeters <= radiusKm * 1000 && isWithinNearbyVisibility(c.data, distanceMeters);
    }).length;
  } else {
    count = nonGhost.length;
  }

  // k-anonymity floor — see [reportableAudienceCount] (`./geo`).
  return { count: reportableAudienceCount(count) };
});

const SEARCH_BY_NAME_LIMIT = 20;

interface SearchProfilePayload {
  uid: string;
  username: string | null;
  firstName: string;
  lastName: string;
  photoUrl: string | null;
  identityVerified: boolean;
  premium: boolean;
}

function buildSearchProfilePayload(id: string, data: FirebaseFirestore.DocumentData): SearchProfilePayload {
  return {
    uid: id,
    username: (data.username as string | undefined) ?? null,
    firstName: (data.firstName as string | undefined) ?? "",
    lastName: (data.lastName as string | undefined) ?? "",
    photoUrl: (data.photoUrl as string | undefined) ?? null,
    identityVerified: (data.identityVerified as boolean | undefined) ?? false,
    premium: (data.premium as boolean | undefined) ?? false,
  };
}

/**
 * Replaces the client's own direct `users.orderBy('nameLower')...`
 * query (`FirebaseDiscoverSearchRepository.searchUsersByName`) — a
 * plain `list` query the client can no longer run at all since Düzəliş
 * Prompt 4 / RT-25 closed `allow list` on `users` outright. That was a
 * genuine regression this function fixes: discovered while researching
 * Düzəliş Prompt 5, not caught during Prompt 4's own verification
 * because the query is written as `_users\n  .orderBy(...)` — a
 * multi-line method chain a same-line `grep "_users\."` silently missed.
 * Never deployed, so no real user was ever affected — but it would have
 * broken outright the moment rules shipped.
 *
 * Also closes the block gap name-search shared with
 * `searchUsersByUsername` (Düzəliş Prompt 5 / K-3): a blocked pair, in
 * EITHER direction, never appears in results — checked directly
 * against both sides' `blockedUsers` arrays via the Admin SDK, same
 * pattern as `findNearbyUsers`. No reverse index needed here (that's
 * only for CLIENT-side list-query filtering, e.g. post/story feeds —
 * this callable already reads every candidate's own doc server-side).
 */
export const searchUsersByName = onCall({ region: "us-central1", enforceAppCheck: false }, async (request) => {
  const uid = request.auth?.uid;
  if (!uid) {
    throw new HttpsError("unauthenticated", "Bu əməliyyat üçün daxil olmalısınız.");
  }
  await assertActiveUser(uid);
  // P0 — shares the `search` counter with `searchUsersByUsername`; both
  // feed the same search box, so one budget across the pair is what a
  // debounced type-ahead actually needs.
  await enforceRateLimit("search", uid, 30, 60);

  const query = (request.data?.query as string | undefined)?.trim().toLowerCase() ?? "";
  if (!query) return { profiles: [] };

  const [callerSnap, snap] = await Promise.all([
    db.collection("users").doc(uid).get(),
    db
      .collection("users")
      .orderBy("nameLower")
      .startAt(query)
      .endAt(`${query}`)
      .limit(SEARCH_BY_NAME_LIMIT)
      .get(),
  ]);
  const myBlockedUsers = (callerSnap.data()?.blockedUsers as string[] | undefined) ?? [];

  const profiles = snap.docs
    .filter((d) => d.id !== uid)
    .filter((d) => !myBlockedUsers.includes(d.id))
    .filter((d) => !((d.data().blockedUsers as string[] | undefined) ?? []).includes(uid))
    .map((d) => buildSearchProfilePayload(d.id, d.data()));

  return { profiles };
});

/**
 * P0 / H-6 — username-prefix search, moved off the client.
 *
 * `firestore.rules` closed `allow list` on `usernames`, which this
 * replaces. RT-25 had already closed `list` on `users` itself to stop
 * mass scraping, but `usernames` was left listable and is a complete
 * `username → uid` index: `orderBy(documentId).startAt([''])` plus
 * paging walked the entire user base, and each uid then resolved to a
 * full public profile through the still-open single-document `get` —
 * including `blockedUsers` (a social graph) and `reportedCount` (a
 * moderation signal). One extra hop, same outcome.
 *
 * `allow get` on `usernames` deliberately stays open, including to
 * signed-out callers (see `docs/ACCEPTED_RISKS.md` and
 * `deep_link_handler.dart`'s `_openProfileByUsername`): resolving ONE
 * already-known username is public profile discovery, which this app
 * wants. Enumerating ALL of them is not. That distinction is the whole
 * point of splitting `get` from `list`.
 *
 * Mirrors `searchUsersByName`'s shape exactly — same result cap, same
 * bidirectional block filter, same fixed field allowlist — since the
 * two feed the same search screen.
 */
export const searchUsersByUsername = onCall({ region: "us-central1", enforceAppCheck: false }, async (request) => {
  const uid = request.auth?.uid;
  if (!uid) {
    throw new HttpsError("unauthenticated", "Bu əməliyyat üçün daxil olmalısınız.");
  }
  await assertActiveUser(uid);
  await enforceRateLimit("search", uid, 30, 60);

  const query = (request.data?.query as string | undefined)?.trim().toLowerCase() ?? "";
  if (!query) return { profiles: [] };

  // `\uf8ff` is the highest code point in the Basic Multilingual
  // Plane — the standard Firestore prefix-range idiom, and exactly what
  // the client query this replaces used (`_kPrefixRangeEnd`).
  const usernamesSnap = await db
    .collection("usernames")
    .orderBy(FieldPath.documentId())
    .startAt(query)
    .endAt(`${query}\uf8ff`)
    .limit(SEARCH_BY_NAME_LIMIT)
    .get();

  const uids = usernamesSnap.docs
    .map((d) => d.data()?.uid as string | undefined)
    .filter((u): u is string => typeof u === "string" && u !== uid);
  if (uids.length === 0) return { profiles: [] };

  const [callerSnap, profileSnaps] = await Promise.all([
    db.collection("users").doc(uid).get(),
    db.getAll(...uids.map((u) => db.collection("users").doc(u))),
  ]);
  const myBlockedUsers = (callerSnap.data()?.blockedUsers as string[] | undefined) ?? [];

  const profiles = profileSnaps
    .filter((d) => d.exists)
    .filter((d) => !myBlockedUsers.includes(d.id))
    .filter((d) => !((d.data()?.blockedUsers as string[] | undefined) ?? []).includes(uid))
    .map((d) => buildSearchProfilePayload(d.id, d.data()!));

  return { profiles };
});

const VENUE_REVIEWS_LIMIT = 100;

/**
 * P0 / M-7 — a venue's review list, moved off the client.
 *
 * `firestore.rules` closed `allow list` on `reviews`, which this
 * replaces. The collection was readable by any signed-in user as a
 * whole, and a review is not ordinary user-generated content here: it
 * can only exist behind `hasVerifiedVisit`, i.e. a waitlist entry a
 * venue's own staff marked `seated`. Its existence is therefore proof
 * that a specific person was physically inside a specific venue. With
 * the document id being `{venueId}_{userId}`, one unbounded list query
 * returned the whole "who was where" graph — the same class of exposure
 * Düzəliş Prompt 4 spent an entire pass removing from the location
 * feed, reachable by a completely different route.
 *
 * `allow get` stays open: reading ONE review whose id you already have
 * (`watchMyReview`, which is a plain `.doc()` read) is not enumeration.
 * Same `get`-vs-`list` distinction as `usernames`.
 *
 * Block filtering is applied here, which the raw query never did — a
 * blocked pair should not see each other's reviews in either direction,
 * matching `searchUsersByName`/`searchUsersByUsername`.
 *
 * Returns plain JSON, not Firestore documents, so the client's own
 * `Review.fromJson` shape is what defines the contract; `createdAt`/
 * `updatedAt`/`ownerReply.repliedAt` are sent as epoch milliseconds and
 * the client's `TimestampConverter` handles the rest.
 */
export const listVenueReviews = onCall({ region: "us-central1", enforceAppCheck: false }, async (request) => {
  const uid = request.auth?.uid;
  if (!uid) {
    throw new HttpsError("unauthenticated", "Bu əməliyyat üçün daxil olmalısınız.");
  }
  await assertActiveUser(uid);
  // Own scope rather than sharing `search`: this is a per-venue read a
  // user performs while browsing, so it runs more often than a search
  // box and shouldn't be able to exhaust that budget (or vice versa).
  await enforceRateLimit("venue-reviews", uid, 60, 60);

  const venueId = request.data?.venueId as string | undefined;
  if (!venueId) throw new HttpsError("invalid-argument", "venueId tələb olunur.");

  const [callerSnap, snap] = await Promise.all([
    db.collection("users").doc(uid).get(),
    db
      .collection("reviews")
      .where("venueId", "==", venueId)
      .orderBy("createdAt", "desc")
      .limit(VENUE_REVIEWS_LIMIT)
      .get(),
  ]);
  const myBlockedUsers = (callerSnap.data()?.blockedUsers as string[] | undefined) ?? [];

  // One `users/{authorId}` read per distinct author, to check the
  // reverse block direction. Deduplicated because a venue's reviews are
  // one-per-user by construction (`{venueId}_{userId}` doc ids), so this
  // is at most `VENUE_REVIEWS_LIMIT` reads and usually far fewer.
  const authorIds = [...new Set(snap.docs.map((d) => d.data().userId as string).filter(Boolean))];
  const authorSnaps = authorIds.length > 0
    ? await db.getAll(...authorIds.map((a) => db.collection("users").doc(a)))
    : [];
  const blockedMe = new Set(
    authorSnaps
      .filter((a) => ((a.data()?.blockedUsers as string[] | undefined) ?? []).includes(uid))
      .map((a) => a.id),
  );

  const millis = (v: unknown): number | null => (v instanceof Timestamp ? v.toMillis() : null);

  const reviews = snap.docs
    .filter((d) => {
      const authorId = d.data().userId as string | undefined;
      return !!authorId && !myBlockedUsers.includes(authorId) && !blockedMe.has(authorId);
    })
    .map((d) => {
      const data = d.data();
      const reply = data.ownerReply as FirebaseFirestore.DocumentData | undefined;
      return {
        id: d.id,
        venueId: data.venueId as string,
        userId: data.userId as string,
        rating: data.rating as number,
        comment: (data.comment as string | undefined) ?? "",
        waitlistEntryId: (data.waitlistEntryId as string | undefined) ?? "",
        createdAt: millis(data.createdAt),
        updatedAt: millis(data.updatedAt) ?? millis(data.createdAt),
        ...(reply
          ? { ownerReply: { text: (reply.text as string | undefined) ?? "", repliedAt: millis(reply.repliedAt) } }
          : {}),
      };
    });

  return { reviews };
});

/** Chat messages this user sent — replaced, not deleted, so the other
 * participant's chat history stays intact. Same scope also owns Storage
 * cleanup: each message's own media (image/video/audio) is deleted
 * from Storage right before the field itself is cleared, using the exact
 * `senderId == uid` set already being queried here — never the whole
 * `{chatId}` folder, since that would also delete the OTHER
 * participant's media.
 *
 * P0 / C-1 — the path comes from [chatMediaPathForMessage] (server-
 * computed) rather than the message's own `mediaUrl` string; see that
 * helper's doc comment for the vector this closes. This call site was
 * the SECOND entry point into it: a user could plant messages pointing
 * at arbitrary objects and then delete their own account to trigger the
 * same arbitrary deletion. */
async function replaceMessagesWithPlaceholder(uid: string): Promise<void> {
  const chatsSnap = await db.collection("chats").where("participants", "array-contains", uid).get();

  for (const chatDoc of chatsSnap.docs) {
    const messagesSnap = await chatDoc.ref.collection("messages").where("senderId", "==", uid).get();
    await Promise.all(
      messagesSnap.docs.map(async (messageDoc) => {
        await deleteChatMessageMedia(chatDoc.id, messageDoc.id, messageDoc.data());
        await messageDoc.ref.update({
          text: DELETED_SENDER_PLACEHOLDER,
          mediaUrl: FieldValue.delete(),
          deletedSender: true,
        });
      })
    );
  }
}

/**
 * Düzəliş Prompt 10 / PAY-24 — PinBox orders this user bought,
 * anonymized in place (not deleted outright) — same
 * "keep-the-record-drop-the-identity" shape as `replaceMessagesWithPlaceholder`
 * above, not the alternative "hard-delete outright" shape
 * `deleteUserPosts`/`deleteUserVenues`/`deleteUserOffers` use: an
 * order is the VENUE's own sale/redemption/payout record too (see
 * `venuePayouts`), so it can't just disappear when the buyer's account
 * does — it just shouldn't keep pointing at a deleted account's uid
 * forever. Was previously the one collection `deleteAccount` never
 * touched at all — no deliberate-exclusion reasoning existed for it
 * the way there is for `payments` (financial/audit record, see
 * `deleteUserDocAndSubcollections`'s own doc comment) — this was a
 * plain omission.
 *
 * `buyerId` itself is left as-is rather than nulled — `PinBoxOrder`
 * (Dart, pinbox_order.dart) declares it `required String buyerId`
 * (non-nullable), so writing `null` here would make every existing
 * client-side reader of this doc throw on parse (this codebase's own
 * per-document `_safePinBox`/`_safeOffer`-style isolation would catch
 * that and just drop the doc from whatever list renders it — silently
 * hiding a venue's own real order/payout history, not what anonymizing
 * a field should do). The bare uid alone, with the matching
 * `users/{uid}` doc already gone (deleted earlier in this same
 * sequence), resolves to nothing on its own — `buyerDeleted` is what
 * actually signals "this buyer account no longer exists" to any
 * future reader.
 */
async function anonymizePinBoxOrders(uid: string): Promise<void> {
  const snap = await db.collection("pinboxOrders").where("buyerId", "==", uid).get();
  await Promise.all(snap.docs.map((doc) => doc.ref.update({ buyerDeleted: true })));
}

/**
 * PinBox listings owned by this user — anonymized and closed, not
 * deleted (BACKLOG #15).
 *
 * Same "keep the record, drop the identity" shape as
 * `anonymizePinBoxOrders` and `archiveCreatedEvents`: a PinBox is not
 * only the owner's listing, it is also what every buyer's own
 * `pinboxOrders` row and every `venuePayouts` obligation points at. Hard
 * deletion would leave those pointing at nothing, so a buyer's order
 * history would render as a blank or "unknown box" — the record would
 * survive with its meaning removed, which is the opposite of what an
 * order history is for.
 *
 * `status: "inactive"` is what actually takes it out of circulation:
 * every discovery query filters on `status == "active"`
 * (`FirebasePinBoxRemoteDatasource`), and `reservePinBoxOrder` now also
 * refuses a box whose venue is gone.
 *
 * Any box still holding RESERVED (paid, un-redeemed) orders raises an
 * admin notification rather than being silently closed: that money has
 * been taken for something nobody can hand over any more, and it needs
 * a human to refund it.
 */
async function anonymizeUserPinBoxes(uid: string): Promise<void> {
  const snap = await db.collection("pinboxes").where("ownerId", "==", uid).get();
  if (snap.empty) return;

  await Promise.all(
    snap.docs.map((doc) => doc.ref.update({ ownerDeleted: true, status: "inactive", updatedAt: FieldValue.serverTimestamp() })),
  );

  const reservedCounts = await Promise.all(
    snap.docs.map(async (doc) => {
      const orders = await db
        .collection("pinboxOrders")
        .where("pinboxId", "==", doc.id)
        .where("status", "==", "reserved")
        .get();
      return { id: doc.id, title: (doc.data().title as string | undefined) ?? doc.id, count: orders.size };
    }),
  );
  const stranded = reservedCounts.filter((r) => r.count > 0);
  if (stranded.length === 0) return;

  const total = stranded.reduce((sum, r) => sum + r.count, 0);
  await notifyAdmins({
    type: "pinbox.orphaned_reserved_orders",
    message:
      `Hesab silindi (${uid}) — sahibsiz qalan PinBox-larda ${total} ödənilmiş, təhvil verilməmiş sifariş var: ` +
      stranded.map((r) => `"${r.title}" (${r.count})`).join(", ") +
      ". Bu sifarişlər artıq təhvil verilə bilməz, əl ilə geri qaytarılmalıdır.",
    targetType: "user",
    targetId: uid,
  });
}

/**
 * Venue events at venues this user owned — cancelled and anonymized,
 * same reasoning as `anonymizeUserPinBoxes` above, minus the money:
 * `venueEvents` carries no participant list (that lives in the separate
 * `events` collection, handled by `archiveCreatedEvents`), so nothing is
 * stranded by closing one. `cancelled` is the status the client already
 * understands for an event that will not happen, and every discovery
 * query filters on `status in ["upcoming", "live"]`.
 */
async function anonymizeUserVenueEvents(uid: string): Promise<void> {
  const venuesSnap = await db.collection("venues").where("ownerId", "==", uid).get();
  const venueIds = venuesSnap.docs.map((d) => d.id);
  if (venueIds.length === 0) return;

  // `where in` caps at 30 values per query; venue counts are small, but
  // chunking keeps this correct for a power user rather than silently
  // missing the tail.
  for (let i = 0; i < venueIds.length; i += 30) {
    const chunk = venueIds.slice(i, i + 30);
    const eventsSnap = await db.collection("venueEvents").where("venueId", "in", chunk).get();
    await Promise.all(
      eventsSnap.docs.map((doc) => doc.ref.update({ ownerDeleted: true, status: "cancelled" })),
    );
  }
}

/** Events this user created — archived (kept for other participants
 * history), not deleted outright. */
async function archiveCreatedEvents(uid: string): Promise<void> {
  const snap = await db.collection("events").where("creatorId", "==", uid).get();
  await Promise.all(snap.docs.map((doc) => doc.ref.update({ creatorDeleted: true })));
}

/** Events this user joined (not created) — leave them so participant
 * counts stay accurate. */
async function leaveJoinedEvents(uid: string): Promise<void> {
  const snap = await db.collection("events").where("participants", "array-contains", uid).get();
  await Promise.all(
    snap.docs
      .filter((doc) => doc.data().creatorId !== uid)
      .map((doc) => doc.ref.update({ participants: FieldValue.arrayRemove(uid) }))
  );
}

/** Follow edges involving this user, either direction (they followed
 * someone, or someone followed them). */
async function deleteFollows(uid: string): Promise<void> {
  const [asFollower, asFollowee] = await Promise.all([
    db.collection("follows").where("followerId", "==", uid).get(),
    db.collection("follows").where("followeeId", "==", uid).get(),
  ]);
  await Promise.all([...asFollower.docs, ...asFollowee.docs].map((doc) => doc.ref.delete()));
}

/** This uid, scrubbed out of every OTHER user's blockedUsers array —
 * their own array disappears with their doc in
 * deleteUserDocAndSubcollections. */
async function scrubFromOthersBlockLists(uid: string): Promise<void> {
  const snap = await db.collection("users").where("blockedUsers", "array-contains", uid).get();
  await Promise.all(snap.docs.map((doc) => doc.ref.update({ blockedUsers: FieldValue.arrayRemove(uid) })));
}

/** Stories this user created, plus their view-tracking subcollections. */
async function deleteStories(uid: string): Promise<void> {
  const snap = await db.collection("stories").where("creatorId", "==", uid).get();
  await Promise.all(
    snap.docs.map(async (storyDoc) => {
      const viewsSnap = await storyDoc.ref.collection("views").get();
      await Promise.all(viewsSnap.docs.map((viewDoc) => viewDoc.ref.delete()));
      await storyDoc.ref.delete();
    })
  );
}

/** The user's own doc, including every owner-scoped subcollection under
 * it — Firestore doesn't cascade-delete subcollections when a parent
 * doc is deleted, so each has to be swept explicitly. `payments` is
 * deliberately NOT included here: it's a financial/audit record of
 * real venue/offer payments and refunds, kept for reconciliation the
 * same way a receipt survives closing the account that made it. */
async function deleteUserDocAndSubcollections(uid: string): Promise<void> {
  const userRef = db.collection("users").doc(uid);
  // F-3 — `likedPosts`, `reposts` and `notifiedEvents` were missing
  // here, so every account deletion left three subcollections behind:
  // the reverse like index, the repost list, and the per-event push
  // dedup markers. `firestore.rules` declares eleven subcollections
  // under `users/{uid}`; these ten plus the deliberately-kept
  // `payments` (financial/audit record) is the complete set. Found by
  // auditing the admin panel's own copy of this routine against this
  // one — both had the same gap.
  const subcollections = [
    "media",
    "notifications",
    "favoriteOffers",
    "likedPosts",
    "reposts",
    "notifiedVenues",
    "notifiedEvents",
    "sessions",
    "profileViews",
    "private",
  ];
  for (const name of subcollections) {
    const snap = await userRef.collection(name).get();
    await Promise.all(snap.docs.map((doc) => doc.ref.delete()));
  }
  await userRef.delete();
}

/** Posts this user authored — `onPostDeleted` (below) already cleans up
 * each one's `likes`/`comments` subcollections as they're deleted here,
 * so this only needs to remove the post docs themselves plus their
 * Storage folder. */
async function deleteUserPosts(uid: string): Promise<void> {
  const snap = await db.collection("posts").where("userId", "==", uid).get();
  await Promise.all(snap.docs.map((doc) => doc.ref.delete()));
}

/** Venues this user owns — deleted outright (not transferred), since
 * venue ownership is tied to the personal account that got it approved
 * (see `Venue.paymentId`'s VIP/premium note elsewhere in this file). */
async function deleteUserVenues(uid: string): Promise<void> {
  const snap = await db.collection("venues").where("ownerId", "==", uid).get();
  for (const doc of snap.docs) {
    const [likesSnap, checkinsSnap, historySnap] = await Promise.all([
      doc.ref.collection("likes").get(),
      doc.ref.collection("activeCheckins").get(),
      doc.ref.collection("audienceHistory").get(),
    ]);
    await Promise.all([...likesSnap.docs, ...checkinsSnap.docs, ...historySnap.docs].map((d) => d.ref.delete()));
    await doc.ref.delete();
    await deleteStorageFile(`venue_photos/${doc.id}.jpg`);
  }
}

/** Offers this user owns — same reasoning as [deleteUserVenues]. */
async function deleteUserOffers(uid: string): Promise<void> {
  const snap = await db.collection("offers").where("ownerId", "==", uid).get();
  for (const doc of snap.docs) {
    const redemptionsSnap = await doc.ref.collection("redemptions").get();
    await Promise.all(redemptionsSnap.docs.map((d) => d.ref.delete()));
    await doc.ref.delete();
    await deleteStorageFile(`offer_photos/${doc.id}.jpg`);
  }
}

/** `phoneNumbers/{phone}` only exists to let a signed-out client look
 * up a uid by phone (password-reset-style flows) — left behind, it
 * would dangle after the account is gone, or block the same number
 * from registering again. Deleted only if it still points at THIS uid,
 * since a prior number change already moves the reservation elsewhere
 * (see `updateUsername`'s doc comment in the auth repository). */
async function releasePhoneNumberReservation(uid: string, phoneNumber: string | undefined): Promise<void> {
  if (!phoneNumber) return;
  const ref = db.collection("phoneNumbers").doc(phoneNumber);
  const snap = await ref.get();
  if (snap.exists && snap.data()?.uid === uid) {
    await ref.delete();
  }
}

/** `usernames/{lowercased}` reservations were never released on
 * deletion (Düzəliş Prompt 11 / AUTH-10) — a deleted user's handle
 * stayed permanently taken, blocking anyone (including the same
 * person re-registering) from ever claiming it again, and leaving a
 * stale `uid` pointer behind. Same "only delete if it still points at
 * THIS uid" safety check as `releasePhoneNumberReservation` above.
 * Must run BEFORE `deleteUserDocAndSubcollections` — it reads
 * `users/{uid}.username` itself, which that step removes. */
async function releaseUsernameReservation(uid: string): Promise<void> {
  const userSnap = await db.collection("users").doc(uid).get();
  const username = userSnap.data()?.username as string | undefined;
  if (!username) return;
  const ref = db.collection("usernames").doc(username.toLowerCase());
  const snap = await ref.get();
  if (snap.exists && snap.data()?.uid === uid) {
    await ref.delete();
  }
}

/** `identityVerifications/{requestId}` docs (queried by `userId`, per
 * `submitIdentityVerification`'s own uniqueness check above) plus the
 * ID-photo Storage folder they reference were never cleaned up on
 * deletion (Düzəliş Prompt 11 / AUTH-11) — a deleted account's
 * government-ID and selfie images survived the account itself
 * indefinitely. There is deliberately no "keep for audit" case here
 * unlike `payments`/`offerAcceptances` — this is raw biometric/ID
 * imagery, not a financial or legal-consent record. */
async function deleteIdentityVerifications(uid: string): Promise<void> {
  const snap = await db.collection("identityVerifications").where("userId", "==", uid).get();
  await Promise.all(snap.docs.map((doc) => doc.ref.delete()));
  await deleteStoragePrefix(`identity_verifications/${uid}/`);
}

async function deleteStorageFile(path: string): Promise<void> {
  // The `_200x200` derivative goes with it. Done HERE rather than at
  // each call site so that every current caller — and every future one
  // — is covered by construction; the bug this closes was precisely
  // that three separate exact-path deletes each named only the
  // original. See [resizedVariantPath] for why a surviving derivative
  // is a leak and not just a stray object. Video/audio paths simply
  // have no derivative (the extension's `INCLUDE_PATH_LIST` covers
  // image folders only), and deleting an object that was never there
  // is already a tolerated no-op below.
  const derivative = resizedVariantPath(path);
  if (derivative) await deleteStorageObject(derivative);
  await deleteStorageObject(path);
}

async function deleteStorageObject(path: string): Promise<void> {
  try {
    await storage.bucket().file(path).delete();
  } catch (e) {
    // Best-effort — no file at this path (e.g. never uploaded) isn't a
    // failure. Logged rather than swallowed silently (P0 / C-1): the
    // bare `catch {}` this replaces made a caller passing a WRONG path
    // completely invisible, which is exactly what let the old
    // `deleteStorageObjectByUrl(mediaUrl)` vector be probed without
    // leaving any trace. A genuine "already gone" delete logs at warn
    // level too — noisy is the correct trade here, since every delete
    // this file performs is now on a path the SERVER computed, so an
    // unexpected miss means a real bug worth seeing.
    logger.warn("deleteStorageObject: delete failed (path may not exist)", { path, error: String(e) });
  }
}

/**
 * P0 / H-5 — asserts a client-supplied media URL points at THIS
 * project's own Storage bucket, or throws.
 *
 * The venue/offer/PinBox image fields all arrive through callables
 * (`submitVenue`, `updateVenue`, `submitOffer`, `updateOffer`,
 * `updatePinBox`), which run on the Admin SDK and therefore bypass
 * `firestore.rules` entirely — so the equivalent rules-side check
 * (`isOwnStorageUrl`) does not cover them and this is the only place
 * that can. See that rule's comment for why an external URL is both a
 * viewer-tracking primitive and a moderation bypass.
 *
 * Prefix comparison rather than a regex: the value is compared against
 * a fixed, fully-qualified origin + bucket, so there is no pattern for
 * a crafted host (`https://firebasestorage.googleapis.com.evil.test/`)
 * to slip through.
 */
const OWN_STORAGE_URL_PREFIX = "https://firebasestorage.googleapis.com/v0/b/kim-var-73ce9.firebasestorage.app/o/";

function assertOwnStorageUrl(url: unknown, fieldName: string): void {
  if (typeof url !== "string" || !url.startsWith(OWN_STORAGE_URL_PREFIX)) {
    throw new HttpsError("invalid-argument", `${fieldName} yalnız PeakPin Storage ünvanı ola bilər.`);
  }
}

/** Resolves a Firebase Storage download URL
 * (`.../o/{encodedPath}?alt=media&token=...`) back to its bucket object
 * path. The Admin SDK has no `refFromURL` — that's a client-SDK-only
 * convenience — so this is the one place that reimplements it. Its ONLY
 * remaining caller is `forwardChatMedia`'s copy step, which validates
 * the resolved path against `CHAT_MEDIA_FOLDERS` plus real chat
 * membership before touching it; the former `deleteStorageObjectByUrl`
 * caller (which did NOT validate, see P0 / C-1) is gone.
 * Returns `null` for a URL that doesn't match the expected `/o/` shape. */
function storagePathFromUrl(url: string): string | null {
  const marker = "/o/";
  const markerIndex = url.indexOf(marker);
  if (markerIndex === -1) return null;

  const pathStart = markerIndex + marker.length;
  const queryIndex = url.indexOf("?", pathStart);
  const encodedPath = queryIndex === -1 ? url.substring(pathStart) : url.substring(pathStart, queryIndex);
  return decodeURIComponent(encodedPath);
}

/** Deletes one chat message's own media, if it has any — see
 * [chatMediaPathForMessage] (`./chat-media`) for why the path is
 * recomputed from server-known values rather than taken from the
 * message's client-written `mediaUrl` field (P0 / C-1). */
async function deleteChatMessageMedia(
  chatId: string,
  messageId: string,
  data: FirebaseFirestore.DocumentData,
): Promise<void> {
  const path = chatMediaPathForMessage(chatId, messageId, data);
  if (!path) return;
  await deleteStorageFile(path);
}

async function deleteStoragePrefix(prefix: string): Promise<void> {
  try {
    await storage.bucket().deleteFiles({ prefix });
  } catch {
    // Best-effort — a missing folder (nothing was ever uploaded there)
    // isn't a failure.
  }
}

/**
 * Düzəliş Prompt 10 — closes the `forwardMessage` shared-file bug
 * (found in Prompt 3, HIGH): before this, a forwarded photo/video/
 * voice message just copied the ORIGINAL message's `mediaUrl` string
 * verbatim into the new message doc — both messages pointed at the
 * exact same Storage object. `deleteMessageForEveryone` (client-side)
 * deletes whatever object its own message pointed at, with no ref-count
 * against other messages — so deleting the ORIGINAL message also
 * silently broke every forwarded copy's media (a 404 on next render).
 * The server-side deletions (`onChatDeleted`/`replaceMessagesWithPlaceholder`)
 * now derive that path from (chatId, senderId, messageId) instead of the
 * URL — see [chatMediaPathForMessage] — which ALSO makes this
 * independent-copy step load-bearing for correctness: each forward's
 * own path is keyed by its own message id, so no two messages can ever
 * resolve to the same object again.
 *
 * The fix is this one narrow server-side copy step, NOT a full
 * `forwardMessage` rewrite: `FirebaseChatRepository.forwardMessage`
 * (Dart) keeps its existing block-check/whoCanMessageMe/pending-
 * accepted transaction logic completely unchanged (re-implementing
 * that server-side would be a much larger, riskier change for this
 * one bug) — it just calls this callable FIRST, per forward target,
 * to get an independent `mediaUrl` before building the message. Uses
 * the Admin SDK's real server-side object copy (no download+re-upload
 * through the client's own bandwidth), same
 * `{folder}/{chatId}/{senderId}/{messageId}.{ext}` path shape every
 * other chat media upload already uses (see storage.rules'
 * `chat_photos/{chatId}/{senderId}/{fileName}` and
 * `_sendMediaMessage`'s own doc comment, firebase_chat_repository.dart)
 * — `messageId` here is the NEW message's own pre-allocated doc id
 * (the client allocates it before calling this, then reuses the same
 * ref to actually write the message), so the destination path is
 * exactly where that message's media "should" live regardless of
 * where it came from.
 */
export const forwardChatMedia = onCall(
  { region: "us-central1", enforceAppCheck: false },
  async (request) => {
    const uid = request.auth?.uid;
    if (!uid) throw new HttpsError("unauthenticated", "Bu əməliyyat üçün daxil olmalısınız.");
    await assertActiveUser(uid);
    await enforceRateLimit("forward-chat-media", uid, 30, 600);

    const sourceUrl = request.data?.sourceUrl as string | undefined;
    const chatId = request.data?.chatId as string | undefined;
    const messageId = request.data?.messageId as string | undefined;
    if (!sourceUrl || !chatId || !messageId) {
      throw new HttpsError("invalid-argument", "sourceUrl, chatId və messageId tələb olunur.");
    }

    // Never trust a client-supplied path blindly (same reasoning as
    // `submitIdentityVerification`'s prefix check above) — the source
    // must be a real chat-media object, and the caller must actually
    // be a participant of the chat it came from.
    const sourcePath = storagePathFromUrl(sourceUrl);
    const sourceFolder = sourcePath?.split("/")[0];
    if (!sourcePath || !sourceFolder || !CHAT_MEDIA_FOLDERS.includes(sourceFolder)) {
      throw new HttpsError("invalid-argument", "Fayl yolu etibarsızdır.");
    }
    const sourceChatId = sourcePath.split("/")[1];
    const [sourceChatSnap, targetChatSnap] = await Promise.all([
      db.collection("chats").doc(sourceChatId).get(),
      db.collection("chats").doc(chatId).get(),
    ]);
    const isParticipant = (snap: FirebaseFirestore.DocumentSnapshot) =>
      ((snap.data()?.participants as string[] | undefined) ?? []).includes(uid);
    if (!sourceChatSnap.exists || !isParticipant(sourceChatSnap) || (targetChatSnap.exists && !isParticipant(targetChatSnap))) {
      throw new HttpsError("permission-denied", "Bu faylı yönləndirmək icazəniz yoxdur.");
    }

    const extension = sourcePath.includes(".") ? sourcePath.slice(sourcePath.lastIndexOf(".")) : "";
    const destPath = `${sourceFolder}/${chatId}/${uid}/${messageId}${extension}`;

    const bucket = storage.bucket();
    await bucket.file(sourcePath).copy(bucket.file(destPath));
    const token = randomUUID();
    await bucket.file(destPath).setMetadata({ metadata: { firebaseStorageDownloadTokens: token } });

    const mediaUrl = `https://firebasestorage.googleapis.com/v0/b/${bucket.name}/o/${encodeURIComponent(destPath)}?alt=media&token=${token}`;
    return { mediaUrl };
  },
);

/**
 * Keeps `posts/{postId}.likesCount`/`commentsCount` as server-computed
 * counters, per the client never being allowed to write those fields
 * directly (see firestore.rules) — a like/comment doc's create/delete
 * is the only client-side write; these triggers fan that into the
 * count. Swallows "post already deleted" races (the like/comment
 * subcollection can still fire once after its parent post is gone)
 * rather than crashing the function.
 */
async function bumpPostCounter(postId: string, field: "likesCount" | "commentsCount", delta: 1 | -1): Promise<void> {
  // Clamped at 0 in a transaction rather than a bare FieldValue.increment
  // — a delete-triggered decrement with no matching prior increment (e.g.
  // an admin/script deleting a like doc directly, which still fires this
  // same trigger) must not push the displayed count negative.
  const ref = db.collection("posts").doc(postId);
  try {
    await db.runTransaction(async (tx) => {
      const snap = await tx.get(ref);
      if (!snap.exists) return;
      const current = (snap.data()?.[field] as number | undefined) ?? 0;
      tx.update(ref, { [field]: Math.max(0, current + delta) });
    });
  } catch {
    // Post doc no longer exists — nothing to bump.
  }
}

/**
 * `users/{uid}.firstName`/`lastName`/`photoUrl` joined into the same
 * "sender" shape every notification card displays — matches
 * `onChatMessageCreated`'s existing name-join logic exactly, just
 * factored out since notification triggers below need it repeatedly.
 */
async function getUserDisplayInfo(uid: string): Promise<{ name: string; photoUrl: string | null }> {
  const snap = await db.collection("users").doc(uid).get();
  const data = snap.data();
  const name =
    [data?.firstName, data?.lastName]
      .filter((part) => typeof part === "string" && part.length > 0)
      .join(" ") || "PeakPin";
  return { name, photoUrl: (data?.photoUrl as string | undefined) ?? null };
}

/**
 * Writes one `users/{uid}/notifications` doc (the client never writes
 * these — see firestore.rules) and, unless the recipient disabled push
 * entirely, also sends a real FCM push — same delivery mechanism as
 * `onChatMessageCreated`, reused rather than duplicated.
 *
 * [category] gates BOTH the inbox write and the push against the
 * matching `notificationPreferences` toggle in Ayarlar → Bildirişlər
 * (missing/undefined defaults to enabled, matching the client's own
 * defaults) — a category a user turned off produces no inbox entry at
 * all, not just a silent push.
 *
 * Never throws: a missing recipient doc, no device tokens, or a push
 * failure all resolve to "nothing happens" rather than failing the
 * triggering write (a like/comment/follow succeeding for the actor
 * must never depend on the recipient's notification plumbing).
 */
async function notifyUser(params: {
  uid: string;
  category: string;
  type: string;
  // AZ text — used ONLY for the FCM push payload below, never
  // persisted to the Firestore doc (the in-app feed renders per the
  // recipient's current app language from `params.params`+`type`
  // instead — see `lib/features/notifications/presentation/
  // notification_localizer.dart`). A push notification fires whether
  // or not the app is open, so there's no client to localize it at
  // send time; this stays Azerbaijani until the project stores each
  // user's chosen language server-side.
  title: string;
  body: string;
  // Structured data the client-side localizer renders from — every
  // call site now passes this (even `{}` when a type's body has no
  // interpolation) so `metadata` on the written doc is never null,
  // which is what tells the feed "this is a new-format notification,
  // render it localized" vs. falling back to raw title/body for
  // pre-migration docs that have none.
  params?: Record<string, unknown>;
  senderId?: string;
  senderName?: string;
  senderPhoto?: string | null;
  targetId?: string;
  targetType?: string;
}): Promise<void> {
  const userSnap = await db.collection("users").doc(params.uid).get();
  if (!userSnap.exists) return;
  // `notificationPreferences`/`fcmTokens` moved to `users/{uid}/private/data`
  // (Düzəliş Prompt 4 / K-1) — this fetch closes every caller of
  // `notifyUser` over the change at once, rather than touching each one.
  const privateData = (await privateDataRef(params.uid).get()).data() ?? {};

  const prefs = (privateData.notificationPreferences ?? {}) as Record<string, boolean>;
  // `security` and `account` are deliberately NOT gated — see
  // [UNGATED_NOTIFICATION_CATEGORIES] (`./notification-categories`) for
  // which types live there and why, and
  // `tests/rules/notification-categories.test.ts`, which fails if a
  // transactional type is ever moved back under a toggle.
  //
  // Before this, the check was an unconditional
  // `if (prefs[params.category] === false) return;`, which meant even
  // `security` could be silenced by writing
  // `notificationPreferences.security = false` — a field the client
  // legitimately owns (it holds the user's own choices, so it is not in
  // `serverOnlyFields()`), and one no UI ever offered. The Settings
  // screen showing no switch was the only thing "protecting" it.
  if (isGatedCategory(params.category) && prefs[params.category] === false) return;

  await db
    .collection("users")
    .doc(params.uid)
    .collection("notifications")
    .add({
      type: params.type,
      metadata: params.params ?? null,
      imageUrl: null,
      senderId: params.senderId ?? null,
      senderName: params.senderName ?? null,
      senderPhoto: params.senderPhoto ?? null,
      targetId: params.targetId ?? null,
      targetType: params.targetType ?? null,
      isRead: false,
      createdAt: FieldValue.serverTimestamp(),
    });

  if (prefs.pushEnabled === false) return;
  const tokens = (privateData.fcmTokens ?? []) as string[];
  if (tokens.length === 0) return;

  // Drives the iOS home-screen app icon badge — APNs applies
  // `aps.badge` automatically on delivery, no client code needed. The
  // count includes the notification just written above (the `.add()`
  // a few lines up isn't reflected in a `.count()` snapshot taken
  // before it commits, so this recount always runs after).
  const unreadCountSnap = await db
    .collection("users")
    .doc(params.uid)
    .collection("notifications")
    .where("isRead", "==", false)
    .count()
    .get();
  const badge = unreadCountSnap.data().count;

  const response = await messaging.sendEachForMulticast({
    tokens,
    notification: { title: params.title, body: params.body },
    data: {
      type: params.type,
      ...(params.targetId ? { targetId: params.targetId } : {}),
      ...(params.targetType ? { targetType: params.targetType } : {}),
    },
    android: { priority: "high" },
    apns: { payload: { aps: { sound: "default", badge } } },
  });

  await pruneStaleTokensAndLogFailures(params.uid, tokens, response);
}

/**
 * Shared by every `sendEachForMulticast` call site — prunes tokens FCM
 * reports as unregistered/invalid (the only failure previously acted
 * on), and now also logs every OTHER kind of failure via
 * `console.error`, which lands in Cloud Logging/`firebase
 * functions:log`. Previously silent: a real APNs-side delivery
 * failure (e.g. the app not being entitled for push notifications)
 * produced a "successful" `sendEachForMulticast` call with no trace
 * anywhere to diagnose it from.
 */
async function pruneStaleTokensAndLogFailures(uid: string, tokens: string[], response: BatchResponse): Promise<void> {
  const staleTokens: string[] = [];
  response.responses.forEach((r, i) => {
    if (r.success) return;
    if (isUnregisteredTokenError(r.error?.code)) {
      staleTokens.push(tokens[i]);
    } else {
      console.error(`FCM send failed for uid=${uid}: code=${r.error?.code} message=${r.error?.message}`);
    }
  });
  if (staleTokens.length > 0) {
    await privateDataRef(uid).set({ fcmTokens: FieldValue.arrayRemove(...staleTokens) }, { merge: true });
  }
}

/**
 * `follows/{followerId}_{followeeId}` has direction baked into the doc
 * id itself, so `followeeId` on the created doc is always who to
 * notify. `status` ("Hesab gizliliyi") decides which of two very
 * different notifications this is: a `pending` doc is a follow
 * REQUEST against a `private` account (needs the followee's
 * approval — see `onFollowUpdated` for what happens once they grant
 * it); anything else (`accepted`, or absent on a pre-migration doc) is
 * a real, already-in-effect follow, same as before this feature.
 * Either way `targetType: 'profile'` deep-links to the follower's own
 * profile — for a pending request, that's also where
 * `UserProfileScreen` shows Accept/Decline instead of Follow.
 */
export const onFollowCreated = onDocumentCreated("follows/{followId}", async (event) => {
  const data = event.data?.data();
  if (!data) return;
  const followerId = data.followerId as string | undefined;
  const followeeId = data.followeeId as string | undefined;
  if (!followerId || !followeeId) return;

  const follower = await getUserDisplayInfo(followerId);

  if (data.status === "pending") {
    await notifyUser({
      uid: followeeId,
      category: "followers",
      type: "followRequest",
      title: follower.name,
      body: "Sizi izləmək istəyir",
      params: {},
      senderId: followerId,
      senderName: follower.name,
      senderPhoto: follower.photoUrl,
      targetId: followerId,
      targetType: "profile",
    });
    return;
  }

  await notifyUser({
    uid: followeeId,
    category: "followers",
    type: "newFollower",
    title: follower.name,
    body: "Sizi izləməyə başladı",
    params: {},
    senderId: followerId,
    senderName: follower.name,
    senderPhoto: follower.photoUrl,
    targetId: followerId,
    targetType: "profile",
  });
});

/**
 * The followee just approved a pending follow request — notify the
 * original requester (`followerId`) it went through. Only fires on
 * the `pending` -> `accepted` transition; any other update to this doc
 * (there currently are no others) is ignored.
 */
export const onFollowUpdated = onDocumentUpdated("follows/{followId}", async (event) => {
  const before = event.data?.before?.data();
  const after = event.data?.after?.data();
  if (!before || !after) return;
  if (before.status !== "pending" || after.status !== "accepted") return;

  const followerId = after.followerId as string | undefined;
  const followeeId = after.followeeId as string | undefined;
  if (!followerId || !followeeId) return;

  const followee = await getUserDisplayInfo(followeeId);
  await notifyUser({
    uid: followerId,
    category: "followers",
    type: "followAccepted",
    title: followee.name,
    body: "İzləmə istəyinizi qəbul etdi",
    params: {},
    senderId: followeeId,
    senderName: followee.name,
    senderPhoto: followee.photoUrl,
    targetId: followeeId,
    targetType: "profile",
  });
});

/**
 * Fires on `premium` false -> true, whichever path caused it — the
 * admin panel's manual "VIP et" grant (Server Action, Admin SDK write)
 * AND a real Apple/Google IAP purchase (`verifyInAppPurchase`/
 * `appStoreServerNotifications`/`googlePlayRtdn`, see the VIP section
 * further down this file) both land here for free, with no second
 * notify call site to keep in sync — watching the field itself is what
 * makes that work regardless of which path set it.
 */
export const onUserUpdated = onDocumentUpdated("users/{userId}", async (event) => {
  const before = event.data?.before.data();
  const after = event.data?.after.data();
  if (!before || !after) return;

  if (before.premium !== true && after.premium === true) {
    await notifyUser({
      uid: event.params.userId,
      category: "account",
      type: "vipGranted",
      title: "VIP statusu aktivləşdi",
      body: "Siz artıq VIP istifadəçi statusundasınız.",
      params: {},
    });
  }

  const beforePrivacy = before.accountPrivacy as string | undefined;
  const afterPrivacy = after.accountPrivacy as string | undefined;
  if (beforePrivacy !== afterPrivacy) {
    await syncAuthorIsPublicForUser(event.params.userId, afterPrivacy !== "private");
  }

  // Düzəliş Prompt 5 (K-3) — reverse index: `blockUser`/`unblockUser`
  // (FirebaseSafetyRepository) only ever write the BLOCKER's own
  // `blockedUsers` array, never anything on the blocked party's own
  // doc. Client-side feed/comment/story filtering (post/story/comment
  // lists are plain `list` queries — firestore.rules structurally can't
  // gate those per-document the way a single-doc `get()` can) needs to
  // know "who has blocked ME" to hide their content, which the forward
  // array alone can't answer without an O(users) scan. Mirrors
  // `syncAuthorIsPublicForUser`'s own denormalization shape just above.
  // Best-effort: a failure here leaves `blockedByUsers` stale for this
  // ONE pair until their next block/unblock action — a feed-filtering
  // blind spot only, never a security bypass (every actual enforcement
  // point — profile read, messages, calls, chat create — checks the
  // forward `blockedUsers` arrays directly, not this index), so no
  // retry/repair job exists for this at current scale; logged so a
  // real failure is at least visible.
  const beforeBlocked = (before.blockedUsers as string[] | undefined) ?? [];
  const afterBlocked = (after.blockedUsers as string[] | undefined) ?? [];
  const blockedAdded = afterBlocked.filter((u) => !beforeBlocked.includes(u));
  const blockedRemoved = beforeBlocked.filter((u) => !afterBlocked.includes(u));
  if (blockedAdded.length > 0 || blockedRemoved.length > 0) {
    const myUid = event.params.userId;
    try {
      await Promise.all([
        ...blockedAdded.map((otherUid) =>
          privateDataRef(otherUid).set({ blockedByUsers: FieldValue.arrayUnion(myUid) }, { merge: true }),
        ),
        ...blockedRemoved.map((otherUid) =>
          privateDataRef(otherUid).set({ blockedByUsers: FieldValue.arrayRemove(myUid) }, { merge: true }),
        ),
      ]);
    } catch (e) {
      logger.error(
        `onUserUpdated: blockedByUsers reverse-index sync failed for uid=${myUid} added=[${blockedAdded}] removed=[${blockedRemoved}]`,
        e,
      );
    }
  }
});

/**
 * `security` — the app's "email" field is a contact address on
 * `users/{uid}/private/data` (Düzəliş Prompt 4; see
 * `FirebaseAccountRepository.updateEmail`), not the actual Firebase
 * Auth sign-in credential (that's a synthetic, never-shown address
 * derived from the username, unrelated to this field — see that
 * repository's own doc comment), so this is a plain Firestore field
 * watch, not an Auth-level hook. Split out of `onUserUpdated` when
 * `email` moved off the public doc — that trigger only ever fires on
 * writes to `users/{userId}` itself, never its `private/data`
 * subdocument, so this alert would otherwise have silently stopped
 * firing entirely post-migration. `before.email !== undefined`
 * excludes setting it for the very first time (onboarding) — that's
 * not a "change" to alert about, there was nothing to compare against
 * yet.
 */
export const onUserPrivateDataUpdated = onDocumentUpdated("users/{userId}/private/{document}", async (event) => {
  const before = event.data?.before.data();
  const after = event.data?.after.data();
  if (!before || !after) return;

  const beforeEmail = before.email as string | undefined;
  const afterEmail = after.email as string | undefined;
  if (beforeEmail !== undefined && afterEmail && beforeEmail !== afterEmail) {
    await notifyUser({
      uid: event.params.userId,
      category: "security",
      type: "security",
      title: "E-poçt ünvanı dəyişdirildi",
      body: `Hesabınızın əlaqə e-poçtu ${afterEmail} ünvanına dəyişdirildi. Bu siz deyilsinizsə, dərhal dəstəklə əlaqə saxlayın.`,
      params: { kind: "email_changed", newEmail: afterEmail },
    });
  }
});

export const onPostLikeCreated = onDocumentCreated("posts/{postId}/likes/{uid}", async (event) => {
  await bumpPostCounter(event.params.postId, "likesCount", 1);

  const likerId = event.params.uid;

  // Mirrors this like into the LIKER's own doc — the "Bəyəndikləri" profile
  // tab reads this subcollection directly rather than trying a client-side
  // `collectionGroup("likes")` query, which Firestore's own rules can't
  // prove safe (same reason a plain `posts.where("userId", "==", otherUid)`
  // list query is already broken elsewhere in firestore.rules — see that
  // file's own comment on the `posts` collection). Same "mirror into the
  // acting user's own subcollection" shape as notifyUser() below.
  await db.collection("users").doc(likerId).collection("likedPosts").doc(event.params.postId).set({
    createdAt: FieldValue.serverTimestamp(),
  });

  const postSnap = await db.collection("posts").doc(event.params.postId).get();
  const postOwnerId = postSnap.data()?.userId as string | undefined;
  if (!postOwnerId || postOwnerId === likerId) return;

  const liker = await getUserDisplayInfo(likerId);
  await notifyUser({
    uid: postOwnerId,
    category: "likes",
    type: "likePost",
    title: liker.name,
    body: "Paylaşımını bəyəndi",
    params: {},
    senderId: likerId,
    senderName: liker.name,
    senderPhoto: liker.photoUrl,
    targetId: event.params.postId,
    targetType: "post",
  });
});

export const onPostLikeDeleted = onDocumentDeleted("posts/{postId}/likes/{uid}", async (event) => {
  await bumpPostCounter(event.params.postId, "likesCount", -1);
  await db.collection("users").doc(event.params.uid).collection("likedPosts").doc(event.params.postId).delete();
});

/**
 * likeCount -> 0-5 rating: base 3.0 (a brand-new, unliked venue reads
 * as "average", never as a fabricated 0) + 0.1 per 5 likes, capped at
 * 5.0. Picked over this session over a couple of alternatives (plain
 * linear with no base, logarithmic) — kept here as the one place this
 * formula lives, so tuning it later is a one-line change.
 */
function computeVenueRating(likeCount: number): number {
  const raw = 3.0 + (likeCount / 5) * 0.1;
  return Math.round(Math.min(5, raw) * 10) / 10;
}

/**
 * Same clamp-in-a-transaction shape as bumpPostCounter, except this
 * one also derives `rating` from the freshly-clamped `likeCount` in
 * the same write — the two fields must never observably disagree
 * (e.g. a client reading mid-update sees an old rating for a new
 * count), which a separate second write couldn't guarantee.
 */
async function bumpVenueLikeCount(venueId: string, delta: 1 | -1): Promise<void> {
  const ref = db.collection("venues").doc(venueId);
  try {
    await db.runTransaction(async (tx) => {
      const snap = await tx.get(ref);
      if (!snap.exists) return;
      const current = (snap.data()?.likeCount as number | undefined) ?? 0;
      const likeCount = Math.max(0, current + delta);
      tx.update(ref, { likeCount, rating: computeVenueRating(likeCount) });
    });
  } catch {
    // Venue doc no longer exists — nothing to bump.
  }
}

export const onVenueLikeCreated = onDocumentCreated("venues/{venueId}/likes/{uid}", async (event) => {
  await bumpVenueLikeCount(event.params.venueId, 1);
});

export const onVenueLikeDeleted = onDocumentDeleted("venues/{venueId}/likes/{uid}", async (event) => {
  await bumpVenueLikeCount(event.params.venueId, -1);
});

/**
 * Recomputes `venues/{venueId}.ratingAverage`/`ratingCount` on every
 * `reviews/{reviewId}` create/update/delete — a full re-aggregate
 * (query every review for the venue, average) rather than an
 * incremental ±delta like `bumpVenueLikeCount`, since a review carries
 * a 1-5 value that can itself CHANGE on edit, not just a boolean
 * like/unlike. Deliberately separate from `rating`/`likeCount` above —
 * see `Venue`'s own doc comment (Dart) for why the two coexist.
 */
export const onReviewWritten = onDocumentWritten("reviews/{reviewId}", async (event) => {
  const venueId = (event.data?.after.data()?.venueId ?? event.data?.before.data()?.venueId) as string | undefined;
  if (!venueId) return;

  const reviewsSnap = await db.collection("reviews").where("venueId", "==", venueId).get();
  const ratings = reviewsSnap.docs.map((d) => (d.data().rating as number | undefined) ?? 0);
  const ratingCount = ratings.length;
  const ratingAverage = ratingCount === 0 ? 0 : Math.round((ratings.reduce((a, b) => a + b, 0) / ratingCount) * 10) / 10;

  try {
    await db.collection("venues").doc(venueId).update({ ratingAverage, ratingCount });
  } catch {
    // Venue doc no longer exists — nothing to update.
  }
});

/**
 * Maintains `venues/{venueId}.activeCheckinCount` — Düzəliş Prompt 4
 * (K-4) narrowed raw `activeCheckins` subcollection reads to the
 * checked-in user and the venue's own owner (see firestore.rules), so
 * every general-audience reader (a venue profile's live "hazırda N
 * nəfər" counter, the live feed's "Ətrafınızda" audience card) must
 * read this aggregate instead of listing the subcollection directly.
 * Same clamp-in-a-transaction shape as [bumpVenueLikeCount].
 * `cleanupStaleCheckins`'s hourly sweep deletes expired docs, which
 * fires the delete side of this pair, so the counter self-corrects on
 * the same cadence the raw subcollection's own staleness window already
 * relied on before this field existed.
 */
/**
 * SOURCE OF TRUTH: `venues/{id}/private/counters.activeCheckinCount`.
 * Server-only, closed to every client including the venue owner.
 *
 * The venue document carries `visibleCheckinCount` — the same number
 * with the k-anonymity floor applied, i.e. 0 below
 * VENUE_AUDIENCE_MIN_REPORTABLE_COUNT. That is what every screen
 * renders, and it is the ONLY check-in number a client can read.
 *
 * The split exists because `venues/{id}` is readable by any signed-in
 * user, so a raw count there is public no matter what the UI chooses
 * to draw. "1 nəfər burada" identifies a specific person to anyone
 * who knows who is nearby, and hiding that in the widget while leaving
 * the number in the document would be decoration, not privacy.
 *
 * Both writes happen in ONE transaction so the mirror cannot drift
 * from the truth.
 */
async function bumpActiveCheckinCount(venueId: string, delta: 1 | -1): Promise<void> {
  const venueRef = db.collection("venues").doc(venueId);
  const countersRef = venueRef.collection("private").doc("counters");
  try {
    await db.runTransaction(async (tx) => {
      const [venueSnap, countersSnap] = await Promise.all([tx.get(venueRef), tx.get(countersRef)]);
      if (!venueSnap.exists) return;
      const current = (countersSnap.data()?.activeCheckinCount as number | undefined) ?? 0;
      const next = Math.max(0, current + delta);
      tx.set(countersRef, { activeCheckinCount: next, updatedAt: FieldValue.serverTimestamp() }, { merge: true });
      tx.update(venueRef, { visibleCheckinCount: reportableAudienceCount(next) });
    });
  } catch {
    // Venue doc no longer exists — nothing to bump.
  }
}

export const onActiveCheckinCreated = onDocumentCreated(
  "venues/{venueId}/activeCheckins/{userId}",
  async (event) => {
    await bumpActiveCheckinCount(event.params.venueId, 1);
  },
);

export const onActiveCheckinDeleted = onDocumentDeleted(
  "venues/{venueId}/activeCheckins/{userId}",
  async (event) => {
    await bumpActiveCheckinCount(event.params.venueId, -1);
  },
);

// Matches FirebaseVenueRemoteDatasource._checkinExpiry on the Dart
// side — both must agree on what "stale" means, since the client
// live-counts only non-stale docs while this function is the one
// that actually deletes them.
const CHECKIN_EXPIRY_MS = 2 * 60 * 60 * 1000;

/**
 * Hourly sweep of every `venues/{venueId}/activeCheckins/{uid}` doc
 * older than CHECKIN_EXPIRY_MS. Uses a collectionGroup query (needs
 * the COLLECTION_GROUP field override in firestore.indexes.json) so
 * one function covers every venue, not one query per venue. Also
 * clears the denormalized `users/{uid}/private/data.activeCheckinVenueId` pointer,
 * but ONLY when it still points at the venue being cleaned up here —
 * guards against wiping a pointer the user already moved elsewhere in
 * the time between this doc going stale and this function running.
 */
export const cleanupStaleCheckins = onSchedule(
  { schedule: "every 60 minutes", region: "europe-west1" },
  async () => {
    const cutoff = Timestamp.fromMillis(Date.now() - CHECKIN_EXPIRY_MS);
    const stale = await db.collectionGroup("activeCheckins").where("createdAt", "<", cutoff).get();

    await Promise.all(
      stale.docs.map(async (doc) => {
        const venueId = doc.ref.parent.parent?.id;
        const uid = doc.id;
        await db.runTransaction(async (tx) => {
          const privateRef = privateDataRef(uid);
          const privateSnap = await tx.get(privateRef);
          if (privateSnap.exists && privateSnap.data()?.activeCheckinVenueId === venueId) {
            tx.update(privateRef, { activeCheckinVenueId: null });
          }
          tx.delete(doc.ref);
        });
      }),
    );
  },
);

// ── Live audience / peak-hour detection ──────────────────────────────

/** Matches `venueAudienceCountProvider`'s 15-minute "recently active" window client-side. */
const AUDIENCE_ACTIVE_WINDOW_MS = 15 * 60 * 1000;
/** `audienceHistory`'s rolling retention — older entries are swept every run. */
const AUDIENCE_HISTORY_RETENTION_MS = 7 * 24 * 60 * 60 * 1000;
/** A venue's live count must beat its usual same-hour average by this multiplier to count as "peak". */
const AUDIENCE_PEAK_THRESHOLD_MULTIPLIER = 1.5;
/** Minimum time between two peak-hour notifications for the same venue. */
const AUDIENCE_PEAK_COOLDOWN_MS = 3 * 60 * 60 * 1000;

/**
 * Meters-based Haversine distance — no geo package on the Functions
 * side, and this is the only place server code needs one (mirrors
 * `Geolocator.distanceBetween`, which is what `venueAudienceCountProvider`
 * uses client-side for the exact same "distance" mode).
 */
/**
 * Whether [userData] (a candidate `users/{uid}` doc) has personally
 * dialed their own Discover radius (`discoverRadiusMode`/
 * `discoverRadiusKm`, mirrored from the client by
 * `discoverRadiusPersistenceProvider` in `location_providers.dart`)
 * wide enough to include a venue at [venueLat]/[venueLng] in
 * [venueCountry]. A venue's own audience radius was never meant to be
 * the ONLY filter for who gets notified about it — product rule: the
 * recipient's own chosen radius always caps it too, so a venue
 * broadcasting to Ölkə/Dünya still can't reach someone who has
 * personally narrowed their own radius to 1 km. The one exception is
 * `independentArtist` follows (see `resolveNotifyCandidates`), which
 * bypass this check entirely — callers there simply don't call this
 * function for that category.
 *
 * Missing `discoverRadiusMode` (a user who's never opened Discover, so
 * the client never had a value to write) defaults to unrestricted
 * rather than silently narrowing every pre-existing user's
 * notifications to nothing — see `discoverRadiusPersistenceProvider`'s
 * own doc comment.
 */
/**
 * "Görünmə radiusu" — the CANDIDATE's own choice of how far away they
 * can be discovered, mirrors [isWithinRecipientDiscoverRadius] exactly
 * (same missing-data-defaults-unrestricted policy) but swaps
 * `discoverRadiusMode/Km` (the VIEWER's own setting) for
 * `visibilityRadiusMode/Km` (the CANDIDATE's own setting) — a
 * different, independently-enforced privacy control from the viewer's
 * discover radius, used by `getDiscoverCandidates` below.
 */
function isWithinTargetVisibilityRadius(
  candidateData: FirebaseFirestore.DocumentData,
  viewerLat: number | undefined,
  viewerLng: number | undefined,
  viewerCountry: string | undefined,
): boolean {
  const mode = candidateData.visibilityRadiusMode as string | undefined;
  if (mode === undefined || mode === "world") return true;
  if (mode === "country") return candidateData.country !== undefined && candidateData.country === viewerCountry;

  const radiusKm = candidateData.visibilityRadiusKm as number | undefined;
  const candidateLat = candidateData.lat as number | undefined;
  const candidateLng = candidateData.lng as number | undefined;
  if (
    radiusKm === undefined ||
    candidateLat === undefined ||
    candidateLng === undefined ||
    viewerLat === undefined ||
    viewerLng === undefined
  ) {
    return true;
  }
  return haversineMeters(viewerLat, viewerLng, candidateLat, candidateLng) <= radiusKm * 1000;
}

function isWithinRecipientDiscoverRadius(
  userData: FirebaseFirestore.DocumentData,
  venueLat: number | undefined,
  venueLng: number | undefined,
  venueCountry: string | undefined,
): boolean {
  const mode = userData.discoverRadiusMode as string | undefined;
  if (mode === undefined || mode === "world") return true;
  if (mode === "country") return userData.country !== undefined && userData.country === venueCountry;

  const radiusKm = userData.discoverRadiusKm as number | undefined;
  const userLat = userData.lat as number | undefined;
  const userLng = userData.lng as number | undefined;
  if (
    radiusKm === undefined ||
    userLat === undefined ||
    userLng === undefined ||
    venueLat === undefined ||
    venueLng === undefined
  ) {
    return true;
  }
  return haversineMeters(venueLat, venueLng, userLat, userLng) <= radiusKm * 1000;
}

interface AudienceUserDoc {
  lat?: number;
  lng?: number;
  ghostModeEnabled?: boolean;
  /** The candidate's own "Görünmə radiusu" — read by
   * [isWithinNearbyVisibility], same as in `findNearbyUsers`. */
  visibilityRadiusMode?: string;
  visibilityRadiusKm?: number;
}

/**
 * Server-side mirror of `venueAudienceCountProvider`
 * (`location_providers.dart`) — same 3 modes, same ghost-mode
 * exclusion (never counts a Ghost Mode user, same privacy rule as
 * every client-side "nearby" computation), just run once per scheduled
 * tick instead of live per screen. Kept in lock-step with the client
 * version deliberately — the whole point of storing history is
 * comparing counts computed the SAME way over time.
 */
function computeAudienceCount(
  venue: FirebaseFirestore.DocumentData,
  activeUsers: AudienceUserDoc[],
  onlineByCountry: Map<string, number>,
  onlineWorldwide: number,
): number {
  const mode = (venue.audienceRadiusMode as string | undefined) ?? "distance";

  if (mode === "country") {
    const country = venue.country as string | undefined;
    return country ? onlineByCountry.get(country) ?? 0 : 0;
  }

  if (mode === "world") {
    return onlineWorldwide;
  }

  const lat = venue.lat as number | undefined;
  const lng = venue.lng as number | undefined;
  const radiusKm = (venue.audienceRadiusKm as number | undefined) ?? 1;
  if (lat === undefined || lng === undefined) return 0;

  let count = 0;
  for (const user of activeUsers) {
    if (user.ghostModeEnabled) continue;
    if (user.lat === undefined || user.lng === undefined) continue;
    const distanceMeters = haversineMeters(lat, lng, user.lat, user.lng);
    if (distanceMeters > radiusKm * 1000) continue;
    // "Görünmə radiusu" — the CANDIDATE's own choice of how far away
    // they may be discovered. `previewVenueAudience` has always applied
    // this to the very same question ("how many people are around this
    // venue"); this function did not, so a user who narrowed their own
    // visibility to 1 km still fed a 30 km venue's live audience count
    // and its peak-hour signal. Two functions answering one question
    // must not disagree about who is in the answer.
    if (!isWithinNearbyVisibility(user, distanceMeters)) continue;
    count++;
  }
  return count;
}

/**
 * Every 15 minutes: records each approved venue's current live
 * audience count (`venues/{venueId}/audienceHistory`, swept back to a
 * 7-day rolling window every run), then compares it against that
 * venue's own usual count for this hour of day — a spike (≥1.5x the
 * average) past a 3-hour-per-venue cooldown pushes a "Pik andır!"
 * notification to the owner that deep-links into Create Offer with the
 * venue pre-selected (see `notification_navigation.dart`'s
 * `venue_create_offer` case).
 *
 * "Usual for this hour" is every history entry from the last 7 days
 * that falls in the SAME hour-of-day (0-23), regardless of exact
 * weekday — comparing only the exact same weekday would leave at most
 * one prior sample inside a 7-day retention window, nowhere near
 * enough to call anything "usual". Hour-of-day, sampled daily over a
 * week, is the useful signal a real business owner would recognize
 * ("normally ~10 people around 2pm, right now there's 40").
 */
export const computeVenueAudienceHistory = onSchedule(
  { schedule: "every 15 minutes", region: "europe-west1" },
  async () => {
    const now = new Date();
    const activeCutoff = Timestamp.fromMillis(now.getTime() - AUDIENCE_ACTIVE_WINDOW_MS);
    const historyCutoffMs = now.getTime() - AUDIENCE_HISTORY_RETENTION_MS;
    const hour = now.getHours();

    const venuesSnap = await db.collection("venues").where("status", "==", "approved").get();
    if (venuesSnap.empty) return;

    // BACKLOG #25 — this function used to read the PUBLIC `users`
    // document and cast it straight to [AudienceUserDoc]. Every field
    // that type names — `lat`, `lng`, `ghostModeEnabled`,
    // `visibilityRadiusMode/Km` — had moved to
    // `users/{uid}/private/data` in Düzəliş Prompt 4 / K-1, so all four
    // read `undefined`, every candidate tripped the `lat === undefined`
    // guard, and the distance branch counted ZERO. Always. The
    // "Ətrafınızda" card has therefore never rendered and no peak-hour
    // push has ever fired for a distance-mode venue — which is every
    // venue, since 'distance' is the default in both the picker and
    // `submitVenue`.
    //
    // Same defect class as P0 / H-9 (a field moved, a reader did not),
    // but the opposite sign: H-9 failed OPEN, because `withPrivateData`
    // merges the two documents and the stale public copy became a live
    // fallback. This failed CLOSED — an absent position produces 0,
    // which is the safest answer available. That is why it was a
    // dormant feature rather than a leak, and why the fix could wait
    // for the hardening below to land first.
    //
    // The reads are deliberately lazy and deduplicated — see
    // [loadAudienceUsers].
    const privateByUid = new Map<string, FirebaseFirestore.DocumentData>();

    /**
     * Public docs merged with their own `private/data`, one read per
     * uid per RUN no matter how many venues ask for it.
     *
     * `withPrivateData` is the same merge, but it re-reads on every
     * call; here the country/world branches below can ask for a user
     * the `lastSeen` scan already covered, and a venue base sharing one
     * country would otherwise pay for that user once per venue.
     */
    const loadAudienceUsers = async (
      docs: FirebaseFirestore.QueryDocumentSnapshot[],
    ): Promise<AudienceUserDoc[]> => {
      const missing = docs.filter((d) => !privateByUid.has(d.id));
      const fetched = await Promise.all(missing.map((d) => privateDataRef(d.id).get()));
      missing.forEach((d, i) => privateByUid.set(d.id, fetched[i].data() ?? {}));
      return docs.map((d) => ({ ...d.data(), ...privateByUid.get(d.id) }) as AudienceUserDoc);
    };

    // Skip the position scan entirely when no approved venue is in
    // 'distance' mode — [computeAudienceCount]'s other two branches
    // never look at `activeUsers`, so the `users` query AND its private
    // reads would both be pure waste. Cheap because the venue set is
    // already in hand; worth having because a small venue base can
    // easily be all-country/all-world.
    const anyDistanceVenue = venuesSnap.docs.some(
      (d) => ((d.data().audienceRadiusMode as string | undefined) ?? "distance") === "distance",
    );
    const activeUsers: AudienceUserDoc[] = anyDistanceVenue
      ? await loadAudienceUsers((await db.collection("users").where("lastSeen", ">", activeCutoff).get()).docs)
      : [];

    // Lazily fetched — only venues actually configured for 'country'/
    // 'world' mode ever touch these (the uncommon case; most venues
    // default to 'distance'), cached per run so N venues sharing a
    // country only cost one extra query, not N.
    const onlineByCountry = new Map<string, number>();
    let onlineWorldwide = -1;

    for (const venueDoc of venuesSnap.docs) {
      const venue = venueDoc.data();
      const mode = (venue.audienceRadiusMode as string | undefined) ?? "distance";

      // These two branches had the SAME moved-field bug as the distance
      // one, just without the visible symptom: `d.data().ghostModeEnabled`
      // reads the PUBLIC document, where that flag has not lived since
      // Düzəliş Prompt 4 / K-1 (it is written by
      // `FirebasePrivacySettingsRepository` to `private/data`). So the
      // filter was a no-op and Ghost Mode users were counted — the
      // count still LOOKED right, which is why this half went unnoticed
      // while the distance half was obviously stuck at 0.
      //
      // docs/VENUE_OCCUPANCY.md states Ghost Mode is excluded "hər üç
      // rejimdə". Until this line it was excluded in none of them.
      if (mode === "country" && venue.country && !onlineByCountry.has(venue.country as string)) {
        const snap = await db
          .collection("users")
          .where("country", "==", venue.country)
          .where("online", "==", true)
          .get();
        const users = await loadAudienceUsers(snap.docs);
        onlineByCountry.set(venue.country as string, users.filter((u) => !u.ghostModeEnabled).length);
      }
      if (mode === "world" && onlineWorldwide === -1) {
        const snap = await db.collection("users").where("online", "==", true).get();
        const users = await loadAudienceUsers(snap.docs);
        onlineWorldwide = users.filter((u) => !u.ghostModeEnabled).length;
      }

      const count = computeAudienceCount(venue, activeUsers, onlineByCountry, onlineWorldwide === -1 ? 0 : onlineWorldwide);

      // TWO NARROW QUERIES, not one full-subcollection read.
      //
      // This used to be a bare `.get()` on the whole subcollection, with
      // a comment calling that cheaper than "two separate range
      // queries". It was the opposite. Retention is 7 days at 96 ticks
      // a day, so the collection sits at ~672 documents and EVERY ONE
      // was read on EVERY tick, for every approved venue — 96 x 672 =
      // 64,512 reads per venue per day, growing linearly with the venue
      // count, to compute an average over ~7 samples and find the ~1
      // document that just expired. That alone put this function past
      // Firestore's 50k/day free read tier with a single venue, while
      // it was still returning zeros.
      //
      // Firestore bills documents RETURNED, not scanned, so narrowing
      // the queries is the whole fix: ~7 + ~1 documents instead of 672.
      // The equality-plus-range pair needs the composite index declared
      // in firestore.indexes.json (`hour` ASC, `timestamp` ASC) — WITHOUT
      // IT THIS THROWS FAILED_PRECONDITION, so deploy indexes before
      // functions.
      const historyCutoffTs = Timestamp.fromMillis(historyCutoffMs);
      const [sameHourSnap, staleSnap] = await Promise.all([
        // This venue's usual level for this hour-of-day: one sample per
        // day inside the window, so ~7 documents.
        venueDoc.ref
          .collection("audienceHistory")
          .where("hour", "==", hour)
          .where("timestamp", ">=", historyCutoffTs)
          .get(),
        // The retention sweep. One document falls out of the window per
        // tick in steady state; the limit is headroom for a run that was
        // skipped or a function that was paused, and anything beyond it
        // is simply swept by the next tick. Range-only, so the automatic
        // single-field index covers it — no composite needed.
        venueDoc.ref
          .collection("audienceHistory")
          .where("timestamp", "<", historyCutoffTs)
          .limit(200)
          .get(),
      ]);
      const sameHourCounts = sameHourSnap.docs.map((d) => d.data().count as number);
      const staleDocs = staleSnap.docs;

      if (sameHourCounts.length > 0) {
        const average = sameHourCounts.reduce((a, b) => a + b, 0) / sameHourCounts.length;
        // The SAME k-anonymity floor the stored `currentAudienceCount`
        // gets a few lines below, applied to the notification too.
        //
        // Without it this push was the one place a raw sub-threshold
        // count still escaped. `average > 0 && count >= average * 1.5`
        // is satisfiable by a SINGLE person: over a week of mostly-zero
        // samples the same-hour average lands around 0.14, so one
        // arrival clears 0.21 and the owner is told "Pik andır!". At a
        // small `audienceRadiusKm` that is not an analytics signal, it
        // is a doorway sensor telling the owner someone is standing
        // outside, at 15-minute resolution.
        //
        // Flooring the count before publishing it and then deriving an
        // alert from the unfloored one would have been the floor in
        // name only — the alert IS a publication, just a narrower
        // audience. `VENUE_AUDIENCE_RADIUS_OPTIONS_KM` keeps the radius
        // itself inside what a reviewer would recognise; this keeps the
        // signal meaningless below k regardless of the radius.
        const isPeak =
          count >= VENUE_AUDIENCE_MIN_REPORTABLE_COUNT &&
          average > 0 &&
          count >= average * AUDIENCE_PEAK_THRESHOLD_MULTIPLIER;

        if (isPeak) {
          const lastNotifiedAt = (venue.lastPeakNotifiedAt as Timestamp | undefined)?.toMillis() ?? 0;
          const cooldownOk = now.getTime() - lastNotifiedAt > AUDIENCE_PEAK_COOLDOWN_MS;
          const ownerId = venue.ownerId as string | undefined;

          if (cooldownOk && ownerId) {
            const name = (venue.name as string | undefined) ?? "";
            await notifyUser({
              uid: ownerId,
              category: "venueUpdates",
              type: "venuePeakHour",
              title: "Pik andır! 🔥",
              body: name
                ? `"${name}" ətrafında adətən daha az insan olur — indi təklif yerləşdirin.`
                : "Ətrafınızda adətən daha az insan olur — indi təklif yerləşdirin.",
              params: { venueName: name },
              targetId: venueDoc.id,
              targetType: "venue_create_offer",
            });
            await venueDoc.ref.update({ lastPeakNotifiedAt: FieldValue.serverTimestamp() });
          }
        }
      }

      await venueDoc.ref.collection("audienceHistory").add({
        count,
        hour,
        timestamp: FieldValue.serverTimestamp(),
      });

      // The Canlı tab's "Ətrafınızda" line reads this field and nothing
      // else. It used to read `activeCheckinCount`, which is a
      // different product entirely — voluntary check-ins — so the tab
      // was showing "people who pressed a button" under a label
      // promising "people around you", and showing it to everyone in
      // radius while the person who pressed the button expected to
      // appear on a venue profile. See docs/VENUE_OCCUPANCY.md.
      //
      // FLOORED HERE, on the server. `venues/{id}` is readable by any
      // signed-in user, so writing the raw count and filtering in the
      // client would publish the number anyway. Below the threshold
      // this is 0 and the client draws no card at all.
      //
      // `audienceCountUpdatedAt` is what lets the client refuse to
      // render a stale figure: this runs every 15 minutes, the tab
      // polls every 30 seconds, and if this schedule stalls the number
      // must stop being presented as current rather than quietly
      // ageing on screen.
      await venueDoc.ref.update({
        currentAudienceCount: reportableAudienceCount(count),
        audienceCountUpdatedAt: FieldValue.serverTimestamp(),
      });
      await Promise.all(staleDocs.map((d) => d.ref.delete()));
    }
  },
);

// ── Birthday offers ───────────────────────────────────────────────────

/** Defensive cap on how many opted-in birthday users one run considers — see this function's own doc comment on the geohash follow-up. */
const BIRTHDAY_CANDIDATE_LIMIT = 1000;

/**
 * How long a `birthdayMatches` document survives — docs/BACKLOG.md #26.
 *
 * A match is written at 11:00 and consumed the same day: by
 * `assertBirthdayTargeting` when the owner submits, and by
 * `publishBirthdayCampaigns` at 13:00. Nothing needs it tomorrow —
 * `assertBirthdayTargeting` rejects a match that is not today's — so
 * three days is pure slack for a run that failed and had to be looked
 * at, matching `INTENT_RETENTION_DAYS`.
 *
 * Removed by a native TTL policy on `expiresAt`, not by a sweep. The
 * collection previously had neither and grew by one document per
 * eligible venue per day, forever.
 */
const BIRTHDAY_MATCH_RETENTION_DAYS = 3;

/**
 * The hour, in Baku, when the day's approved birthday campaigns go
 * live — see `publishBirthdayCampaigns`.
 *
 * Named rather than inlined because four things depend on this one
 * number: the scheduled publish, the "is this late?" branch in
 * `onOfferUpdated`, the admin reminder half an hour before it, and the
 * deadline the 11:00 push quotes to owners.
 */
const BIRTHDAY_PUBLISH_HOUR = 13;

interface BirthdayUserDoc {
  uid: string;
  lat?: number;
  lng?: number;
  country?: string;
  discoverRadiusMode?: string;
  discoverRadiusKm?: number;
}

/**
 * Daily at 11:00 Azerbaijan time (`Asia/Baku` — see `timeZone` below,
 * which controls when Cloud Scheduler fires this, not what a plain
 * `Date` reports once it's running: Cloud Functions' own runtime clock
 * reads UTC, so "today" is derived from an Asia/Baku-formatted string,
 * never from `Date.getMonth()/getDate()` directly): finds every user
 * whose `birthDate` month+day matches today (birth YEAR never
 * matters) and who has opted in via `PrivacySettings.birthdayOffersOptIn`
 * (`users/{uid}.birthdayOffersOptIn`) — a user who never opted in is
 * invisible to this function entirely, not merely excluded from the
 * final notification.
 *
 * For every approved venue with `birthdayNotificationsEnabled`, checks
 * which of those birthday users fall within EACH birthday user's OWN
 * chosen Discover radius (see [isWithinRecipientDiscoverRadius]) — NOT
 * the venue's `audienceRadiusMode`/`audienceRadiusKm`, which is scoped
 * to the owner-only "Ətrafda N istifadəçi" live counter
 * (`computeAudienceCount`) only, unrelated to reach. One
 * `birthdayMatches/{date}_{venueId}` doc per venue that matched at
 * least one user, plus ONE push per OWNER nudging them to create a
 * birthday campaign.
 *
 * ── 11:00, and why that exact hour ─────────────────────────────────
 *
 * This used to run at 00:05. It now runs at 11:00 because the two
 * hours between this function and `publishBirthdayCampaigns` (13:00)
 * are the MODERATION WINDOW, and that window is the whole design:
 *
 *   11:00  the owner is told "N people nearby have a birthday today"
 *   11:05  the owner creates a campaign
 *   ~12:xx a moderator approves it
 *   13:00  every approved campaign publishes at once, and the birthday
 *          users get exactly one notification
 *
 * Computing at midnight bought nothing and cost accuracy: a user's
 * `lat`/`lng` at 00:05 is eleven hours staler than at 11:00, and
 * nothing could act on the result until the morning anyway.
 *
 * ── One push per owner, not one per venue ──────────────────────────
 *
 * An owner with three eligible venues used to get three separate
 * pushes in the same minute. They now get one. With a single matched
 * venue the deep link is unchanged (`targetType: 'birthday_match'` →
 * the pre-filled Create Offer flow, see `NotificationType.birthdayMatch`'s
 * doc comment client-side); with several there is no single match to
 * open, so it points at the owner's venue list instead.
 *
 * Full collection scans for now (bounded by the `birthdayOffersOptIn`/
 * `birthdayNotificationsEnabled` filters already, plus
 * [BIRTHDAY_CANDIDATE_LIMIT] defensively) — per product decision, this
 * ships and gets tested against a small real dataset before any
 * geohash-sharded query work, so a venue base too large for a daily
 * full scan isn't a problem this build needs to solve yet.
 */
export const computeBirthdayMatches = onSchedule(
  { schedule: "0 11 * * *", timeZone: "Asia/Baku", region: "europe-west1" },
  async () => {
    const now = new Date();
    // Both sides of the birthday comparison are now read in Asia/Baku —
    // see `./birthday`, and the doc comment there for why the UTC
    // extraction this replaces fired a day early.
    const todayKey = bakuDateKey(now);

    const [optedInUsersSnap, eligibleVenuesSnap] = await Promise.all([
      db.collection("users").where("birthdayOffersOptIn", "==", true).limit(BIRTHDAY_CANDIDATE_LIMIT).get(),
      db
        .collection("venues")
        .where("status", "==", "approved")
        .where("birthdayNotificationsEnabled", "==", true)
        .get(),
    ]);
    if (optedInUsersSnap.empty || eligibleVenuesSnap.empty) return;

    // `ghostModeEnabled`/`birthDate`/`lat`/`lng`/`discoverRadiusMode`/
    // `discoverRadiusKm` all moved to `users/{uid}/private/data` (Düzəliş
    // Prompt 4 / K-1) — `birthdayOffersOptIn` itself stayed public
    // (query constraint, see `privateDataRef`'s doc comment), so the
    // query above still works, but every other field this loop reads
    // now needs a second, per-candidate fetch.
    const privateSnaps = await Promise.all(optedInUsersSnap.docs.map((doc) => privateDataRef(doc.id).get()));

    const birthdayUsers: BirthdayUserDoc[] = [];
    optedInUsersSnap.docs.forEach((doc, i) => {
      const data = privateSnaps[i].data() ?? {};
      if (data.ghostModeEnabled) return;
      const birthDate = data.birthDate as Timestamp | undefined;
      if (!birthDate) return;
      if (!isBirthdayToday(birthDate.toDate(), now)) return;
      birthdayUsers.push({
        uid: doc.id,
        lat: data.lat,
        lng: data.lng,
        country: doc.data().country, // `country` stays on the main (public) doc
        discoverRadiusMode: data.discoverRadiusMode,
        discoverRadiusKm: data.discoverRadiusKm,
      });
    });
    if (birthdayUsers.length === 0) return;

    // Collected across every venue, then sent as ONE push per owner
    // below — see this function's doc comment.
    const newMatchesByOwner = new Map<string, { matchId: string; userCount: number }[]>();

    for (const venueDoc of eligibleVenuesSnap.docs) {
      const venue = venueDoc.data();
      // Category allowlist — `birthdayNotificationsEnabled` alone was
      // the whole gate, so any approved venue that flipped the toggle
      // (a clinic, a car wash) entered the birthday flow. The toggle
      // still governs opt-out; this governs eligibility.
      if (!isBirthdayCategory(venue.category)) continue;
      const venueLat = venue.lat as number | undefined;
      const venueLng = venue.lng as number | undefined;
      const venueCountry = venue.country as string | undefined;

      // Same recipient-radius rule as `resolveNotifyCandidates` — each
      // birthday user's OWN chosen Discover radius is the only
      // geographic gate. No independentArtist-follow exception here:
      // birthday matching isn't follow-based, every candidate above is
      // a generic opted-in user, not someone who chose to follow this
      // venue.
      const matchedUserIds = birthdayUsers
        .filter((u) => isWithinRecipientDiscoverRadius(u, venueLat, venueLng, venueCountry))
        .map((u) => u.uid);

      if (matchedUserIds.length === 0) continue;

      // Doc id is deterministic (date + venue), so a re-run for the
      // same day (retry, manual trigger) never double-counts or
      // double-pushes for a venue already processed today.
      const matchRef = db.collection("birthdayMatches").doc(`${todayKey}_${venueDoc.id}`);
      if ((await matchRef.get()).exists) continue;

      await matchRef.set({
        venueId: venueDoc.id,
        date: todayKey,
        matchedUserIds,
        count: matchedUserIds.length,
        notified: false,
        // `offerCreated: false` was written here and NEVER set to true —
        // no line of code updated it (docs/BACKLOG.md #26). Removed
        // rather than wired up: nothing reads it, and the honest
        // version is not cheap. "Did the owner act on this nudge?"
        // cannot be answered by a flag set at submit time, because a
        // campaign can be submitted and then rejected; answering it
        // properly means reading the offer's final status. A field that
        // always says `false` is worse than no field, because it looks
        // like an answer.
        createdAt: FieldValue.serverTimestamp(),
        // docs/BACKLOG.md #26 — this collection grew without bound
        // because nothing ever removed a day's matches. A native TTL
        // on `expiresAt` does it with no scheduled sweep to forget,
        // the same arrangement as `notificationIntents`.
        expiresAt: Timestamp.fromMillis(Date.now() + BIRTHDAY_MATCH_RETENTION_DAYS * 24 * 60 * 60 * 1000),
      });

      const ownerId = venue.ownerId as string | undefined;
      if (!ownerId) continue;

      const owned = newMatchesByOwner.get(ownerId) ?? [];
      owned.push({ matchId: matchRef.id, userCount: matchedUserIds.length });
      newMatchesByOwner.set(ownerId, owned);
    }

    for (const [ownerId, matches] of newMatchesByOwner) {
      const totalUsers = matches.reduce((sum, m) => sum + m.userCount, 0);
      const single = matches.length === 1;

      await notifyUser({
        uid: ownerId,
        category: "venueUpdates",
        type: "birthdayMatch",
        title: "🎂 Ad günü fürsəti",
        // The 13:00 deadline is stated in the push itself. An owner
        // cannot use a moderation window nothing tells them about:
        // "yarat" alone gave no reason to act now rather than tonight,
        // by which time the day is over.
        body: single
          ? `Bugün yaxınlığınızda ${totalUsers} PeakPin istifadəçisinin doğum günüdür. Kampaniyanı saat ${BIRTHDAY_PUBLISH_HOUR}:00-a qədər yaradın!`
          : `${matches.length} məkanınızın yaxınlığında bu gün ${totalUsers} PeakPin istifadəçisinin doğum günüdür. Kampaniyaları saat ${BIRTHDAY_PUBLISH_HOUR}:00-a qədər yaradın!`,
        params: { count: totalUsers, venueCount: matches.length },
        // With one match the existing pre-filled Create Offer deep link
        // still works. With several there is no single match to open.
        targetId: single ? matches[0].matchId : todayKey,
        targetType: single ? "birthday_match" : "my_venues",
      });

      await Promise.all(
        matches.map((m) => db.collection("birthdayMatches").doc(m.matchId).update({ notified: true })),
      );
    }
  },
);

/** Same charset the register screen enforces (`_usernamePattern` in
 * onboarding_screen.dart: `[a-zA-Z0-9._]{3,20}`) — matching anything
 * wider would just pick up false positives (emails, decorative
 * "@@@"s) that could never resolve to a real handle anyway. */
const MENTION_PATTERN = /@([a-zA-Z0-9._]{3,20})/g;

function extractMentionedUsernames(text: string): string[] {
  const usernames = new Set<string>();
  for (const match of text.matchAll(MENTION_PATTERN)) {
    // `usernames/{usernameId}` doc ids are always lowercased (see that
    // collection's own firestore.rules doc comment) — a mention is
    // case-insensitive against whatever case the handle owner
    // actually registered with.
    usernames.add(match[1].toLowerCase());
  }
  return Array.from(usernames);
}

/**
 * Resolves @-mentions in [text] (a post caption or comment) to uids —
 * via the public `usernames/{usernameId}` lookup collection, the same
 * one the register screen's availability check and login use — and
 * sends each a [mention] notification. Shared by `onPostCreated`
 * (caption) and `onPostCommentCreated` (comment text) below. Silently
 * skips a token that doesn't resolve to any account (typo, or
 * genuinely no such handle) and never notifies the author about
 * mentioning themselves.
 */
async function notifyMentionedUsers(params: { text: string; authorId: string; postId: string }): Promise<void> {
  const usernames = extractMentionedUsernames(params.text);
  if (usernames.length === 0) return;

  const resolvedSnaps = await Promise.all(usernames.map((u) => db.collection("usernames").doc(u).get()));
  const mentionedUids = new Set<string>();
  for (const snap of resolvedSnaps) {
    const uid = snap.data()?.uid as string | undefined;
    if (uid && uid !== params.authorId) mentionedUids.add(uid);
  }
  if (mentionedUids.size === 0) return;

  const author = await getUserDisplayInfo(params.authorId);
  const preview = params.text.length > 80 ? `${params.text.slice(0, 80)}…` : params.text;

  await Promise.all(
    Array.from(mentionedUids).map((uid) =>
      notifyUser({
        uid,
        category: "comments",
        type: "mention",
        title: author.name,
        body: preview || "Sizi bir paylaşımda etiketlədi",
        params: { preview },
        senderId: params.authorId,
        senderName: author.name,
        senderPhoto: author.photoUrl,
        targetId: params.postId,
        targetType: "post",
      }),
    ),
  );
}

/** Confirms to nobody, notifies only whoever the caption @-mentions —
 * the post owner obviously already knows they posted. */
export const onPostCreated = onDocumentCreated("posts/{postId}", async (event) => {
  const post = event.data?.data();
  if (!post) return;
  const authorId = post.userId as string | undefined;
  if (!authorId) return;

  // Denormalized copy of the author's CURRENT account privacy, set
  // server-side (never trust the client for this — a false "true"
  // here would leak a private account's video into the public
  // discover grid) so that grid's query (`authorIsPublic == true`,
  // across every author) is a plain list query Firestore rules can
  // actually prove safe — `firestore.rules` can't prove a per-author
  // `get()`-based privacy check the way it can a flat field compare.
  // Kept in sync afterwards by `onUserUpdated` below, whenever
  // `accountPrivacy` itself changes.
  const authorSnap = await db.collection("users").doc(authorId).get();
  const authorIsPublic = (authorSnap.data()?.accountPrivacy as string | undefined) !== "private";
  await event.data?.ref.set({ authorIsPublic }, { merge: true });

  const caption = post.caption as string | undefined;
  if (!caption) return;
  await notifyMentionedUsers({ text: caption, authorId, postId: event.params.postId });
});

/** Firestore batch write cap — chunk any bulk update into groups this size. */
const FIRESTORE_BATCH_LIMIT = 500;

/**
 * Fans a privacy-setting change out to every one of that author's
 * existing posts' `authorIsPublic` copy (see `onPostCreated` above for
 * why the denormalized copy exists at all). Chunked into
 * [FIRESTORE_BATCH_LIMIT]-sized batches since a prolific poster can
 * easily exceed Firestore's single-batch write cap.
 */
async function syncAuthorIsPublicForUser(uid: string, isPublic: boolean): Promise<void> {
  const postsSnap = await db.collection("posts").where("userId", "==", uid).get();
  const docs = postsSnap.docs.filter((d) => d.data().authorIsPublic !== isPublic);
  for (let i = 0; i < docs.length; i += FIRESTORE_BATCH_LIMIT) {
    const batch = db.batch();
    for (const doc of docs.slice(i, i + FIRESTORE_BATCH_LIMIT)) {
      batch.update(doc.ref, { authorIsPublic: isPublic });
    }
    await batch.commit();
  }
}

export const onPostCommentCreated = onDocumentCreated("posts/{postId}/comments/{commentId}", async (event) => {
  await bumpPostCounter(event.params.postId, "commentsCount", 1);

  const comment = event.data?.data();
  if (!comment) return;
  const commenterId = comment.userId as string | undefined;
  const replyToCommentId = comment.replyToCommentId as string | undefined;
  if (!commenterId) return;

  const commentText = (comment.text as string | undefined) ?? "";
  if (commentText) {
    await notifyMentionedUsers({ text: commentText, authorId: commenterId, postId: event.params.postId });
  }

  const commenter = await getUserDisplayInfo(commenterId);
  const preview = commentText.length > 80 ? `${commentText.slice(0, 80)}…` : commentText;

  // A reply notifies the parent comment's author (replyComment); a
  // top-level comment notifies the post owner (commentPost) — mutually
  // exclusive so the same comment never produces two notification docs
  // for the common case where they're the same person.
  if (replyToCommentId) {
    const parentSnap = await db
      .collection("posts")
      .doc(event.params.postId)
      .collection("comments")
      .doc(replyToCommentId)
      .get();
    const parentAuthorId = parentSnap.data()?.userId as string | undefined;
    if (!parentAuthorId || parentAuthorId === commenterId) return;

    await notifyUser({
      uid: parentAuthorId,
      category: "comments",
      type: "replyComment",
      title: commenter.name,
      body: preview || "Şərhinizə cavab yazdı",
      params: { preview },
      senderId: commenterId,
      senderName: commenter.name,
      senderPhoto: commenter.photoUrl,
      targetId: event.params.postId,
      targetType: "post",
    });
    return;
  }

  const postSnap = await db.collection("posts").doc(event.params.postId).get();
  const postOwnerId = postSnap.data()?.userId as string | undefined;
  if (!postOwnerId || postOwnerId === commenterId) return;

  await notifyUser({
    uid: postOwnerId,
    category: "comments",
    type: "commentPost",
    title: commenter.name,
    body: preview || "Paylaşımına şərh yazdı",
    params: { preview },
    senderId: commenterId,
    senderName: commenter.name,
    senderPhoto: commenter.photoUrl,
    targetId: event.params.postId,
    targetType: "post",
  });
});

/**
 * Confirms to the submitting owner that their venue was created — the
 * one notification in this file with no separate "sender", since the
 * event is the system reacting to the owner's own submission.
 */
export const onVenueCreated = onDocumentCreated("venues/{venueId}", async (event) => {
  const venue = event.data?.data();
  if (!venue) return;
  const ownerId = venue.ownerId as string | undefined;
  if (!ownerId) return;
  const name = (venue.name as string | undefined) ?? "";

  await notifyUser({
    uid: ownerId,
    category: "account",
    type: "venueAdded",
    title: "Məkanınız əlavə edildi",
    body: name ? `"${name}" uğurla yaradıldı.` : "Məkanınız uğurla yaradıldı.",
    params: { venueName: name },
    targetId: event.params.venueId,
    targetType: "venue",
  });
});

/**
 * Fires when `verified` flips false→true. No moderation/admin UI sets
 * that flag yet (it's created `false` by `FirebaseVenueRepository` and
 * nothing in this codebase flips it today) — same "real trigger, no
 * producer wired up yet" situation as `onFriendRequestUpdated`.
 *
 * Also fires on a moderation `status` change (pending → approved/
 * needs_revision/rejected, set exclusively by the admin panel's Server
 * Actions via the Admin SDK — firestore.rules blocks the owner from
 * writing `status` themselves) — see `moderationStatusNotification`.
 */
export const onVenueUpdated = onDocumentUpdated("venues/{venueId}", async (event) => {
  const before = event.data?.before.data();
  const after = event.data?.after.data();
  if (!before || !after) return;

  const ownerId = after.ownerId as string | undefined;
  if (!ownerId) return;
  const name = (after.name as string | undefined) ?? "";

  if (before.verified !== after.verified && after.verified === true) {
    await notifyUser({
      uid: ownerId,
      category: "account",
      type: "venueVerified",
      title: "Məkanınız təsdiqləndi",
      body: name ? `"${name}" artıq təsdiqlənmiş məkandır.` : "Məkanınız təsdiqləndi.",
      params: { venueName: name },
      targetId: event.params.venueId,
      targetType: "venue",
    });
  }

  if (before.status !== after.status) {
    const notification = moderationStatusNotification(
      "venue",
      name,
      after.status,
      after.reviewNote,
      Boolean(after.paymentId),
    );
    if (notification) {
      await notifyUser({
        uid: ownerId,
        category: "account",
        ...notification,
        targetId: event.params.venueId,
        targetType: "venue",
      });
    }

    if (after.status === "approved" && !("isFoundingVenue" in after)) {
      await assignFoundingVenueIfEligible(event.params.venueId);
    }
  }
});

/** How many of the first FOUNDING_VENUE_LIMIT venues get free offer placements — see `assignFoundingVenueIfEligible`. */
const FOUNDING_VENUE_LIMIT = 1000;
const FOUNDING_VENUE_FREE_OFFERS = 5;
const FOUNDING_VENUE_WINDOW_MS = 30 * 24 * 60 * 60 * 1000;

/**
 * "İlk 1000 abunə olan venue" — counted at first APPROVAL, not at raw
 * signup: a rejected/spam registration never really became a
 * subscriber (the recurring `subscriptionRenewsAt` billing itself only
 * ever bills `status == 'approved'` venues — see
 * `renewVenueSubscriptions`), so counting it against the founding pool
 * would waste a slot on something that was never real revenue. Guarded
 * by the caller (`!("isFoundingVenue" in after)`) so a later
 * needs_revision → re-approved cycle on the SAME venue never re-enters
 * this and never double-counts against the global limit.
 *
 * `config/foundingVenueCounter` is a single counter doc updated inside
 * the same transaction as the venue write, so two venues approved in
 * the same instant can't both slip in as the 1000th.
 *
 * Also grants the "1 ay ödə, 1 ay hədiyyə al" perk here, not at the
 * first payment (`applyPaymentOutcome`) — founding status isn't known
 * yet at that point, since it's only assigned on first approval, which
 * always happens strictly after the first (real, Epoint-confirmed)
 * payment. The owner already paid for their first cycle in full; this
 * just pushes `subscriptionRenewsAt` one more `SUBSCRIPTION_CYCLE_MS`
 * forward, skipping what would otherwise be the 2nd charge. Additive
 * regardless of how long moderation review took (adds to whatever
 * `subscriptionRenewsAt` already holds, not "+30 days from today"), so
 * a slow review never shrinks or stretches the free month.
 */
async function assignFoundingVenueIfEligible(venueId: string): Promise<void> {
  const counterRef = db.collection("config").doc("foundingVenueCounter");
  const venueRef = db.collection("venues").doc(venueId);

  await db.runTransaction(async (tx) => {
    const counterSnap = await tx.get(counterRef);
    const venueSnap = await tx.get(venueRef);
    const count = (counterSnap.data()?.count as number | undefined) ?? 0;

    if (count >= FOUNDING_VENUE_LIMIT) {
      tx.update(venueRef, { isFoundingVenue: false });
      return;
    }

    const currentRenewsAt = (venueSnap.data()?.subscriptionRenewsAt as Timestamp | undefined)?.toDate();

    tx.set(counterRef, { count: count + 1 }, { merge: true });
    tx.update(venueRef, {
      isFoundingVenue: true,
      freeOffersUsed: 0,
      freeOfferWindowEnd: Timestamp.fromDate(new Date(Date.now() + FOUNDING_VENUE_WINDOW_MS)),
      ...(currentRenewsAt
        ? { subscriptionRenewsAt: Timestamp.fromDate(new Date(currentRenewsAt.getTime() + SUBSCRIPTION_CYCLE_MS)) }
        : {}),
    });
  });
}

/**
 * Same moderation-status notification as `onVenueUpdated`, for offers
 * — offers have no `verified` concept, so this trigger only ever
 * watches `status`. Also the trigger point for
 * `notifyNearbyUsersOfNewOffer` below — an offer only ever becomes
 * visible to browsing users the moment `status` reaches 'approved'
 * (see firestore.rules' discovery queries), so that transition IS
 * this app's real equivalent of "a new offer was published".
 */
export const onOfferUpdated = onDocumentUpdated("offers/{offerId}", async (event) => {
  const before = event.data?.before.data();
  const after = event.data?.after.data();
  if (!before || !after) return;
  if (before.status === after.status) return;

  const ownerId = after.ownerId as string | undefined;
  if (!ownerId) return;
  const title = (after.title as string | undefined) ?? "";

  const notification = moderationStatusNotification(
    "offer",
    title,
    after.status,
    after.reviewNote,
    Boolean(after.paymentId),
  );
  if (notification) {
    await notifyUser({
      uid: ownerId,
      category: "account",
      ...notification,
      targetId: event.params.offerId,
      targetType: "offer",
    });
  }

  // Not gated on `before.status === 'pending'` — a needs_revision →
  // approved transition after the owner fixes something is just as
  // much "this offer is now real and visible" from a browsing user's
  // perspective as a first-time approval is.
  //
  // A `happyHour` offer additionally only fires this if it's actually
  // inside its window right at approval — otherwise a push saying "new
  // offer nearby" would send someone straight to a discount that's
  // hidden from every list until its window opens (see
  // `computeHappyHourActive`/`Offer.happyHourActive`). Approving it
  // outside the window simply means no approval-time push goes out;
  // this deliberately does NOT add a second push for when the window
  // later opens — that would fire once a day for as long as the offer
  // runs, which is a bigger notification-strategy call than fixing
  // this mismatch calls for.
  if (after.status === "approved") {
    if (after.offerType === "birthday") {
      // Approval does NOT publish. A birthday campaign approved inside
      // the 11:00–13:00 moderation window waits for
      // `publishBirthdayCampaigns`, so the whole day's campaigns appear
      // together instead of trickling out one venue at a time ahead of
      // the notification that announces them.
      //
      // Past 13:00 that run has already happened, so a late approval
      // publishes itself — visible immediately, silent unless nobody
      // was notified today. See `publishBirthdayOffers`.
      await publishLateBirthdayOfferIfNeeded(event.params.offerId, after);
    } else if (after.offerType !== "happyHour" || after.happyHourActive === true) {
      // Records the intent; `sendDailyOpportunityDigest` decides who
      // hears about it and when — see [recordListingIntent].
      await recordListingIntent("offer", event.params.offerId, after.venueId as string, ownerId, after);
    }
  }
});

// ── Happy Hour real-time filtering ───────────────────────────────────

/** Azerbaijan has used a fixed UTC+4 offset year-round since abolishing
 * DST in 2016 — the venue/offer network is Azerbaijan-only, so this is
 * a deliberate fixed constant, not a per-venue/user timezone lookup. */
const AZERBAIJAN_UTC_OFFSET_MINUTES = 4 * 60;

/** `Date.getUTCDay()` index order (0 = Sunday), matching `Offer.activeDays`'s
 * lowercase 3-letter keys (see `kAllWeekdayKeys` in `create_offer_screen.dart`). */
const WEEKDAY_KEYS = ["sun", "mon", "tue", "wed", "thu", "fri", "sat"];

/**
 * Whether an `OfferType.happyHour` offer's daily window covers this
 * exact instant, in Azerbaijan local time. Handles an overnight window
 * (e.g. 22:00–02:00) by treating "start > end" as wrapping past
 * midnight, same as a normal wall-clock reading would.
 */
function isHappyHourActiveNow(
  activeHours: { start?: unknown; end?: unknown } | undefined,
  activeDays: unknown
): boolean {
  const start = typeof activeHours?.start === "string" ? activeHours.start : undefined;
  const end = typeof activeHours?.end === "string" ? activeHours.end : undefined;
  const days = Array.isArray(activeDays) ? (activeDays as string[]) : [];
  if (!start || !end || days.length === 0) return false;

  const local = new Date(Date.now() + AZERBAIJAN_UTC_OFFSET_MINUTES * 60 * 1000);
  if (!days.includes(WEEKDAY_KEYS[local.getUTCDay()])) return false;

  const minutesNow = local.getUTCHours() * 60 + local.getUTCMinutes();
  const [startH, startM] = start.split(":").map(Number);
  const [endH, endM] = end.split(":").map(Number);
  if ([startH, startM, endH, endM].some((n) => Number.isNaN(n))) return false;
  const startMinutes = startH * 60 + startM;
  const endMinutes = endH * 60 + endM;
  if (startMinutes === endMinutes) return false;

  return startMinutes < endMinutes
    ? minutesNow >= startMinutes && minutesNow < endMinutes
    : minutesNow >= startMinutes || minutesNow < endMinutes;
}

/** True for every offer type except `happyHour`, whose visibility
 * actually depends on the clock — see [isHappyHourActiveNow]. */
function computeHappyHourActive(offer: FirebaseFirestore.DocumentData): boolean {
  if (offer.offerType !== "happyHour") return true;
  return isHappyHourActiveNow(
    offer.activeHours as { start?: unknown; end?: unknown } | undefined,
    offer.activeDays
  );
}

/**
 * Keeps `Offer.happyHourActive` correct the moment an offer is created
 * or its type/hours/days are edited — firestore.rules blocks the
 * client from ever writing this field itself (same lock-field pattern
 * as `status`), so this trigger and [refreshHappyHourOfferStatus]
 * below (which re-checks on a timer, since nothing else "writes" an
 * offer just because the clock crossed its window) are the only two
 * places it's ever set. Guarded against re-triggering itself: this
 * function's own `.update()` call is a write too, but by the time it
 * fires again the stored value already matches, so the `!==` check
 * below short-circuits.
 */
export const maintainHappyHourActiveFlag = onDocumentWritten("offers/{offerId}", async (event) => {
  const after = event.data?.after;
  if (!after?.exists) return;
  const data = after.data();
  if (!data) return;

  const computed = computeHappyHourActive(data);
  if (data.happyHourActive === computed) return;
  await after.ref.update({ happyHourActive: computed });
});

/**
 * Re-evaluates every approved Happy Hour offer's [computeHappyHourActive]
 * on a timer — [maintainHappyHourActiveFlag] only fires on a write to
 * the offer itself, so without this, an offer that nobody touches
 * would stay stuck at whatever `happyHourActive` value it had when it
 * was last written, even long after its daily window opened or closed.
 * 5-minute granularity trades a little boundary precision for not
 * running a query every minute.
 */
export const refreshHappyHourOfferStatus = onSchedule(
  { schedule: "every 5 minutes", region: "europe-west1" },
  async () => {
    const snap = await db.collection("offers").where("offerType", "==", "happyHour").where("status", "==", "approved").get();
    await Promise.all(
      snap.docs.map(async (doc) => {
        const computed = computeHappyHourActive(doc.data());
        if (doc.data().happyHourActive !== computed) {
          await doc.ref.update({ happyHourActive: computed });
        }
      })
    );
  }
);

// ── Waitlist ──────────────────────────────────────────────────────────

/**
 * Server-side "join the walk-in waitlist" — the ONLY path that may
 * create a `venues/{venueId}/waitlist` doc (firestore.rules' own
 * `allow create` on that collection is `if false`; this function uses
 * the Admin SDK, which bypasses rules entirely). A direct client write
 * validated only by rules could check the NEW document's own shape,
 * but never "does this exact phone number already have a `waiting`
 * entry at this venue" — that requires reading OTHER documents at
 * commit time, which is exactly what the transaction below does. A
 * `tx.get(query)` read is committed atomically together with the
 * following write, so two joins for the same phone number arriving at
 * the same instant can't both slip through — the second one's query
 * read gets invalidated by the first's write and the transaction
 * retries, seeing the just-created entry.
 */
export const joinWaitlist = onCall({ region: "us-central1", enforceAppCheck: false }, async (request) => {
  const uid = request.auth?.uid;
  if (!uid) throw new HttpsError("unauthenticated", "Bu əməliyyat üçün daxil olmalısınız.");
  await assertActiveUser(uid);

  // P0 — every join writes an entry, re-runs
  // `maintainWaitlistQueuePositions` over the whole queue, AND pushes a
  // notification to the venue owner. The only duplicate guard is on
  // `phoneNumber`, which the caller chooses freely, so a loop with
  // made-up numbers was an owner-notification flood plus queue
  // pollution. Nobody legitimately joins five queues an hour.
  await enforceRateLimit("waitlist", uid, 5, 3600);

  const venueId = request.data?.venueId as string | undefined;
  if (!venueId) throw new HttpsError("invalid-argument", "venueId tələb olunur.");

  const partySize = request.data?.partySize as number | undefined;
  if (!Number.isInteger(partySize) || (partySize as number) < 1 || (partySize as number) > 10) {
    throw new HttpsError("invalid-argument", "partySize 1-10 aralığında tam ədəd olmalıdır.");
  }

  const rawPhone = (request.data?.phoneNumber as string | undefined)?.trim();
  if (!rawPhone) throw new HttpsError("invalid-argument", "phoneNumber tələb olunur.");
  // Normalised for the same reason as `completeOnboarding`, plus one
  // specific to this flow: the duplicate check below is an equality
  // match on this exact string, so two spellings of the same number
  // ("+994 50 274 98 98" and "+994502749898") would each get their own
  // queue entry.
  let phoneNumber: string;
  try {
    phoneNumber = normalizePhoneNumber(rawPhone);
  } catch (e) {
    throw new HttpsError("invalid-argument", e instanceof InvalidPhoneNumberError ? e.reason : "invalid-phone-number");
  }

  const note = request.data?.note as string | undefined;
  if (note !== undefined && typeof note !== "string") {
    throw new HttpsError("invalid-argument", "note sətir olmalıdır.");
  }

  const venueSnap = await db.collection("venues").doc(venueId).get();
  if (!venueSnap.exists) throw new HttpsError("not-found", "Məkan tapılmadı.");

  // Must be a live venue. A `pending`/`rejected`/`awaiting_payment`/
  // `subscription_overdue` venue is not discoverable, so the only way to
  // reach its queue is a stale link or a direct call — and joining the
  // queue of a venue that is not open for business is meaningless for
  // the guest and noise for the owner.
  if (venueSnap.data()?.status !== "approved") {
    throw new HttpsError("failed-precondition", "venue-unavailable");
  }

  // ALLOWLIST, not the three-item blacklist this used to check — see
  // `./venue-categories`. The blacklist answered "is this one of the
  // three offer-only categories", which let a hotel or a clinic accept
  // queue entries; the product rule is a specific set of ten.
  const venueCategory = venueSnap.data()?.category as string | undefined;
  if (!isWaitlistCategory(venueCategory)) {
    throw new HttpsError("failed-precondition", "Bu məkan kateqoriyası növbə funksiyasını dəstəkləmir.");
  }

  const waitlistRef = db.collection("venues").doc(venueId).collection("waitlist");
  const newEntryRef = waitlistRef.doc();

  await db.runTransaction(async (tx) => {
    const existingSnap = await tx.get(
      waitlistRef.where("phoneNumber", "==", phoneNumber).where("status", "==", "waiting").limit(1)
    );
    // `already-exists` (not `failed-precondition`) — this isn't a state
    // the CALLER can fix by retrying, it's a genuine duplicate-resource
    // rejection, same HTTP-status-code intent as e.g. a unique-username
    // conflict.
    if (!existingSnap.empty) throw new HttpsError("already-exists", "already-waiting");

    tx.set(newEntryRef, {
      userId: uid,
      partySize,
      phoneNumber,
      ...(note ? { note } : {}),
      status: "waiting",
      joinedAt: FieldValue.serverTimestamp(),
    });
  });

  // Owner-facing signal — previously the ONLY way an owner found out
  // someone joined was manually opening VenueWaitlistScreen and
  // noticing a new row. `targetType: "venue_waitlist"` (not plain
  // "venue") so tapping the notification skips straight to the
  // waitlist itself, not just the venue profile — see
  // `notification_navigation.dart`.
  const ownerId = venueSnap.data()!.ownerId as string;
  const venueName = (venueSnap.data()?.name as string | undefined) ?? "";
  const quotedVenue = venueName ? `"${venueName}"` : "Məkanınız";
  await notifyUser({
    uid: ownerId,
    category: "account",
    type: "venueWaitlistJoined",
    title: "Növbəyə yeni yazılış",
    body: `${quotedVenue} növbəsinə ${partySize} nəfərlik yeni yazılış oldu.`,
    params: { name: venueName, partySize },
    targetId: venueId,
    targetType: "venue_waitlist",
  });

  return { entryId: newEntryRef.id };
});

/** A `called` entry auto-reverts to `no_show` if the owner never marks
 * it seated within this long — mirrors the "5 dəqiqəyə gəlin" push
 * copy with some slack for the sweep's own 5-minute cadence. */
const WAITLIST_NO_SHOW_TIMEOUT_MS = 10 * 60 * 1000;

/**
 * Keeps every `waiting` entry's `queuePosition` correct — fires on
 * every create/status-change in a venue's waitlist (a join, a cancel,
 * a call, anything), and just recomputes 1..N by `joinedAt` order over
 * whatever's `waiting` right now. Doing this server-side, instead of
 * each client computing its own "how many ahead of me" count, is what
 * makes two people joining at the same instant land on different
 * numbers instead of racing onto the same one.
 *
 * Also the sole sender of the `waitlistCalled` notification, gated on
 * the entry's status having JUST become `called` this write (not
 * already having been) — this function's own `queuePosition`-only
 * writes below don't touch `status`, so they can never re-trigger it.
 */
export const maintainWaitlistQueuePositions = onDocumentWritten(
  "venues/{venueId}/waitlist/{entryId}",
  async (event) => {
    const venueId = event.params.venueId;
    const before = event.data?.before.data();
    const after = event.data?.after.data();

    if (after && before?.status !== "called" && after.status === "called") {
      const venueSnap = await db.collection("venues").doc(venueId).get();
      const venueName = (venueSnap.data()?.name as string | undefined) ?? "";
      const userId = after.userId as string | undefined;
      if (userId) {
        await notifyUser({
          uid: userId,
          category: "account",
          type: "waitlistCalled",
          title: "Sıra sizindir!",
          body: venueName ? `${venueName} — 5 dəqiqəyə gəlin.` : "5 dəqiqəyə gəlin.",
          params: { venueName },
          targetId: venueId,
          targetType: "venue",
        });
      }
    }

    const waitingSnap = await db
      .collection("venues")
      .doc(venueId)
      .collection("waitlist")
      .where("status", "==", "waiting")
      .orderBy("joinedAt")
      .get();

    await Promise.all(
      waitingSnap.docs.map((doc, index) => {
        const position = index + 1;
        if (doc.data().queuePosition === position) return Promise.resolve();
        return doc.ref.update({ queuePosition: position });
      })
    );
  }
);

/**
 * A `called` entry the owner never followed up on (no "Gəldi"/"Gəlmədi")
 * within [WAITLIST_NO_SHOW_TIMEOUT_MS] auto-becomes `no_show` — without
 * this, a forgotten entry would sit "called" forever, silently blocking
 * nothing but looking like an open loop in the owner's Növbə view.
 */
export const expireStaleWaitlistCalls = onSchedule(
  { schedule: "every 5 minutes", region: "europe-west1" },
  async () => {
    const cutoff = Timestamp.fromMillis(Date.now() - WAITLIST_NO_SHOW_TIMEOUT_MS);
    const staleSnap = await db
      .collectionGroup("waitlist")
      .where("status", "==", "called")
      .where("calledAt", "<", cutoff)
      .get();

    await Promise.all(staleSnap.docs.map((doc) => doc.ref.update({ status: "no_show" })));
  }
);

// Düzəliş Prompt 8 / Y-3 — how old an Auth account can be, with no
// `users/{uid}` doc, before it counts as "abandoned" for this report.
// 48h is well past any real user's onboarding hesitation; a bot/probe
// account that never finishes `completeOnboarding` shows up immediately.
const ORPHAN_AUTH_ACCOUNT_AGE_MS = 48 * 60 * 60 * 1000;

/**
 * REPORT-ONLY, NEVER DELETES (Düzəliş Prompt 8 / Y-3 — deliberately
 * scoped down from a cleanup job to a visibility job; deletion needs a
 * separate, explicit decision, not an automated sweep). Lists every
 * Firebase Auth account older than [ORPHAN_AUTH_ACCOUNT_AGE_MS] with no
 * matching `users/{uid}` document — i.e. signed up (or was
 * auto-created, as in the 26 August probe) but never completed
 * `completeOnboarding` — and logs the count + full list (uid, email,
 * createdAt) so it's visible in Cloud Logging without needing a manual
 * script. Paginates through `auth.listUsers()` since the whole roster
 * doesn't fit one page once the project has more than 1000 users.
 */
export const reportOrphanAuthAccounts = onSchedule({ schedule: "every 24 hours", region: "us-central1" }, async () => {
  const cutoff = Date.now() - ORPHAN_AUTH_ACCOUNT_AGE_MS;
  const orphans: { uid: string; email: string | undefined; createdAt: string }[] = [];

  let pageToken: string | undefined;
  do {
    const page = await auth.listUsers(1000, pageToken);
    for (const user of page.users) {
      const createdAtMs = new Date(user.metadata.creationTime).getTime();
      if (createdAtMs > cutoff) continue;
      const userDoc = await db.collection("users").doc(user.uid).get();
      if (!userDoc.exists) {
        orphans.push({ uid: user.uid, email: user.email, createdAt: user.metadata.creationTime });
      }
    }
    pageToken = page.pageToken;
  } while (pageToken);

  logger.warn(`orphan-auth-accounts count=${orphans.length}`, { orphans });
});

/** 2h after a "Gəldi" (`seated`) mark — long enough to actually have had the visit, short enough the experience is still fresh. */
const REVIEW_PROMPT_DELAY_MS = 2 * 60 * 60 * 1000;

/**
 * Nudges a guest to review the venue 2 hours after their waitlist
 * entry was marked `seated` — `reviewPromptSentAt` (Admin-SDK-only,
 * `firestore.rules` never lets the client touch it) is stamped right
 * after so the same visit is never prompted twice. `notifyUser`'s
 * `title`/`body` are the actual push payload text (exact copy the
 * product spec requires); the in-app feed re-localizes the same
 * message per-locale from `type: reviewPrompt` + `params` instead
 * (see `notification_localizer.dart`), same split every other
 * notification type already uses.
 */
export const sendReviewPrompts = onSchedule({ schedule: "every 15 minutes", region: "europe-west1" }, async () => {
  const cutoff = Timestamp.fromMillis(Date.now() - REVIEW_PROMPT_DELAY_MS);
  const dueSnap = await db.collectionGroup("waitlist").where("status", "==", "seated").where("seatedAt", "<=", cutoff).get();

  await Promise.all(
    dueSnap.docs.map(async (doc) => {
      const data = doc.data();
      if (data.reviewPromptSentAt) return;

      const venueId = doc.ref.parent.parent?.id;
      const userId = data.userId as string | undefined;
      if (!venueId || !userId) return;

      const venueSnap = await db.collection("venues").doc(venueId).get();
      const venueName = (venueSnap.data()?.name as string | undefined) ?? "";
      if (!venueSnap.exists) return;

      await notifyUser({
        uid: userId,
        category: "venueUpdates",
        type: "reviewPrompt",
        title: venueName,
        body: `Siz ${venueName}-nin qonağı olmusunuz, bu barədə təəssüratlarınızı yazın, digər müştərilər faydalansın.`,
        params: { venueId, venueName, waitlistEntryId: doc.id },
        targetId: venueId,
        targetType: "venue",
      });

      await doc.ref.update({ reviewPromptSentAt: FieldValue.serverTimestamp() });
    })
  );
});

/**
 * Force-disables `Venue.waitlistEnabled` the moment an owner edits a
 * venue's `category` into one no longer allowed to run a waitlist (see
 * `config/waitlistCategories.enabledCategories`, set via
 * `admin-panel/scripts/set-waitlist-categories.ts`) — the client-side
 * toggle in `VenueWaitlistScreen` already refuses to turn it back ON
 * for an ineligible category, but a category CHANGE while it's already
 * on needs this server-side sweep to turn it back off. Every currently
 * `waiting` entry's user gets a `waitlistDisabled` notification
 * recommending they contact the venue directly — their entry itself is
 * left as `waiting` (not auto-cancelled), since the owner can still
 * resolve it from their own Növbə screen, which stays reachable for a
 * venue with waitlist history regardless of category eligibility.
 */
export const disableWaitlistOnIneligibleCategory = onDocumentUpdated("venues/{venueId}", async (event) => {
  const before = event.data?.before.data();
  const after = event.data?.after.data();
  if (!before || !after) return;
  if (before.category === after.category) return;
  if (after.waitlistEnabled !== true) return;

  const configSnap = await db.collection("config").doc("waitlistCategories").get();
  const enabledCategories = (configSnap.data()?.enabledCategories as string[] | undefined) ?? [];
  if (enabledCategories.includes(after.category as string)) return;

  const venueId = event.params.venueId;
  await db.collection("venues").doc(venueId).update({ waitlistEnabled: false });

  const venueName = (after.name as string | undefined) ?? "";
  const waitingSnap = await db
    .collection("venues")
    .doc(venueId)
    .collection("waitlist")
    .where("status", "==", "waiting")
    .get();

  await Promise.all(
    waitingSnap.docs.map((doc) => {
      const userId = doc.data().userId as string | undefined;
      if (!userId) return Promise.resolve();
      return notifyUser({
        uid: userId,
        category: "account",
        type: "waitlistDisabled",
        title: "Növbə deaktiv edildi",
        body: venueName
          ? `${venueName} növbə funksiyasını söndürdü. Məkanla əlaqə saxlamağınızı tövsiyə edirik.`
          : "Növbə funksiyası söndürüldü. Məkanla əlaqə saxlamağınızı tövsiyə edirik.",
        params: { venueName },
        targetId: venueId,
        targetType: "venue",
      });
    })
  );
});

/**
 * Links the waitlist and the seat counter: the moment an owner marks
 * an entry "Gəldi" (`status` → `seated`), this decrements
 * `Venue.availableSeats` by that entry's `partySize` — the owner
 * otherwise has no way to keep the count honest without doing the
 * subtraction themselves for every party seated from the queue. Only
 * ever fires on the exact `called`→`seated` transition (guarded
 * explicitly, on top of `onUpdate`'s own "only real changes" behavior,
 * per the spec's own defense-in-depth ask), and no-ops entirely when
 * `availableSeats` is null — a venue that never turned the counter on
 * has nothing for this to touch. Clamped at 0, never negative, same
 * "can't go below empty" reasoning as the manual stepper's own 0 floor.
 * The count only ever goes back UP by the owner's own "+" tap — this
 * function can't know when a physical table actually frees up.
 */
export const decrementSeatsOnWaitlistSeated = onDocumentUpdated(
  "venues/{venueId}/waitlist/{entryId}",
  async (event) => {
    const before = event.data?.before.data();
    const after = event.data?.after.data();
    if (!before || !after) return;
    if (before.status === "seated" || after.status !== "seated") return;

    const venueId = event.params.venueId;
    const venueRef = db.collection("venues").doc(venueId);
    const venueSnap = await venueRef.get();
    const currentSeats = venueSnap.data()?.availableSeats as number | undefined;
    if (currentSeats === undefined || currentSeats === null) return;

    const partySize = (after.partySize as number | undefined) ?? 0;
    const newSeats = Math.max(0, currentSeats - partySize);
    await venueRef.update({ availableSeats: newSeats, seatsUpdatedAt: FieldValue.serverTimestamp() });
  }
);

/**
 * Validates a birthday offer's targeting against the server's own
 * record of who actually has a birthday — or throws.
 *
 * `submitOffer` used to copy `targetUserIds` and `birthdayMatchId`
 * straight from the request onto the offer document, with no check at
 * all. `notifyBirthdayTargetUsers` then pushed to every uid in that
 * list. So any approved venue owner could send "🎉 Sənə xüsusi ad günü
 * təklifi!" to ANY set of users, on any day, whether or not it was
 * their birthday — a targeted push primitive dressed as a feature.
 * `updateOffer` never touched these fields and `firestore.rules` locks
 * both on update, so `submitOffer` was the only way in and is the only
 * place this check is needed.
 *
 * `birthdayMatches` is the source of truth: `computeBirthdayMatches`
 * writes it with the Admin SDK and its rule is `allow write: if false`,
 * so a client cannot manufacture a match to point at.
 *
 * Returns `null` for an ordinary offer, so the caller can treat "not a
 * birthday offer" and "a valid birthday offer" without a second flag.
 */
async function assertBirthdayTargeting(
  data: Record<string, unknown>,
  venueId: string,
): Promise<{ matchId: string; userIds: string[] } | null> {
  const matchId = data.birthdayMatchId as string | undefined;
  const requested = (data.targetUserIds as string[] | undefined) ?? [];

  if (!matchId && requested.length === 0) return null;
  // Neither half is meaningful alone: a match with nobody selected
  // sends nothing, and a uid list with no match is exactly the
  // unvalidated shape this function exists to reject.
  if (!matchId || requested.length === 0) {
    rejectRequest("invalid-argument", "offer.birthday-targeting-incomplete",
      "Ad günü təklifi üçün həm eşleşmə, həm hədəf siyahısı tələb olunur.",
      { hasMatchId: Boolean(matchId), targetCount: requested.length });
  }

  const matchSnap = await db.collection("birthdayMatches").doc(matchId).get();
  if (!matchSnap.exists) {
    rejectRequest("invalid-argument", "offer.birthday-match-not-found",
      "Ad günü eşleşməsi tapılmadı.", { matchId });
  }
  const match = matchSnap.data()!;

  // The match must be TODAY's.
  //
  // `computeBirthdayMatches` stamps each match with the Baku date it
  // was computed for, and `birthdayMatches` documents linger for
  // [BIRTHDAY_MATCH_RETENTION_DAYS]. Without this check an owner could
  // submit last week's `birthdayMatchId` on any later day and reach
  // that day's birthday users — people whose birthday is long past —
  // which is the same targeted-push primitive `assertBirthdayTargeting`
  // exists to close, just displaced in time rather than in identity.
  const todayKey = bakuDateKey(new Date());
  if (match.date !== todayKey) {
    rejectRequest("failed-precondition", "offer.birthday-match-expired",
      "Bu ad günü eşleşməsi bugünkü deyil.", { matchId, matchDate: match.date, todayKey });
  }

  // The match belongs to ONE venue. Without this an owner could quote
  // another venue's match id and inherit its recipient list.
  if (match.venueId !== venueId) {
    rejectRequest("permission-denied", "offer.birthday-match-foreign-venue",
      "Bu ad günü eşleşməsi başqa məkana aiddir.", { matchId, venueId });
  }

  const matched = new Set((match.matchedUserIds as string[] | undefined) ?? []);
  const outside = requested.filter((uid) => !matched.has(uid));
  if (outside.length > 0) {
    rejectRequest("permission-denied", "offer.birthday-target-outside-match",
      "Hədəf siyahısı ad günü eşleşməsindən kənar istifadəçi ehtiva edir.",
      { matchId, outsideCount: outside.length });
  }

  // De-duplicated: a repeated uid would otherwise mean a repeated push.
  return { matchId, userIds: [...new Set(requested)] };
}

/**
 * ── PUBLISHING A DAY'S BIRTHDAY CAMPAIGNS ─────────────────────────
 *
 * `notifyBirthdayTargetUsers` used to live here. It ran the moment a
 * birthday offer was APPROVED and did two things: wrote each
 * recipient's `users/{uid}/birthdayOffers/{offerId}` marker — which is
 * what every client-side filter reads to decide whether the offer is
 * visible at all — and sent that recipient a push.
 *
 * Both were wrong for this flow, and the marker more so than the push.
 * Publication is a single moment:
 *
 *   11:00  computeBirthdayMatches tells owners
 *   11:00–13:00  the MODERATION WINDOW: the owner writes a campaign,
 *                a moderator approves it. Approval publishes NOTHING.
 *   13:00  publishBirthdayCampaigns — every campaign approved in that
 *          window appears at once, in the Canlı tab and the ticker,
 *          and each birthday user gets exactly ONE push.
 *
 * Writing the marker at approval time meant a campaign approved at
 * 12:10 became visible at 12:10 — the publication leaking out ahead of
 * the notification announcing it, in dribs and drabs, one venue at a
 * time. Dropping only the push would not have fixed that.
 *
 * So approval no longer publishes; this does. It is shared by the
 * 13:00 schedule and by the late path in `onOfferUpdated`, because
 * "publish these campaigns to these people" is one operation whether
 * it is forty campaigns or one.
 */
interface BirthdayPublishOffer {
  offerId: string;
  venueId: string;
  venueName: string;
  category: string;
  /** The validated recipients, from `offers/{id}/private/targeting`. */
  userIds: string[];
}

/** What the ranking needs to know about one venue, measured once per
 * run rather than once per recipient. */
interface BirthdayVenueMetrics {
  category: string;
  lat?: number;
  lng?: number;
  country?: string;
  liveContentTypes: number;
  activeCampaigns: number;
  boosted: boolean;
}

/**
 * The four ranking inputs for every venue publishing today.
 *
 * Measured PER VENUE, not per recipient: the venue's content is the
 * same whoever is looking at it, and only the distance term varies by
 * user. Doing it the other way round would multiply these queries by
 * the number of birthday users for no additional information.
 *
 * `activeCampaigns` counts ALL the venue's live approved offers, not
 * its birthday ones — see `scoreVenue`'s doc comment for why counting
 * birthday campaigns would make that 20% weight a constant.
 */
async function loadBirthdayVenueMetrics(venueIds: string[]): Promise<Map<string, BirthdayVenueMetrics>> {
  const metrics = new Map<string, BirthdayVenueMetrics>();
  if (venueIds.length === 0) return metrics;

  const now = Timestamp.now();

  for (let i = 0; i < venueIds.length; i += 30) {
    const chunk = venueIds.slice(i, i + 30);
    // `where in` caps at 30 values — same chunking as
    // `anonymizeUserVenueEvents`.
    const [venuesSnap, offersSnap, eventsSnap, pinboxesSnap] = await Promise.all([
      db.collection("venues").where(FieldPath.documentId(), "in", chunk).get(),
      db.collection("offers").where("venueId", "in", chunk).where("status", "==", "approved").get(),
      db.collection("venueEvents").where("venueId", "in", chunk).get(),
      db.collection("pinboxes").where("venueId", "in", chunk).where("status", "==", "active").get(),
    ]);

    for (const venueDoc of venuesSnap.docs) {
      const v = venueDoc.data();
      metrics.set(venueDoc.id, {
        category: (v.category as string | undefined) ?? "",
        lat: v.lat as number | undefined,
        lng: v.lng as number | undefined,
        country: v.country as string | undefined,
        liveContentTypes: 0,
        activeCampaigns: 0,
        boosted: false,
      });
    }

    for (const offerDoc of offersSnap.docs) {
      const o = offerDoc.data();
      const m = metrics.get(o.venueId as string);
      if (!m) continue;
      // `status: approved` alone is not "live" — an offer whose window
      // has closed keeps that status forever.
      const endDate = o.endDate as Timestamp | undefined;
      if (endDate && endDate.toMillis() < now.toMillis()) continue;
      m.activeCampaigns += 1;
      const boostedUntil = o.boostedUntil as Timestamp | undefined;
      if (boostedUntil && boostedUntil.toMillis() > now.toMillis()) m.boosted = true;
    }

    const venuesWithEvent = new Set<string>();
    for (const eventDoc of eventsSnap.docs) {
      const e = eventDoc.data();
      // `ended`/`cancelled` are not something anyone can go to tonight.
      if (e.status !== "upcoming" && e.status !== "live") continue;
      venuesWithEvent.add(e.venueId as string);
    }
    const venuesWithPinbox = new Set(pinboxesSnap.docs.map((d) => d.data().venueId as string));

    // Distinct content KINDS, so each of the three contributes at most
    // once however many documents it has — this is the VARIETY signal,
    // deliberately separate from `activeCampaigns`' volume. See
    // `scoreVenue`.
    for (const venueId of chunk) {
      const m = metrics.get(venueId);
      if (!m) continue;
      m.liveContentTypes =
        (m.activeCampaigns > 0 ? 1 : 0) +
        (venuesWithEvent.has(venueId) ? 1 : 0) +
        (venuesWithPinbox.has(venueId) ? 1 : 0);
    }
  }

  return metrics;
}

/**
 * Publishes [offers] to their recipients and notifies each recipient
 * ONCE.
 *
 * ── One birthday push per user per day ─────────────────────────────
 *
 * `users/{uid}/birthdayFeed/{dateKey}.notifiedAt` is the record that
 * a push already went out today. The 13:00 run sets it; the late path
 * checks it.
 *
 * That is what makes a late campaign safe to publish immediately. A
 * campaign approved at 16:00 still matters — the birthday is today and
 * the person can still go out this evening — and its placement fee was
 * already paid, so dropping it would charge an owner for a moderator's
 * delay. But a second push per straggling venue is precisely the
 * per-listing spam the digest work removed. So a late campaign becomes
 * VISIBLE at once and stays SILENT, unless nothing was published at
 * 13:00 at all, in which case it sends the push that never went.
 *
 * ── The opt-in is re-checked here, and stops the PUSH only ─────────
 *
 * `computeBirthdayMatches` filters on `birthdayOffersOptIn` at 11:00,
 * and that is a snapshot. Someone who switches the setting off at
 * 12:00 is still sitting in `matchedUserIds` and would otherwise be
 * pushed to at 13:00 — an opt-out that visibly fails on the one day it
 * is about. The flag is read again, per recipient, at publish time.
 *
 * What it does NOT do is hide the campaigns. The marker and the
 * `birthdayFeed` document are written either way, so someone who opens
 * the app themselves still finds "Ad günü fürsətləri" waiting.
 * Switching the setting off says "do not interrupt me", not "keep this
 * from me" — the same reading `pushEnabled` already gets, where the
 * push stops and the in-app content stays. Suppressing the content too
 * would mean a user who went looking found nothing, with no way to
 * tell that their own setting was the reason.
 *
 * `notifiedAt` is therefore only stamped when a push actually goes
 * out, and it means exactly that. An opted-out user's feed carries no
 * `notifiedAt`, which is correct: nothing was sent.
 */
async function publishBirthdayOffers(offers: BirthdayPublishOffer[], todayKey: string): Promise<void> {
  if (offers.length === 0) return;

  const offersByUser = new Map<string, BirthdayPublishOffer[]>();
  for (const offer of offers) {
    for (const uid of offer.userIds) {
      const list = offersByUser.get(uid) ?? [];
      list.push(offer);
      offersByUser.set(uid, list);
    }
  }
  if (offersByUser.size === 0) return;

  const metrics = await loadBirthdayVenueMetrics([...new Set(offers.map((o) => o.venueId))]);

  for (const [uid, userOffers] of offersByUser) {
    const [userSnap, privateSnap, feedSnap] = await Promise.all([
      db.collection("users").doc(uid).get(),
      privateDataRef(uid).get(),
      db.collection("users").doc(uid).collection("birthdayFeed").doc(todayKey).get(),
    ]);
    if (!userSnap.exists) continue;

    const user = userSnap.data() ?? {};
    if (user.banned === true) continue;
    // Re-read, not trusted from 11:00 — and it gates the push alone,
    // not the content. See this function's doc comment.
    const optedIn = user.birthdayOffersOptIn === true;

    const priv = privateSnap.data() ?? {};
    const recipient = {
      lat: priv.lat as number | undefined,
      lng: priv.lng as number | undefined,
      country: user.country as string | undefined,
      discoverRadiusMode: priv.discoverRadiusMode as string | undefined,
      discoverRadiusKm: priv.discoverRadiusKm as number | undefined,
    };

    // The marker each client filter reads — written BEFORE the push so
    // the campaign is already visible when the notification lands.
    await Promise.all(
      userOffers.map((offer) =>
        db
          .collection("users")
          .doc(uid)
          .collection("birthdayOffers")
          .doc(offer.offerId)
          .set({ offerId: offer.offerId, venueName: offer.venueName, createdAt: FieldValue.serverTimestamp() }),
      ),
    );

    const candidates: BirthdayVenueCandidate[] = [];
    const nameByVenueId = new Map<string, string>();
    for (const offer of userOffers) {
      const m = metrics.get(offer.venueId);
      if (!m) continue;
      nameByVenueId.set(offer.venueId, offer.venueName);
      candidates.push({
        venueId: offer.venueId,
        category: m.category || offer.category,
        distanceMeters:
          typeof recipient.lat === "number" && typeof recipient.lng === "number" &&
          typeof m.lat === "number" && typeof m.lng === "number"
            ? haversineMeters(recipient.lat, recipient.lng, m.lat, m.lng)
            : 0,
        reachMeters:
          recipient.discoverRadiusMode === "distance" && typeof recipient.discoverRadiusKm === "number"
            ? recipient.discoverRadiusKm * 1000
            : undefined,
        liveContentTypes: m.liveContentTypes,
        activeCampaigns: m.activeCampaigns,
        boosted: m.boosted,
      });
    }
    if (candidates.length === 0) continue;

    // A late publish merges into whatever 13:00 already wrote, rather
    // than replacing it — the earlier venues do not disappear from the
    // list because a straggler arrived.
    const existing = feedSnap.data();
    const alreadyListed = (existing?.venueIds as string[] | undefined) ?? [];
    const ranked = rankCandidates(candidates);
    const rankedIds = ranked.map((r) => r.venueId);
    const venueIds = [...new Set([...alreadyListed, ...rankedIds])].slice(0, BIRTHDAY_FEED_MAX);

    const highlights = pickDistinctCategoryVenues(ranked, BIRTHDAY_HIGHLIGHT_COUNT);
    const alreadyNotified = existing?.notifiedAt !== undefined && existing?.notifiedAt !== null;
    const shouldNotify = optedIn && !alreadyNotified;

    await db
      .collection("users")
      .doc(uid)
      .collection("birthdayFeed")
      .doc(todayKey)
      .set(
        {
          date: todayKey,
          // Written whatever the opt-in says — this is the content, and
          // the content is not what the setting turns off.
          venueIds,
          // `highlightVenueIds` is the record of which venues the push
          // NAMED, so it is written only when a push is actually sent.
          ...(shouldNotify
            ? { highlightVenueIds: highlights.map((h) => h.venueId), notifiedAt: FieldValue.serverTimestamp() }
            : {}),
          updatedAt: FieldValue.serverTimestamp(),
          // Same TTL reasoning as `birthdayMatches` — a day's feed is
          // meaningless tomorrow, and nothing should have to sweep it.
          expiresAt: Timestamp.fromMillis(Date.now() + BIRTHDAY_MATCH_RETENTION_DAYS * 24 * 60 * 60 * 1000),
        },
        { merge: true },
      );

    if (!shouldNotify) continue;

    const names = highlights.map((h) => nameByVenueId.get(h.venueId) ?? "").filter((n) => n !== "");
    await notifyUser({
      uid,
      category: "venueOffers",
      type: "birthdayVenues",
      title: "🎂 Ad günün mübarək!",
      body: birthdayDigestBody(names),
      params: { count: venueIds.length, venueNames: names },
      // The list, not one venue — the whole point of the 13:00 moment
      // is that several campaigns arrive together.
      targetId: todayKey,
      targetType: "birthday_feed",
    });
  }
}

/** "A, B və C bu gün sənə xüsusi kampaniya təklif edir." — degrades to
 * one or two names, and to a countless phrasing when a venue somehow
 * has no name at all. */
function birthdayDigestBody(names: string[]): string {
  if (names.length === 0) return "Yaxınlığındakı məkanlar bu gün sənə xüsusi kampaniya hazırlayıb!";
  if (names.length === 1) return `${names[0]} bu gün sənə xüsusi kampaniya təklif edir!`;
  const last = names[names.length - 1];
  return `${names.slice(0, -1).join(", ")} və ${last} bu gün sənə xüsusi kampaniya təklif edir!`;
}

/**
 * Reads today's approved birthday campaigns, from the day's matches.
 *
 * Goes through `birthdayMatches` rather than querying `offers` by date:
 * `birthdayMatchId` is what ties a campaign to a specific day AND to a
 * specific venue, it is validated on submit (`assertBirthdayTargeting`)
 * and locked against update in `firestore.rules`. A `createdAt`-based
 * query would also catch a campaign built against a stale match.
 */
async function loadTodaysApprovedBirthdayOffers(todayKey: string): Promise<BirthdayPublishOffer[]> {
  const matchesSnap = await db.collection("birthdayMatches").where("date", "==", todayKey).get();
  if (matchesSnap.empty) return [];
  const matchIds = matchesSnap.docs.map((d) => d.id);

  const offers: BirthdayPublishOffer[] = [];
  for (let i = 0; i < matchIds.length; i += 30) {
    const chunk = matchIds.slice(i, i + 30);
    const snap = await db
      .collection("offers")
      .where("birthdayMatchId", "in", chunk)
      .where("status", "==", "approved")
      .get();
    for (const doc of snap.docs) {
      const offer = await toBirthdayPublishOffer(doc.id, doc.data());
      if (offer) offers.push(offer);
    }
  }
  return offers;
}

/** The recipients ride in `offers/{id}/private/targeting`, never on the
 * offer document — see `assertBirthdayTargeting`. An offer whose
 * targeting is missing publishes to nobody rather than to everybody. */
async function toBirthdayPublishOffer(
  offerId: string,
  data: FirebaseFirestore.DocumentData,
): Promise<BirthdayPublishOffer | null> {
  const targetingSnap = await db.collection("offers").doc(offerId).collection("private").doc("targeting").get();
  const userIds = (targetingSnap.data()?.userIds as string[] | undefined) ?? [];
  if (userIds.length === 0) return null;
  return {
    offerId,
    venueId: data.venueId as string,
    venueName: (data.venueName as string | undefined) ?? "",
    category: (data.category as string | undefined) ?? "",
    userIds,
  };
}

/**
 * 13:00 Asia/Baku — the day's single publication moment.
 *
 * Everything approved during the 11:00–13:00 moderation window goes
 * live here, together: the campaigns become visible in the Canlı tab
 * and the ticker, and each birthday user gets one notification naming
 * up to three of them.
 *
 * Sends NOTHING when no owner acted. Zero campaigns means no push, no
 * `birthdayFeed` document, and therefore no empty "Ad günü fürsətləri"
 * section in the client — a birthday greeting attached to nothing at
 * all is worse than silence.
 */
export const publishBirthdayCampaigns = onSchedule(
  { schedule: `0 ${BIRTHDAY_PUBLISH_HOUR} * * *`, timeZone: "Asia/Baku", region: "europe-west1" },
  async () => {
    const todayKey = bakuDateKey(new Date());
    const offers = await loadTodaysApprovedBirthdayOffers(todayKey);
    if (offers.length === 0) return;
    await publishBirthdayOffers(offers, todayKey);
    logger.info("publishBirthdayCampaigns", { todayKey, offerCount: offers.length });
  },
);

/**
 * A birthday campaign approved AFTER the 13:00 publication.
 *
 * Publishes it on its own, or does nothing if the scheduled run has
 * not happened yet — in which case `publishBirthdayCampaigns` will
 * pick it up with everything else in a few minutes' time, which is the
 * outcome the whole design wants.
 *
 * "Is it past 13:00" is asked in Baku, not in the runtime's UTC:
 * `onSchedule`'s `timeZone` controls when Cloud Scheduler fires, not
 * what `new Date()` reports inside a running function. Comparing
 * `getHours()` here would put the cutoff at 09:00 local, four hours
 * early, and silently publish the day's campaigns one by one — the
 * exact failure this branch exists to avoid. Same reasoning as
 * `computeBirthdayMatches`' `todayKey`; see `./birthday`.
 */
async function publishLateBirthdayOfferIfNeeded(
  offerId: string,
  data: FirebaseFirestore.DocumentData,
): Promise<void> {
  const now = new Date();
  const todayKey = bakuDateKey(now);

  // The match's own date, not today's — an approval that somehow lands
  // the next morning belongs to a birthday that is over, and must not
  // reach yesterday's recipients.
  const matchId = data.birthdayMatchId as string | undefined;
  if (!matchId || !matchId.startsWith(`${todayKey}_`)) return;

  if (bakuHour(now) < BIRTHDAY_PUBLISH_HOUR) return;

  const offer = await toBirthdayPublishOffer(offerId, data);
  if (!offer) return;
  await publishBirthdayOffers([offer], todayKey);
  logger.info("publishLateBirthdayOffer", { offerId, todayKey });
}

/**
 * 12:30 Asia/Baku — the moderators' half-hour warning.
 *
 * The whole flow hangs on a birthday campaign being approved before
 * 13:00, and until this existed nothing actively said so: the offers
 * queue is sorted by `createdAt` and a birthday campaign looked like
 * any other pending row. The admin panel now marks them (see
 * `listOffers`/`offers-table.tsx`), but a badge only works on someone
 * already looking at the page. This is the part that reaches an admin
 * who is not.
 *
 * Writes nothing when the queue is clear.
 */
export const remindAdminsOfPendingBirthdayCampaigns = onSchedule(
  { schedule: `30 ${BIRTHDAY_PUBLISH_HOUR - 1} * * *`, timeZone: "Asia/Baku", region: "europe-west1" },
  async () => {
    const todayKey = bakuDateKey(new Date());
    const matchesSnap = await db.collection("birthdayMatches").where("date", "==", todayKey).get();
    if (matchesSnap.empty) return;
    const matchIds = matchesSnap.docs.map((d) => d.id);

    let pending = 0;
    for (let i = 0; i < matchIds.length; i += 30) {
      const chunk = matchIds.slice(i, i + 30);
      const snap = await db
        .collection("offers")
        .where("birthdayMatchId", "in", chunk)
        .where("status", "==", "pending")
        .count()
        .get();
      pending += snap.data().count;
    }
    if (pending === 0) return;

    await notifyAdmins({
      type: "birthdayCampaignsPending",
      message: `${pending} ad günü kampaniyası təsdiq gözləyir — ${BIRTHDAY_PUBLISH_HOUR}:00-a 30 dəqiqə qalıb.`,
      targetType: "offers",
      targetId: todayKey,
    });
  },
);

/**
 * ONE INTENT PER LISTING — the replacement for three fan-out
 * functions.
 *
 * `notifyNearbyUsersOfNewOffer`, `...NewPinBox` and `...NewEvent` used
 * to live here. Each one, at the moment a listing went live, scanned up
 * to 1000 `users`, merged every candidate's `private/data`, and read a
 * per-user throttle document — about 3000 reads for ONE listing — then
 * sent one push per matching user. The offer/PinBox paths throttled per
 * VENUE for 24 hours, so fifty venues meant fifty pushes; the event path
 * had only a per-event dedup, so one venue posting twenty events sent
 * twenty. At fifty thousand venues that is roughly 150 million reads a
 * day and, for the person holding the phone, a reason to uninstall.
 *
 * Now the trigger writes a single document and returns. Once a day
 * `sendDailyOpportunityDigest` reads the day's intents ONCE, reads the
 * opted-in users ONCE, and sends at most three notifications each —
 * "5 yeni kampaniya" and "47 yeni kampaniya" cost exactly the same one
 * push. Cost drops from `O(listings x users)` continuously to
 * `O(listings) + O(users)` once a day.
 *
 * The counting rules (radius, owner exclusion, per-type cap) live in
 * `./digest` so they can be tested without an emulator; this function
 * only writes the raw fact that something was published.
 *
 * `expiresAt` drives a native Firestore TTL policy on this collection —
 * see [INTENT_RETENTION_DAYS] for why three days and why nothing here
 * sweeps.
 */
async function recordListingIntent(
  type: IntentType,
  listingId: string,
  venueId: string,
  ownerId: string,
  venue: FirebaseFirestore.DocumentData,
): Promise<void> {
  const lat = venue.lat as number | undefined;
  const lng = venue.lng as number | undefined;
  // A venue with no position cannot be matched against anyone's radius,
  // so recording the intent would only create a document the digest
  // must skip. Not an error — `submitVenue` requires coordinates, so
  // this is a guard against legacy documents, not a live case.
  if (typeof lat !== "number" || typeof lng !== "number") return;

  await db.collection("notificationIntents").doc(`${type}_${listingId}`).set({
    type,
    listingId,
    venueId,
    ownerId,
    lat,
    lng,
    ...(venue.country ? { country: venue.country } : {}),
    createdAt: FieldValue.serverTimestamp(),
    expiresAt: Timestamp.fromMillis(Date.now() + INTENT_RETENTION_DAYS * 24 * 60 * 60 * 1000),
  });
}


/**
 * `ghostModeEnabled`/`discoverRadiusMode`/`discoverRadiusKm`/`lat`/`lng`
 * moved to `users/{uid}/private/data` (Düzəliş Prompt 4) — merges each
 * candidate's private doc on top of its public doc so
 * `isWithinRecipientDiscoverRadius` and callers' own `ghostModeEnabled`
 * check keep seeing the fields they always have.
 */
/** A user's public document merged with their own `private/data`. Was
 * declared alongside the fan-out functions this replaced; kept here
 * with `withPrivateData`, its only producer. */
interface NotifyCandidate {
  id: string;
  data: FirebaseFirestore.DocumentData;
}

async function withPrivateData(
  docs: FirebaseFirestore.DocumentSnapshot[],
): Promise<NotifyCandidate[]> {
  const existing = docs.filter((d) => d.exists);
  const privateSnaps = await Promise.all(existing.map((d) => privateDataRef(d.id).get()));
  return existing.map((d, i) => ({
    id: d.id,
    data: { ...(d.data() ?? {}), ...(privateSnaps[i].data() ?? {}) },
  }));
}


/**
 * Drives `VenueEvent.status`'s fully automatic `upcoming` → `live` →
 * `ended` lifecycle off [VenueEvent.startAt]/[endAt] — the owner never
 * sets these directly (see the entity's doc comment).
 *
 * Was "every 15 minutes" — too coarse: a short event (its own
 * `endAt` less than 15 minutes after `startAt`) could satisfy BOTH
 * the upcoming->live and live->ended queries in the SAME run (the
 * second query runs right after the first commits), skipping
 * straight from `upcoming` to `ended` with no client ever observing
 * `live` in between. 1-minute cadence keeps the two scans small (this
 * app's event volume is nowhere near a scale where that matters) and
 * bounds the skip-through window to events shorter than a minute.
 */
/**
 * A new event records an intent, exactly like offers and PinBoxes.
 *
 * Unlike those two an event has no approval step to wait for — it is
 * live the moment it is created — so this fires on create rather than
 * on a status transition.
 */
export const onVenueEventCreated = onDocumentCreated("venueEvents/{eventId}", async (event) => {
  const data = event.data?.data();
  if (!data) return;
  const venueId = data.venueId as string | undefined;
  if (!venueId) return;
  const venueSnap = await db.collection("venues").doc(venueId).get();
  const venue = venueSnap.data();
  if (!venue) return;
  const ownerId = venue.ownerId as string | undefined;
  if (!ownerId) return;
  await recordListingIntent("event", event.params.eventId, venueId, ownerId, venue);
});

/**
 * The daily digest — at most three notifications per user, whatever
 * the venue count.
 *
 * 15:00 Asia/Baku: late enough that the day's listings exist, early
 * enough that someone can still act on "bitmədən al" tonight. Sending
 * in the morning would attach an evening decision to a work day.
 *
 * Reads the day's intents once and the opted-in users once, then does
 * the matching in memory — see `./digest` for the counting rules and
 * for why this shape replaced three per-listing fan-outs.
 *
 * Deliberately does NOT skip someone who already opened the app and
 * saw the content: "has seen it" and "does not want to be told" are
 * different statements, and inferring the second from the first
 * produces behaviour nobody can explain. Users who want silence have a
 * switch — `venueOffers`, which `notifyUser` enforces.
 */
export const sendDailyOpportunityDigest = onSchedule(
  { schedule: "0 15 * * *", timeZone: "Asia/Baku", region: "europe-west1" },
  async () => {
    const cutoff = Timestamp.fromMillis(Date.now() - DIGEST_LOOKBACK_MS);
    const intentsSnap = await db
      .collection("notificationIntents")
      .where("createdAt", ">=", cutoff)
      .get();
    if (intentsSnap.empty) return;

    const intents: DigestIntent[] = [];
    const countryByVenueId = new Map<string, string | undefined>();
    for (const doc of intentsSnap.docs) {
      const d = doc.data();
      const type = d.type as IntentType | undefined;
      if (type !== "offer" && type !== "pinbox" && type !== "event") continue;
      if (typeof d.lat !== "number" || typeof d.lng !== "number") continue;
      intents.push({
        type,
        venueId: d.venueId as string,
        ownerId: (d.ownerId as string | undefined) ?? "",
        lat: d.lat as number,
        lng: d.lng as number,
      });
      countryByVenueId.set(d.venueId as string, d.country as string | undefined);
    }
    if (intents.length === 0) return;

    // ONE pass over the audience, not one per listing. This is the
    // whole economy of the change: the read cost no longer multiplies
    // by how many venues published today.
    const usersSnap = await db.collection("users").get();
    const candidates = await withPrivateData(usersSnap.docs);

    for (const candidate of candidates) {
      // `notifyUser` applies the `venueOffers` switch itself, but
      // checking here too avoids building a digest for someone who has
      // already said no.
      const prefs = (candidate.data.notificationPreferences ?? {}) as Record<string, boolean>;
      if (prefs.venueOffers === false) continue;
      if (candidate.data.banned === true) continue;

      const counts = digestCountsFor(intents, {
        uid: candidate.id,
        lat: candidate.data.lat as number | undefined,
        lng: candidate.data.lng as number | undefined,
        country: candidate.data.country as string | undefined,
        discoverRadiusMode: candidate.data.discoverRadiusMode as string | undefined,
        discoverRadiusKm: candidate.data.discoverRadiusKm as number | undefined,
      }, countryByVenueId);

      for (const { type, count } of digestNotifications(counts)) {
        await notifyUser({
          uid: candidate.id,
          category: "venueOffers",
          type: DIGEST_NOTIFICATION_TYPE[type],
          title: DIGEST_TITLE[type],
          body: DIGEST_BODY[type](count),
          params: { count },
          // The Canlı tab is where all three kinds of content live —
          // one destination for all three digests, so the notification
          // lands where the user can act on any of them.
          targetType: "live_feed",
        });
      }
    }
  },
);

/** Notification `type` per digest kind — see `./notification-categories`. */
const DIGEST_NOTIFICATION_TYPE: Record<IntentType, string> = {
  offer: "dailyOffersDigest",
  pinbox: "dailyPinboxDigest",
  event: "dailyEventsDigest",
};

const DIGEST_TITLE: Record<IntentType, string> = {
  offer: "Yeni kampaniyalar",
  pinbox: "Yeni PinBox qutuları",
  event: "Yeni tədbirlər",
};

const DIGEST_BODY: Record<IntentType, (count: number) => string> = {
  offer: (n) => `Ətrafında ${n} yeni kampaniya səni gözləyir, seçim et və faydalan`,
  pinbox: (n) => `Ətrafında ${n} yeni məhdud sayda PinBox qutusu var, bitmədən al`,
  event: (n) => `Ətrafında ${n} tədbir var`,
};

export const advanceVenueEventStatuses = onSchedule(
  { schedule: "every 1 minutes", region: "europe-west1" },
  async () => {
    const now = Timestamp.now();

    const toLiveSnap = await db
      .collection("venueEvents")
      .where("status", "==", "upcoming")
      .where("startAt", "<=", now)
      .get();
    await Promise.all(toLiveSnap.docs.map((doc) => doc.ref.update({ status: "live" })));

    const toEndedSnap = await db
      .collection("venueEvents")
      .where("status", "==", "live")
      .where("endAt", "<=", now)
      .get();
    await Promise.all(toEndedSnap.docs.map((doc) => doc.ref.update({ status: "ended" })));
  }
);

/**
 * Shared copy for the venue/offer moderation-decision notification —
 * `kind`/`name` only change the wording, `status`/`reviewNote` decide
 * which message (or none, for the `pending` state itself — nothing
 * notifies when a listing first becomes pending, that's covered by
 * `onVenueCreated`'s "your venue was added" notification instead).
 */
function moderationStatusNotification(
  kind: "venue" | "offer" | "pinbox",
  name: string,
  status: unknown,
  reviewNote: unknown,
  // Only ever true for venue listings today (offers/pinboxes have no
  // payment concept tied to the LISTING itself — PinBox's revenue is
  // the per-order commission, not a flat fee, see `PinBox`'s own doc
  // comment) — appends the 7-day/refund-timeline wording that only
  // makes sense when a real `payments/{paymentId}` doc is attached.
  hasPayment = false,
): { type: string; title: string; body: string; params: Record<string, unknown> } | null {
  const noun = kind === "venue" ? "Məkanınız" : kind === "offer" ? "Təklifiniz" : "Qutunuz";
  const quoted = name ? `"${name}"` : noun;
  const note = typeof reviewNote === "string" && reviewNote.trim() ? reviewNote.trim() : undefined;
  // venue.name/offer.title are required fields — always non-empty by
  // the time a listing exists to be moderated, so the client-side
  // localizer templates always interpolate a real `{name}` and doesn't
  // need its own noun-fallback branch the way this function's own
  // `quoted` still defensively does for the push text above.
  const params: Record<string, unknown> = { name, hasPayment: hasPayment, ...(note ? { note } : {}) };

  switch (status) {
    case "approved":
      return {
        type: `${kind}Approved`,
        title: `${noun} təsdiqləndi`,
        body: `${quoted} təsdiqləndi və artıq hər kəsə görünür.`,
        params,
      };
    case "needs_revision": {
      const revisionSuffix = hasPayment
        ? " 7 gün ərzində düzəldib yenidən göndərin, əks halda ödənişiniz avtomatik geri qaytarılacaq."
        : "";
      return {
        type: `${kind}NeedsRevision`,
        title: `${noun} üzərində düzəliş tələb olunur`,
        body: (note ? `${quoted}: ${note}.` : `${quoted} üzərində düzəliş tələb olunur.`) + revisionSuffix,
        params,
      };
    }
    case "rejected": {
      const refundSuffix = hasPayment ? " Ödənişiniz 3-14 iş günü ərzində kartınıza qaytarılacaq." : "";
      return {
        type: `${kind}Rejected`,
        title: `${noun} rədd edildi`,
        body: (note ? `${quoted}: ${note}.` : `${quoted} rədd edildi.`) + refundSuffix,
        params,
      };
    }
    default:
      return null;
  }
}

/**
 * Undoes the "revision_pending" flag `setVenueStatus`/`setOfferStatus`
 * (admin panel) set when a listing was sent back for revision — shared
 * by `resubmitVenue`/`resubmitOffer` since resubmitting either never
 * charges again, it just returns the existing payment to its normal
 * "paid, awaiting review" state. No-ops for listings predating the
 * payment feature (no `paymentId`).
 */
/**
 * The venue's `audienceRadiusKm`, validated against the picker's own
 * option list — or an `invalid-argument` if it is anything else.
 *
 * Both writers (`submitVenue`, `updateVenue`) previously took this
 * field as `(data.audienceRadiusKm as number) ?? 1.0`: no type check,
 * no bounds, and — because a radius-only edit is the ONE venue change
 * deliberately exempt from re-entering moderation (see `updateVenue`'s
 * doc comment) — no human ever saw the result either. A caller hitting
 * the callable directly could set any number at all; the app's own
 * picker offers six fixed chips and can't express anything else.
 *
 * Absent is not an error: it means "unchanged"/"use the default", and
 * 1 km is a member of the allowlist. Present-but-not-in-the-list is an
 * error rather than a clamp — clamping 0.001 to 0.1 would honour a
 * request nobody could have made through the UI, and silence is how
 * this field got here.
 *
 * See [VENUE_AUDIENCE_RADIUS_OPTIONS_KM] (`./geo`) for the list, why
 * it is an allowlist rather than a range, and what has to happen if
 * the Remote Config radius list ever changes.
 */
function assertAllowedAudienceRadius(value: unknown): number {
  if (value === undefined || value === null) return 1.0;
  if (!isAllowedVenueAudienceRadiusKm(value)) {
    rejectRequest("invalid-argument", "venue.invalid-audience-radius",
      "Auditoriya radiusu üçün yalnız hazır seçimlərdən biri qəbul edilir.",
      { allowed: VENUE_AUDIENCE_RADIUS_OPTIONS_KM, received: value });
  }
  return value as number;
}

function revertRevisionPayment(tx: FirebaseFirestore.Transaction, paymentId: string | undefined): void {
  if (!paymentId) return;
  tx.update(db.collection("payments").doc(paymentId), {
    status: "completed",
    updatedAt: FieldValue.serverTimestamp(),
  });
}

/**
 * Venue field edits, moved server-side — replaces the old client-side
 * `FirebaseVenueRepository.updateVenue` direct Firestore write +
 * separately-called `resubmitVenue`, which had two problems: nothing
 * stopped a modified client from writing content directly (firestore
 * .rules only blocked grant-of-trust fields like `status`, not the
 * content fields themselves) while simply skipping the `resubmitVenue`
 * call, and a `resubmitVenue` failure after a successful field write
 * could leave an edited `approved` venue silently stuck live without
 * ever re-entering review. Same shape as `submitVenue`: the client
 * uploads a new photo to Storage first (if any) and passes the
 * resulting URL here as a plain string, same as `submitVenue` already
 * does — this function never receives a raw file.
 *
 * Re-review is diff-based, not blanket: `needsReReview` is true only
 * when the venue was already `needs_revision`/`approved` AND something
 * OTHER than `audienceRadiusMode`/`audienceRadiusKm` actually changed.
 * A radius-only edit (or a no-op resubmit of unchanged fields) applies
 * immediately and stays visible — the one deliberate exception to
 * "every edit of a live venue re-enters moderation", since the live
 * audience radius has no bearing on what a reviewer approved. Any
 * other changed field re-enters the venue into `pending` exactly like
 * `resubmitVenue` used to (same status/reviewNote/reviewedBy/
 * reviewedAt/revisionDeadline reset, same `revertRevisionPayment`
 * call) — just atomically, in the same transaction as the field write,
 * so the two can no longer drift apart.
 */
export const updateVenue = onCall(
  { region: "us-central1", enforceAppCheck: false },
  async (request) => {
    const uid = request.auth?.uid;
    if (!uid) throw new HttpsError("unauthenticated", "Bu əməliyyat üçün daxil olmalısınız.");
    await assertActiveUser(uid);

    const data = request.data as Record<string, unknown>;
    const venueId = data.venueId as string | undefined;
    const name = (data.name as string | undefined)?.trim();
    const category = data.category as string | undefined;
    const photoUrl = data.photoUrl as string | undefined; // only present if a new photo was uploaded
    if (photoUrl !== undefined) assertOwnStorageUrl(photoUrl, "photoUrl"); // P0 / H-5
    const lat = data.lat as number | undefined;
    const lng = data.lng as number | undefined;
    const address = (data.address as string | undefined)?.trim();
    const country = data.country as string | undefined;
    const openingHours = data.openingHours as Record<string, unknown> | undefined;
    const socialLinks = data.socialLinks as Record<string, unknown> | undefined;
    const audienceRadiusMode = (data.audienceRadiusMode as string | undefined) ?? "distance";
    const audienceRadiusKm = assertAllowedAudienceRadius(data.audienceRadiusKm);
    const birthdayNotificationsEnabled = (data.birthdayNotificationsEnabled as boolean | undefined) ?? false;

    if (!venueId || !name || !category || lat === undefined || lng === undefined || !address || !openingHours) {
      throw new HttpsError("invalid-argument", "Tələb olunan sahələr çatışmır.");
    }

    const ref = db.collection("venues").doc(venueId);
    const sentForReReview = await db.runTransaction(async (tx) => {
      const snap = await tx.get(ref);
      if (!snap.exists) throw new HttpsError("not-found", "Məkan tapılmadı.");
      const current = snap.data()!;
      if (current.ownerId !== uid) throw new HttpsError("permission-denied", "Bu məkanın sahibi deyilsiniz.");

      const currentSocialLinks = (current.socialLinks as Record<string, unknown> | undefined) ?? null;
      const contentChanged =
        current.name !== name ||
        current.category !== category ||
        (photoUrl !== undefined && current.photoUrl !== photoUrl) ||
        current.lat !== lat ||
        current.lng !== lng ||
        (current.address as string | undefined) !== address ||
        ((current.country as string | undefined) ?? null) !== (country ?? null) ||
        JSON.stringify(current.openingHours ?? {}) !== JSON.stringify(openingHours) ||
        JSON.stringify(currentSocialLinks) !== JSON.stringify(socialLinks ?? null) ||
        Boolean(current.birthdayNotificationsEnabled) !== birthdayNotificationsEnabled;

      const wasLive = current.status === "needs_revision" || current.status === "approved";
      const needsReReview = wasLive && contentChanged;

      tx.update(ref, {
        name,
        nameLower: name.toLowerCase(),
        category,
        lat,
        lng,
        position: { geopoint: new GeoPoint(lat, lng), geohash: geohashForLocation([lat, lng], 9) },
        address,
        country: country ?? null,
        openingHours,
        socialLinks: socialLinks ?? null,
        audienceRadiusMode,
        audienceRadiusKm,
        birthdayNotificationsEnabled,
        updatedAt: FieldValue.serverTimestamp(),
        ...(photoUrl !== undefined ? { photoUrl } : {}),
        ...(needsReReview
          ? { status: "pending", reviewNote: null, reviewedBy: null, reviewedAt: null, revisionDeadline: null }
          : {}),
      });

      if (needsReReview) {
        revertRevisionPayment(tx, current.paymentId as string | undefined);
      }

      return needsReReview;
    });

    return { sentForReReview };
  },
);

/**
 * Owner resubmits a venue after editing it — the only way `status` can
 * move back to `pending`, since firestore.rules blocks the owner from
 * writing `status` directly. Client flow: `updateVenue` (normal field
 * edit, owner-permitted) then this callable. Two distinct callers:
 *   - `needs_revision` → the existing "fix what the admin flagged and
 *     resubmit" flow.
 *   - `approved` → an owner editing an ALREADY-LIVE venue. Nothing about
 *     firestore.rules stops an owner from silently swapping in different
 *     (or inappropriate) photos/text on a venue that already cleared
 *     review, so every edit of a live venue re-enters the moderation
 *     queue exactly like a brand-new one — see `CreateVenueScreen
 *     ._submitEdit`'s call site.
 * Rejects anything else (`pending`/`rejected`) so a stray call can't
 * pull a listing still awaiting its first review, or a rejected one,
 * into 'pending' through this side door.
 *
 * No longer called from the venue edit flow (`updateVenue`, above,
 * folds this same status-flip logic in atomically, gated on an actual
 * content diff) — kept as a standalone callable in case a future admin
 * or support flow needs to force a resubmit without going through a
 * full field edit.
 */
export const resubmitVenue = onCall({ region: "us-central1", enforceAppCheck: false }, async (request) => {
  const uid = request.auth?.uid;
  if (!uid) throw new HttpsError("unauthenticated", "Bu əməliyyat üçün daxil olmalısınız.");
  await assertActiveUser(uid);

  const venueId = request.data?.venueId as string | undefined;
  if (!venueId) throw new HttpsError("invalid-argument", "venueId tələb olunur.");

  const ref = db.collection("venues").doc(venueId);
  await db.runTransaction(async (tx) => {
    const snap = await tx.get(ref);
    if (!snap.exists) throw new HttpsError("not-found", "Məkan tapılmadı.");
    const data = snap.data()!;
    if (data.ownerId !== uid) throw new HttpsError("permission-denied", "Bu məkanın sahibi deyilsiniz.");
    if (data.status !== "needs_revision" && data.status !== "approved") {
      throw new HttpsError("failed-precondition", "not-eligible");
    }

    tx.update(ref, {
      status: "pending",
      reviewNote: null,
      reviewedBy: null,
      reviewedAt: null,
      revisionDeadline: null,
      updatedAt: FieldValue.serverTimestamp(),
    });

    revertRevisionPayment(tx, data.paymentId as string | undefined);
  });

  return { ok: true };
});

/**
 * Düzəliş Prompt 6 / INFRA-5 — Offer equivalent of `updateVenue`, same
 * problem it fixed: the old flow (client writes content fields
 * directly via Firestore, then separately calls `resubmitOffer`) let a
 * modified client skip the second call and silently swap in different
 * content on an already-approved offer with no re-review at all —
 * `firestore.rules`' `offers/{offerId}` update rule never blocked the
 * content fields themselves, only the grant-of-trust ones. This folds
 * both into one atomic transaction, diff-gated exactly like
 * `updateVenue`: re-review only when the offer was already
 * `needs_revision`/`approved` AND a real content field actually
 * changed.
 */
export const updateOffer = onCall(
  { region: "us-central1", enforceAppCheck: false },
  async (request) => {
    const uid = request.auth?.uid;
    if (!uid) throw new HttpsError("unauthenticated", "Bu əməliyyat üçün daxil olmalısınız.");
    await assertActiveUser(uid);

    const data = request.data as Record<string, unknown>;
    const offerId = data.offerId as string | undefined;
    const category = data.category as string | undefined;
    const title = (data.title as string | undefined)?.trim();
    const description = (data.description as string | undefined)?.trim();
    const offerType = data.offerType as string | undefined;
    const discountValue = data.discountValue as number | undefined;
    const startDate = data.startDate as string | undefined;
    const endDate = data.endDate as string | undefined;
    const imageUrl = data.imageUrl as string | undefined; // only present if a new photo was uploaded
    if (imageUrl !== undefined) assertOwnStorageUrl(imageUrl, "imageUrl"); // P0 / H-5
    const terms = (data.terms as string | undefined)?.trim();
    const activeHours = data.activeHours as Record<string, unknown> | undefined;
    const activeDays = (data.activeDays as string[] | undefined) ?? [];

    if (!offerId || !category || !title || !description || !offerType || !startDate || !endDate) {
      throw new HttpsError("invalid-argument", "Tələb olunan sahələr çatışmır.");
    }

    const startTimestamp = Timestamp.fromDate(new Date(startDate));
    const endTimestamp = Timestamp.fromDate(new Date(endDate));

    const ref = db.collection("offers").doc(offerId);
    const sentForReReview = await db.runTransaction(async (tx) => {
      const snap = await tx.get(ref);
      if (!snap.exists) throw new HttpsError("not-found", "Təklif tapılmadı.");
      const current = snap.data()!;
      if (current.ownerId !== uid) throw new HttpsError("permission-denied", "Bu təklifin sahibi deyilsiniz.");

      const contentChanged =
        current.category !== category ||
        current.title !== title ||
        current.description !== description ||
        current.offerType !== offerType ||
        ((current.discountValue as number | undefined) ?? null) !== (discountValue ?? null) ||
        (current.startDate as Timestamp | undefined)?.toMillis() !== startTimestamp.toMillis() ||
        (current.endDate as Timestamp | undefined)?.toMillis() !== endTimestamp.toMillis() ||
        ((current.terms as string | undefined) ?? null) !== (terms ?? null) ||
        JSON.stringify(current.activeHours ?? null) !== JSON.stringify(activeHours ?? null) ||
        JSON.stringify(current.activeDays ?? []) !== JSON.stringify(activeDays) ||
        (imageUrl !== undefined && current.imageUrl !== imageUrl);

      const wasLive = current.status === "needs_revision" || current.status === "approved";
      const needsReReview = wasLive && contentChanged;

      tx.update(ref, {
        category,
        title,
        description,
        offerType,
        discountValue: discountValue ?? null,
        startDate: startTimestamp,
        endDate: endTimestamp,
        terms: terms ?? null,
        activeHours: activeHours ?? null,
        activeDays,
        updatedAt: FieldValue.serverTimestamp(),
        ...(imageUrl !== undefined ? { imageUrl } : {}),
        ...(needsReReview
          ? { status: "pending", reviewNote: null, reviewedBy: null, reviewedAt: null, revisionDeadline: null }
          : {}),
      });

      if (needsReReview) {
        revertRevisionPayment(tx, current.paymentId as string | undefined);
      }

      return needsReReview;
    });

    return { sentForReReview };
  },
);

/** Offer equivalent of `resubmitVenue` — same contract (`needs_revision`
 * OR `approved` → `pending`), same reasoning. Still called from
 * `deleteAccount`-adjacent flows or a future admin/support path; no
 * longer reachable from the normal offer-edit flow now that
 * `updateOffer` folds this same status-flip logic in atomically. */
export const resubmitOffer = onCall({ region: "us-central1", enforceAppCheck: false }, async (request) => {
  const uid = request.auth?.uid;
  if (!uid) throw new HttpsError("unauthenticated", "Bu əməliyyat üçün daxil olmalısınız.");
  await assertActiveUser(uid);

  const offerId = request.data?.offerId as string | undefined;
  if (!offerId) throw new HttpsError("invalid-argument", "offerId tələb olunur.");

  const ref = db.collection("offers").doc(offerId);
  await db.runTransaction(async (tx) => {
    const snap = await tx.get(ref);
    if (!snap.exists) throw new HttpsError("not-found", "Təklif tapılmadı.");
    const data = snap.data()!;
    if (data.ownerId !== uid) throw new HttpsError("permission-denied", "Bu təklifin sahibi deyilsiniz.");
    if (data.status !== "needs_revision" && data.status !== "approved") {
      throw new HttpsError("failed-precondition", "not-eligible");
    }

    tx.update(ref, {
      status: "pending",
      reviewNote: null,
      reviewedBy: null,
      reviewedAt: null,
      revisionDeadline: null,
      updatedAt: FieldValue.serverTimestamp(),
    });
    revertRevisionPayment(tx, data.paymentId as string | undefined);
  });

  return { ok: true };
});

/**
 * Düzəliş Prompt 6 / INFRA-5 — PinBox equivalent of `updateVenue`/
 * `updateOffer`, same fix: content fields were never blocked in
 * `firestore.rules`' `pinboxes/{pinboxId}` update rule, so a modified
 * client could silently swap in different content on a live PinBox
 * without ever calling `resubmitPinBox`. Folds both into one atomic
 * transaction. `active` (PinBox's "live" status — there is no
 * `approved`) or `needs_revision` re-enters moderation on an actual
 * content change, mirroring `resubmitPinBox`'s own eligibility check.
 * No `paymentId` field exists on PinBox (no flat listing fee — see
 * `PinBox`'s own doc comment), so there's nothing equivalent to
 * `revertRevisionPayment` to call here.
 */
export const updatePinBox = onCall(
  { region: "us-central1", enforceAppCheck: false },
  async (request) => {
    const uid = request.auth?.uid;
    if (!uid) throw new HttpsError("unauthenticated", "Bu əməliyyat üçün daxil olmalısınız.");
    await assertActiveUser(uid);

    const data = request.data as Record<string, unknown>;
    const pinboxId = data.pinboxId as string | undefined;
    const title = (data.title as string | undefined)?.trim();
    const description = (data.description as string | undefined)?.trim();
    const originalPrice = data.originalPrice as number | undefined;
    const pinboxPrice = data.pinboxPrice as number | undefined;
    const pickupWindowStart = data.pickupWindowStart as string | undefined;
    const pickupWindowEnd = data.pickupWindowEnd as string | undefined;
    const imageUrl = data.imageUrl as string | undefined; // only present if a new photo was uploaded
    if (imageUrl !== undefined) assertOwnStorageUrl(imageUrl, "imageUrl"); // P0 / H-5

    if (
      !pinboxId || !title || !description || originalPrice === undefined ||
      pinboxPrice === undefined || !pickupWindowStart || !pickupWindowEnd
    ) {
      throw new HttpsError("invalid-argument", "Tələb olunan sahələr çatışmır.");
    }

    const startTimestamp = Timestamp.fromDate(new Date(pickupWindowStart));
    const endTimestamp = Timestamp.fromDate(new Date(pickupWindowEnd));

    const ref = db.collection("pinboxes").doc(pinboxId);
    const sentForReReview = await db.runTransaction(async (tx) => {
      const snap = await tx.get(ref);
      if (!snap.exists) throw new HttpsError("not-found", "PinBox tapılmadı.");
      const current = snap.data()!;
      if (current.ownerId !== uid) throw new HttpsError("permission-denied", "Bu qutunun sahibi deyilsiniz.");

      // Category allowlist, checked on every re-publish and not only at
      // creation: both this and `resubmitPinBox` push the box back
      // through moderation and back into discovery, so a venue whose
      // category changed to an ineligible one must not be able to
      // relist through an edit. One venue read on an infrequent owner
      // action — see `./venue-categories`.
      const venueSnap = await tx.get(db.collection("venues").doc(current.venueId as string));
      if (!isPinBoxCategory(venueSnap.data()?.category)) {
        throw new HttpsError("failed-precondition", "Bu məkan kateqoriyası PinBox funksiyasını dəstəkləmir.");
      }

      const contentChanged =
        current.title !== title ||
        current.description !== description ||
        (current.originalPrice as number | undefined) !== originalPrice ||
        (current.pinboxPrice as number | undefined) !== pinboxPrice ||
        (current.pickupWindowStart as Timestamp | undefined)?.toMillis() !== startTimestamp.toMillis() ||
        (current.pickupWindowEnd as Timestamp | undefined)?.toMillis() !== endTimestamp.toMillis() ||
        (imageUrl !== undefined && current.imageUrl !== imageUrl);

      const wasLive = current.status === "needs_revision" || current.status === "active";
      const needsReReview = wasLive && contentChanged;

      tx.update(ref, {
        title,
        description,
        originalPrice,
        pinboxPrice,
        pickupWindowStart: startTimestamp,
        pickupWindowEnd: endTimestamp,
        updatedAt: FieldValue.serverTimestamp(),
        ...(imageUrl !== undefined ? { imageUrl } : {}),
        ...(needsReReview ? { status: "pending", reviewNote: null, reviewedBy: null, reviewedAt: null } : {}),
      });

      return needsReReview;
    });

    return { sentForReReview };
  },
);

/**
 * PinBox equivalent of `resubmitVenue`/`resubmitOffer` — two distinct
 * callers: `needs_revision` → the admin sent it back with a reason, the
 * owner fixed it and is resubmitting for review; `active` → an owner
 * editing an already-live PinBox, which re-enters moderation the same
 * "no silent content swap on a live listing" way `resubmitVenue`'s
 * `approved` branch does. No `revisionDeadline`/`paymentId` fields
 * exist on PinBox (no flat listing fee — see `PinBox`'s own doc
 * comment), so there's nothing equivalent to `revertRevisionPayment` to
 * call here. No longer reachable from the normal PinBox-edit flow now
 * that `updatePinBox` folds this same status-flip logic in atomically
 * — kept standalone for the same reason `resubmitVenue` is.
 */
export const resubmitPinBox = onCall({ region: "us-central1", enforceAppCheck: false }, async (request) => {
  const uid = request.auth?.uid;
  if (!uid) throw new HttpsError("unauthenticated", "Bu əməliyyat üçün daxil olmalısınız.");
  await assertActiveUser(uid);

  const pinboxId = request.data?.pinboxId as string | undefined;
  if (!pinboxId) throw new HttpsError("invalid-argument", "pinboxId tələb olunur.");

  const ref = db.collection("pinboxes").doc(pinboxId);
  await db.runTransaction(async (tx) => {
    const snap = await tx.get(ref);
    if (!snap.exists) throw new HttpsError("not-found", "PinBox tapılmadı.");
    const data = snap.data()!;
    if (data.ownerId !== uid) throw new HttpsError("permission-denied", "Bu qutunun sahibi deyilsiniz.");
    if (data.status !== "active" && data.status !== "needs_revision") {
      throw new HttpsError("failed-precondition", "not-eligible");
    }
    // Same allowlist as `updatePinBox` — see its comment.
    const venueSnap = await tx.get(db.collection("venues").doc(data.venueId as string));
    if (!isPinBoxCategory(venueSnap.data()?.category)) {
      throw new HttpsError("failed-precondition", "Bu məkan kateqoriyası PinBox funksiyasını dəstəkləmir.");
    }

    tx.update(ref, {
      status: "pending",
      reviewNote: null,
      reviewedBy: null,
      reviewedAt: null,
      updatedAt: FieldValue.serverTimestamp(),
    });
  });

  return { ok: true };
});

/**
 * Confirms to the submitting owner that their PinBox was created —
 * mirrors `onVenueCreated` exactly.
 */
export const onPinBoxCreated = onDocumentCreated("pinboxes/{pinboxId}", async (event) => {
  const pinbox = event.data?.data();
  if (!pinbox) return;
  const ownerId = pinbox.ownerId as string | undefined;
  if (!ownerId) return;
  const title = (pinbox.title as string | undefined) ?? "";

  await notifyUser({
    uid: ownerId,
    category: "account",
    type: "pinboxAdded",
    title: "Qutunuz əlavə edildi",
    body: title ? `"${title}" uğurla yaradıldı, admin təsdiqini gözləyir.` : "Qutunuz uğurla yaradıldı.",
    params: { pinboxTitle: title },
    targetId: event.params.pinboxId,
    targetType: "pinbox",
  });
});

/**
 * Same moderation-status notification as `onOfferUpdated`, for PinBox —
 * this was missing entirely (see Faza 0's own audit: PinBox never had
 * ANY owner-facing notification, not even a "created" confirmation),
 * so an owner had no way to learn their box was approved/rejected
 * short of manually reopening Qutularım. PinBox's live-equivalent
 * status is `'active'`, not `'approved'` — normalized to `'approved'`
 * before reaching `moderationStatusNotification` (which only knows the
 * venue/offer vocabulary) so the same switch handles all three kinds.
 */
export const onPinBoxUpdated = onDocumentUpdated("pinboxes/{pinboxId}", async (event) => {
  const before = event.data?.before.data();
  const after = event.data?.after.data();
  if (!before || !after) return;
  if (before.status === after.status) return;

  const ownerId = after.ownerId as string | undefined;
  if (!ownerId) return;
  const title = (after.title as string | undefined) ?? "";

  const normalizedStatus = after.status === "active" ? "approved" : after.status;
  const notification = moderationStatusNotification("pinbox", title, normalizedStatus, after.reviewNote, false);
  if (notification) {
    await notifyUser({
      uid: ownerId,
      category: "account",
      ...notification,
      targetId: event.params.pinboxId,
      targetType: "pinbox",
    });
  }

  if (after.status === "active") {
    await recordListingIntent("pinbox", event.params.pinboxId, after.venueId as string, ownerId, after);
  }
});

/**
 * Sole writer of `identityVerifications/{requestId}` — firestore.rules
 * blocks every client write on that collection outright (see its own
 * doc comment) because "at most one active pending request per user"
 * needs a query, not a single-doc rule check. Enforced here instead:
 * reject if the caller already has a `pending` doc, otherwise create
 * one server-side (uid comes from the auth context, never trusted from
 * the client) referencing the three Storage PATHS the client already
 * uploaded to `identity_verifications/{uid}/{requestId}/...` (see
 * storage.rules) — not download URLs, so this doc never leaks the
 * images to anyone who reads it, including the submitting user
 * themselves (matches its `allow read: if ... uid == userId` in
 * firestore.rules: they may see their own status/rejectionReason, but
 * a Storage path alone gets them nothing without an admin-issued
 * signed URL).
 */
export const submitIdentityVerification = onCall({ region: "us-central1", enforceAppCheck: false }, async (request) => {
  const uid = request.auth?.uid;
  if (!uid) throw new HttpsError("unauthenticated", "Bu əməliyyat üçün daxil olmalısınız.");
  await assertActiveUser(uid);

  const requestId = request.data?.requestId as string | undefined;
  const idFrontPath = request.data?.idFrontPath as string | undefined;
  const idBackPath = request.data?.idBackPath as string | undefined;
  const selfieWithIdPath = request.data?.selfieWithIdPath as string | undefined;
  if (!requestId || !idFrontPath || !idBackPath || !selfieWithIdPath) {
    throw new HttpsError("invalid-argument", "Bütün sənədlər tələb olunur.");
  }

  // Every path must live under this exact uid's own Storage folder —
  // guards against a tampered client pointing the doc at someone
  // else's (or a nonexistent) file, same "never trust client-supplied
  // paths blindly" reasoning as `resubmitVenue`'s ownerId check above.
  const expectedPrefix = `identity_verifications/${uid}/${requestId}/`;
  if (![idFrontPath, idBackPath, selfieWithIdPath].every((p) => p.startsWith(expectedPrefix))) {
    throw new HttpsError("invalid-argument", "Sənəd yolları etibarsızdır.");
  }

  const existingPending = await db
    .collection("identityVerifications")
    .where("userId", "==", uid)
    .where("status", "==", "pending")
    .limit(1)
    .get();
  if (!existingPending.empty) {
    throw new HttpsError("failed-precondition", "already-pending");
  }

  // Düzəliş Prompt 10 / AUTH-15 — `requestId` is client-supplied (the
  // client's own Firestore auto-id, allocated before upload) and the
  // write below is a `.set()`, which fully OVERWRITES whatever already
  // exists at that id. Without this guard, a request landing on an id
  // that already belongs to a DIFFERENT user's pending submission would
  // silently replace it — the victim's record (and the admin's ability
  // to ever review it) would just vanish, with no error surfaced to
  // anyone. Not currently reachable in practice (the id is a random,
  // non-enumerable Firestore auto-id never exposed to non-owners — see
  // `firestore.rules`' `identityVerifications/{requestId}` read rule),
  // but the fix is cheap and the blast radius if this assumption ever
  // breaks is a silently dropped identity-verification submission, so
  // this closes it regardless of today's actual exploitability.
  const existingAtRequestId = await db.collection("identityVerifications").doc(requestId).get();
  if (existingAtRequestId.exists && existingAtRequestId.data()?.userId !== uid) {
    logger.error("submitIdentityVerification: requestId already belongs to a different user", {
      uid,
      requestId,
      existingOwner: existingAtRequestId.data()?.userId,
    });
    throw new HttpsError("already-exists", "request-id-taken");
  }

  await db.collection("identityVerifications").doc(requestId).set({
    userId: uid,
    idFrontPath,
    idBackPath,
    selfieWithIdPath,
    status: "pending",
    rejectionReason: null,
    submittedAt: FieldValue.serverTimestamp(),
    reviewedAt: null,
    reviewedByAdminId: null,
  });

  return { ok: true };
});

/**
 * Notification-only side of a review decision — the decision itself
 * (including setting `users/{uid}.identityVerified` on approval) is
 * the admin panel's `setIdentityVerificationStatus` Server Action, not
 * this trigger; same "state change lives in the action, fan-out lives
 * in a trigger reacting to it" split as `onVenueUpdated`/
 * `onOfferUpdated` + `moderationStatusNotification`.
 */
export const onIdentityVerificationUpdated = onDocumentUpdated("identityVerifications/{requestId}", async (event) => {
  const before = event.data?.before.data();
  const after = event.data?.after.data();
  if (!before || !after) return;
  if (before.status === after.status) return;
  if (after.status !== "approved" && after.status !== "rejected") return;

  const userId = after.userId as string | undefined;
  if (!userId) return;

  if (after.status === "approved") {
    await notifyUser({
      uid: userId,
      category: "account",
      type: "identityVerificationApproved",
      title: "Kimliyiniz təsdiqləndi",
      body: "Profilinizdə mavi tık nişanı aktivləşdi.",
      params: {},
    });
    return;
  }

  const reason = typeof after.rejectionReason === "string" && after.rejectionReason.trim() ? after.rejectionReason.trim() : undefined;
  await notifyUser({
    uid: userId,
    category: "account",
    type: "identityVerificationRejected",
    title: "Kimlik doğrulaması rədd edildi",
    body: reason ? `Səbəb: ${reason}` : "Müraciətiniz rədd edildi.",
    params: reason ? { note: reason } : {},
  });
});

const IDENTITY_VERIFICATION_IMAGE_RETENTION_MS = 90 * 24 * 60 * 60 * 1000;

/**
 * Daily sweep: 90 days after a request was reviewed (approved OR
 * rejected — never a still-`pending` one), deletes its 3 Storage
 * images and clears the now-dangling path fields. The
 * `identityVerifications/{requestId}` Firestore doc itself is kept —
 * status/reviewedAt/reviewedByAdminId stay as an audit trail — only
 * the actual ID/selfie photos, the sensitive part, get removed once
 * there's no realistic dispute-window reason left to hold onto them.
 * `deleteFiles({ prefix })` removes all 3 in one call since they share
 * `identity_verifications/{userId}/{requestId}/` as their prefix.
 */
export const cleanupExpiredIdentityVerificationImages = onSchedule(
  { schedule: "every 24 hours", region: "europe-west1" },
  async () => {
    const cutoff = Timestamp.fromMillis(Date.now() - IDENTITY_VERIFICATION_IMAGE_RETENTION_MS);

    for (const status of ["approved", "rejected"] as const) {
      const expired = await db
        .collection("identityVerifications")
        .where("status", "==", status)
        .where("reviewedAt", "<", cutoff)
        .get();

      await Promise.all(
        expired.docs.map(async (doc) => {
          const data = doc.data();
          // Firestore can't combine two inequality filters (reviewedAt
          // AND idFrontPath) in one query — this in-memory check is
          // what makes a re-run after a previous sweep already cleared
          // the paths a no-op instead of re-issuing an empty-prefix
          // delete every day for the rest of that doc's existence.
          if (data.idFrontPath == null) return;
          const userId = data.userId as string;
          const requestId = doc.id;
          try {
            await storage.bucket().deleteFiles({ prefix: `identity_verifications/${userId}/${requestId}/` });
          } catch {
            // A file already gone (e.g. a re-run after a partial
            // previous failure) must not block clearing the doc below.
          }
          await doc.ref.update({ idFrontPath: null, idBackPath: null, selfieWithIdPath: null });
        }),
      );
    }
  },
);

/**
 * Fires whenever a `payments/{paymentId}` doc's `status` newly becomes
 * `refund_pending` (from admin rejection, or `expireListingRevisionDeadlines`
 * below auto-rejecting an expired revision window) — NOT on every write,
 * so resubmitting (which flips a doc from `revision_pending` back to
 * `completed`) or the admin's own "mark as refunded" action (which flips
 * it to `refunded`) never re-triggers this. Shared by both venue and
 * offer listings (`listingType` on the doc), same as everything else
 * downstream of `payments/{paymentId}`.
 *
 * Calls Epoint's real `/reverse` endpoint (`reverseEpointTransaction`,
 * epoint.ts — confirmed against the official API PDF, NOT
 * `/refund-request`, which needs a `card_uid` this app's checkout flow
 * never has) against `epointTransaction` (captured at confirmed-success
 * time in `applyPaymentOutcome`). On success, advances `status` to
 * `refunded` itself — no more manual bank transfer for the common case.
 *
 * Two things still fall back to the OLD manual path (admin panel's
 * Payments page, filtered on `refund_pending`, is still the queue for
 * these): a payment written before this field existed (no
 * `epointTransaction` to reverse), and a `/reverse` call Epoint itself
 * rejects (e.g. code 914 "reversal original not found" — the doc gives
 * no guaranteed time window). Either case notifies admins so a payment
 * that still needs a manual refund is never silently missed now that
 * most of them resolve themselves.
 */
export const processPaymentRefund = onDocumentUpdated(
  { document: "payments/{paymentId}", secrets: [epointPublicKey, epointPrivateKey, epointEnv] },
  async (event) => {
    const before = event.data?.before.data();
    const after = event.data?.after.data();
    if (!before || !after) return;
    if (before.status === "refund_pending" || after.status !== "refund_pending") return;

    const paymentId = event.params.paymentId;
    const epointTransaction = after.epointTransaction as string | undefined;
    const amount = after.amount as number | undefined;
    const currency = (after.currency as string | undefined) ?? "AZN";
    const listingType = after.listingType as string | undefined;
    const listingId = after.listingId as string | undefined;

    const notifyManualFallback = async (reason: string) => {
      logger.error("processPaymentRefund: falling back to manual refund", { paymentId, reason });
      if (!listingType || !listingId) return;
      const nameSnap =
        listingType === "venue"
          ? await db.collection("venues").doc(listingId).get()
          : listingType === "offer"
            ? await db.collection("offers").doc(listingId).get()
            : null;
      const name = (nameSnap?.data()?.name as string | undefined) ?? (nameSnap?.data()?.title as string | undefined) ?? "";
      await notifyAdmins({
        type: "refund.manual",
        message: `${name ? `"${name}"` : listingId} üçün avtomatik geri qaytarma alınmadı (${reason}) — ${amount} ${currency} əl ilə qaytarılmalıdır.`,
        targetType: listingType,
        targetId: listingId,
      });
    };

    if (!epointTransaction) {
      await notifyManualFallback("bu ödənişdə Epoint əməliyyat ID-si yoxdur");
      return;
    }

    let result;
    try {
      result = await reverseEpointTransaction({
        publicKey: epointPublicKeyValue(),
        privateKey: epointPrivateKeyValue(),
        env: epointEnvValue(),
        epointTransaction,
        amount,
        currency,
      });
    } catch (e) {
      logger.error("processPaymentRefund: Epoint /reverse request threw", { paymentId, error: e });
      await notifyManualFallback("Epoint sorğusu uğursuz oldu");
      return;
    }

    if (!result.succeeded) {
      await notifyManualFallback(result.message ?? "Epoint əməliyyatı rədd etdi");
      return;
    }

    await db.collection("payments").doc(paymentId).update({
      status: "refunded",
      refundedAt: FieldValue.serverTimestamp(),
      updatedAt: FieldValue.serverTimestamp(),
    });
    logger.info("processPaymentRefund: refunded automatically via Epoint", { paymentId, amount, currency });

    // Düzəliş Prompt 6 / K-11 — reverses whatever entitlement this
    // payment granted. Deliberately NO branch here for
    // `venue_subscription`/`offer_placement_fee`: every path that ever
    // sets `refund_pending` for those two types (`setVenueStatus`/
    // `setOfferStatus` rejecting the listing, or
    // `expireRevisionDeadlinesFor`'s auto-reject sweep) ALREADY flips
    // the venue's/offer's own `status` to `rejected` in the SAME write
    // that triggers this — adding a second, independent write to the
    // same doc from here would risk racing that already-correct state
    // for no benefit (the listing is already hidden via `status`, not
    // via `subscriptionRenewsAt`/anything this trigger could add).
    // Confirmed by reading both admin actions directly before writing
    // this — not assumed.
    const type = after.type as string | undefined;
    if (type === "boost_fee" && listingType === "offer" && listingId) {
      await db.collection("offers").doc(listingId).update({
        boostedUntil: null,
        updatedAt: FieldValue.serverTimestamp(),
      });
    } else if (type === "venue_premium" && listingType === "venue" && listingId) {
      await db.runTransaction(async (tx) => {
        const venueRef = db.collection("venues").doc(listingId);
        const venueSnap = await tx.get(venueRef);
        if (!venueSnap.exists) return;
        const months = after.premiumMonths as number | undefined;
        const currentExpiresAt = (venueSnap.data()?.premiumExpiresAt as Timestamp | undefined)?.toDate();
        if (!months || !currentExpiresAt) return;
        const rolledBack = new Date(currentExpiresAt.getTime() - months * 30 * 24 * 60 * 60 * 1000);
        const stillPremium = rolledBack > new Date();
        tx.update(venueRef, {
          premiumExpiresAt: Timestamp.fromDate(rolledBack),
          isPremium: stillPremium,
          updatedAt: FieldValue.serverTimestamp(),
        });
      });
    } else if (type === "pinbox_order" && listingType === "pinboxOrder" && listingId) {
      await cancelPinBoxPayoutForRefund(listingId);
    }
  },
);

/**
 * One collection's worth of `expireListingRevisionDeadlines`'s sweep —
 * shared by the venues and offers passes below so the "find expired,
 * reject, mark payment refund_pending" logic only exists once. Returns
 * how many docs it touched, purely for the summary log line.
 */
async function expireRevisionDeadlinesFor(collectionName: "venues" | "offers"): Promise<number> {
  const now = Timestamp.now();
  const expired = await db
    .collection(collectionName)
    .where("status", "==", "needs_revision")
    .where("revisionDeadline", "<=", now)
    .get();

  await Promise.all(
    expired.docs.map(async (doc) => {
      const data = doc.data();
      await doc.ref.update({
        status: "rejected",
        revisionDeadline: null,
        updatedAt: FieldValue.serverTimestamp(),
      });
      const paymentId = data.paymentId as string | undefined;
      if (paymentId) {
        await db.collection("payments").doc(paymentId).update({
          status: "refund_pending",
          updatedAt: FieldValue.serverTimestamp(),
        });
      }
    }),
  );

  return expired.size;
}

/**
 * Daily sweep — in one invocation — for venues AND offers an admin
 * sent back for revision (`status: 'needs_revision'`) whose 7-day
 * `revisionDeadline` has passed without the owner resubmitting —
 * auto-rejects them and marks their payment for refund, exactly like
 * the admin's own "Rədd et və pulu qaytar" action (see
 * `setVenueStatus`/`setOfferStatus` in the admin panel).
 * `onVenueUpdated`/`onOfferUpdated` pick up the `status` change and
 * send the owner the same rejection notification either way. Firestore
 * has no single query spanning two different top-level collections, so
 * "one pass" here means one scheduled invocation running both queries,
 * not one query — `expireRevisionDeadlinesFor` is the shared logic
 * that keeps this from being two near-identical functions.
 */
export const expireListingRevisionDeadlines = onSchedule(
  { schedule: "every 24 hours", region: "europe-west1" },
  async () => {
    const [venueCount, offerCount] = await Promise.all([
      expireRevisionDeadlinesFor("venues"),
      expireRevisionDeadlinesFor("offers"),
    ]);

    if (venueCount > 0 || offerCount > 0) {
      logger.info("expireListingRevisionDeadlines: auto-rejected expired listings", { venueCount, offerCount });
    }
  },
);


const SUBSCRIPTION_CYCLE_MS = 30 * 24 * 60 * 60 * 1000;

/** Düzəliş Prompt 6 / PAY-10 — grace window before an unpaid venue is
 * suspended, counted in business days (weekends don't count against
 * the owner). Purely a new policy — nothing in this codebase enforced
 * any grace period before this. */
const SUBSCRIPTION_OVERDUE_GRACE_BUSINESS_DAYS = 5;

/** Adds `days` business days (Mon–Fri) to `start`, skipping weekends
 * entirely — used only to compute the PAY-10 suspension threshold.
 * Firestore can't express "N business days" as a query bound, so this
 * is evaluated per already-fetched venue inside `renewVenueSubscriptions`
 * rather than as a second query. */
function addBusinessDays(start: Date, days: number): Date {
  const result = new Date(start.getTime());
  let remaining = days;
  while (remaining > 0) {
    result.setDate(result.getDate() + 1);
    const dayOfWeek = result.getDay();
    if (dayOfWeek !== 0 && dayOfWeek !== 6) remaining--;
  }
  return result;
}

/**
 * Finds this venue's most recent `venue_subscription` payment and
 * reuses it if it's still `pending` AND no Epoint checkout was ever
 * started for it (so a second call — the daily schedule catching up,
 * or the owner tapping "Ödə" before either one actually reached Epoint —
 * never double-invoices the same overdue cycle); otherwise creates a
 * fresh pending one, since Epoint permanently rejects a second request
 * for an `order_id` it already saw (see `startEpointCheckoutForPayment`'s
 * own doc comment) — reusing a doc that already has a `checkoutStartedAt`
 * would make the owner's own "Ödə" retry fail every time. The
 * superseded doc is marked `failed` so it doesn't sit in the admin
 * panel's "gözləyən" queue forever. Shared by `renewVenueSubscriptions`
 * (which only acts when this actually creates a new doc) and
 * `retryVenueSubscriptionPayment` (which always wants a checkout for
 * whatever's pending, new or not).
 */
interface PendingOfferAcceptance {
  version: string;
  documentUrl: string;
  appVersion: string;
  platform: string;
}

/**
 * Düzəliş Prompt 10 / H #181 — canonical "current business offer"
 * source of truth. Before this, `submitVenue`/
 * `retryVenueSubscriptionPayment` trusted the CLIENT's own
 * `offerAcceptance.version`/`documentUrl` verbatim and recorded
 * exactly that into `venues/{id}.offerAcceptedVersion`/
 * `offerDocumentUrl` — a modified client could make a venue owner's
 * permanent legal-acceptance record say they accepted a version/URL
 * that was never actually shown to them, undermining the record's
 * whole evidentiary point. `appVersion`/`platform` stay client-
 * supplied (audit-only — which build/OS the tap happened on, no legal
 * weight of their own). Same `config/{docId}`, read-only-from-client
 * shape as `config/legal` (`currentTermsVersion`/`currentPrivacyVersion`)
 * — hand-edited via the admin script
 * `admin-panel/scripts/set-business-offer-version.ts` whenever the
 * offer PDF changes materially.
 */
async function currentBusinessOffer(): Promise<{ version: string; documentUrl: string }> {
  const snap = await db.collection("config").doc("businessOffer").get();
  const version = snap.data()?.currentVersion as string | undefined;
  const documentUrl = snap.data()?.documentUrl as string | undefined;
  if (!version || !documentUrl) {
    logger.error("currentBusinessOffer: config/businessOffer is missing or incomplete");
    throw new HttpsError("failed-precondition", "business-offer-not-configured");
  }
  return { version, documentUrl };
}

async function ensurePendingSubscriptionPayment(
  venueId: string,
  ownerId: string,
  category: string,
  venueName: string,
  offerAcceptance?: PendingOfferAcceptance,
): Promise<{ ref: FirebaseFirestore.DocumentReference; amount: number; isNew: boolean }> {
  const existing = await db
    .collection("payments")
    .where("listingType", "==", "venue")
    .where("listingId", "==", venueId)
    .where("type", "==", "venue_subscription")
    .orderBy("createdAt", "desc")
    .limit(1)
    .get();

  const latest = existing.docs[0];
  if (latest && latest.data().status === "pending" && !latest.data().checkoutStartedAt) {
    if (offerAcceptance) {
      await latest.ref.update({
        pendingOfferAcceptance: { ...offerAcceptance, acceptedAt: FieldValue.serverTimestamp() },
        updatedAt: FieldValue.serverTimestamp(),
      });
    }
    return { ref: latest.ref, amount: latest.data().amount as number, isNew: false };
  }
  if (latest && latest.data().status === "pending" && latest.data().checkoutStartedAt) {
    // Düzəliş Prompt 6 / K-10 — `superseded`, not `failed`: this payment
    // was never declined, a newer one is just replacing it (Epoint
    // rejects a reused `order_id`, so a fresh doc/checkout is required).
    // `applyPaymentOutcome` still honors a late success arriving on a
    // `superseded` doc — see that function's own doc comment.
    await latest.ref.update({ status: "superseded", updatedAt: FieldValue.serverTimestamp() });
  }

  const amount = venueSubscriptionFeeByCategory[category];
  if (amount === undefined) throw new Error(`no subscription fee tier for category ${category}`);

  const ref = db.collection("payments").doc();
  await ref.set({
    ownerId,
    listingType: "venue",
    listingId: venueId,
    type: "venue_subscription",
    description: `Məkan abunəliyi — ${venueName}`,
    amount,
    currency: "AZN",
    status: "pending",
    ...(offerAcceptance ? { pendingOfferAcceptance: { ...offerAcceptance, acceptedAt: FieldValue.serverTimestamp() } } : {}),
    createdAt: FieldValue.serverTimestamp(),
    updatedAt: FieldValue.serverTimestamp(),
  });
  return { ref, amount, isNew: true };
}

/**
 * "Məkanlar üzrə aylıq abunəlik" (see `_venueListingFeeFor`'s own doc
 * comment for the signed tariff PDF this table mirrors) — the recurring
 * half of venue billing. Used to write straight to `'completed'` with
 * no real charge (see `listing_payment.dart`'s own still-current doc
 * comments for that same stand-in pattern elsewhere); THIS collection
 * point now requires a real Epoint payment
 * each cycle, same as `submitOffer`'s fee path — `subscriptionRenewsAt`
 * only advances once `epointWebhook` confirms the charge, not here.
 *
 * Invoices at most once per overdue cycle (via
 * `ensurePendingSubscriptionPayment`'s `isNew` check) — a venue that
 * stays unpaid keeps showing the same pending payment/checkout rather
 * than getting re-invoiced every time this runs. A venue whose category
 * fell out of `venueSubscriptionFeeByCategory` (should never happen —
 * see that table's own doc comment) is skipped and logged.
 */
export const renewVenueSubscriptions = onSchedule(
  { schedule: "every 24 hours", region: "europe-west1", secrets: [epointPublicKey, epointPrivateKey, epointEnv] },
  async () => {
    const now = new Date();
    const snap = await db
      .collection("venues")
      .where("status", "==", "approved")
      .where("subscriptionRenewsAt", "<=", Timestamp.fromDate(now))
      .get();

    if (snap.empty) return;

    let invoiced = 0;
    let suspended = 0;
    for (const doc of snap.docs) {
      const data = doc.data();
      const category = data.category as string | undefined;
      if (!category || venueSubscriptionFeeByCategory[category] === undefined) {
        logger.error("renewVenueSubscriptions: no fee tier for category", { venueId: doc.id, category });
        continue;
      }

      const ownerId = data.ownerId as string | undefined;
      if (!ownerId) continue;

      const venueName = (data.name as string | undefined) ?? "";
      const { ref: paymentRef, amount, isNew } = await ensurePendingSubscriptionPayment(doc.id, ownerId, category, venueName);
      if (isNew) {
        try {
          await startEpointCheckoutForPayment(paymentRef.id, amount, `Məkan abunəliyi — ${venueName}`);
        } catch (e) {
          logger.error("renewVenueSubscriptions: Epoint checkout failed", { venueId: doc.id, error: e });
          // Payment doc stays 'pending' regardless — the owner's own
          // "Ödə" button (retryVenueSubscriptionPayment) tries again.
        }

        await notifyUser({
          uid: ownerId,
          category: "account",
          type: "venueSubscriptionDue",
          title: "Məkan abunəliyi ödənişi tələb olunur",
          body: venueName ? `"${venueName}" üçün abunəlik ödənişini tamamlayın.` : "Abunəlik ödənişini tamamlayın.",
          params: { venueName, amount },
          targetId: doc.id,
          targetType: "venue_subscription_due",
        });
        invoiced++;
      }

      // Düzəliş Prompt 6 / PAY-10 — past the grace period, an
      // `approved` venue that's still unpaid is suspended so it drops
      // out of every existing `where("status","==","approved")` query
      // (discover, `firestore.rules` reads, etc.) with no changes
      // needed anywhere else — `applyPaymentOutcome`'s venue_subscription
      // renewal branch is the only way back to `approved`.
      const renewsAt = (data.subscriptionRenewsAt as Timestamp).toDate();
      if (now >= addBusinessDays(renewsAt, SUBSCRIPTION_OVERDUE_GRACE_BUSINESS_DAYS)) {
        await doc.ref.update({ status: "subscription_overdue", updatedAt: FieldValue.serverTimestamp() });
        suspended++;
      }
    }

    if (invoiced > 0) logger.info("renewVenueSubscriptions: invoiced venue subscriptions", { invoiced });
    if (suspended > 0) logger.info("renewVenueSubscriptions: suspended overdue venue subscriptions", { suspended });
  },
);

/**
 * Owner-initiated "Ödə" button on `MyVenuesScreen`'s overdue banner —
 * re-opens (or, if the daily schedule hasn't caught up to this venue
 * yet, creates) a checkout for the current cycle. Requires the venue
 * to actually BE overdue server-side (not just client-computed) so
 * this can't be used to prepay/skip ahead of the real due date.
 */
export const retryVenueSubscriptionPayment = onCall(
  // App Check enforcement qəsdən `false`-dur — iOS DeviceCheck
  // qeydiyyatı gözlənilir (səbəb və simptom: bu faylın başındakı
  // şərh). Açılma şərti: Firebase Console → App Check-də HƏR İKİ
  // platformada təsdiqlənmə faizi sabit yüksək olduqda.
  { region: "us-central1", secrets: [epointPublicKey, epointPrivateKey, epointEnv], enforceAppCheck: false },
  async (request) => {
    const uid = request.auth?.uid;
    if (!uid) throw new HttpsError("unauthenticated", "Bu əməliyyat üçün daxil olmalısınız.");
    await assertActiveUser(uid);
    // Düzəliş Prompt 8 / PAY-16 — shared "checkout" scope across all 8
    // Epoint-initiating callables (see this prompt's own doc note: none
    // of them accept a raw card number, so the real risk is volumetric
    // checkout-session/API-call abuse, not a card-testing oracle).
    await enforceRateLimit("checkout", uid, 10, 600);

    const venueId = request.data?.venueId as string | undefined;
    if (!venueId) throw new HttpsError("invalid-argument", "venueId tələb olunur.");

    const venueSnap = await db.collection("venues").doc(venueId).get();
    const venue = venueSnap.data();
    if (!venue) throw new HttpsError("not-found", "Məkan tapılmadı.");
    if (venue.ownerId !== uid) throw new HttpsError("permission-denied", "Bu məkanın sahibi deyilsiniz.");

    const renewsAt = (venue.subscriptionRenewsAt as Timestamp | undefined)?.toDate();
    if (!renewsAt || renewsAt > new Date()) {
      throw new HttpsError("failed-precondition", "Bu məkanın abunəlik ödənişi hələ gecikməyib.");
    }

    const category = venue.category as string | undefined;
    if (!category) throw new HttpsError("failed-precondition", "Məkanın kateqoriyası tapılmadı.");

    // Re-acceptance is only required when Remote Config's
    // `business_offer_version` has moved past what this venue last
    // accepted — the client only sends `offerAcceptance` when it
    // detected that mismatch and the owner confirmed
    // `showBusinessOfferReacceptSheet`. A venue with NO acceptance on
    // file at all (pre-dates this feature) is blocked here the same
    // way `submitVenue` blocks a first-time creation without one —
    // every other venue (already has some accepted version, client
    // didn't flag a mismatch) proceeds unchanged, exactly today's
    // behavior.
    const offerAcceptanceInput = request.data?.offerAcceptance as Record<string, unknown> | undefined;
    let offerAcceptance: PendingOfferAcceptance | undefined;
    if (offerAcceptanceInput) {
      const offerAppVersion = offerAcceptanceInput.appVersion as string | undefined;
      const offerPlatform = offerAcceptanceInput.platform as string | undefined;
      if (!offerAppVersion || !offerPlatform) {
        throw new HttpsError("invalid-argument", "Düzgün offerAcceptance tələb olunur.");
      }
      const { version, documentUrl } = await currentBusinessOffer();
      offerAcceptance = { version, documentUrl, appVersion: offerAppVersion, platform: offerPlatform };
    } else if (!venue.offerAcceptedVersion) {
      throw new HttpsError("failed-precondition", "Biznes Xidmətlərinin Publik Ofertasını qəbul etməlisiniz.");
    }

    const venueName = (venue.name as string | undefined) ?? "";
    const { ref: paymentRef, amount } = await ensurePendingSubscriptionPayment(
      venueId,
      uid,
      category,
      venueName,
      offerAcceptance,
    );
    const checkoutUrl = await startEpointCheckoutForPayment(paymentRef.id, amount, `Məkan abunəliyi — ${venueName}`);

    return { checkoutUrl, feeAmount: amount, paymentId: paymentRef.id };
  },
);

/**
 * Venue creation, moved server-side — replaces the old client-side
 * `FirebaseVenueRepository.createVenue` + `createListingPayment` stub
 * (`lib/core/data/listing_payment.dart`), which wrote a `payments` doc
 * straight to `status: 'completed'` with NO real Epoint charge, a
 * leftover from before Epoint was wired up that offers/PinBox already
 * migrated away from but venues never did. Same shape as `submitOffer`:
 * the venue doc is created here (pre-allocated id from the client, same
 * as `allocateVenueId` always did, so the already-uploaded photo lands
 * on the right doc), `status: 'awaiting_payment'` — invisible to
 * everyone, not yet in the moderation queue — until `epointWebhook`
 * confirms the charge (`applyPaymentOutcome`'s venue_subscription
 * first-payment branch flips it to `'pending'` and sets
 * `subscriptionRenewsAt` for the first time). `firestore.rules`'
 * `venues/{venueId}` create rule is `false` — this Admin-SDK path is
 * now the only way a venue doc gets created.
 */
export const submitVenue = onCall(
  { region: "us-central1", secrets: [epointPublicKey, epointPrivateKey, epointEnv], enforceAppCheck: false },
  async (request) => {
    const uid = request.auth?.uid;
    if (!uid) throw new HttpsError("unauthenticated", "Bu əməliyyat üçün daxil olmalısınız.");
    await assertActiveUser(uid);

    // The ONLY gate on "can this account create a venue" — a self-service
    // toggle in Privacy/Security ("Biznes fəaliyyəti"), default 'active'
    // for every account (same default `firestore.rules`' old
    // `isBusinessUser` used, `.get('businessStatus', 'active')`). That
    // rule was the sole enforcement point before venue creation moved
    // server-side; this replicates it here now that the rule itself is
    // `allow create: if false`.
    //
    // Fixed (Düzəliş Prompt 11 / audit follow-up finding) — this used to
    // read `requesterSnap.data()?.businessStatus`, which silently
    // evaluates to `undefined` (not `"none"`) when the doc doesn't
    // exist at all, so a missing `users/{uid}` document let this check
    // pass through rather than deny. `assertActiveUser` above already
    // closes that specific hole (it throws first if the doc is
    // missing), but `requesterSnap.data()!` now also fails loudly
    // instead of silently if that were ever somehow bypassed.
    const requesterSnap = await db.collection("users").doc(uid).get();
    if ((requesterSnap.data()!.businessStatus as string | undefined) === "none") {
      rejectRequest("permission-denied", "submitVenue.business-inactive",
        "Məkan yaratmaq üçün Ayarlar → Biznes fəaliyyəti bölməsindən aktiv edin.");
    }

    const data = request.data as Record<string, unknown>;
    const clientVenueId = data.venueId as string | undefined;
    const name = (data.name as string | undefined)?.trim();
    const category = data.category as string | undefined;
    const photoUrl = data.photoUrl as string | undefined;
    const lat = data.lat as number | undefined;
    const lng = data.lng as number | undefined;
    const address = (data.address as string | undefined)?.trim();
    const openingHours = data.openingHours as Record<string, unknown> | undefined;
    if (!clientVenueId || !name || !category || !photoUrl || lat === undefined || lng === undefined || !address || !openingHours) {
      rejectRequest("invalid-argument", "submitVenue.missing-fields", "Tələb olunan sahələr çatışmır.", {
        missing: {
          venueId: !clientVenueId, name: !name, category: !category, photoUrl: !photoUrl,
          lat: lat === undefined, lng: lng === undefined, address: !address, openingHours: !openingHours,
        },
      });
    }
    // P0 / H-5. Logs the URL's PREFIX only — enough to see whether it
    // is a different bucket, a plain http URL, or something else
    // entirely, without writing a token-bearing download URL into logs
    // anyone with log access could then use.
    if (!photoUrl.startsWith(OWN_STORAGE_URL_PREFIX)) {
      rejectRequest("invalid-argument", "submitVenue.foreign-photo-url",
        "photoUrl yalnız PeakPin Storage ünvanı ola bilər.",
        { prefix: photoUrl.slice(0, 60) });
    }

    const fee = venueSubscriptionFeeByCategory[category];
    if (fee === undefined) {
      logger.error("submitVenue: no subscription fee tier for category", { category });
      throw new HttpsError("failed-precondition", "Bu məkan kateqoriyası üçün haqq cədvəli tapılmadı.");
    }

    // "PeakPin Biznes Xidmətlərinin Publik Ofertası" — every venue's
    // FIRST subscription payment must have a fresh acceptance attached
    // (see `PendingOfferAcceptance`/`applyPaymentOutcome`'s
    // `venue_subscription` branch, which promotes this to
    // `venues/{id}.offerAcceptedVersion` + `offerAcceptances/{id}` only
    // once the charge actually succeeds). No optional/legacy path here
    // — every caller of `submitVenue` is on a build that shows the
    // acceptance checkbox, so there's no old client to stay compatible
    // with (checked: no active Play/App Store testers at the time this
    // shipped).
    const offerAcceptanceInput = data.offerAcceptance as Record<string, unknown> | undefined;
    const offerAppVersion = offerAcceptanceInput?.appVersion as string | undefined;
    const offerPlatform = offerAcceptanceInput?.platform as string | undefined;
    if (!offerAppVersion || !offerPlatform) {
      rejectRequest("failed-precondition", "submitVenue.offer-not-accepted",
        "Biznes Xidmətlərinin Publik Ofertasını qəbul etməlisiniz.",
        { hasAppVersion: Boolean(offerAppVersion), hasPlatform: Boolean(offerPlatform) });
    }
    const { version: offerVersion, documentUrl: offerDocumentUrl } = await currentBusinessOffer();
    const offerAcceptance: PendingOfferAcceptance = {
      version: offerVersion,
      documentUrl: offerDocumentUrl,
      appVersion: offerAppVersion,
      platform: offerPlatform,
    };

    const venueRef = db.collection("venues").doc(clientVenueId);
    if ((await venueRef.get()).exists) {
      rejectRequest("already-exists", "submitVenue.duplicate-id", "Bu ID artıq istifadə olunub.",
        { venueId: clientVenueId });
    }

    const { ref: paymentRef, amount } = await ensurePendingSubscriptionPayment(
      clientVenueId,
      uid,
      category,
      name,
      offerAcceptance,
    );

    await venueRef.set({
      ownerId: uid,
      name,
      nameLower: name.toLowerCase(),
      category,
      photoUrl,
      lat,
      lng,
      position: { geopoint: new GeoPoint(lat, lng), geohash: geohashForLocation([lat, lng], 9) },
      address,
      ...(data.country ? { country: data.country } : {}),
      openingHours,
      status: "awaiting_payment",
      paymentId: paymentRef.id,
      verified: false,
      likeCount: 0,
      rating: 3.0,
      ...(data.socialLinks ? { socialLinks: data.socialLinks } : {}),
      audienceRadiusMode: (data.audienceRadiusMode as string | undefined) ?? "distance",
      audienceRadiusKm: assertAllowedAudienceRadius(data.audienceRadiusKm),
      birthdayNotificationsEnabled: (data.birthdayNotificationsEnabled as boolean | undefined) ?? false,
      createdAt: FieldValue.serverTimestamp(),
    });

    const checkoutUrl = await startEpointCheckoutForPayment(paymentRef.id, amount, `Məkan abunəliyi — ${name}`);

    return { venueId: venueRef.id, checkoutUrl, feeAmount: amount, paymentId: paymentRef.id };
  },
);

/**
 * Re-opens a checkout for a venue whose FIRST subscription payment
 * previously failed or was abandoned — same `payments` doc, a fresh
 * Epoint request. Distinct from `retryVenueSubscriptionPayment`, which
 * only handles an already-live venue's overdue RENEWAL (it explicitly
 * requires an existing, past-due `subscriptionRenewsAt` — a brand new
 * `awaiting_payment` venue has none yet). Mirrors `retryOfferPayment`.
 */
export const retryVenueCreationPayment = onCall(
  // App Check enforcement qəsdən `false`-dur — iOS DeviceCheck
  // qeydiyyatı gözlənilir (səbəb və simptom: bu faylın başındakı
  // şərh). Açılma şərti: Firebase Console → App Check-də HƏR İKİ
  // platformada təsdiqlənmə faizi sabit yüksək olduqda.
  { region: "us-central1", secrets: [epointPublicKey, epointPrivateKey, epointEnv], enforceAppCheck: false },
  async (request) => {
    const uid = request.auth?.uid;
    if (!uid) throw new HttpsError("unauthenticated", "Bu əməliyyat üçün daxil olmalısınız.");
    await assertActiveUser(uid);
    await enforceRateLimit("checkout", uid, 10, 600);

    const venueId = request.data?.venueId as string | undefined;
    if (!venueId) throw new HttpsError("invalid-argument", "venueId tələb olunur.");

    const venueSnap = await db.collection("venues").doc(venueId).get();
    const venue = venueSnap.data();
    if (!venue) throw new HttpsError("not-found", "Məkan tapılmadı.");
    if (venue.ownerId !== uid) throw new HttpsError("permission-denied", "Bu məkanın sahibi deyilsiniz.");
    if (venue.status !== "awaiting_payment") {
      throw new HttpsError("failed-precondition", "Bu məkan ödəniş gözləmir.");
    }

    const paymentsSnap = await db
      .collection("payments")
      .where("listingType", "==", "venue")
      .where("listingId", "==", venueId)
      .where("type", "==", "venue_subscription")
      .orderBy("createdAt", "desc")
      .limit(1)
      .get();
    const paymentDoc = paymentsSnap.docs[0];
    if (!paymentDoc) throw new HttpsError("not-found", "Bu məkan üçün ödəniş qeydi tapılmadı.");
    if (paymentDoc.data().status === "completed") {
      throw new HttpsError("failed-precondition", "Bu ödəniş artıq tamamlanıb.");
    }

    const amount = paymentDoc.data().amount as number;
    const venueName = (venue.name as string | undefined) ?? "";
    const description = (paymentDoc.data().description as string | undefined) ?? `Məkan abunəliyi — ${venueName}`;

    // Epoint permanently rejects a second checkout request for the same
    // `order_id` (= payment doc id) — see `startEpointCheckoutForPayment`'s
    // own doc comment. A payment doc that already went through Epoint
    // once (the original submitVenue attempt) can never be reused, so
    // this creates a fresh one instead of just flipping the old one back
    // to 'pending' the way it used to (confirmed via live testing: the
    // very first version of this function hit "Duplicate order_id value"
    // every time).
    let targetRef = paymentDoc.ref;
    if (paymentDoc.data().checkoutStartedAt) {
      // Düzəliş Prompt 6 / K-10 — `superseded`, not `failed` (see
      // `ensurePendingSubscriptionPayment`'s identical comment).
      await paymentDoc.ref.update({ status: "superseded", updatedAt: FieldValue.serverTimestamp() });
      targetRef = db.collection("payments").doc();
      // The acceptance travels with the retry. `submitVenue` attaches
      // it to the FIRST payment, and `applyPaymentOutcome` promotes it
      // into the venue's permanent record only when the charge
      // succeeds — so if the first attempt fails and this creates a
      // fresh doc without it, the venue goes live with no proof its
      // owner ever accepted the public offer. That happened on
      // 2026-08-31: first attempt failed, retry succeeded, and
      // `offerAcceptances` stayed empty on a paid, approved venue.
      // Owners who pay on the first try got a record; owners who had to
      // retry did not, which is not a distinction the contract makes.
      const carriedOfferAcceptance = paymentDoc.data().pendingOfferAcceptance as
        | PendingOfferAcceptance
        | undefined;
      await targetRef.set({
        ownerId: uid,
        listingType: "venue",
        listingId: venueId,
        type: "venue_subscription",
        ...(carriedOfferAcceptance ? { pendingOfferAcceptance: carriedOfferAcceptance } : {}),
        description,
        amount,
        currency: (paymentDoc.data().currency as string | undefined) ?? "AZN",
        status: "pending",
        createdAt: FieldValue.serverTimestamp(),
        updatedAt: FieldValue.serverTimestamp(),
      });
    } else {
      await targetRef.update({ status: "pending", updatedAt: FieldValue.serverTimestamp() });
    }

    const checkoutUrl = await startEpointCheckoutForPayment(targetRef.id, amount, description);

    return { checkoutUrl, feeAmount: amount, paymentId: targetRef.id };
  },
);

/**
 * Düzəliş Prompt 6 / K-10 — `createBoostCheckout`/`createVenuePremiumCheckout`
 * (unlike `retryOfferPayment`/`retryVenueCreationPayment`/
 * `ensurePendingSubscriptionPayment`) never checked for an existing
 * `pending` payment before creating a fresh one — two tabs/attempts for
 * the same offer/venue could each carry their own `pending` doc,
 * completely independent of the other, and if BOTH later succeeded
 * `applyPaymentOutcome`'s own idempotency guard wouldn't catch it
 * either (two different doc ids, two different `status !== "pending"`
 * checks, both legitimately pass) — `boostedUntil`/`premiumExpiresAt`
 * would each get extended TWICE for one intended purchase. Marks every
 * other still-`pending` payment for this exact listing+type
 * `superseded` before a new one is created, closing that gap the same
 * way the other three checkout-creators already do.
 */
async function supersedeOtherPendingPayments(
  listingType: string,
  listingId: string,
  type: string,
): Promise<void> {
  const existing = await db
    .collection("payments")
    .where("listingType", "==", listingType)
    .where("listingId", "==", listingId)
    .where("type", "==", type)
    .where("status", "==", "pending")
    .get();
  await Promise.all(
    existing.docs.map((doc) => doc.ref.update({ status: "superseded", updatedAt: FieldValue.serverTimestamp() })),
  );
}

/** 6/12/18 saat → 2/4/6 AZN — same tiers as the create form's own tier picker (`offer_details_screen.dart`). */
const BOOST_FEE_BY_HOURS: Record<number, number> = { 6: 2, 12: 4, 18: 6 };

/**
 * "Təklifi önə çək" checkout — replaces the old direct client write to
 * `Offer.boostedUntil` (blocked now in firestore.rules' offers update
 * rule) with the same pending-payment-then-webhook shape as
 * `submitOffer`'s fee path. `boostedUntil` is set ONLY by
 * `epointWebhook` on a confirmed charge, never here.
 */
export const createBoostCheckout = onCall(
  // App Check enforcement qəsdən `false`-dur — iOS DeviceCheck
  // qeydiyyatı gözlənilir (səbəb və simptom: bu faylın başındakı
  // şərh). Açılma şərti: Firebase Console → App Check-də HƏR İKİ
  // platformada təsdiqlənmə faizi sabit yüksək olduqda.
  { region: "us-central1", secrets: [epointPublicKey, epointPrivateKey, epointEnv], enforceAppCheck: false },
  async (request) => {
    const uid = request.auth?.uid;
    if (!uid) throw new HttpsError("unauthenticated", "Bu əməliyyat üçün daxil olmalısınız.");
    await assertActiveUser(uid);
    await enforceRateLimit("checkout", uid, 10, 600);

    const offerId = request.data?.offerId as string | undefined;
    const hours = request.data?.hours as number | undefined;
    if (!offerId || hours === undefined || !(hours in BOOST_FEE_BY_HOURS)) {
      throw new HttpsError("invalid-argument", "Düzgün offerId/hours tələb olunur.");
    }

    const offerSnap = await db.collection("offers").doc(offerId).get();
    const offer = offerSnap.data();
    if (!offer) throw new HttpsError("not-found", "Təklif tapılmadı.");
    if (offer.ownerId !== uid) throw new HttpsError("permission-denied", "Bu təklifin sahibi deyilsiniz.");

    const amount = BOOST_FEE_BY_HOURS[hours];
    const description = `Təklifi önə çək — ${hours} saat`;
    await supersedeOtherPendingPayments("offer", offerId, "boost_fee");
    const paymentRef = db.collection("payments").doc();
    await paymentRef.set({
      ownerId: uid,
      listingType: "offer",
      listingId: offerId,
      type: "boost_fee",
      boostHours: hours,
      description,
      amount,
      currency: "AZN",
      status: "pending",
      createdAt: FieldValue.serverTimestamp(),
      updatedAt: FieldValue.serverTimestamp(),
    });

    const checkoutUrl = await startEpointCheckoutForPayment(paymentRef.id, amount, description);
    return { checkoutUrl, feeAmount: amount, paymentId: paymentRef.id };
  },
);

/** 1/6/12 ay → 22/99/199 AZN — must match `VenuePremiumBottomSheet`'s own tiers exactly. */
const VENUE_PREMIUM_FEE_BY_MONTHS: Record<number, number> = { 1: 22, 6: 99, 12: 199 };

/**
 * "Məkanı premium et" checkout — same pending-payment-then-webhook
 * shape as `createBoostCheckout`. `isPremium`/`premiumSince`/
 * `premiumExpiresAt` are set ONLY by `applyPaymentOutcome`'s
 * `venue_premium` branch on a confirmed charge, never here (see
 * firestore.rules' venues update rule).
 */
export const createVenuePremiumCheckout = onCall(
  // App Check enforcement qəsdən `false`-dur — iOS DeviceCheck
  // qeydiyyatı gözlənilir (səbəb və simptom: bu faylın başındakı
  // şərh). Açılma şərti: Firebase Console → App Check-də HƏR İKİ
  // platformada təsdiqlənmə faizi sabit yüksək olduqda.
  { region: "us-central1", secrets: [epointPublicKey, epointPrivateKey, epointEnv], enforceAppCheck: false },
  async (request) => {
    const uid = request.auth?.uid;
    if (!uid) throw new HttpsError("unauthenticated", "Bu əməliyyat üçün daxil olmalısınız.");
    await assertActiveUser(uid);
    await enforceRateLimit("checkout", uid, 10, 600);

    const venueId = request.data?.venueId as string | undefined;
    const months = request.data?.months as number | undefined;
    if (!venueId || months === undefined || !(months in VENUE_PREMIUM_FEE_BY_MONTHS)) {
      throw new HttpsError("invalid-argument", "Düzgün venueId/months tələb olunur.");
    }

    const venueSnap = await db.collection("venues").doc(venueId).get();
    const venue = venueSnap.data();
    if (!venue) throw new HttpsError("not-found", "Məkan tapılmadı.");
    if (venue.ownerId !== uid) throw new HttpsError("permission-denied", "Bu məkanın sahibi deyilsiniz.");

    const amount = VENUE_PREMIUM_FEE_BY_MONTHS[months];
    const description = `Məkanı premium et — ${months} ay`;
    await supersedeOtherPendingPayments("venue", venueId, "venue_premium");
    const paymentRef = db.collection("payments").doc();
    await paymentRef.set({
      ownerId: uid,
      listingType: "venue",
      listingId: venueId,
      type: "venue_premium",
      premiumMonths: months,
      description,
      amount,
      currency: "AZN",
      status: "pending",
      createdAt: FieldValue.serverTimestamp(),
      updatedAt: FieldValue.serverTimestamp(),
    });

    const checkoutUrl = await startEpointCheckoutForPayment(paymentRef.id, amount, description);
    return { checkoutUrl, feeAmount: amount, paymentId: paymentRef.id };
  },
);

/**
 * Cleans up a deleted post's `likes`/`comments` subcollections —
 * Firestore doesn't cascade-delete them, and the client CAN'T (each
 * like/comment doc's own rule only lets its own author delete it, not
 * the post owner). Admin SDK bypasses that, same as deleteAccount.
 */
/**
 * Cancels the payments still waiting on a listing that has just been
 * deleted.
 *
 * As a TRIGGER rather than a step inside each delete path, on purpose.
 * A venue can be deleted from at least four places — the app's own
 * `deleteVenue`, the admin panel's account deletion, `deleteAccount`'s
 * `deleteUserVenues`, and by hand in the console — and the app cannot
 * write to `payments` at all (server-only by rules). Patching the
 * paths that CAN would have covered some of them, which is the shape
 * of bug this codebase keeps producing. A delete trigger covers every
 * path there is, including the ones added later.
 *
 * Only `pending` moves. A `completed` payment is a historical fact
 * about money that changed hands and must survive the thing it paid
 * for; `failed` and `orphan_target` are already terminal.
 *
 * Queried by `listingId` alone — one equality filter on an
 * automatically-indexed field, then filtered in memory. A listing has
 * a handful of payments at most, and this avoids requiring a new
 * composite index for a path that runs on deletion.
 */
async function cancelPendingPaymentsForListing(listingId: string, reason: string): Promise<void> {
  const snap = await db.collection("payments").where("listingId", "==", listingId).get();
  const pending = snap.docs.filter((d) => isCancellableOnListingDelete(d.get("status")));
  if (pending.length === 0) return;

  await Promise.all(
    pending.map((d) =>
      d.ref.update({
        status: "cancelled",
        cancelledReason: reason,
        cancelledAt: FieldValue.serverTimestamp(),
        updatedAt: FieldValue.serverTimestamp(),
      }),
    ),
  );
  logger.info("cancelPendingPaymentsForListing: cancelled pending payments", {
    listingId,
    reason,
    count: pending.length,
  });
}

/**
 * A deleted venue must not leave an open checkout behind it. Without
 * this, the Epoint page stays payable and the webhook lands on a venue
 * that is gone — see `applyPaymentOutcome`'s orphan guard, which is
 * the second half of the same problem and the one that catches
 * whatever slips past this.
 */
export const onVenueDeleted = onDocumentDeleted("venues/{venueId}", async (event) => {
  await cancelPendingPaymentsForListing(event.params.venueId, "venue-deleted");
  const path = venuePhotoPath(event.data?.data()?.ownerId, event.params.venueId);
  if (path) await deleteStorageFile(path);
});

/** Same reasoning as `onVenueDeleted`, for offer placement and boost fees. */
export const onOfferDeleted = onDocumentDeleted("offers/{offerId}", async (event) => {
  await cancelPendingPaymentsForListing(event.params.offerId, "offer-deleted");
  const path = offerPhotoPath(event.data?.data()?.ownerId, event.params.offerId);
  if (path) await deleteStorageFile(path);
});

// PinBox has no equivalent trigger, and that is deliberate rather than
// an omission: a `pinbox_order` payment's `listingId` is the ORDER's
// id, not the box's, and `anonymizeUserPinBoxes` keeps orders intact
// when a box goes away. So deleting a box does not orphan a payment —
// deleting an order would, and nothing deletes orders.

/**
 * Story cleanup — an EXPLICIT scheduled sweep, not a TTL policy.
 *
 * `stories/{id}` carries `expiresAt` (24 hours) and Firestore has a
 * native TTL feature that would delete on it for free. That was the
 * first design and it was rejected, because a story is three things,
 * not one: the document, its `views` subcollection, and a Storage
 * object plus the Resize extension's `_200x200` derivative. TTL removes
 * only the document. Subcollections and Storage would survive it.
 *
 * The tempting repair was to let TTL fire `onDocumentDeleted` and clean
 * up from there. That chain is NOT something this project can verify:
 * the Firestore emulator does not implement TTL at all, so it cannot be
 * tested locally, and a live test means deploying a probe and waiting —
 * TTL publishes no deletion-latency guarantee. Building every story's
 * cleanup on an unverified assumption would mean discovering it was
 * wrong from a storage bill months later, which is exactly how the
 * `birthdayMatches` and `stories` accumulation happened in the first
 * place.
 *
 * So the sweep is explicit and does all three itself. A TTL policy on
 * `expiresAt` can still be enabled as a harmless backstop — if the
 * chain does work, it removes documents this sweep already handled; if
 * it does not, nothing is lost.
 *
 * Hourly rather than daily: a story is only alive for 24 hours, so a
 * daily sweep would leave one up to a full extra day. The query is
 * bounded by one hour's expirations, which is proportional to real
 * usage rather than to the collection's size.
 */
export const cleanupExpiredStories = onSchedule(
  { schedule: "every 60 minutes", region: "europe-west1" },
  async () => {
    const expired = await db
      .collection("stories")
      .where("expiresAt", "<", Timestamp.now())
      .limit(500)
      .get();
    if (expired.empty) return;

    for (const storyDoc of expired.docs) {
      // Deleting the document fires `onStoryDeleted`, which owns the
      // `views` + Storage cleanup — one cleanup path for both the
      // scheduled expiry and a user's own "Sil". Duplicating it here
      // would be a second place to forget.
      await storyDoc.ref.delete();
    }
    logger.info("cleanupExpiredStories: removed expired stories", { count: expired.size });
  },
);

/**
 * Everything a story owns, removed together — whichever way the story
 * itself went (the hourly expiry sweep, the creator's own delete, or
 * an account deletion).
 *
 * Before this, `FirebaseStoryRepository.deleteStory` was a bare
 * `_stories.doc(id).delete()`: the Storage object, its `_200x200`
 * derivative and every `views` document stayed behind forever. Only
 * account deletion cleaned up properly, via a prefix delete.
 *
 * The Storage path is DERIVED from `creatorId` + the document id +
 * `mediaType` (see `./media-paths`), never parsed out of the stored
 * `mediaUrl` — same rule as `chatMediaPathForMessage`, and the reason
 * is P0 / C-1.
 */
export const onStoryDeleted = onDocumentDeleted("stories/{storyId}", async (event) => {
  const data = event.data?.data();
  if (!data) return;

  const viewsSnap = await event.data!.ref.collection("views").get();
  await Promise.all(viewsSnap.docs.map((d) => d.ref.delete()));

  const path = storyMediaPath(data.creatorId, event.params.storyId, data.mediaType);
  if (path) await deleteStorageFile(path);
});

/**
 * A deleted listing takes its photo with it.
 *
 * `onVenueDeleted`/`onOfferDeleted` existed already but only cancelled
 * pending payments; PinBox and events had no delete trigger at all. The
 * client repositories DO delete these objects on the owner's own
 * "Sil" — with the same derived paths — but that call is best-effort
 * (its failure is swallowed), and it is not the only way a listing can
 * disappear. These triggers are the backstop that makes the cleanup
 * true regardless of which path removed the document.
 *
 * `deleteStorageFile` takes the `_200x200` derivative with it, which
 * matters more than the original: the derivative reuses the original's
 * download token, so a surviving copy stays publicly readable by
 * anyone who kept the URL.
 */
export const onPinBoxDeleted = onDocumentDeleted("pinboxes/{pinboxId}", async (event) => {
  const data = event.data?.data();
  if (!data) return;
  const path = pinboxPhotoPath(data.ownerId, event.params.pinboxId);
  if (path) await deleteStorageFile(path);
});

export const onVenueEventDeleted = onDocumentDeleted("venueEvents/{eventId}", async (event) => {
  const data = event.data?.data();
  if (!data) return;
  // Events store no `ownerId` of their own — the venue holds it, and
  // the cover was uploaded under that uid.
  const venueSnap = await db.collection("venues").doc(data.venueId as string).get();
  const path = eventCoverPath(venueSnap.data()?.ownerId, event.params.eventId);
  if (path) await deleteStorageFile(path);
});

export const onPostDeleted = onDocumentDeleted("posts/{postId}", async (event) => {
  const postRef = event.data?.ref;
  if (!postRef) return;

  const [likesSnap, commentsSnap] = await Promise.all([
    postRef.collection("likes").get(),
    postRef.collection("comments").get(),
  ]);

  await Promise.all([...likesSnap.docs, ...commentsSnap.docs].map((doc) => doc.ref.delete()));

  // Post media is the one case that cannot be DERIVED: the file name is
  // the upload's microsecond timestamp, allocated before the document
  // exists (`firebase_post_repository.dart:36`), so nothing server-side
  // can reconstruct it. It is CONFINED instead — the stored URL is
  // only honoured when it resolves under this post's own author folder,
  // which `firestore.rules` pinned to the author's uid at create time.
  // Same reasoning, and the same helper shape, as the admin panel's
  // `confinedStoragePath`; see admin-panel/src/lib/storage-path.ts for
  // the arbitrary-deletion vector both of them close.
  //
  // Until now this trigger cleaned only the subcollections. Whether the
  // image survived depended on WHICH path deleted the post: the client
  // removed it best-effort, the admin panel did not (until the
  // 2026-08-31 audit), and nothing else did at all.
  const data = event.data?.data();
  const ownerUid = data?.userId;
  if (typeof ownerUid !== "string") return;
  const prefix = `posts/${ownerUid}/`;
  for (const url of [data?.mediaUrl, data?.thumbnailUrl]) {
    const path = confinedStoragePath(url, prefix);
    if (path) await deleteStorageFile(path);
  }
});

/**
 * Deleting a comment (by its author, or the post owner — see
 * firestore.rules) doesn't cascade to its own `likes` subcollection,
 * and should also give back the one it added to the post's
 * `commentsCount`. Fires for both top-level comments and replies alike
 * (they're the same subcollection).
 */
export const onCommentDeleted = onDocumentDeleted("posts/{postId}/comments/{commentId}", async (event) => {
  const commentRef = event.data?.ref;
  if (commentRef) {
    const likesSnap = await commentRef.collection("likes").get();
    await Promise.all(likesSnap.docs.map((doc) => doc.ref.delete()));

    // A deleted top-level comment's own replies don't cascade-delete on
    // their own — Firestore has no such relationship, they're just
    // sibling docs in the same flat `comments` subcollection with a
    // `replyToCommentId` pointer (see `PostComment`'s doc comment).
    // Left alone, a reply becomes an orphan: invisible in the UI
    // (`comments_sheet.dart` only ever renders a reply nested under its
    // parent, which is now gone) but still counted in `commentsCount`.
    // Deleting them here re-triggers this same function for each —
    // which handles their own `likes` cleanup and counter decrement
    // with no special-casing needed, since a reply never has replies of
    // its own, so this can't recurse further than one level.
    const repliesSnap = await commentRef.parent.where("replyToCommentId", "==", commentRef.id).get();
    await Promise.all(repliesSnap.docs.map((doc) => doc.ref.delete()));
  }
  await bumpPostCounter(event.params.postId, "commentsCount", -1);
});

async function bumpCommentCounter(postId: string, commentId: string, delta: 1 | -1): Promise<void> {
  // Same clamp-at-0 reasoning as bumpPostCounter above.
  const ref = db.collection("posts").doc(postId).collection("comments").doc(commentId);
  try {
    await db.runTransaction(async (tx) => {
      const snap = await tx.get(ref);
      if (!snap.exists) return;
      const current = (snap.data()?.likesCount as number | undefined) ?? 0;
      tx.update(ref, { likesCount: Math.max(0, current + delta) });
    });
  } catch {
    // Comment no longer exists — nothing to bump.
  }
}

export const onCommentLikeCreated = onDocumentCreated("posts/{postId}/comments/{commentId}/likes/{uid}", async (event) => {
  await bumpCommentCounter(event.params.postId, event.params.commentId, 1);
});

export const onCommentLikeDeleted = onDocumentDeleted("posts/{postId}/comments/{commentId}/likes/{uid}", async (event) => {
  await bumpCommentCounter(event.params.postId, event.params.commentId, -1);
});

const CHAT_PREVIEW_LABELS: Record<string, string> = {
  image: "📷 Şəkil",
  video: "🎥 Video",
  audio: "🎤 Səsli mesaj",
  post: "📎 Paylaşım",
};

/**
 * Düzəliş Prompt 10 / INFRA-20, RT-7 — closes a real privacy gap: the
 * client's own `deleteChat` (`FirebaseChatRepository.deleteChat`) only
 * ever deletes the `chats/{chatId}` doc itself — Firestore never
 * cascades a delete to subcollections, so `messages` (every message
 * either participant ever sent) survived untouched: unreachable from
 * `watchChats` (which queries the now-gone parent), but still fully
 * present and directly readable by chatId. Worse, because `chatIdFor`
 * is deterministic (sorted participant uids), the exact same two
 * people messaging each other again later recreates a
 * `chats/{chatId}` doc at the IDENTICAL id, and `watchMessages` pulls
 * the old, never-deleted history right back in — "I deleted this
 * conversation" secretly wasn't true, and could silently un-delete
 * itself.
 *
 * Runs as a trigger (not inlined into a `deleteChat` Cloud Function)
 * so it fires regardless of which code path removes the chat doc.
 * Also cleans up every message's Storage file — `deleteChat` never
 * touched Storage either, so every photo/video/voice note ever sent in
 * the chat (both directions) leaked permanently. Safe to unconditionally
 * delete each message's file now (and only now): Düzəliş Prompt 10's
 * `forwardChatMedia` fix means a forwarded copy always has its OWN
 * independent Storage object, so deleting one message's file here can
 * never break a DIFFERENT message living in some other chat.
 */
/**
 * P0 / H-4 — hard-deletes a chat once BOTH participants have hidden it.
 *
 * `firestore.rules` no longer lets any client delete a `chats/{chatId}`
 * document (one participant deleting it wiped the other's history and
 * media, see that rule's comment). "Söhbəti sil" now sets
 * `hiddenFor.{own uid}` instead, and this trigger is what finally
 * removes the document — deliberately by deleting the SAME document a
 * client used to delete, so `onChatDeleted` below fires exactly as it
 * always did and the messages plus their Storage objects are cleaned up
 * through the one existing cascade rather than a second, parallel one.
 *
 * Fires only on the transition INTO the fully-hidden state (`before`
 * not hidden by everyone, `after` hidden by everyone) — otherwise every
 * subsequent write to an already-fully-hidden document would re-attempt
 * the delete.
 */
export const hardDeleteFullyHiddenChat = onDocumentUpdated("chats/{chatId}", async (event) => {
  const before = event.data?.before.data();
  const after = event.data?.after.data();
  if (!before || !after) return;

  const participants = after.participants;
  if (isChatHiddenByEveryone(participants, before.hiddenFor)) return; // already handled
  if (!isChatHiddenByEveryone(participants, after.hiddenFor)) return;

  logger.info("hardDeleteFullyHiddenChat: both participants hid this chat, deleting", {
    chatId: event.params.chatId,
  });
  // Deleting the parent document is what triggers `onChatDeleted`,
  // which owns the messages + media cleanup.
  await event.data!.after.ref.delete();
});

export const onChatDeleted = onDocumentDeleted("chats/{chatId}", async (event) => {
  const chatRef = event.data?.ref;
  if (!chatRef) return;
  const { chatId } = event.params;

  const messagesSnap = await chatRef.collection("messages").get();
  await Promise.all(
    messagesSnap.docs.map(async (doc) => {
      // P0 / C-1 — the Storage path is recomputed from (chatId, this
      // message's own id, its rules-pinned `senderId`, its `type`),
      // NOT read out of the client-written `mediaUrl` field. See
      // [chatMediaPathForMessage]'s doc comment for the full reasoning:
      // the old `deleteStorageObjectByUrl(mediaUrl)` here accepted any
      // string containing "/o/" as a bucket path and deleted it with
      // Admin SDK privileges, and it also destroyed the ORIGINAL post
      // media of any shared-post message in the thread.
      await deleteChatMessageMedia(chatId, doc.id, doc.data());
      await doc.ref.delete();
    }),
  );
});

// Post-launch QA — "hər kəs üçün sil" (`deleteMessageForEveryone`, a
// raw client delete of the message doc, see `FirebaseChatRepository`)
// used to leave `chats/{chatId}`'s own `lastMessage`/`lastMessageType`/
// `lastMessageAt`/`lastMessageSenderId` completely untouched — those
// fields are a denormalized TEXT COPY taken once at send time, never a
// live reference to the message doc, so the chats-list preview kept
// showing a message's content even after that message was gone from
// the conversation itself. This is exactly the privacy gap the report
// called out: the person who just deleted a message "for everyone" has
// no way to know their own text is still visible in the list.
//
// Only recomputes when the just-deleted message WAS the chat's current
// preview — compared via `chats.lastMessageAt.isEqual(deletedMessage.
// sentAt)`, which is reliable because both are written from the SAME
// `FieldValue.serverTimestamp()` commit inside `_sendMessage`'s one
// transaction. Deleting an OLDER message (already superseded by a
// newer one) is an explicit no-op — the preview is correctly whatever
// it already was, no write happens at all.
export const onChatMessageDeleted = onDocumentDeleted(
  "chats/{chatId}/messages/{messageId}",
  async (event) => {
    const deletedData = event.data?.data();
    const deletedSentAt = deletedData?.sentAt as Timestamp | undefined;
    if (!deletedSentAt) return;

    const { chatId } = event.params;
    const chatRef = db.collection("chats").doc(chatId);
    const chatSnap = await chatRef.get();
    // The whole chat may be mid-cascade-delete (`onChatDeleted` above,
    // which deletes every message doc too) — nothing left to update.
    if (!chatSnap.exists) return;

    const currentLastMessageAt = chatSnap.data()?.lastMessageAt as Timestamp | undefined;
    if (!currentLastMessageAt || !currentLastMessageAt.isEqual(deletedSentAt)) {
      return; // Not the current preview — explicit no-op, nothing to recompute.
    }

    const remainingSnap = await chatRef.collection("messages").orderBy("sentAt", "desc").limit(1).get();

    if (remainingSnap.empty) {
      await chatRef.update({ lastMessage: "", lastMessageType: "deleted" });
      return;
    }

    const remaining = remainingSnap.docs[0].data();
    await chatRef.update({
      lastMessage: (remaining.text as string | undefined) ?? "",
      lastMessageType: remaining.type as string,
      lastMessageAt: remaining.sentAt,
      lastMessageSenderId: remaining.senderId as string | undefined,
    });
  },
);

// How many of a chat's most-recent messages `onChatMessageDeletedForUser`
// below scans, newest-first, to find the first one NOT in the uid's own
// `deletedFor` — Firestore has no "array-not-contains" query, so this is
// an in-memory filter over a bounded page rather than a real query.
// Matches this file's existing "bounded candidate scan" convention (see
// `NEARBY_CANDIDATE_SCAN_LIMIT`). A uid who has "məndən sil"-ed MORE than
// this many consecutive most-recent messages (unusual — normal use
// deletes one at a time) would fall through to the `deleted` fallback
// below even though an older, still-visible-to-them message technically
// exists further back; documented limitation, not treated as a bug.
const LAST_MESSAGE_OVERRIDE_SCAN_LIMIT = 100;

// Post-launch QA — "məndən sil" (`deleteMessageForMe`, which only ever
// adds the caller's own uid to that ONE message's `deletedFor`) is the
// harder half of the same bug: `chats/{chatId}` is the ONE doc BOTH
// participants read for the list preview, so nothing here may depend on
// who's asking — a per-user override map on that same doc
// (`lastMessageOverride.{uid}`, exactly mirroring how `unreadCount`/
// `pinnedBy`/`archivedBy`/`mutedBy` already track other per-participant
// state on this one shared doc) is what lets the OTHER participant's
// view stay completely unaffected. Written ONLY here (Admin SDK,
// bypasses rules) — `firestore.rules`' `chats/{chatId}` update rule
// explicitly blocks this field from any client write, so neither
// participant can fabricate what the OTHER one sees in their own list.
//
// Same "was this actually their current preview" guard as
// `onChatMessageDeleted` above, just evaluated per-uid against either
// their existing override's timestamp or (if they have none yet) the
// shared `lastMessageAt` — hiding an old, already-superseded message is
// a no-op for that uid exactly like it is for the shared fields.
export const onChatMessageDeletedForUser = onDocumentUpdated(
  "chats/{chatId}/messages/{messageId}",
  async (event) => {
    const before = event.data?.before.data();
    const after = event.data?.after.data();
    if (!before || !after) return;

    const beforeDeletedFor = (before.deletedFor as string[] | undefined) ?? [];
    const afterDeletedFor = (after.deletedFor as string[] | undefined) ?? [];
    if (afterDeletedFor.length <= beforeDeletedFor.length) return; // not a new self-hide
    const newlyHiddenFor = afterDeletedFor.filter((uid) => !beforeDeletedFor.includes(uid));
    if (newlyHiddenFor.length === 0) return;

    const messageSentAt = after.sentAt as Timestamp | undefined;
    if (!messageSentAt) return;

    const { chatId } = event.params;
    const chatRef = db.collection("chats").doc(chatId);
    const chatSnap = await chatRef.get();
    if (!chatSnap.exists) return;

    const chatData = chatSnap.data()!;
    const sharedLastMessageAt = chatData.lastMessageAt as Timestamp | undefined;
    const existingOverride = (chatData.lastMessageOverride as Record<string, { at?: Timestamp }> | undefined) ?? {};

    const updates: Record<string, unknown> = {};
    for (const uid of newlyHiddenFor) {
      const uidCurrentPreviewAt = existingOverride[uid]?.at ?? sharedLastMessageAt;
      if (!uidCurrentPreviewAt || !uidCurrentPreviewAt.isEqual(messageSentAt)) continue;

      const recentSnap = await chatRef
        .collection("messages")
        .orderBy("sentAt", "desc")
        .limit(LAST_MESSAGE_OVERRIDE_SCAN_LIMIT)
        .get();
      const visible = recentSnap.docs.find(
        (doc) => !((doc.data().deletedFor as string[] | undefined) ?? []).includes(uid),
      );

      updates[`lastMessageOverride.${uid}`] = visible
        ? {
            text: (visible.data().text as string | undefined) ?? "",
            type: visible.data().type as string,
            at: visible.data().sentAt,
          }
        : { text: "", type: "deleted", at: messageSentAt };
    }

    if (Object.keys(updates).length > 0) {
      await chatRef.update(updates);
    }
  },
);

/**
 * Sends a real push notification to the recipient's device(s) whenever
 * a new chat message is written — the client only ever writes the
 * message doc itself (see `FirebaseChatRepository._sendMessage`), it
 * never sends a push directly, so this trigger is the only thing that
 * makes a message actually reach the recipient's phone in real time
 * while the app isn't open.
 *
 * Skips sending (silently, not an error) when: the recipient muted
 * this specific chat (`chats/{chatId}.mutedBy[receiverId]`), their
 * global "Mesajlar" notification category or push master toggle is
 * off (`users/{receiverId}.notificationPreferences`), or they have no
 * registered device tokens yet.
 */
export const onChatMessageCreated = onDocumentCreated(
  "chats/{chatId}/messages/{messageId}",
  async (event) => {
    const message = event.data?.data();
    if (!message) return;

    const { chatId } = event.params;
    const senderId = message.senderId as string | undefined;
    const receiverId = message.receiverId as string | undefined;
    if (!senderId || !receiverId) return;

    // P0 / H-4 — a new message un-hides the conversation for BOTH
    // sides. Without this, "Söhbəti sil" would be permanent from the
    // hider's point of view: the other participant could keep writing
    // and the thread would never reappear.
    //
    // KNOWN RACE, accepted: this trigger runs asynchronously after the
    // message document is written, so a user who hides a chat in the
    // sub-second window between those two events has their hide undone
    // and sees the conversation reappear. Observed for real while
    // building the end-to-end cascade test, which initially failed for
    // exactly this reason. Left as-is deliberately — the failure
    // direction is to SHOW a conversation rather than hide one, which
    // is the safe side for a change whose entire purpose is stopping
    // one participant from making a thread disappear; it is
    // self-correcting (hide again); and the alternative (timestamping
    // every `hiddenFor` entry and comparing against the message's own
    // `sentAt`) buys a one-second edge case at the cost of a more
    // complex field shape that `firestore.rules` would then also have
    // to validate.
    //
    // Done server-side, and FIRST, on purpose. Server-side because
    // `firestore.rules` only lets a client set its OWN `hiddenFor` key,
    // so the sender structurally cannot clear the receiver's. First
    // because everything below this point has early returns (muted
    // receiver, receiver already has the chat open) that are about
    // whether to PUSH a notification — none of them should decide
    // whether the conversation is visible at all.
    const chatRef = db.collection("chats").doc(chatId);
    const chatSnapForHidden = await chatRef.get();
    const hiddenFor = (chatSnapForHidden.data()?.hiddenFor ?? {}) as Record<string, boolean>;
    if (hiddenFor[senderId] === true || hiddenFor[receiverId] === true) {
      await chatRef.update({ [`hiddenFor.${senderId}`]: false, [`hiddenFor.${receiverId}`]: false });
    }

    const chatSnap = await db.collection("chats").doc(chatId).get();
    const mutedBy = (chatSnap.data()?.mutedBy ?? {}) as Record<string, boolean>;
    if (mutedBy[receiverId] === true) return;

    const [senderSnap, receiverSnap, receiverPrivateSnap] = await Promise.all([
      db.collection("users").doc(senderId).get(),
      db.collection("users").doc(receiverId).get(),
      privateDataRef(receiverId).get(),
    ]);
    const receiverData = receiverSnap.data();
    if (!receiverData) return;
    const receiverPrivateData = receiverPrivateSnap.data() ?? {};

    // Receiver has this exact chat open right now (foreground) — see
    // `activeChatId` on `users/{uid}/private/data`, set/cleared by
    // ChatConversationScreen. A push while they're already looking at
    // the conversation would just be noise (and could double-count as
    // an unread badge blip); the in-app message list itself is the
    // real-time signal in that case.
    if (receiverPrivateData.activeChatId === chatId) return;

    const prefs = receiverPrivateData.notificationPreferences ?? {};
    const pushEnabled = prefs.pushEnabled ?? true;
    const messagesEnabled = prefs.messages ?? true;
    if (!pushEnabled || !messagesEnabled) return;

    const tokens = (receiverPrivateData.fcmTokens ?? []) as string[];
    if (tokens.length === 0) return;

    const senderData = senderSnap.data();
    const senderName = [senderData?.firstName, senderData?.lastName]
      .filter((part) => typeof part === "string" && part.length > 0)
      .join(" ") || "PeakPin";

    // Never the raw message text — a push can sit on a lock screen for
    // anyone nearby to read. Non-text types already used a generic
    // type label (CHAT_PREVIEW_LABELS); text now gets the same
    // treatment instead of leaking its content.
    const type = message.type as string | undefined;
    const body = type && type !== "text" ? CHAT_PREVIEW_LABELS[type] ?? "Yeni mesaj" : "Sizə mesaj göndərdi";

    // No custom Android notification channel — the client doesn't create
    // one (would need flutter_local_notifications), so this relies on
    // FlutterFire's auto-created default channel rather than pointing at
    // a channelId that doesn't exist.
    const response = await messaging.sendEachForMulticast({
      tokens,
      notification: { title: senderName, body },
      data: { type: "chat_message", chatId, senderId },
      android: { priority: "high" },
      apns: { payload: { aps: { sound: "default" } } },
    });

    await pruneStaleTokensAndLogFailures(receiverId, tokens, response);
  }
);

function isUnregisteredTokenError(code?: string): boolean {
  return code === "messaging/registration-token-not-registered" || code === "messaging/invalid-registration-token";
}

/**
 * Faza 5 (bildiriş sistemi tamamlanması) — the admin panel's Bell
 * icon's data source. Deliberately minimal, per that phase's own
 * scope: one Firestore doc, no web-push/VAPID infra. Sits alongside
 * (not instead of) the existing privacy@peakpin.app email below —
 * that's an out-of-band alert an admin sees even with the panel
 * closed; this is the in-panel, persistent, markable-read history the
 * Bell button previously had no data behind at all.
 */
async function notifyAdmins(params: {
  type: string;
  message: string;
  targetType: string;
  targetId: string;
}): Promise<void> {
  await db.collection("adminNotifications").add({
    ...params,
    read: false,
    createdAt: FieldValue.serverTimestamp(),
  });
}

/**
 * Relays every new user report (from `report_user_sheet.dart`'s
 * "Report user" flow, e.g. harassment, spam, fake profile) to
 * privacy@peakpin.app — this collection previously had zero
 * notification path, only the admin panel's own manual review queue.
 */
export const onUserReportCreated = onDocumentCreated(
  { document: "reports/{reportId}", secrets: [resendApiKey] },
  async (event) => {
    const data = event.data?.data();
    if (!data) return;

    const reporterId = data.reporterId as string | undefined;
    const reportedUserId = data.reportedUserId as string | undefined;
    const reason = (data.reason as string | undefined) ?? "(səbəb qeyd edilməyib)";
    if (!reporterId || !reportedUserId) return;

    const [reporter, reported] = await Promise.all([
      getUserDisplayInfo(reporterId),
      getUserDisplayInfo(reportedUserId),
    ]);

    await sendPrivacyNotificationEmail(
      "Yeni istifadəçi şikayəti — PeakPin",
      `<p><strong>Şikayətçi:</strong> ${escapeHtml(reporter.name)} (${reporterId})</p>
       <p><strong>Şikayət olunan:</strong> ${escapeHtml(reported.name)} (${reportedUserId})</p>
       <p><strong>Səbəb:</strong> ${escapeHtml(reason)}</p>
       ${data.chatId ? `<p><strong>Söhbət ID:</strong> ${escapeHtml(String(data.chatId))}</p>` : ""}
       <p>Baxmaq üçün admin paneldəki "İstifadəçilər" bölümünə keçin.</p>`
    );

    await notifyAdmins({
      type: "report.user",
      message: `${reporter.name} → ${reported.name}: ${reason}`,
      targetType: "user",
      targetId: reportedUserId,
    });
  }
);

/**
 * Relays every new event report ("Tədbir şikayətləri", `reportEvent()`
 * in firebase_venue_event_repository.dart) to privacy@peakpin.app —
 * same reasoning as onUserReportCreated above.
 */
export const onEventReportCreated = onDocumentCreated(
  { document: "eventReports/{reportId}", secrets: [resendApiKey] },
  async (event) => {
    const data = event.data?.data();
    if (!data) return;

    const eventId = data.eventId as string | undefined;
    const reportedBy = data.reportedBy as string | undefined;
    const reason = (data.reason as string | undefined) ?? "(səbəb qeyd edilməyib)";
    if (!eventId || !reportedBy) return;

    const [reporter, eventSnap] = await Promise.all([
      getUserDisplayInfo(reportedBy),
      db.collection("venueEvents").doc(eventId).get(),
    ]);
    const eventTitle = (eventSnap.data()?.title as string | undefined) ?? eventId;

    await sendPrivacyNotificationEmail(
      "Yeni tədbir şikayəti — PeakPin",
      `<p><strong>Şikayətçi:</strong> ${escapeHtml(reporter.name)} (${reportedBy})</p>
       <p><strong>Tədbir:</strong> ${escapeHtml(eventTitle)} (${eventId})</p>
       <p><strong>Səbəb:</strong> ${escapeHtml(reason)}</p>
       <p>Baxmaq üçün admin paneldəki "Tədbir şikayətləri" bölümünə keçin.</p>`
    );

    await notifyAdmins({
      type: "report.event",
      message: `${reporter.name} → "${eventTitle}": ${reason}`,
      targetType: "event",
      targetId: eventId,
    });
  }
);

/**
 * Relays every new review report ("Rəy şikayətləri", `reportReview()`
 * in firebase_review_repository.dart) — same shape as
 * `onEventReportCreated` above. A review's own author/the venue owner
 * can't delete it directly (see `Review`'s doc comment); this queue,
 * resolved from the admin panel's "Review Reports" page, is the only
 * removal path.
 */
export const onReviewReportCreated = onDocumentCreated(
  { document: "reviewReports/{reportId}", secrets: [resendApiKey] },
  async (event) => {
    const data = event.data?.data();
    if (!data) return;

    const reviewId = data.reviewId as string | undefined;
    const reporterId = data.reporterId as string | undefined;
    const reason = (data.reason as string | undefined) ?? "(səbəb qeyd edilməyib)";
    if (!reviewId || !reporterId) return;

    const [reporter, reviewSnap] = await Promise.all([getUserDisplayInfo(reporterId), db.collection("reviews").doc(reviewId).get()]);
    const reviewComment = (reviewSnap.data()?.comment as string | undefined) ?? reviewId;

    await sendPrivacyNotificationEmail(
      "Yeni rəy şikayəti — PeakPin",
      `<p><strong>Şikayətçi:</strong> ${escapeHtml(reporter.name)} (${reporterId})</p>
       <p><strong>Rəy:</strong> ${escapeHtml(reviewComment)} (${reviewId})</p>
       <p><strong>Səbəb:</strong> ${escapeHtml(reason)}</p>
       <p>Baxmaq üçün admin paneldəki "Rəy şikayətləri" bölümünə keçin.</p>`
    );

    await notifyAdmins({
      type: "report.review",
      message: `${reporter.name} → "${reviewComment}": ${reason}`,
      targetType: "review",
      targetId: reviewId,
    });
  }
);

/** How many recent device signatures to remember per account — an
 * older one just quietly ages out (LRU-ish, most-recent-first) rather
 * than growing the array forever. */
const KNOWN_DEVICE_SIGNATURE_LIMIT = 8;

/**
 * Fires before every sign-in, across every provider/platform — a
 * Blocking Function that needs no client-side change, and is purely
 * observational: this NEVER throws, so a bug here can never lock
 * anyone out of their own account — the entire body is wrapped in
 * try/catch specifically because blocking a sign-in is a far worse
 * failure mode than silently missing one security alert.
 *
 * Keys a "known devices" list on `users/{uid}/private/data.knownDeviceSignatures`
 * off a hash of the sign-in's `userAgent` (Identity Platform provides
 * this on the event directly — no client-side device-fingerprinting
 * code needed). A signature not already in that list means: notify
 * (`security`, `kind: 'new_device'`) and remember it; one that's
 * already there is an ordinary repeat sign-in from the same
 * app/OS/browser combination — nothing to say. An account with an
 * EMPTY list (brand new, or every prior sign-in predates this
 * function) just silently records its first signature instead of
 * alerting — there's no earlier device to compare against yet, so a
 * "new device" notice on someone's very first-ever sign-in would be
 * meaningless noise, not a security signal.
 *
 * Must run in us-central1 — Identity Platform blocking functions are
 * restricted to that region regardless of where the rest of this
 * codebase's functions are deployed.
 */
export const notifyOnNewDeviceSignIn = beforeUserSignedIn({ region: "us-central1" }, async (event) => {
  try {
    const uid = event.data?.uid;
    if (!uid) return;

    // A brand-new account has no `users/{uid}` doc yet — completeOnboarding
    // (client-side, onboarding_screen.dart) is what creates it, once the
    // owner actually fills in name/birth date/username. Touching the doc
    // here (even just to record a device signature) would create it
    // prematurely with none of that, which defeats the client's own
    // "does users/{uid} exist yet" new-user gate (AuthRepository
    // ._hydrateFromFirestore/_afterSignIn) — a first-time signer would
    // silently skip the onboarding screen entirely, landing in the main
    // app with an empty profile. There's also nothing meaningful to
    // compare a "new device" against on someone's very first sign-in
    // anyway (see this function's own doc comment above).
    //
    // event.additionalUserInfo?.isNewUser alone isn't reliable here —
    // confirmed via a live repro that it's falsy on this event for a
    // brand-new EMAIL_PASSWORD sign-up (unlike Apple/Google), which let
    // this function slip through and create the doc anyway. Comparing
    // creationTime/lastSignInTime is Firebase's own documented
    // work-around for exactly this gap and holds for every provider.
    const creationTime = event.data?.metadata?.creationTime;
    const lastSignInTime = event.data?.metadata?.lastSignInTime;
    const isNewUser = event.additionalUserInfo?.isNewUser || (!!creationTime && creationTime === lastSignInTime);
    if (isNewUser) return;

    const signature = createHash("sha256").update(event.userAgent || "unknown").digest("hex").slice(0, 16);

    const privateRef = privateDataRef(uid);
    const privateSnap = await privateRef.get();
    const known = (privateSnap.data()?.knownDeviceSignatures as string[] | undefined) ?? [];

    if (known.includes(signature)) return;

    if (known.length > 0) {
      await notifyUser({
        uid,
        category: "security",
        type: "security",
        title: "Yeni cihazdan giriş",
        body: "Hesabınıza tanış olmayan bir cihazdan daxil olundu. Bu siz deyilsinizsə, dərhal dəstəklə əlaqə saxlayın.",
        params: { kind: "new_device" },
      });
    }

    await privateRef.set(
      { knownDeviceSignatures: [signature, ...known.filter((s) => s !== signature)].slice(0, KNOWN_DEVICE_SIGNATURE_LIMIT) },
      { merge: true },
    );
  } catch (e) {
    logger.error("notifyOnNewDeviceSignIn failed", e);
  }
});

/**
 * PinBox Faza 7 — the ONLY path that ever creates a `pinboxOrders` doc
 * or decrements `pinboxes/{id}.stockRemaining` (both locked from direct
 * client writes in firestore.rules — see those rules' own doc
 * comments). Stock check + decrement + order creation all happen in one
 * transaction so two buyers hitting "Ödə" on the last unit at the same
 * moment can never both succeed — the loser gets a clean
 * `failed-precondition`, not an oversold box.
 *
 * No real payment gateway is wired yet (see `core/data/listing_payment.dart`'s
 * own doc comment — the same "no provider, write straight to
 * completed" stub every other listing type already uses); this
 * function stands in for "payment captured" the same way. Once a real
 * gateway exists, its webhook becomes the trigger for this same
 * transaction instead of a client-initiated call, same migration path
 * `listing_payment.dart` already describes.
 *
 * Per the product's explicit "ləğv edilə bilməz" rule, there's no
 * corresponding "cancel/refund" callable — a reservation is final the
 * moment this function returns.
 */
export const reservePinBoxOrder = onCall(
  // App Check enforcement qəsdən `false`-dur — iOS DeviceCheck
  // qeydiyyatı gözlənilir (səbəb və simptom: bu faylın başındakı
  // şərh). Açılma şərti: Firebase Console → App Check-də HƏR İKİ
  // platformada təsdiqlənmə faizi sabit yüksək olduqda.
  { region: "us-central1", secrets: [epointPublicKey, epointPrivateKey, epointEnv], enforceAppCheck: false },
  async (request) => {
    const uid = request.auth?.uid;
    if (!uid) throw new HttpsError("unauthenticated", "Bu əməliyyat üçün daxil olmalısınız.");
    await assertActiveUser(uid);
    // Düzəliş Prompt 8 / RT-29 — stock is decremented right away, before
    // payment confirms (see this function's own doc comment above); an
    // uncapped reservation rate is a free way to "hold" a competitor's
    // entire stock without ever paying.
    await enforceRateLimit("reserve", uid, 10, 600);

    const pinboxId = request.data?.pinboxId as string | undefined;
    if (!pinboxId) throw new HttpsError("invalid-argument", "pinboxId tələb olunur.");
    const quantity = (request.data?.quantity as number | undefined) ?? 1;
    if (!Number.isInteger(quantity) || quantity < 1) {
      throw new HttpsError("invalid-argument", "quantity müsbət tam ədəd olmalıdır.");
    }

    const pinboxRef = db.collection("pinboxes").doc(pinboxId);
    const orderRef = db.collection("pinboxOrders").doc();

    // Stock is held (decremented) right away, same as before — only the
    // order's own status changes, sitting in `awaiting_payment` until
    // the Epoint webhook confirms the charge. This keeps the box's
    // displayed stock accurate the instant checkout starts, and a
    // declined/abandoned payment gives the held unit back via
    // `applyPaymentOutcome`'s failure branch above.
    const { venueId, pinboxTitle, amount } = await db.runTransaction(async (tx) => {
      const snap = await tx.get(pinboxRef);
      if (!snap.exists) throw new HttpsError("not-found", "PinBox tapılmadı.");
      const data = snap.data()!;

      // The venue behind the box must still exist AND still be approved.
      // This function previously read no venue at all — it validated the
      // PinBox document and nothing else — which meant a box whose
      // owner had deleted their account, or whose venue had been
      // rejected or suspended for non-payment, still took real money:
      // discovery filters only on `status == "active"` (see
      // `FirebasePinBoxRemoteDatasource`), the charge went through, a
      // `venuePayouts` row was written with `ownerId: null`, and
      // `redeemPinBoxOrder` then refused every redemption attempt
      // because it requires the venue's owner. The buyer paid for
      // something nobody could hand over.
      //
      // Read inside the transaction, not before it, so a venue deleted
      // between the check and the stock decrement cannot slip through.
      const venueSnap = await tx.get(db.collection("venues").doc(data.venueId as string));
      if (!venueSnap.exists) throw new HttpsError("failed-precondition", "venue-unavailable");
      if (venueSnap.data()?.status !== "approved") {
        throw new HttpsError("failed-precondition", "venue-unavailable");
      }

      if (data.status !== "active") throw new HttpsError("failed-precondition", "not-active");

      // Belt-and-braces against a stale client list: the Flutter
      // discovery fetches already exclude a box past its own
      // `pickupWindowEnd` (see `FirebasePinBoxRepository`'s doc comment),
      // but nothing flips `status` off `active` on a schedule the moment
      // that happens, so this transaction is the actual enforcement point.
      const pickupWindowEnd = (data.pickupWindowEnd as Timestamp | undefined)?.toDate();
      if (!pickupWindowEnd || pickupWindowEnd.getTime() <= Date.now()) {
        throw new HttpsError("failed-precondition", "pickup-window-ended");
      }

      const stockRemaining = (data.stockRemaining as number | undefined) ?? 0;
      if (stockRemaining < quantity) throw new HttpsError("failed-precondition", "sold-out");

      const newRemaining = stockRemaining - quantity;
      tx.update(pinboxRef, {
        stockRemaining: newRemaining,
        ...(newRemaining <= 0 ? { status: "soldOut" } : {}),
        updatedAt: FieldValue.serverTimestamp(),
      });

      const pinboxPrice = (data.pinboxPrice as number | undefined) ?? 0;
      const orderAmount = pinboxPrice * quantity;
      tx.set(orderRef, {
        pinboxId,
        venueId: data.venueId,
        buyerId: uid,
        quantity,
        amountPaid: orderAmount,
        status: "awaiting_payment",
        qrToken: null,
        qrTokenExpiresAt: null,
        createdAt: FieldValue.serverTimestamp(),
        redeemedAt: null,
      });

      return {
        venueId: data.venueId as string,
        pinboxTitle: (data.title as string | undefined) ?? "",
        amount: orderAmount,
      };
    });

    const description = `PinBox — ${pinboxTitle}`;
    const paymentRef = db.collection("payments").doc();
    await paymentRef.set({
      ownerId: uid,
      listingType: "pinboxOrder",
      listingId: orderRef.id,
      type: "pinbox_order",
      description,
      amount,
      currency: "AZN",
      status: "pending",
      venueId,
      createdAt: FieldValue.serverTimestamp(),
      updatedAt: FieldValue.serverTimestamp(),
    });

    // Stock/soldOut above already committed by the time this runs — if
    // Epoint's own request rejects outright (bad merchant credentials,
    // its API unreachable, etc.), no webhook will EVER arrive to
    // trigger applyPaymentOutcome's normal decline-handling path, so
    // the held unit would stay lost and the box would stay wrongly
    // soldOut forever. Reusing applyPaymentOutcome(..., false) here
    // runs the exact same restore-stock/reopen-box logic a real
    // declined charge would, then the original error is still
    // rethrown so the client sees the failure either way.
    try {
      const checkoutUrl = await startEpointCheckoutForPayment(paymentRef.id, amount, description);
      return { orderId: orderRef.id, checkoutUrl, feeAmount: amount, paymentId: paymentRef.id };
    } catch (e) {
      await applyPaymentOutcome(paymentRef.id, false);
      throw e;
    }
  },
);

/**
 * PinBox Faza 8 — QR bilet təhlükəsizliyi. Deliberately NOT a stateless
 * signed token (HMAC/JWT) — a random opaque value stored on the order
 * doc and compared server-side at redemption (PinBox Faza 9) is equally
 * secure here (the only writer is this function, via the Admin SDK;
 * `pinboxOrders` is already `allow write: if false` for every client)
 * and avoids standing up secret-key management for no extra protection.
 *
 * A 6-digit code, not a long random string — PinBox Faza 9's "no camera
 * scanning" constraint means redemption is a manual-entry fallback by
 * design, so the code itself has to be short enough for a cashier to
 * read off the buyer's screen and type in. 6 digits (1M possibilities)
 * inside a short, per-venue-scoped, [_qrTokenTtlMs]-bounded window is
 * the same trade-off banking/delivery OTP codes make, and the QR image
 * still encodes this exact value for a future camera-scan upgrade —
 * nothing else about the security model changes.
 *
 * Client calls this every 30s while the ticket screen is open (see
 * `PinBoxTicketScreen`'s refresh timer) — [_qrTokenTtlMs] deliberately
 * outlives that interval by a margin so a slow network round-trip never
 * shows an already-expired code, while still keeping any single
 * screenshot useless well within the same viewing session.
 */
const _qrTokenTtlMs = 40_000;

// App Check enforcement qəsdən `false`-dur — iOS DeviceCheck
// qeydiyyatı gözlənilir (səbəb və simptom: bu faylın başındakı
// şərh). Açılma şərti: Firebase Console → App Check-də HƏR İKİ
// platformada təsdiqlənmə faizi sabit yüksək olduqda.
export const generatePinBoxQrToken = onCall({ region: "us-central1", enforceAppCheck: false }, async (request) => {
  const uid = request.auth?.uid;
  if (!uid) throw new HttpsError("unauthenticated", "Bu əməliyyat üçün daxil olmalısınız.");
  await assertActiveUser(uid);

  const orderId = request.data?.orderId as string | undefined;
  if (!orderId) throw new HttpsError("invalid-argument", "orderId tələb olunur.");

  const orderRef = db.collection("pinboxOrders").doc(orderId);
  const orderSnap = await orderRef.get();
  if (!orderSnap.exists) throw new HttpsError("not-found", "Sifariş tapılmadı.");
  const order = orderSnap.data()!;

  if (order.buyerId !== uid) throw new HttpsError("permission-denied", "Bu sifarişin sahibi deyilsiniz.");
  if (order.status !== "reserved") throw new HttpsError("failed-precondition", "not-reserved");

  const pinboxSnap = await db.collection("pinboxes").doc(order.pinboxId as string).get();
  const pinbox = pinboxSnap.data();
  // Existence only — deliberately NOT `status === "approved"`.
  //
  // This order is already paid for. If the venue were suspended for an
  // unpaid subscription mid-pickup-window, refusing the QR code would
  // punish the BUYER for the owner's billing problem, and
  // `redeemPinBoxOrder` (which only requires the caller to own the
  // venue) would still let the handover happen. A venue that no longer
  // exists is different: nobody can ever redeem the code, so a clear
  // error beats a token that silently never works.
  const qrVenueSnap = await db.collection("venues").doc(order.venueId as string).get();
  if (!qrVenueSnap.exists) throw new HttpsError("failed-precondition", "venue-unavailable");
  const pickupStart = (pinbox?.pickupWindowStart as Timestamp | undefined)?.toMillis();
  const pickupEnd = (pinbox?.pickupWindowEnd as Timestamp | undefined)?.toMillis();
  const now = Date.now();
  if (pickupStart === undefined || pickupEnd === undefined || now < pickupStart || now > pickupEnd) {
    throw new HttpsError("failed-precondition", "outside-pickup-window");
  }

  const token = randomInt(100000, 1000000).toString();
  const expiresAtMs = now + _qrTokenTtlMs;
  await orderRef.update({ qrToken: token, qrTokenExpiresAt: Timestamp.fromMillis(expiresAtMs) });

  return { qrToken: token, qrTokenExpiresAtMs: expiresAtMs };
});

/**
 * PinBox Faza 9 — venue-side redemption. Manual code entry only (Faza 0
 * explicitly rules out building camera-scan infrastructure) — the
 * cashier reads the current 6-digit code off the buyer's ticket screen
 * and types it in. Matches ONLY against this venue's own still-
 * 'reserved' orders (never a global lookup) and rejects an expired
 * code the same way an unmatched one is rejected, so there's no way to
 * distinguish "wrong code" from "right code, too late" from the error
 * alone.
 */
// App Check enforcement qəsdən `false`-dur — iOS DeviceCheck
// qeydiyyatı gözlənilir (səbəb və simptom: bu faylın başındakı
// şərh). Açılma şərti: Firebase Console → App Check-də HƏR İKİ
// platformada təsdiqlənmə faizi sabit yüksək olduqda.
export const redeemPinBoxOrder = onCall({ region: "us-central1", enforceAppCheck: false }, async (request) => {
  const uid = request.auth?.uid;
  if (!uid) throw new HttpsError("unauthenticated", "Bu əməliyyat üçün daxil olmalısınız.");
  await assertActiveUser(uid);
  // Düzəliş Prompt 8 / RT-31, PAY-22 — `qrToken` is a 6-digit numeric
  // code (1,000,000 possibilities, 40s TTL, plain string-equality
  // compare, no attempt-lockout of its own — see `generatePinBoxQrToken`'s
  // doc comment). 30/5min is generous enough for a busy venue's real
  // back-to-back check-in flow while making brute-forcing a live code
  // computationally pointless within its own TTL.
  await enforceRateLimit("redeem", uid, 30, 300);

  const venueId = request.data?.venueId as string | undefined;
  const code = request.data?.code as string | undefined;
  if (!venueId || !code) throw new HttpsError("invalid-argument", "venueId və code tələb olunur.");

  const venueSnap = await db.collection("venues").doc(venueId).get();
  if (!venueSnap.exists) throw new HttpsError("not-found", "Məkan tapılmadı.");
  if (venueSnap.data()!.ownerId !== uid) throw new HttpsError("permission-denied", "Bu məkanın sahibi deyilsiniz.");

  const candidates = await db
    .collection("pinboxOrders")
    .where("venueId", "==", venueId)
    .where("status", "==", "reserved")
    .get();

  const now = Date.now();
  const match = candidates.docs.find((doc) => {
    const data = doc.data();
    const expiresAtMs = (data.qrTokenExpiresAt as Timestamp | undefined)?.toMillis();
    return data.qrToken === code && expiresAtMs !== undefined && expiresAtMs > now;
  });

  if (!match) throw new HttpsError("not-found", "Kod düzgün deyil və ya vaxtı keçib.");

  await match.ref.update({
    status: "completed",
    redeemedAt: FieldValue.serverTimestamp(),
    qrToken: null,
    qrTokenExpiresAt: null,
  });

  const orderData = match.data();
  const pinboxSnap = await db.collection("pinboxes").doc(orderData.pinboxId as string).get();

  return {
    orderId: match.id,
    pinboxTitle: (pinboxSnap.data()?.title as string | undefined) ?? "",
    quantity: orderData.quantity as number,
  };
});

const PINBOX_PAYOUT_COMMISSION_RATE = 0.15;

/**
 * Düzəliş Prompt 6 / K-11 — the PinBox side of `processPaymentRefund`.
 * A genuine policy change from PinBox's original "ləğv edilə bilməz"
 * design (see `reservePinBoxOrder`'s own doc comment) — deliberate, per
 * this prompt's explicit requirement, not an oversight.
 *
 * Marks the order `refunded` and settles its `venuePayouts` obligation
 * two different ways depending on whether the venue's 85% share was
 * already paid out:
 *  - `pending` (not yet paid) → simply `cancelled`. No money moved yet.
 *  - `paid` (already transferred) → NO automatic clawback exists (the
 *    money is in the venue's own account). The original row becomes
 *    `cancelled_after_payout` (kept, never deleted, as the audit
 *    trail), and a NEW row is written with a NEGATIVE `payoutAmount` —
 *    the standard accounting "debit line" shape, netted against this
 *    venue's next real payout by an admin (Müqavilə 7.7 is the
 *    contractual basis for deducting a refunded amount from the
 *    Sifarişçi's own share). The admin-panel UI to actually surface/
 *    settle this negative row is Prompt 9's scope — the data model is
 *    ready now.
 */
async function cancelPinBoxPayoutForRefund(orderId: string): Promise<void> {
  await db.runTransaction(async (tx) => {
    const orderRef = db.collection("pinboxOrders").doc(orderId);
    const payoutRef = db.collection("venuePayouts").doc(orderId);
    const [orderSnap, payoutSnap] = await Promise.all([tx.get(orderRef), tx.get(payoutRef)]);

    if (orderSnap.exists) {
      tx.update(orderRef, { status: "refunded", updatedAt: FieldValue.serverTimestamp() });
    }
    if (!payoutSnap.exists) return;

    const payout = payoutSnap.data()!;
    if (payout.status === "paid") {
      tx.update(payoutRef, { status: "cancelled_after_payout", updatedAt: FieldValue.serverTimestamp() });
      tx.set(db.collection("venuePayouts").doc(`${orderId}-debt`), {
        orderId,
        relatedPayoutId: orderId,
        venueId: payout.venueId ?? null,
        venueName: payout.venueName ?? "Naməlum",
        ownerId: payout.ownerId ?? null,
        pinboxId: payout.pinboxId ?? null,
        pinboxTitle: payout.pinboxTitle ?? "Naməlum",
        quantity: payout.quantity ?? null,
        grossAmount: payout.grossAmount ?? null,
        commissionRate: payout.commissionRate ?? PINBOX_PAYOUT_COMMISSION_RATE,
        commissionAmount: payout.commissionAmount ?? null,
        // Negative — this is money OWED BACK by the venue, not owed TO it.
        payoutAmount: typeof payout.payoutAmount === "number" ? -payout.payoutAmount : null,
        currency: payout.currency ?? "AZN",
        status: "debt",
        createdAt: FieldValue.serverTimestamp(),
        updatedAt: FieldValue.serverTimestamp(),
      });
    } else if (payout.status === "pending") {
      tx.update(payoutRef, { status: "cancelled", updatedAt: FieldValue.serverTimestamp() });
    }
    // Any other status (already cancelled/debt/cancelled_after_payout)
    // — no-op, this refund was already processed once.
  });
}

// ---------------------------------------------------------------------------
// Təklif yerləşdirmə haqqı (offer placement fee) — Epoint-backed, replaces
// the old flat 3 AZN "offer_listing" fee `listing_payment.dart`'s
// `createOffer` used to write straight to 'completed'. This is the first
// REAL payment gate in the app: an offer that needs the fee sits in
// `awaiting_payment` (invisible to everyone, including the admin queue)
// until `epointWebhook` confirms the charge, only then does it become a
// normal `pending` offer subject to the usual moderation review — payment
// confirmation and content moderation are deliberately two separate gates.
// ---------------------------------------------------------------------------

/**
 * Same subscription-tier AZN amount → placement-fee AZN amount mapping as
 * the PeakPin pricing sheet: 15/20/25/30 AZN monthly categories → 2/4/5/7
 * AZN per offer. Keyed off `venueSubscriptionFeeByCategory`'s own tier
 * value rather than duplicating a second 39-entry category table, so the
 * two can never drift against each other — a category's placement fee is
 * always a function of its subscription tier, never set independently.
 */
const OFFER_PLACEMENT_FEE_BY_SUBSCRIPTION_TIER: Record<number, number> = { 15: 2, 20: 4, 25: 5, 30: 7 };

function offerPlacementFeeForCategory(category: string): number | undefined {
  const tier = venueSubscriptionFeeByCategory[category];
  if (tier === undefined) return undefined;
  return OFFER_PLACEMENT_FEE_BY_SUBSCRIPTION_TIER[tier];
}

/**
 * Epoint's own hosted checkout page needs SOME URL to redirect the
 * browser to once the card form is done — these are plain static pages
 * (not part of this Cloud Functions deploy), separate from how the app
 * actually learns payment succeeded. That real signal is always
 * `epointWebhook` below flipping the `payments` doc to 'completed' and,
 * from there, the offer doc's own `status` field — the Flutter side
 * listens to that Firestore doc directly rather than trusting the
 * redirect, since the redirect only fires if the user's browser is still
 * open and connected, unlike the server-to-server webhook.
 */
// Served from admin-panel (admin.peakpin.app/payment/success|error), not
// peakpin.app — that domain is a separate Vercel project this codebase
// has no source access to, and peakpin.app/payment/{success,error}
// simply didn't exist (a real customer landed on a 404 after paying).
// admin-panel is a project this codebase DOES control, and Epoint
// doesn't care what domain the redirect is on. Move these to
// peakpin.app proper once that project's own source is available to
// build the same two pages there instead.
const EPOINT_SUCCESS_REDIRECT_URL = "https://admin.peakpin.app/payment/success";
const EPOINT_ERROR_REDIRECT_URL = "https://admin.peakpin.app/payment/error";

/**
 * Starts an Epoint checkout for one `payments` doc and returns the
 * hosted-checkout URL — shared by `submitOffer`'s fee branch and
 * `retryOfferPayment` so a failed/expired checkout can be re-started
 * without re-deriving the fee or creating a second payment doc.
 */
/**
 * Epoint permanently rejects a second `/api/1/request` for an `order_id`
 * it has already seen — "Duplicate order_id value" — even if the first
 * attempt was never completed (abandoned, card declined, network
 * error). `orderId` here is always the `payments/{paymentId}` doc's own
 * id, so once a payment doc has been through this function once, it can
 * NEVER be reused for a second checkout attempt. Stamping
 * `checkoutStartedAt` right after a successful call is what every
 * "reuse this pending payment or make a fresh one" call site (below)
 * checks before reusing — discovered via live testing against Epoint's
 * real API while building `retryVenueCreationPayment` (a retry
 * immediately hit this error), and confirmed to affect the pre-existing
 * `retryOfferPayment`/`ensurePendingSubscriptionPayment` reuse pattern
 * identically, not something specific to the venue-creation flow.
 */
async function startEpointCheckoutForPayment(
  paymentId: string,
  amount: number,
  description: string,
): Promise<string> {
  const { redirectUrl } = await createEpointCheckout({
    publicKey: epointPublicKeyValue(),
    privateKey: epointPrivateKeyValue(),
    env: epointEnvValue(),
    orderId: paymentId,
    amount,
    description,
    successRedirectUrl: EPOINT_SUCCESS_REDIRECT_URL,
    errorRedirectUrl: EPOINT_ERROR_REDIRECT_URL,
  });
  await db.collection("payments").doc(paymentId).update({ checkoutStartedAt: FieldValue.serverTimestamp() });
  return redirectUrl;
}

/**
 * Replaces the client's old direct `offers.add(...)` write (see
 * `FirebaseOfferRepository.createOffer`'s git history) — offer CREATE is
 * now Cloud-Function-only (firestore.rules: `allow create: if false`),
 * because the free-quota decrement below must be race-safe across two
 * near-simultaneous submissions from the same founding venue, which a
 * security-rules-only check can't guarantee the way a transaction can.
 *
 * `category`/`venueName`/`venuePhotoUrl`/`lat`/`lng`/`address`/`country`
 * are all read from the venue doc server-side, never trusted from the
 * client, same reasoning as this session's earlier "offer category must
 * always be its venue's category" fix — just enforced one layer deeper
 * now that creation itself moved server-side.
 */
export const submitOffer = onCall(
  { region: "us-central1", secrets: [epointPublicKey, epointPrivateKey, epointEnv], enforceAppCheck: false },
  async (request) => {
    const uid = request.auth?.uid;
    if (!uid) throw new HttpsError("unauthenticated", "Bu əməliyyat üçün daxil olmalısınız.");
    await assertActiveUser(uid);
    // P0 — same Epoint/moderation cost per call as `submitVenue`,
    // shared `submit-listing` counter, higher ceiling: offers are
    // created far more often than venues.
    await enforceRateLimit("submit-listing", uid, 10, 3600);

    const data = request.data as Record<string, unknown>;
    const clientOfferId = data.offerId as string | undefined;
    const venueId = data.venueId as string | undefined;
    const title = (data.title as string | undefined)?.trim();
    const description = (data.description as string | undefined)?.trim();
    const offerType = data.offerType as string | undefined;
    const startDateRaw = data.startDate as string | undefined;
    const endDateRaw = data.endDate as string | undefined;
    if (!clientOfferId || !venueId || !title || !description || !offerType || !startDateRaw || !endDateRaw) {
      throw new HttpsError("invalid-argument", "Tələb olunan sahələr çatışmır.");
    }

    const venueSnap = await db.collection("venues").doc(venueId).get();
    const venue = venueSnap.data();
    if (!venue) throw new HttpsError("not-found", "Məkan tapılmadı.");
    if (venue.ownerId !== uid) throw new HttpsError("permission-denied", "Bu məkanın sahibi deyilsiniz.");

    const category = venue.category as string | undefined;
    const fee = category ? offerPlacementFeeForCategory(category) : undefined;
    if (fee === undefined) {
      logger.error("submitOffer: no placement fee tier for category", { venueId, category });
      throw new HttpsError("failed-precondition", "Bu məkan kateqoriyası üçün haqq cədvəli tapılmadı.");
    }

    const lat = venue.lat as number;
    const lng = venue.lng as number;
    // Pre-allocated by the client (`allocateOfferId`) so the photo it
    // already uploaded to Storage under this id lands on the same
    // document — same pattern as the old direct-write flow, just
    // handed to this function instead of used in a client-side
    // `.set()`. A collision with an existing doc would mean the client
    // somehow replayed an id it already used, which allocateOfferId's
    // own randomness makes practically impossible; guarded anyway
    // rather than silently overwriting.
    const offerRef = db.collection("offers").doc(clientOfferId);
    if ((await offerRef.get()).exists) {
      throw new HttpsError("already-exists", "Bu ID artıq istifadə olunub.");
    }

    // P0 / H-5 — optional (an offer may carry no image), but if one is
    // supplied it must be ours.
    const offerImageUrl = data.imageUrl as string | undefined;
    if (offerImageUrl !== undefined) assertOwnStorageUrl(offerImageUrl, "imageUrl");

    const birthdayTargeting = await assertBirthdayTargeting(data, venueId);

    const baseOfferData = {
      ownerId: uid,
      venueId,
      venueName: (venue.name as string | undefined) ?? "",
      venuePhotoUrl: (venue.photoUrl as string | undefined) ?? null,
      lat,
      lng,
      position: { geopoint: new GeoPoint(lat, lng), geohash: geohashForLocation([lat, lng], 9) },
      address: (venue.address as string | undefined) ?? "",
      ...(venue.country ? { country: venue.country } : {}),
      category,
      title,
      description,
      offerType,
      discountValue: (data.discountValue as number | undefined) ?? null,
      startDate: Timestamp.fromDate(new Date(startDateRaw)),
      endDate: Timestamp.fromDate(new Date(endDateRaw)),
      imageUrl: (data.imageUrl as string | undefined) ?? null,
      terms: (data.terms as string | undefined) ?? null,
      activeHours: (data.activeHours as Record<string, unknown> | undefined) ?? null,
      activeDays: (data.activeDays as string[] | undefined) ?? [],
      ...(birthdayTargeting ? { birthdayMatchId: birthdayTargeting.matchId } : {}),
      // `targetUserIds` is NO LONGER WRITTEN HERE — see
      // [assertBirthdayTargeting] for the validation, and the
      // `private/targeting` write after this document is created for
      // where the list now lives. The offer document keeps only
      // `offerType: 'birthday'`, which says THAT an offer is targeted
      // without saying at whom.
      ...(data.personalMessage ? { personalMessage: data.personalMessage } : {}),
      reviewNote: null,
      reviewedBy: null,
      reviewedAt: null,
      happyHourActive: true,
      createdAt: FieldValue.serverTimestamp(),
    };

    const venueRef = db.collection("venues").doc(venueId);
    const eligibility = await db.runTransaction(async (tx) => {
      const freshVenueSnap = await tx.get(venueRef);
      const freshVenue = freshVenueSnap.data() ?? {};
      const isFoundingVenue = freshVenue.isFoundingVenue === true;
      const freeOffersUsed = (freshVenue.freeOffersUsed as number | undefined) ?? 0;
      const windowEnd = (freshVenue.freeOfferWindowEnd as Timestamp | undefined)?.toDate();
      const isFree = isFoundingVenue && freeOffersUsed < FOUNDING_VENUE_FREE_OFFERS && !!windowEnd && new Date() < windowEnd;

      // The targeted uid list rides in a server-only subcollection, in
      // the SAME transaction as the offer itself — an offer that is
      // `offerType: 'birthday'` must never exist without its targeting,
      // or `publishBirthdayCampaigns` would silently reach nobody.
      if (birthdayTargeting) {
        tx.set(offerRef.collection("private").doc("targeting"), {
          userIds: birthdayTargeting.userIds,
          matchId: birthdayTargeting.matchId,
          createdAt: FieldValue.serverTimestamp(),
        });
      }

      if (isFree) {
        tx.set(offerRef, { ...baseOfferData, status: "pending" });
        tx.update(venueRef, { freeOffersUsed: freeOffersUsed + 1 });
        return { isFree: true } as const;
      }

      tx.set(offerRef, { ...baseOfferData, status: "awaiting_payment" });
      return { isFree: false } as const;
    });

    if (eligibility.isFree) {
      return { offerId: offerRef.id, requiresPayment: false };
    }

    const feeDescription = `Təklif yerləşdirmə haqqı — ${title}`;
    const paymentRef = db.collection("payments").doc();
    await paymentRef.set({
      ownerId: uid,
      listingType: "offer",
      listingId: offerRef.id,
      type: "offer_placement_fee",
      description: feeDescription,
      amount: fee,
      currency: "AZN",
      status: "pending",
      createdAt: FieldValue.serverTimestamp(),
      updatedAt: FieldValue.serverTimestamp(),
    });

    const checkoutUrl = await startEpointCheckoutForPayment(paymentRef.id, fee, feeDescription);

    return { offerId: offerRef.id, requiresPayment: true, checkoutUrl, feeAmount: fee, paymentId: paymentRef.id };
  },
);

/**
 * Re-opens a checkout for an offer whose payment previously failed
 * (Epoint returned an error status, or the owner never finished the
 * card form) — same `payments` doc, a fresh Epoint request. Rejects
 * anything not currently in a retryable state so this can't be used to
 * re-charge an already-paid offer or conjure a checkout for one that
 * never needed payment in the first place.
 */
export const retryOfferPayment = onCall(
  // App Check enforcement qəsdən `false`-dur — iOS DeviceCheck
  // qeydiyyatı gözlənilir (səbəb və simptom: bu faylın başındakı
  // şərh). Açılma şərti: Firebase Console → App Check-də HƏR İKİ
  // platformada təsdiqlənmə faizi sabit yüksək olduqda.
  { region: "us-central1", secrets: [epointPublicKey, epointPrivateKey, epointEnv], enforceAppCheck: false },
  async (request) => {
    const uid = request.auth?.uid;
    if (!uid) throw new HttpsError("unauthenticated", "Bu əməliyyat üçün daxil olmalısınız.");
    await assertActiveUser(uid);
    await enforceRateLimit("checkout", uid, 10, 600);

    const offerId = request.data?.offerId as string | undefined;
    if (!offerId) throw new HttpsError("invalid-argument", "offerId tələb olunur.");

    const offerSnap = await db.collection("offers").doc(offerId).get();
    const offer = offerSnap.data();
    if (!offer) throw new HttpsError("not-found", "Təklif tapılmadı.");
    if (offer.ownerId !== uid) throw new HttpsError("permission-denied", "Bu təklifin sahibi deyilsiniz.");
    if (offer.status !== "awaiting_payment") {
      throw new HttpsError("failed-precondition", "Bu təklif ödəniş gözləmir.");
    }

    const paymentsSnap = await db
      .collection("payments")
      .where("listingType", "==", "offer")
      .where("listingId", "==", offerId)
      .where("type", "==", "offer_placement_fee")
      .orderBy("createdAt", "desc")
      .limit(1)
      .get();
    const paymentDoc = paymentsSnap.docs[0];
    if (!paymentDoc) throw new HttpsError("not-found", "Bu təklif üçün ödəniş qeydi tapılmadı.");
    if (paymentDoc.data().status === "completed") {
      throw new HttpsError("failed-precondition", "Bu ödəniş artıq tamamlanıb.");
    }

    const amount = paymentDoc.data().amount as number;
    const description =
      (paymentDoc.data().description as string | undefined) ?? `Təklif yerləşdirmə haqqı — ${(offer.title as string | undefined) ?? ""}`;

    // Epoint permanently rejects a second checkout request for the same
    // `order_id` (= payment doc id) — see `startEpointCheckoutForPayment`'s
    // own doc comment. A payment doc that already went through Epoint
    // once (the original submitOffer attempt) can never be reused, so
    // this creates a fresh one instead of just flipping the old one back
    // to 'pending' the way it used to.
    let targetRef = paymentDoc.ref;
    if (paymentDoc.data().checkoutStartedAt) {
      // Düzəliş Prompt 6 / K-10 — `superseded`, not `failed` (see
      // `ensurePendingSubscriptionPayment`'s identical comment).
      await paymentDoc.ref.update({ status: "superseded", updatedAt: FieldValue.serverTimestamp() });
      targetRef = db.collection("payments").doc();
      await targetRef.set({
        ownerId: uid,
        listingType: "offer",
        listingId: offerId,
        type: "offer_placement_fee",
        description,
        amount,
        currency: (paymentDoc.data().currency as string | undefined) ?? "AZN",
        status: "pending",
        createdAt: FieldValue.serverTimestamp(),
        updatedAt: FieldValue.serverTimestamp(),
      });
    } else {
      await targetRef.update({ status: "pending", updatedAt: FieldValue.serverTimestamp() });
    }

    const checkoutUrl = await startEpointCheckoutForPayment(targetRef.id, amount, description);

    return { checkoutUrl, feeAmount: amount, paymentId: targetRef.id };
  },
);

/**
 * Epoint's server-to-server callback — an HTTP endpoint, not `onCall`,
 * since Epoint has no Firebase Auth token to present. Trust comes
 * entirely from `verifyEpointSignature` recomputing the signature with
 * the same private key Epoint signed with; nothing here is trusted
 * before that check passes. Idempotent by design (checks
 * `payment.status === "pending"` before acting) so a webhook retry —
 * Epoint, like most gateways, retries on anything but a 200 — can't
 * double-fire the downstream effect.
 */
/**
 * The one place that turns a resolved Epoint outcome (success/failure)
 * into the actual Firestore side effects — shared by `epointWebhook`,
 * which every Epoint-backed payment resolves through regardless of
 * method (card checkout, or the Apple Pay/Google Pay token widget —
 * see `createEpointWidgetCheckout`). Per this task's own "don't build
 * a second webhook path" requirement: no payment method gets its own
 * copy of this dispatch.
 *
 * Idempotent — returns `false` (no-op) for a payment that's already
 * past `pending`, so a retried webhook delivery or a duplicate token
 * submission can't double-fire the downstream effect.
 */
/**
 * The realistic subset of Epoint's bank decline `code` table (see
 * developer.epoint.az/error-codes — an ISO-8583-shaped list of ~80
 * codes, most of which are file-operation/POS-terminal codes that
 * can't actually occur for an online card-not-present payment) mapped
 * to a customer-facing AZ reason, so a decline reads as "kartınızda
 * kifayət qədər vəsait yoxdur" instead of a bare "uğursuz oldu" no
 * matter which of these came back. Falls back to Epoint's own
 * `message` field, then a generic line, for anything outside this set.
 */
const BANK_DECLINE_MESSAGE_BY_CODE: Record<string, string> = {
  "100": "Bank ödənişi rədd etdi.",
  "101": "Kartınızın müddəti bitib.",
  "102": "Bank bu əməliyyatı şübhəli hesab edib rədd etdi.",
  "103": "Bank ilə əlaqə saxlamaq lazımdır.",
  "104": "Bu kart məhdudlaşdırılıb.",
  "105": "Bank ilə əlaqə saxlamaq lazımdır.",
  "107": "Kart sahibi bankı ilə əlaqə saxlamalıdır.",
  "108": "Kart sahibi bankı ilə əlaqə saxlamalıdır.",
  "109": "Ödəniş konfiqurasiyasında xəta — dəstək komandası ilə əlaqə saxlayın.",
  "110": "Yanlış ödəniş məbləği.",
  "111": "Kart nömrəsi yanlışdır.",
  "112": "Bu əməliyyat üçün PIN tələb olunur.",
  "116": "Kartınızda kifayət qədər vəsait yoxdur.",
  "117": "Yanlış PIN daxil edildi.",
  "118": "Kart məlumatları tapılmadı.",
  "119": "Bu əməliyyat kartınıza icazə verilmir.",
  "120": "Bu əməliyyat terminala icazə verilmir.",
  "122": "Təhlükəsizlik pozuntusu aşkarlandı.",
  "125": "Etibarsız kart.",
  "129": "Bank bu kartı şübhəli hesab edir.",
  "180": "Ödəniş kart sahibinin tələbi ilə ləğv edildi.",
};

function bankDeclineMessage(code: string | undefined, epointMessage: string | undefined): string {
  if (code && BANK_DECLINE_MESSAGE_BY_CODE[code]) return BANK_DECLINE_MESSAGE_BY_CODE[code];
  if (epointMessage && epointMessage.trim()) return epointMessage.trim();
  return "Ödəniş bankınız tərəfindən rədd edildi.";
}

async function applyPaymentOutcome(
  orderId: string,
  succeeded: boolean,
  failureDetail?: { code?: string; message?: string },
  epointTransaction?: string,
  webhookAmount?: number,
  webhookCurrency?: string,
): Promise<boolean> {
  const paymentRef = db.collection("payments").doc(orderId);

  // Düzəliş Prompt 6 / PAY-5 — the read-and-idempotency-check used to
  // happen OUTSIDE `db.runTransaction`, as a plain `paymentRef.get()`.
  // Two concurrent invocations for the same orderId (confirmed real
  // path: `payWithSavedCard` calling this directly while a hosted-
  // checkout webhook for the SAME `paymentId` is also in flight — both
  // target the identical `payments` doc, `payWithSavedCard`'s `-sc`
  // suffix only scopes the Epoint-side charge call, not this doc) could
  // both read `status === "pending"` before either committed, then both
  // apply their own entitlement writes. Moving the read AND the guard
  // inside the transaction means Firestore's own transaction retry-on-
  // conflict guarantees only ONE of two racing calls ever sees
  // `pending`/`superseded` — the other re-reads post-commit and exits
  // via the same guard, same as any other late/duplicate call.
  let payment: FirebaseFirestore.DocumentData | undefined;
  let processed = false;
  let wasSuperseded = false;
  /** Set when the paid-for listing no longer exists — see the guard
   * inside the transaction. Reported to admins AFTER the transaction
   * resolves, never from inside the callback: `notifyAdmins` performs
   * its own writes, and the Admin SDK may re-run this callback on
   * contention, which would duplicate the notification. */
  // Declared WITHOUT an initializer on purpose: `= null` would let
  // TypeScript narrow the type to `null` here and never widen it back,
  // since the only assignment happens inside the transaction callback.
  let orphanReport:
    | {
        paymentId: string;
        type: string;
        listingType: string;
        listingId: string;
        amount: number;
        currency: string;
        epointTransaction: string | null;
      }
    | undefined;
  let amountMismatch = false;

  await db.runTransaction(async (tx) => {
    const paymentSnap = await tx.get(paymentRef);
    const data = paymentSnap.data();
    if (!data) return;
    // Düzəliş Prompt 6 / K-10 — `superseded` (a newer payment doc was
    // created for the same listing+type, see `retryOfferPayment` and
    // friends) is now ALSO processed, not just `pending`. Before this,
    // a late-arriving success on a superseded doc was silently dropped
    // here — Epoint had genuinely charged the card, but this function
    // returned `false` before ever reaching the entitlement-granting
    // code below, and `epointWebhook` reported "already processed" as
    // if nothing were wrong. `wasSuperseded` (below) drives the
    // admin-visible flag this case gets once honored.
    if (data.status !== "pending" && data.status !== "superseded") return;

    // Düzəliş Prompt 6 / PAY-4 — only enforced when the webhook payload
    // actually included an amount (unconfirmed until a real webhook is
    // observed — see this repo's own doc comment on `decodeEpointData`
    // acknowledging there's no official payload spec). A half-qəpik
    // tolerance absorbs float round-trip noise, not a real discrepancy.
    if (succeeded && webhookAmount !== undefined) {
      const expectedAmount = data.amount as number;
      const expectedCurrency = ((data.currency as string | undefined) ?? "AZN").toUpperCase();
      const amountOk = Math.abs(webhookAmount - expectedAmount) < 0.005;
      // CONFIRMED DEAD as of 2026-08-31: Epoint's payment callback
      // carries `amount` but NO `currency` (real payload logged and
      // inspected — keys are amount, bank_response, bank_transaction,
      // card_expiry_date, card_mask, card_name, code, message,
      // operation_code, order_id, other_attr, rrn, status,
      // transaction). So `webhookCurrency` is always undefined and
      // this always evaluates true. Kept rather than deleted because
      // Epoint could add the field, and a check that starts working on
      // its own is better than one nobody remembers to re-add — but
      // nobody should read this line as "currency is verified".
      const currencyOk = !webhookCurrency || webhookCurrency.toUpperCase() === expectedCurrency;
      if (!amountOk || !currencyOk) {
        payment = data;
        processed = true;
        amountMismatch = true;
        tx.update(paymentRef, {
          status: "amount_mismatch",
          updatedAt: FieldValue.serverTimestamp(),
        });
        return;
      }
    }

    payment = data;
    processed = true;
    wasSuperseded = data.status === "superseded";

    // Firestore transactions need every read before any write — the
    // venue_subscription branch needs the venue's current
    // subscriptionRenewsAt to compute the next cycle, a FAILED
    // pinbox_order needs its own order doc (for pinboxId/quantity, to
    // release the stock it held), and a SUCCEEDED pinbox_order needs
    // both the order (pinboxId) and the pinbox/venue docs (title/name)
    // to write the venuePayouts obligation row below — all reads
    // happen up front regardless of which payment type this actually is.
    const venueRef =
      succeeded &&
      (payment.type === "venue_subscription" || payment.type === "venue_premium") &&
      payment.listingType === "venue"
        ? db.collection("venues").doc(payment.listingId as string)
        : null;
    const venueSnap = venueRef ? await tx.get(venueRef) : null;
    // Düzəliş Prompt 10 / Y-6 pattern sweep — every `venueSnap?.data()?.X`
    // read below (the `venue_subscription`/`venue_premium` branches) is
    // defensive, not a live gap: `venueSnap` is non-null exactly when
    // `venueRef` is, which is only set once `payment.type`/`listingType`
    // have already been checked above, so a real venue doc is always
    // expected here. Left as optional-chained rather than asserted
    // non-null (which would mean throwing INSIDE this transaction
    // callback — deliberately avoided elsewhere in this same function,
    // see `completeOnboarding`'s own doc comment on why an `HttpsError`
    // thrown mid-callback doesn't interact predictably with Admin SDK's
    // retry-on-contention) purely so a venue doc somehow missing at this
    // exact moment fails safe (falls through to a default/no-op branch)
    // instead of throwing from a place that can't safely throw.
    const pinboxOrderRef =
      payment.type === "pinbox_order" && payment.listingType === "pinboxOrder"
        ? db.collection("pinboxOrders").doc(payment.listingId as string)
        : null;
    const pinboxOrderSnap = pinboxOrderRef ? await tx.get(pinboxOrderRef) : null;
    // Needed on failure to decide whether restoring stock should also
    // reopen a box this exact order sold out, AND on success to get
    // the box's title for the venuePayouts obligation row.
    const pinboxRef = pinboxOrderSnap?.exists
      ? db.collection("pinboxes").doc(pinboxOrderSnap.data()!.pinboxId as string)
      : null;
    const pinboxSnap = pinboxRef ? await tx.get(pinboxRef) : null;
    const pinboxOrderVenueRef =
      succeeded && pinboxOrderSnap?.exists
        ? db.collection("venues").doc(pinboxOrderSnap.data()!.venueId as string)
        : null;
    const pinboxOrderVenueSnap = pinboxOrderVenueRef ? await tx.get(pinboxOrderVenueRef) : null;

    // Offers were the one target never read before being written. The
    // read has to happen up here: a Firestore transaction refuses any
    // read issued after its first write.
    const offerRef =
      succeeded &&
      (payment.type === "offer_placement_fee" || payment.type === "boost_fee") &&
      payment.listingType === "offer"
        ? db.collection("offers").doc(payment.listingId as string)
        : null;
    const offerSnap = offerRef ? await tx.get(offerRef) : null;

    // ── The thing this payment was FOR may be gone ──────────────────
    //
    // A venue can be deleted between opening the Epoint checkout and
    // the webhook landing — it happened in testing on 2026-08-31 and
    // it is not exotic: the checkout page stays open, the owner
    // changes their mind, the venue goes, the payment does not.
    //
    // The old comment here called a missing venue "defensive, not a
    // live gap" and said it would "fall through to a no-op branch".
    // Both were wrong. `tx.update()` on a document that does not exist
    // throws NOT_FOUND, and because that happens inside the
    // transaction it rolls back EVERYTHING — including this payment's
    // own status write. So the charge went through, the payment stayed
    // `pending`, and Epoint retried into the same failure forever.
    //
    // Refusing loudly is the only honest outcome: nothing was
    // delivered, so nothing may be marked `completed`, and a human has
    // to decide about the money. `orphan_target` is a terminal status
    // an admin resolves by refunding — the notification below carries
    // everything `/reverse` needs.
    const targetMissing = isPaymentTargetMissing(succeeded, [
      { applies: venueRef !== null, exists: venueSnap?.exists ?? false },
      { applies: offerRef !== null, exists: offerSnap?.exists ?? false },
      { applies: pinboxOrderRef !== null, exists: pinboxOrderSnap?.exists ?? false },
    ]);

    if (targetMissing) {
      tx.update(paymentRef, {
        status: "orphan_target",
        ...(epointTransaction ? { epointTransaction } : {}),
        orphanedAt: FieldValue.serverTimestamp(),
        updatedAt: FieldValue.serverTimestamp(),
      });
      orphanReport = {
        paymentId: paymentRef.id,
        type: String(payment.type),
        listingType: String(payment.listingType),
        listingId: String(payment.listingId),
        amount: Number(payment.amount ?? 0),
        currency: String(payment.currency ?? "AZN"),
        epointTransaction: epointTransaction ?? null,
      };
      return;
    }

    tx.update(paymentRef, {
      status: succeeded ? "completed" : "failed",
      // Epoint's OWN transaction id (distinct from this doc's own id,
      // which is the `order_id` Epoint was given) — the only identifier
      // `/reverse` accepts, so this is what a later automatic refund
      // (`processPaymentRefund`) needs. Only meaningful once a charge
      // actually succeeded; a failed attempt never has a real
      // transaction to reverse.
      ...(succeeded && epointTransaction ? { epointTransaction } : {}),
      ...(!succeeded && failureDetail
        ? {
            failureCode: failureDetail.code ?? null,
            failureMessage: bankDeclineMessage(failureDetail.code, failureDetail.message),
          }
        : {}),
      updatedAt: FieldValue.serverTimestamp(),
    });

    if (payment.type === "offer_placement_fee" && payment.listingType === "offer") {
      if (succeeded && offerRef) {
        tx.update(offerRef, {
          status: "pending",
          paymentId: paymentRef.id,
          updatedAt: FieldValue.serverTimestamp(),
        });
      }
      // On failure the offer just stays `awaiting_payment` —
      // `retryOfferPayment` is the owner's way back in; nothing to
      // undo here since the offer was never made visible.
    } else if (payment.type === "venue_subscription" && payment.listingType === "venue" && venueRef && venueSnap?.exists) {
      if (succeeded) {
        // Promotes the draft acceptance `submitVenue`/
        // `retryVenueSubscriptionPayment` attached to THIS payment doc
        // (see `PendingOfferAcceptance`) into the venue's permanent,
        // client-unwritable acceptance record — only now, because only
        // now is the charge actually confirmed (see 3.2 of the offer's
        // own terms: "checkbox işarələnəndə müvəqqəti... ödəniş uğurlu
        // olduqda yazılsın"). Absent on a renewal that didn't need
        // re-acceptance (RC version unchanged) — venue's existing
        // acceptance fields are left untouched either way (never
        // overwritten with nothing).
        const pendingOfferAcceptance = payment.pendingOfferAcceptance as PendingOfferAcceptance | undefined;
        // A first charge with no acceptance attached means the venue is
        // about to go live with nothing on file — the exact gap the
        // retry path used to open. A RENEWAL legitimately has none
        // (nothing to re-accept when the version has not moved), so
        // only the first payment is worth warning about. Loud on
        // purpose: this is a contract record, and its absence is
        // invisible in the app.
        if (!pendingOfferAcceptance && venueSnap?.data()?.status === "awaiting_payment") {
          logger.warn("applyPaymentOutcome: first venue payment carries no offer acceptance", {
            paymentId: paymentRef.id,
            venueId: payment.listingId,
          });
        }
        const offerAcceptanceVenueUpdate = pendingOfferAcceptance
          ? {
              offerAcceptedVersion: pendingOfferAcceptance.version,
              offerAcceptedAt: FieldValue.serverTimestamp(),
              offerAcceptedFrom: `${pendingOfferAcceptance.appVersion} / ${pendingOfferAcceptance.platform}`,
              offerDocumentUrl: pendingOfferAcceptance.documentUrl,
            }
          : {};
        if (pendingOfferAcceptance) {
          tx.set(venueRef.collection("offerAcceptances").doc(), {
            version: pendingOfferAcceptance.version,
            documentUrl: pendingOfferAcceptance.documentUrl,
            appVersion: pendingOfferAcceptance.appVersion,
            platform: pendingOfferAcceptance.platform,
            acceptedAt: FieldValue.serverTimestamp(),
            paymentId: paymentRef.id,
          });
        }

        const isFirstPayment = venueSnap?.data()?.status === "awaiting_payment";
        if (isFirstPayment) {
          // First-ever charge for a brand new venue (`submitVenue`) —
          // this is what actually admits it into moderation; nothing
          // free happens here even for a founding venue, since
          // `isFoundingVenue` isn't assigned until first approval
          // (`assignFoundingVenueIfEligible`), which is the only place
          // that can grant the free 2nd cycle — see its own doc comment.
          tx.update(venueRef, {
            status: "pending",
            paymentId: paymentRef.id,
            subscriptionRenewsAt: Timestamp.fromDate(new Date(Date.now() + SUBSCRIPTION_CYCLE_MS)),
            // Drives the "Ödənişiniz təsdiqləndi" card on MyVenuesScreen
            // — cleared by the owner dismissing it (see
            // `dismissFirstPaymentAnnouncement`, firebase_venue_
            // repository.dart). Deliberately read LIVE alongside
            // `isFoundingVenue`/`subscriptionRenewsAt` at render time,
            // not frozen into params here — `isFoundingVenue` isn't
            // known yet at this exact moment (only set on first
            // approval, see `assignFoundingVenueIfEligible`), so the
            // card self-corrects from the non-founding wording to the
            // founding one if approval (and the free 2nd cycle) lands
            // before the owner dismisses it.
            firstPaymentAnnouncementPending: true,
            updatedAt: FieldValue.serverTimestamp(),
            ...offerAcceptanceVenueUpdate,
          });
        } else {
          const prevRenewsAt = (venueSnap?.data()?.subscriptionRenewsAt as Timestamp | undefined)?.toDate() ?? new Date();
          const nextRenewsAt = new Date(prevRenewsAt.getTime() + SUBSCRIPTION_CYCLE_MS);
          // Düzəliş Prompt 6 / PAY-10 — `renewVenueSubscriptions` suspends
          // a venue to `subscription_overdue` after the grace period; a
          // successful payment while suspended is the owner's only way
          // back to `approved` (nothing else ever flips it forward).
          const wasSuspended = venueSnap?.data()?.status === "subscription_overdue";
          tx.update(venueRef, {
            ...(wasSuspended ? { status: "approved" } : {}),
            paymentId: paymentRef.id,
            subscriptionRenewsAt: Timestamp.fromDate(nextRenewsAt),
            updatedAt: FieldValue.serverTimestamp(),
            ...offerAcceptanceVenueUpdate,
          });
        }
      }
      // On failure the venue just stays `awaiting_payment` (first
      // payment) or keeps its stale-past `subscriptionRenewsAt`
      // (renewal) — `retryVenueCreationPayment`/
      // `retryVenueSubscriptionPayment` are the owner's way back in
      // either way, nothing to undo here.
      // On failure subscriptionRenewsAt stays in the past — the venue
      // simply stays overdue, `retryVenueSubscriptionPayment` is the
      // owner's way back in. Nothing about the venue's own status/
      // visibility changes just because a payment attempt failed.
    } else if (payment.type === "boost_fee" && payment.listingType === "offer") {
      if (succeeded) {
        const hours = payment.boostHours as number;
        if (offerRef) tx.update(offerRef, {
          boostedUntil: Timestamp.fromDate(new Date(Date.now() + hours * 60 * 60 * 1000)),
          updatedAt: FieldValue.serverTimestamp(),
        });
      }
    } else if (payment.type === "venue_premium" && payment.listingType === "venue" && venueRef && venueSnap?.exists) {
      if (succeeded) {
        const months = payment.premiumMonths as number;
        const currentExpiresAt = (venueSnap?.data()?.premiumExpiresAt as Timestamp | undefined)?.toDate();
        const now = new Date();
        // Extend, don't overwrite — a renewal purchased before expiry
        // stacks the new period on top of the remaining time instead
        // of resetting the clock to zero.
        const base = currentExpiresAt && currentExpiresAt > now ? currentExpiresAt : now;
        const wasAlreadyPremium = venueSnap?.data()?.isPremium === true;
        tx.update(venueRef, {
          isPremium: true,
          // Only reset on a not-premium -> premium transition — a
          // renewal of an already-active venue keeps its original
          // grant date (see Venue.premiumSince's doc comment).
          ...(wasAlreadyPremium ? {} : { premiumSince: Timestamp.fromDate(now) }),
          // 30-day months, same fixed-millisecond approximation this
          // file already uses for SUBSCRIPTION_CYCLE_MS elsewhere.
          premiumExpiresAt: Timestamp.fromDate(new Date(base.getTime() + months * 30 * 24 * 60 * 60 * 1000)),
          premiumExpiryReminderSent: false,
          updatedAt: FieldValue.serverTimestamp(),
        });
      }
      // On failure the venue's premium status just stays whatever it
      // already was — nothing to undo, the owner can simply retry the
      // checkout from the same "Məkanı premium et" entry point.
    } else if (pinboxOrderRef && pinboxOrderSnap?.exists) {
      if (succeeded) {
        // `reservePinBoxOrder` already decremented stock and created
        // this order as `awaiting_payment` — a confirmed charge just
        // flips it to the state `generatePinBoxQrToken`/
        // `redeemPinBoxOrder` already expect, nothing else changes.
        tx.update(pinboxOrderRef, {
          status: "reserved",
          paymentId: paymentRef.id,
          updatedAt: FieldValue.serverTimestamp(),
        });

        // The venue's 85% share becomes owed the moment the charge is
        // confirmed — not at redemption or at month-end — per the
        // admin panel's "PinBox Öhdəlikləri" page: one obligation row
        // per order, visible as "pending" immediately, settled by hand
        // once a month (see `markPinBoxPayoutPaid` in admin-panel).
        // Doc id = order id, so this can never double-write even if
        // applyPaymentOutcome is somehow invoked twice for the same
        // order (the top-of-function `status !== "pending"` guard
        // already prevents that anyway — this is just belt-and-braces).
        const order = pinboxOrderSnap.data()!;
        const grossAmount = payment.amount as number;
        // Düzəliş Prompt 10 / PAY-28 (formula only — NOT the full
        // float→cents migration, deliberately deferred per Prompt 6's
        // own decision; `payments.amount`/every other float AZN field
        // stays as-is) — the OLD formula rounded `commissionAmount`
        // first (round-half-up) and derived `payoutAmount` as the AZN-
        // float remainder, which let the rounding remainder land on
        // EITHER side depending on the exact fractional value. A full
        // scan of every possible gross-cent value (1–5000 qəpik) found
        // this discrepancy on ~46% of them, and — critically — it was
        // NEVER once in PeakPin's favor, always the venue's: the venue
        // silently received 1 extra qəpik on roughly half of all
        // possible order totals. Computing `payoutAmount` directly via
        // `Math.floor` and deriving `commissionAmount` as the integer-
        // cents remainder instead makes the venue's share deterministically
        // round DOWN and the remainder always land on PeakPin's side —
        // exactly the rule this app's own terms state ("məkanın payı
        // həmişə tam hesablansın").
        const grossCents = Math.round(grossAmount * 100);
        const payoutCents = Math.floor(grossCents * (1 - PINBOX_PAYOUT_COMMISSION_RATE));
        const commissionCents = grossCents - payoutCents;
        const payoutAmount = payoutCents / 100;
        const commissionAmount = commissionCents / 100;
        tx.set(db.collection("venuePayouts").doc(pinboxOrderRef.id), {
          orderId: pinboxOrderRef.id,
          paymentId: paymentRef.id,
          venueId: order.venueId as string,
          venueName: (pinboxOrderVenueSnap?.data()?.name as string | undefined) ?? "Naməlum",
          ownerId: (pinboxOrderVenueSnap?.data()?.ownerId as string | undefined) ?? null,
          pinboxId: order.pinboxId as string,
          pinboxTitle: (pinboxSnap?.data()?.title as string | undefined) ?? "Naməlum",
          quantity: order.quantity as number,
          grossAmount,
          commissionRate: PINBOX_PAYOUT_COMMISSION_RATE,
          commissionAmount,
          payoutAmount,
          currency: (payment.currency as string) ?? "AZN",
          status: "pending",
          createdAt: FieldValue.serverTimestamp(),
          updatedAt: FieldValue.serverTimestamp(),
        });
      } else if (pinboxRef && pinboxSnap) {
        // Payment declined/abandoned — the held stock was never
        // actually sold, so give it back (atomic increment, safe
        // against concurrent activity on the same box) rather than
        // losing a unit to every failed checkout attempt. Also reopens
        // the box if THIS reservation was what sold it out in the
        // first place — otherwise the restored unit would sit
        // invisible behind a stale `soldOut` status forever.
        const order = pinboxOrderSnap.data()!;
        const quantity = order.quantity as number;
        const currentRemaining = (pinboxSnap.data()?.stockRemaining as number | undefined) ?? 0;
        const restoredRemaining = currentRemaining + quantity;
        tx.update(pinboxOrderRef, { status: "payment_failed", updatedAt: FieldValue.serverTimestamp() });
        tx.update(pinboxRef, {
          stockRemaining: FieldValue.increment(quantity),
          ...(pinboxSnap.data()?.status === "soldOut" && restoredRemaining > 0 ? { status: "active" } : {}),
          updatedAt: FieldValue.serverTimestamp(),
        });
      }
    }
  });

  if (orphanReport) {
    // Money was taken for something that no longer exists. Nobody can
    // be granted anything, so this needs a person: the notification
    // carries the Epoint transaction id, which is the only identifier
    // `/reverse` accepts for a refund.
    logger.error("applyPaymentOutcome: paid-for listing is gone", orphanReport);
    await notifyAdmins({
      type: "payment.orphan_target",
      message:
        `Ödəniş alındı, amma aid olduğu ${orphanReport.listingType} artıq mövcud deyil — ` +
        `${orphanReport.amount} ${orphanReport.currency}, ${orphanReport.type}, ` +
        `listingId: ${orphanReport.listingId}, ödəniş: ${orphanReport.paymentId}` +
        (orphanReport.epointTransaction
          ? `, Epoint tranzaksiyası: ${orphanReport.epointTransaction} (geri qaytarma üçün lazımdır)`
          : ", Epoint tranzaksiya ID-si yoxdur"),
      targetType: "payment",
      targetId: orphanReport.paymentId,
    });
    // Deliberately `false`: nothing was delivered, so this must not
    // read as a processed payment anywhere upstream.
    return false;
  }

  if (!processed) {
    if (!payment) logger.error("applyPaymentOutcome: unknown payment", { orderId });
    return false;
  }
  // Narrows `payment` from `T | undefined` to `T` for everything below —
  // `processed` is only ever set `true` in the same transaction branch
  // that also sets `payment`, so this can't actually trigger; it exists
  // purely so TypeScript carries that guarantee across the `await
  // db.runTransaction(...)` boundary, which it can't infer on its own.
  if (!payment) return false;

  if (amountMismatch) {
    logger.error("applyPaymentOutcome: webhook amount/currency mismatch — no entitlement granted", {
      orderId,
      webhookAmount,
      webhookCurrency,
      expectedAmount: payment.amount,
      expectedCurrency: payment.currency,
    });
    await notifyAdmins({
      type: "payment.amount_mismatch",
      message: `Ödəniş məbləği uyğunsuzluğu: gözlənilən ${payment.amount} ${payment.currency ?? "AZN"}, gələn ${webhookAmount} ${webhookCurrency ?? "?"} — entitlement VERİLMƏDİ (orderId: ${orderId}).`,
      targetType: (payment.listingType as string | undefined) ?? "payment",
      targetId: (payment.listingId as string | undefined) ?? orderId,
    });
    return false;
  }

  // Düzəliş Prompt 6 / K-10 — a late success on a `superseded` payment
  // IS now honored (the entitlement-granting code above already ran,
  // using the same additive extend-don't-overwrite logic every renewal
  // already relies on), but it must never be silent — this is real
  // money that arrived through a link the owner was told to abandon.
  if (wasSuperseded && succeeded) {
    logger.warn("applyPaymentOutcome: honoring late success on a superseded payment", { orderId });
    await db.collection("payments").doc(orderId).update({ honoredAfterSupersede: true });
    await notifyAdmins({
      type: "payment.honored_after_supersede",
      message: `Köhnəlmiş ödəniş linkindən gec təsdiq gəldi və xidmət verildi — ${payment.amount} ${payment.currency ?? "AZN"} (orderId: ${orderId}, ${payment.listingType}/${payment.listingId}).`,
      targetType: (payment.listingType as string | undefined) ?? "payment",
      targetId: (payment.listingId as string | undefined) ?? orderId,
    });
  }

  // Outside the transaction, deliberately — a push send has no place in
  // a block Firestore can silently retry on contention. The card
  // checkout flow opens in the device's EXTERNAL browser
  // (`launchUrl(..., mode: .externalApplication)`, see
  // `epoint_checkout.dart`), so the app has no way to know when the
  // browser closes or the user comes back; `epointWebhook` calling this
  // is the only signal the owner ever gets that their payment actually
  // went through, short of manually reopening the exact right screen.
  if (succeeded) {
    const ownerId = payment.ownerId as string;
    const amount = payment.amount as number;
    const currency = (payment.currency as string) ?? "AZN";
    if (payment.type === "offer_placement_fee" || payment.type === "boost_fee") {
      const offerSnap = await db.collection("offers").doc(payment.listingId as string).get();
      const name = (offerSnap.data()?.title as string | undefined) ?? "";
      const quoted = name ? `"${name}"` : "Təklifiniz";
      const owner = await getUserDisplayInfo(ownerId);
      if (payment.type === "offer_placement_fee") {
        await notifyUser({
          uid: ownerId,
          category: "account",
          type: "offerPaymentConfirmed",
          title: "Ödəniş təsdiqləndi",
          body: `${quoted} üçün ödəniş qəbul edildi, indi nəzərdən keçirilir.`,
          params: { name },
          targetId: payment.listingId as string,
          targetType: "offer",
        });
        await notifyAdmins({
          type: "payment.succeeded",
          message: `${owner.name} → ${quoted} (təklif yerləşdirmə haqqı): ${amount} ${currency}`,
          targetType: "offer",
          targetId: payment.listingId as string,
        });
      } else {
        const hours = payment.boostHours as number;
        await notifyUser({
          uid: ownerId,
          category: "account",
          type: "offerBoosted",
          title: "Təklifiniz önə çəkildi",
          body: `${quoted} ${hours} saat önə çəkildi.`,
          params: { name, hours },
          targetId: payment.listingId as string,
          targetType: "offer",
        });
        await notifyAdmins({
          type: "payment.succeeded",
          message: `${owner.name} → ${quoted} (${hours} saat önə çəkmə): ${amount} ${currency}`,
          targetType: "offer",
          targetId: payment.listingId as string,
        });
      }
    } else if (payment.type === "venue_subscription") {
      const freshVenueSnap = await db.collection("venues").doc(payment.listingId as string).get();
      const name = (freshVenueSnap.data()?.name as string | undefined) ?? "";
      // `status === "pending"` only ever happens here as the direct
      // result of THIS payment's first-payment branch above (a renewal
      // never touches `status`) — reliable enough to distinguish
      // "just created" from "recurring cycle" without extra plumbing.
      const isFirstPayment = freshVenueSnap.data()?.status === "pending";
      const owner = await getUserDisplayInfo(ownerId);
      const quoted = name ? `"${name}"` : "Məkanınız";
      await notifyUser({
        uid: ownerId,
        category: "account",
        type: isFirstPayment ? "venuePaymentConfirmed" : "venueSubscriptionRenewed",
        title: isFirstPayment ? "Ödəniş təsdiqləndi" : "Abunəlik yeniləndi",
        body: isFirstPayment
          ? `${quoted} üçün ödəniş qəbul edildi, indi nəzərdən keçirilir.`
          : `${quoted} üçün abunəlik ödənişi təsdiqləndi.`,
        params: { name },
        targetId: payment.listingId as string,
        targetType: "venue",
      });
      await notifyAdmins({
        type: "payment.succeeded",
        message: `${owner.name} → ${quoted} (${isFirstPayment ? "ilk abunəlik ödənişi" : "abunəlik yenilənməsi"}): ${amount} ${currency}`,
        targetType: "venue",
        targetId: payment.listingId as string,
      });
    } else if (payment.type === "venue_premium") {
      const freshVenueSnap = await db.collection("venues").doc(payment.listingId as string).get();
      const name = (freshVenueSnap.data()?.name as string | undefined) ?? "";
      const months = payment.premiumMonths as number;
      const owner = await getUserDisplayInfo(ownerId);
      const quoted = name ? `"${name}"` : "Məkanınız";
      await notifyUser({
        uid: ownerId,
        category: "account",
        type: "venuePremiumActivated",
        title: "Premium status aktivləşdi",
        body: `${quoted} indi premium statusundadır (${months} ay).`,
        params: { name, months },
        targetId: payment.listingId as string,
        targetType: "venue",
      });
      await notifyAdmins({
        type: "payment.succeeded",
        message: `${owner.name} → ${quoted} (${months} ay premium): ${amount} ${currency}`,
        targetType: "venue",
        targetId: payment.listingId as string,
      });
    } else if (payment.type === "pinbox_order") {
      const freshOrderSnap = await db.collection("pinboxOrders").doc(payment.listingId as string).get();
      const pinboxId = freshOrderSnap.data()?.pinboxId as string | undefined;
      const freshPinboxSnap = pinboxId ? await db.collection("pinboxes").doc(pinboxId).get() : null;
      const title = (freshPinboxSnap?.data()?.title as string | undefined) ?? "";
      const owner = await getUserDisplayInfo(ownerId);
      const quoted = title ? `"${title}"` : "PinBox";
      await notifyUser({
        uid: ownerId,
        category: "account",
        type: "pinboxOrderConfirmed",
        title: "Sifariş təsdiqləndi",
        body: `${quoted} sifarişiniz təsdiqləndi, QR biletiniz hazırdır.`,
        params: { title },
        targetId: payment.listingId as string,
        targetType: "pinbox_order",
      });
      await notifyAdmins({
        type: "payment.succeeded",
        message: `${owner.name} → ${quoted} (PinBox sifarişi): ${amount} ${currency}`,
        targetType: "pinbox_order",
        targetId: payment.listingId as string,
      });
    }
  } else if (failureDetail) {
    // Only a REAL bank decline (routed through the webhook, where
    // Epoint's own code/message are available) gets a notification
    // here — `reservePinBoxOrder`'s own catch block already surfaces a
    // synchronous checkout-request failure (e.g. "Merchant not found")
    // directly in the app, no bank code exists for that case, and the
    // user is still looking at the screen when it happens.
    const ownerId = payment.ownerId as string;
    const reason = bankDeclineMessage(failureDetail.code, failureDetail.message);
    let name = "";
    let targetType = "";
    if (payment.type === "offer_placement_fee" || payment.type === "boost_fee") {
      const offerSnap = await db.collection("offers").doc(payment.listingId as string).get();
      name = (offerSnap.data()?.title as string | undefined) ?? "";
      targetType = "offer";
    } else if (payment.type === "venue_subscription" || payment.type === "venue_premium") {
      const freshVenueSnap = await db.collection("venues").doc(payment.listingId as string).get();
      name = (freshVenueSnap.data()?.name as string | undefined) ?? "";
      targetType = "venue";
    } else if (payment.type === "pinbox_order") {
      targetType = "pinbox_order";
    }
    await notifyUser({
      uid: ownerId,
      category: "account",
      type: "paymentFailed",
      title: "Ödəniş uğursuz oldu",
      body: name ? `"${name}": ${reason}` : reason,
      params: { name, reason },
      targetId: payment.listingId as string,
      targetType,
    });
  }

  return true;
}

/** Epoint never returns a card brand — inferred from the mask's leading digit(s), the same convention every card network itself uses. */
function inferCardBrand(mask: string | undefined): "visa" | "mastercard" | "other" {
  const digits = (mask ?? "").replace(/\D/g, "");
  if (digits.startsWith("4")) return "visa";
  if (/^5[1-5]/.test(digits) || /^2(2[2-9]|[3-6]\d|7[01])/.test(digits)) return "mastercard";
  return "other";
}

/** `/get-status-card`'s `expired_date` format isn't documented anywhere; handles both "MM/YY" and "MMYY" defensively. */
function parseEpointExpiry(expiredDate: string | undefined): { expMonth: number; expYear: number } | null {
  const match = (expiredDate ?? "").match(/^(\d{2})\D?(\d{2,4})$/);
  if (!match) return null;
  const expMonth = parseInt(match[1], 10);
  const expYear = match[2].length === 2 ? 2000 + parseInt(match[2], 10) : parseInt(match[2], 10);
  if (expMonth < 1 || expMonth > 12) return null;
  return { expMonth, expYear };
}

/**
 * The `savedCards/{orderId}` sibling of `applyPaymentOutcome` — same
 * idempotency guard (no-op if the doc is missing or already resolved).
 * On failure the pending doc is deleted outright rather than marked
 * `'failed'`: a card that was never actually saved shouldn't leave a
 * stub row in "Kartlarım". On success, makes one extra `/get-status-card`
 * call for the expiry date (`createEpointCardRegistration`'s own
 * response/webhook payload doesn't include it) and marks this the
 * user's default card iff it's their first active one.
 */
async function applyCardRegistrationOutcome(
  orderId: string,
  succeeded: boolean,
  decoded: Record<string, unknown>,
): Promise<boolean> {
  const cardRef = db.collection("savedCards").doc(orderId);
  const cardSnap = await cardRef.get();
  const card = cardSnap.data();
  if (!card || card.status !== "pending") return false;

  const epointCardId = decoded.card_id as string | undefined;
  if (!succeeded || !epointCardId) {
    await cardRef.delete();
    return true;
  }

  const cardMask = decoded.card_mask as string | undefined;
  let expiry: { expMonth: number; expYear: number } | null = null;
  try {
    const status = await getEpointCardStatus({
      publicKey: epointPublicKeyValue(),
      privateKey: epointPrivateKeyValue(),
      env: epointEnvValue(),
      epointCardId,
    });
    expiry = parseEpointExpiry(status.expiredDate);
  } catch (e) {
    logger.error("applyCardRegistrationOutcome: get-status-card failed", { orderId, error: e });
  }

  const existingActive = await db
    .collection("savedCards")
    .where("ownerId", "==", card.ownerId)
    .where("status", "==", "active")
    .limit(1)
    .get();

  await cardRef.update({
    status: "active",
    epointCardId,
    cardMask: cardMask ?? null,
    cardBrand: inferCardBrand(cardMask),
    expMonth: expiry?.expMonth ?? null,
    expYear: expiry?.expYear ?? null,
    isDefault: existingActive.empty,
    updatedAt: FieldValue.serverTimestamp(),
  });
  return true;
}

/**
 * Epoint's server-to-server callback for every card-based checkout —
 * the standard redirect flow, the Apple Pay/Google Pay Token Widget,
 * AND card registration (`savedCards/{orderId}`) all resolve through
 * this SAME endpoint (Epoint has one callback URL per merchant
 * account, not one per request/flow) — `payments/{orderId}` is tried
 * first (the common case), `savedCards/{orderId}` second. Not
 * `onCall`, since Epoint has no Firebase Auth token OR App Check token
 * to present (both are Firebase-client-SDK mechanisms; Epoint is an
 * external server, same reasoning as `appStoreServerNotifications`
 * below) — trust comes entirely from `verifyEpointSignature`
 * recomputing the signature with the same private key Epoint signed
 * with; nothing here is trusted before that check passes.
 */
export const epointWebhook = onRequest(
  { region: "us-central1", secrets: [epointPublicKey, epointPrivateKey, epointEnv] },
  async (req, res) => {
    // Düzəliş Prompt 8 / INFRA-46 — IP-scoped, not uid-scoped (this is
    // an external webhook, there's no Firebase Auth context). Defense
    // -in-depth only: `verifyEpointSignature` below is already the real
    // protection (a fake request is rejected by a cheap SHA1 compare,
    // not an expensive certificate-chain check — unlike
    // `appStoreServerNotifications`'s JWS verification, this one is not
    // an "expensive verification per fake request" problem). This just
    // caps request volume/log noise from a single source.
    try {
      await enforceRateLimit("webhook-epoint", req.ip ?? "unknown", 60, 60);
    } catch {
      res.status(429).send("rate limited");
      return;
    }

    const body = req.body as Record<string, unknown>;
    const data = body?.data as string | undefined;
    const signature = body?.signature as string | undefined;
    if (!data || !signature) {
      res.status(400).send("missing data/signature");
      return;
    }

    if (!verifyEpointSignature(epointPrivateKeyValue(), data, signature)) {
      logger.error("epointWebhook: signature mismatch");
      res.status(400).send("invalid signature");
      return;
    }

    const decoded = decodeEpointData(data);
    // Düzəliş Prompt 6 / PAY-4 — this repo has no official Epoint
    // webhook payload spec (see `decodeEpointData`'s own doc comment);
    // logging the full decoded object, every call, is the only way to
    // ever confirm what fields a REAL webhook actually sends (amount/
    // currency in particular — see below). Keep this until that's
    // confirmed against a real transaction, then this can be trimmed
    // back to just the fields actually used.
    logger.info("epointWebhook: decoded payload", { decoded });

    const orderId = decoded.order_id as string | undefined;
    const epointStatus = decoded.status as string | undefined;
    if (!orderId) {
      res.status(400).send("missing order_id");
      return;
    }

    const succeeded = epointStatus === "success";
    const failureDetail = succeeded
      ? undefined
      : { code: decoded.code as string | undefined, message: decoded.message as string | undefined };
    // Only meaningful if Epoint's webhook actually includes these
    // (unconfirmed — see the log line above) — `applyPaymentOutcome`
    // itself no-ops the check entirely when `webhookAmount` is
    // `undefined`, so this stays harmless either way until confirmed.
    // An unparseable `amount` (e.g. non-numeric) is treated the same as
    // absent, not as `NaN` — a `NaN` comparison would always flag a
    // false mismatch instead of just skipping the check.
    const parsedWebhookAmount = decoded.amount !== undefined ? Number(decoded.amount) : undefined;
    const webhookAmount =
      parsedWebhookAmount !== undefined && !Number.isNaN(parsedWebhookAmount) ? parsedWebhookAmount : undefined;
    const webhookCurrency = decoded.currency as string | undefined;

    const paymentSnap = await db.collection("payments").doc(orderId).get();
    if (paymentSnap.exists) {
      const applied = await applyPaymentOutcome(
        orderId,
        succeeded,
        failureDetail,
        succeeded ? (decoded.transaction as string | undefined) : undefined,
        succeeded ? webhookAmount : undefined,
        succeeded ? webhookCurrency : undefined,
      );
      res.status(200).send(applied ? "ok" : "already processed or unknown order_id");
      return;
    }

    const cardSnap = await db.collection("savedCards").doc(orderId).get();
    if (cardSnap.exists) {
      const applied = await applyCardRegistrationOutcome(orderId, succeeded, decoded);
      res.status(200).send(applied ? "ok" : "already processed or unknown order_id");
      return;
    }

    logger.error("epointWebhook: unknown order_id", { orderId });
    res.status(200).send("unknown order_id");
  },
);

// ---------------------------------------------------------------------------
// Apple Pay / Google Pay — one shared entry point per method, reused by every
// Epoint checkout flow above (offer placement fee, boost, venue subscription)
// via `paymentId` rather than each flow growing its own copy. Both still
// resolve through `applyPaymentOutcome`/`epointWebhook` — no second webhook
// path, per this task's own requirement.
// ---------------------------------------------------------------------------

/** Loads a `payments/{paymentId}` doc the CALLING user actually owns, or throws. Shared by both methods below. */
async function loadOwnedPendingPayment(uid: string, paymentId: string): Promise<FirebaseFirestore.DocumentData> {
  const snap = await db.collection("payments").doc(paymentId).get();
  const payment = snap.data();
  if (!payment) throw new HttpsError("not-found", "Ödəniş tapılmadı.");
  if (payment.ownerId !== uid) throw new HttpsError("permission-denied", "Bu ödənişin sahibi deyilsiniz.");
  if (payment.status !== "pending") throw new HttpsError("failed-precondition", "Bu ödəniş artıq emal olunub.");
  return payment;
}

/**
 * Apple Pay AND Google Pay — one Token Widget request either way,
 * confirmed against Epoint's own docs + raw widget HTML (inspected
 * live): the returned page carries BOTH Apple's ApplePaySession JS
 * (merchant id `merchant.az.epoint.applepay`) and Google's Pay JS
 * (`merchantId: 'BCR2DN4TY3DITOZH'`, `gatewayMerchantId:
 * 'epointpayment_txn001'`) — both under EPOINT's OWN merchant
 * accounts, not ours, so neither platform needs anything registered
 * on PeakPin's side (no Apple Merchant ID/domain verification, no
 * Google Pay `gatewayMerchantId` review). The widget's own JS shows
 * whichever button the visiting device/browser actually supports; the
 * client doesn't need to pick one when requesting the URL.
 *
 * The client embeds the returned URL in a WKWebView (see
 * `EpointTokenWidgetScreen` in the Flutter app). The customer pays
 * inside that widget; Epoint reports the result to `epointWebhook`
 * exactly like a card checkout does — this function only ever hands
 * back a URL, it never itself decides success/failure. (Formerly
 * `createApplePayCheckout` — renamed once Google Pay turned out to
 * go through the exact same request, not a separate native
 * integration; see the git history for the old
 * `submitGooglePayToken`/`EPOINT_GOOGLE_PAY_MERCHANT_ID` path this
 * replaced.)
 */
export const createEpointWidgetCheckout = onCall(
  // App Check enforcement qəsdən `false`-dur — iOS DeviceCheck
  // qeydiyyatı gözlənilir (səbəb və simptom: bu faylın başındakı
  // şərh). Açılma şərti: Firebase Console → App Check-də HƏR İKİ
  // platformada təsdiqlənmə faizi sabit yüksək olduqda.
  { region: "us-central1", secrets: [epointPublicKey, epointPrivateKey, epointEnv], enforceAppCheck: false },
  async (request) => {
    const uid = request.auth?.uid;
    if (!uid) throw new HttpsError("unauthenticated", "Bu əməliyyat üçün daxil olmalısınız.");
    await assertActiveUser(uid);
    await enforceRateLimit("checkout", uid, 10, 600);

    const paymentId = request.data?.paymentId as string | undefined;
    if (!paymentId) throw new HttpsError("invalid-argument", "paymentId tələb olunur.");

    const payment = await loadOwnedPendingPayment(uid, paymentId);
    const { widgetUrl } = await createEpointTokenWidget({
      publicKey: epointPublicKeyValue(),
      privateKey: epointPrivateKeyValue(),
      env: epointEnvValue(),
      orderId: paymentId,
      amount: payment.amount as number,
      description: (payment.description as string | undefined) ?? "PeakPin",
    });

    return { widgetUrl };
  },
);

// ---------------------------------------------------------------------------
// Saved cards ("Kartlarım") — register a card once via Epoint's own hosted
// page (`startCardRegistration`), then charge it synchronously for any of
// the 4 checkout flows above (`payWithSavedCard`) without a redirect/webview
// step. Registration completion reaches `epointWebhook` exactly like every
// other Epoint flow (see `applyCardRegistrationOutcome` above); a saved-card
// CHARGE doesn't need the webhook at all — `/execute-pay` is synchronous, so
// `payWithSavedCard` calls `applyPaymentOutcome` itself, inline.
// ---------------------------------------------------------------------------

export const startCardRegistration = onCall(
  // App Check enforcement qəsdən `false`-dur — iOS DeviceCheck
  // qeydiyyatı gözlənilir (səbəb və simptom: bu faylın başındakı
  // şərh). Açılma şərti: Firebase Console → App Check-də HƏR İKİ
  // platformada təsdiqlənmə faizi sabit yüksək olduqda.
  { region: "us-central1", secrets: [epointPublicKey, epointPrivateKey, epointEnv], enforceAppCheck: false },
  async (request) => {
    const uid = request.auth?.uid;
    if (!uid) throw new HttpsError("unauthenticated", "Bu əməliyyat üçün daxil olmalısınız.");
    await assertActiveUser(uid);
    await enforceRateLimit("checkout", uid, 10, 600);

    const cardRef = db.collection("savedCards").doc();
    await cardRef.set({ ownerId: uid, status: "pending", createdAt: FieldValue.serverTimestamp() });

    const { redirectUrl } = await createEpointCardRegistration({
      publicKey: epointPublicKeyValue(),
      privateKey: epointPrivateKeyValue(),
      env: epointEnvValue(),
      orderId: cardRef.id,
      description: "PeakPin kart qeydiyyatı",
      successRedirectUrl: EPOINT_SUCCESS_REDIRECT_URL,
      errorRedirectUrl: EPOINT_ERROR_REDIRECT_URL,
    });

    return { checkoutUrl: redirectUrl };
  },
);

/** Loads a `savedCards/{cardId}` doc the CALLING user actually owns and can charge, or throws. */
async function loadOwnedActiveCard(uid: string, cardId: string): Promise<FirebaseFirestore.DocumentData> {
  const snap = await db.collection("savedCards").doc(cardId).get();
  const card = snap.data();
  if (!card) throw new HttpsError("not-found", "Kart tapılmadı.");
  if (card.ownerId !== uid) throw new HttpsError("permission-denied", "Bu kartın sahibi deyilsiniz.");
  if (card.status !== "active") throw new HttpsError("failed-precondition", "Bu kart hazır deyil.");
  return card;
}

/**
 * A distinct `-sc` suffix on the order_id, not the plain `paymentId` —
 * this payment doc may already have gone through `startEpointCheckoutForPayment`
 * once (a card/Apple/Google Pay attempt the customer abandoned before
 * switching to a saved card), and Epoint permanently rejects a reused
 * order_id (see `startEpointCheckoutForPayment`'s own doc comment).
 */
export const payWithSavedCard = onCall(
  // App Check enforcement qəsdən `false`-dur — iOS DeviceCheck
  // qeydiyyatı gözlənilir (səbəb və simptom: bu faylın başındakı
  // şərh). Açılma şərti: Firebase Console → App Check-də HƏR İKİ
  // platformada təsdiqlənmə faizi sabit yüksək olduqda.
  { region: "us-central1", secrets: [epointPublicKey, epointPrivateKey, epointEnv], enforceAppCheck: false },
  async (request) => {
    const uid = request.auth?.uid;
    if (!uid) throw new HttpsError("unauthenticated", "Bu əməliyyat üçün daxil olmalısınız.");
    await assertActiveUser(uid);
    await enforceRateLimit("checkout", uid, 10, 600);

    const paymentId = request.data?.paymentId as string | undefined;
    const cardId = request.data?.cardId as string | undefined;
    if (!paymentId || !cardId) throw new HttpsError("invalid-argument", "paymentId və cardId tələb olunur.");

    const payment = await loadOwnedPendingPayment(uid, paymentId);
    const card = await loadOwnedActiveCard(uid, cardId);

    const result = await chargeEpointSavedCard({
      publicKey: epointPublicKeyValue(),
      privateKey: epointPrivateKeyValue(),
      env: epointEnvValue(),
      epointCardId: card.epointCardId as string,
      amount: payment.amount as number,
      orderId: `${paymentId}-sc`,
      description: (payment.description as string | undefined) ?? "PeakPin",
    });

    try {
      await applyPaymentOutcome(
        paymentId,
        result.succeeded,
        result.succeeded ? undefined : { message: result.message },
        result.succeeded ? result.transaction : undefined,
      );
    } catch (e) {
      // Düzəliş Prompt 6 / PAY-18 — `chargeEpointSavedCard` already
      // charged the card by this point; if applying the outcome itself
      // throws (a crash between the two, not a declined charge), the
      // payment doc could be left stuck `pending` forever with no
      // automatic way to notice money was taken but never serviced.
      // This alone doesn't reconcile it (no Epoint transaction-status
      // API is confirmed to exist in this integration — see the
      // function's own doc comment), but it stops the failure from
      // being silent so an admin can investigate manually.
      logger.error("payWithSavedCard: applyPaymentOutcome threw after a possibly-successful charge", {
        paymentId,
        chargeSucceeded: result.succeeded,
        error: e,
      });
      await notifyAdmins({
        type: "payment.outcome_apply_failed",
        message: `Saxlanmış kartla ödəniş: kart ${result.succeeded ? "veznədən tutuldu" : "rədd edildi"}, amma nəticənin tətbiqi xəta ilə üzləşdi — əl ilə yoxlanılmalıdır (paymentId: ${paymentId}).`,
        targetType: "payment",
        targetId: paymentId,
      });
      throw new HttpsError("internal", "Ödəniş nəticəsi tətbiq edilə bilmədi, dəstək ilə əlaqə saxlayın.");
    }

    return { succeeded: result.succeeded, failureMessage: result.succeeded ? undefined : result.message };
  },
);

// App Check enforcement qəsdən `false`-dur — iOS DeviceCheck
// qeydiyyatı gözlənilir (səbəb və simptom: bu faylın başındakı
// şərh). Açılma şərti: Firebase Console → App Check-də HƏR İKİ
// platformada təsdiqlənmə faizi sabit yüksək olduqda.
export const deleteSavedCard = onCall({ region: "us-central1", enforceAppCheck: false }, async (request) => {
  const uid = request.auth?.uid;
  if (!uid) throw new HttpsError("unauthenticated", "Bu əməliyyat üçün daxil olmalısınız.");
  await assertActiveUser(uid);

  const cardId = request.data?.cardId as string | undefined;
  if (!cardId) throw new HttpsError("invalid-argument", "cardId tələb olunur.");

  const cardRef = db.collection("savedCards").doc(cardId);
  const card = (await cardRef.get()).data();
  if (!card) throw new HttpsError("not-found", "Kart tapılmadı.");
  if (card.ownerId !== uid) throw new HttpsError("permission-denied", "Bu kartın sahibi deyilsiniz.");

  await cardRef.delete();

  // Epoint has no card-deregistration API — this only stops PeakPin
  // from listing/using it, it doesn't remove it from Epoint's side.
  if (card.isDefault) {
    const nextDefault = await db
      .collection("savedCards")
      .where("ownerId", "==", uid)
      .where("status", "==", "active")
      .orderBy("createdAt", "desc")
      .limit(1)
      .get();
    if (!nextDefault.empty) {
      await nextDefault.docs[0].ref.update({ isDefault: true, updatedAt: FieldValue.serverTimestamp() });
    }
  }

  return { deleted: true };
});

// App Check enforcement qəsdən `false`-dur — iOS DeviceCheck
// qeydiyyatı gözlənilir (səbəb və simptom: bu faylın başındakı
// şərh). Açılma şərti: Firebase Console → App Check-də HƏR İKİ
// platformada təsdiqlənmə faizi sabit yüksək olduqda.
export const setDefaultSavedCard = onCall({ region: "us-central1", enforceAppCheck: false }, async (request) => {
  const uid = request.auth?.uid;
  if (!uid) throw new HttpsError("unauthenticated", "Bu əməliyyat üçün daxil olmalısınız.");
  await assertActiveUser(uid);

  const cardId = request.data?.cardId as string | undefined;
  if (!cardId) throw new HttpsError("invalid-argument", "cardId tələb olunur.");

  await loadOwnedActiveCard(uid, cardId);

  const otherCards = await db
    .collection("savedCards")
    .where("ownerId", "==", uid)
    .where("status", "==", "active")
    .get();

  await db.runTransaction(async (tx) => {
    for (const doc of otherCards.docs) {
      if (doc.id === cardId) continue;
      if (doc.data().isDefault) tx.update(doc.ref, { isDefault: false, updatedAt: FieldValue.serverTimestamp() });
    }
    tx.update(db.collection("savedCards").doc(cardId), { isDefault: true, updatedAt: FieldValue.serverTimestamp() });
  });

  return { ok: true };
});

// ---------------------------------------------------------------------------
// VIP (`users/{uid}.premium`/`premiumExpiresAt`) — App Store/Play Store IAP,
// entirely separate from Epoint above (see functions/src/iap.ts's own doc
// comment). `premium` is the SAME field the admin panel's manual "VIP et"
// toggle already writes (see `setUserPremium`/`onUserUpdated`) — a real
// purchase is just another way that field reaches `true`, not a second
// parallel VIP system, so every existing premium-gated screen picks this up
// automatically with no changes on its end.
// ---------------------------------------------------------------------------

/** Public app identifiers — not secrets, just this app's own bundle/package id on each store. */
const APPLE_BUNDLE_ID = "com.peakpin.app";
const GOOGLE_PLAY_PACKAGE_NAME = "com.peakpin.app";

/**
 * The app's numeric App Store Connect id (found in its App Store
 * Connect URL, e.g. apps/1234567890) — `SignedDataVerifier` requires
 * this to validate a PRODUCTION transaction/notification actually
 * belongs to this app, not just this bundle id. Not set yet (no value
 * to put here) — Production verification will fail with
 * INVALID_APP_IDENTIFIER until this is. See this app's own IAP setup
 * instructions for where to find it.
 */
const APPLE_APP_STORE_ID = process.env.APPLE_APP_STORE_ID ? Number(process.env.APPLE_APP_STORE_ID) : undefined;

/** Service-account JSON key for the Play Console service account with "View financial data" access — set via `firebase functions:secrets:set GOOGLE_PLAY_SERVICE_ACCOUNT_JSON`. */
const googlePlayServiceAccountJson = defineSecret("GOOGLE_PLAY_SERVICE_ACCOUNT_JSON");

/** [kVipPackages] (Flutter, vip_package.dart) — kept in sync by hand, same reasoning as the Epoint fee tables' own duplicate-table doc comments. Only used as a fallback when a transaction/subscription's own `expiresDate` is unavailable. */
const VIP_PRODUCT_DURATIONS_MS: Record<string, number> = {
  peakpin_vip_monthly: 30 * 24 * 60 * 60 * 1000,
  peakpin_vip_quarterly: 90 * 24 * 60 * 60 * 1000,
  peakpin_vip_yearly: 365 * 24 * 60 * 60 * 1000,
};

async function grantPremium(uid: string, expiresAtMs: number): Promise<void> {
  await db.collection("users").doc(uid).update({
    premium: true,
    premiumExpiresAt: Timestamp.fromMillis(expiresAtMs),
    updatedAt: FieldValue.serverTimestamp(),
  });
}

/**
 * Apple's and Google's renewal/cancellation notifications identify a
 * subscription by `originalTransactionId`/`purchaseToken` — neither
 * carries a Firebase uid. `verifyInAppPurchase` claims this mapping the
 * moment it first grants premium so `appStoreServerNotifications`/
 * `googlePlayRtdn` can resolve who to update later; `platform`/
 * `productId` ride along so those handlers don't have to re-derive
 * them.
 *
 * Düzəliş Prompt 7 / PAY-25 — this used to be an unconditional
 * `.set(..., {merge:true})`: ANY uid presenting a genuine (Apple/
 * Google-verified) receipt could silently overwrite a DIFFERENT uid's
 * ownership record and claim that person's paid VIP subscription — a
 * single leaked/shared `receiptData` string granted unlimited accounts
 * premium. Now: a transaction already owned by a DIFFERENT,
 * STILL-EXISTING account is rejected outright (`"owned_by_other"`);
 * the one deliberate exception is a transaction whose previous owner's
 * `users/{uid}` doc no longer exists (account deleted via
 * `deleteAccount`) — that rebinds automatically to the new uid so a
 * customer who deletes and recreates their PeakPin account doesn't
 * lose the VIP they're still actually paying Apple/Google for, but
 * every such rebind is logged to `adminNotifications` so an admin can
 * spot an abnormal pattern. Wrapped in a transaction (same TOCTOU
 * reasoning as `applyPaymentOutcome`, Düzəliş Prompt 6 / PAY-5): two
 * different uids racing to claim the same fresh receipt simultaneously
 * must not both succeed.
 */
async function claimIapSubscriptionOwnership(
  key: string,
  uid: string,
  platform: "ios" | "android",
  productId: string,
): Promise<"claimed" | "owned_by_other"> {
  const ref = db.collection("iapSubscriptions").doc(key);
  let rebindingFromDeletedUid: string | undefined;

  const outcome = await db.runTransaction(async (tx) => {
    const existingUid = (await tx.get(ref)).data()?.uid as string | undefined;
    if (existingUid && existingUid !== uid) {
      const previousOwnerSnap = await tx.get(db.collection("users").doc(existingUid));
      if (previousOwnerSnap.exists) return "owned_by_other" as const;
      rebindingFromDeletedUid = existingUid;
    }
    tx.set(ref, { uid, platform, productId, updatedAt: FieldValue.serverTimestamp() }, { merge: true });
    return "claimed" as const;
  });

  if (outcome === "claimed" && rebindingFromDeletedUid) {
    logger.warn("claimIapSubscriptionOwnership: rebinding to a new uid after the previous owner's account was deleted", {
      key,
      previousUid: rebindingFromDeletedUid,
      newUid: uid,
    });
    await notifyAdmins({
      type: "iap.receipt_rebound",
      message: `IAP qəbzi silinmiş hesabdan (${rebindingFromDeletedUid}) yeni hesaba (${uid}) köçürüldü — məhsul: ${productId}.`,
      targetType: "user",
      targetId: uid,
    });
  }

  return outcome;
}

/**
 * Client-initiated verification right after a purchase completes (see
 * `vip_purchase_listener.dart`'s `_onPurchaseUpdate`) — the only place
 * that ever grants premium from a fresh purchase; renewals after this
 * are `appStoreServerNotifications`/`googlePlayRtdn`'s job. Always
 * re-verifies against the actual store (Apple's signed transaction
 * chain / Google's live subscription lookup) rather than trusting
 * anything the client claims about its own purchase.
 */
export const verifyInAppPurchase = onCall(
  // Düzəliş Prompt 7 / PAY-25, Qrup 1 (ödəniş) — KOD YAZILIB, DEPLOY
  // EDİLMƏYİB. `true`-nun deploy edilməsi ARALIQ mərhələ olmadan
  // dərhal production enforcement-dir (bax: bu funksiyanın da daxil
  // olduğu top-of-file şərh, sətir ~27-40 — eyni səbəbdən bütün
  // funksiyalarda bir dəfə `false`-a qaytarılıb). Deploy ETMƏZDƏN
  // ƏVVƏL Firebase Console → App Check-də platform-üzrə (xüsusən iOS)
  // təsdiqlənmə faizi yoxlanmalıdır.
  { region: "us-central1", secrets: [googlePlayServiceAccountJson], enforceAppCheck: false },
  async (request) => {
    const uid = request.auth?.uid;
    if (!uid) throw new HttpsError("unauthenticated", "Bu əməliyyat üçün daxil olmalısınız.");
    await assertActiveUser(uid);
    // Düzəliş Prompt 7 — ayrı "iap-verify" scope, Epoint-in "checkout"
    // scope-undan fərqli sayğac altında: bu, checkout linki YARATMIR,
    // artıq tamamlanmış bir alışı doğrulayır — eyni 10/600s tezliyi
    // (mövcud "checkout" callable-lərinin özü ilə eyni rəqəm) kifayət
    // qədər səxavətli, restore-purchases-in bir neçə məhsulu ard-arda
    // göndərməsinə imkan verir.
    await enforceRateLimit("iap-verify", uid, 10, 600);

    const productId = request.data?.productId as string | undefined;
    const platform = request.data?.platform as string | undefined;
    const receiptData = request.data?.receiptData as string | undefined;
    if (!productId || !platform || !receiptData) {
      throw new HttpsError("invalid-argument", "productId, platform və receiptData tələb olunur.");
    }
    if (!(productId in VIP_PRODUCT_DURATIONS_MS)) {
      throw new HttpsError("invalid-argument", "Naməlum VIP product ID.");
    }

    if (platform === "ios") {
      let verified;
      let usedEnvironment: "Production" | "Sandbox" = "Production";
      try {
        verified = await verifyAppleTransaction({
          signedTransactionInfo: receiptData,
          bundleId: APPLE_BUNDLE_ID,
          environment: "Production",
          appAppleId: APPLE_APP_STORE_ID,
        });
      } catch {
        // A TestFlight/sandbox purchase fails Production verification
        // by design (the transaction's own environment claim won't
        // match) — retry once against Sandbox before giving up, the
        // same fallback shape Apple's older verifyReceipt endpoint's
        // status-21007 used to require by hand.
        usedEnvironment = "Sandbox";
        verified = await verifyAppleTransaction({
          signedTransactionInfo: receiptData,
          bundleId: APPLE_BUNDLE_ID,
          environment: "Sandbox",
          appAppleId: undefined,
        });
      }

      if (verified.revoked) {
        logger.warn("verifyInAppPurchase: revoked Apple transaction", { uid, productId });
        throw new HttpsError("failed-precondition", "Bu alış geri qaytarılıb.");
      }
      if (verified.productId !== productId) {
        logger.warn("verifyInAppPurchase: Apple productId mismatch", { uid, expected: productId, actual: verified.productId });
        throw new HttpsError("failed-precondition", "Product ID uyğun gəlmir.");
      }

      // Düzəliş Prompt 7 / H #196 — Sandbox fallback ancaq real
      // TestFlight/development testerlər üçün mövcuddur, amma HANSI
      // environment-in doğruladığı əvvəllər HEÇ YOXLANILMIRDI — bir
      // sandbox qəbzi (istənilən sandbox Apple ID ilə pulsuz əldə
      // edilə bilər) production-da istənilən hesaba VIP verirdi. İndi:
      // yalnız `config/iapTesters.testerUids`-də olan PeakPin uid-ləri
      // üçün Sandbox nəticəsi qəbul edilir.
      if (usedEnvironment === "Sandbox") {
        const testersSnap = await db.collection("config").doc("iapTesters").get();
        const testerUids = (testersSnap.data()?.testerUids as string[] | undefined) ?? [];
        if (!testerUids.includes(uid)) {
          logger.warn("verifyInAppPurchase: sandbox transaction rejected — uid not in config/iapTesters", { uid, productId });
          await notifyAdmins({
            type: "iap.sandbox_rejected",
            message: `Sandbox qəbzi production-da rədd edildi (test siyahısında deyil) — uid: ${uid}, məhsul: ${productId}.`,
            targetType: "user",
            targetId: uid,
          });
          throw new HttpsError("failed-precondition", "Bu alış test mühitindən gəlib və qəbul edilmir.");
        }
      }

      const expiresAtMs = verified.expiresDateMs ?? Date.now() + VIP_PRODUCT_DURATIONS_MS[productId];
      const claim = await claimIapSubscriptionOwnership(verified.originalTransactionId, uid, "ios", productId);
      if (claim === "owned_by_other") {
        logger.error("verifyInAppPurchase: iOS transaction already owned by a different, still-active uid", {
          uid,
          originalTransactionId: verified.originalTransactionId,
          productId,
        });
        await notifyAdmins({
          type: "iap.receipt_theft_attempt",
          message: `Başqa hesaba aid IAP qəbzi ilə VIP əldə etmə cəhdi — uid: ${uid}, məhsul: ${productId}.`,
          targetType: "user",
          targetId: uid,
        });
        throw new HttpsError("permission-denied", "Bu alış artıq başqa hesaba bağlıdır.");
      }
      await grantPremium(uid, expiresAtMs);
      return { success: true, expiresAt: expiresAtMs };
    }

    if (platform === "android") {
      const verified = await verifyGoogleSubscription({
        serviceAccountJson: googlePlayServiceAccountJson.value(),
        packageName: GOOGLE_PLAY_PACKAGE_NAME,
        purchaseToken: receiptData,
      });

      if (verified.productId !== productId) {
        logger.warn("verifyInAppPurchase: Google productId mismatch", { uid, expected: productId, actual: verified.productId });
        throw new HttpsError("failed-precondition", "Product ID uyğun gəlmir.");
      }
      if (!["SUBSCRIPTION_STATE_ACTIVE", "SUBSCRIPTION_STATE_IN_GRACE_PERIOD"].includes(verified.subscriptionState)) {
        logger.warn("verifyInAppPurchase: Google subscription not active", { uid, productId, state: verified.subscriptionState });
        throw new HttpsError("failed-precondition", "Abunəlik aktiv deyil.");
      }

      const expiresAtMs = verified.expiryTimeMs || Date.now() + VIP_PRODUCT_DURATIONS_MS[productId];
      const claim = await claimIapSubscriptionOwnership(receiptData, uid, "android", productId);
      if (claim === "owned_by_other") {
        logger.error("verifyInAppPurchase: Android purchase token already owned by a different, still-active uid", {
          uid,
          productId,
        });
        await notifyAdmins({
          type: "iap.receipt_theft_attempt",
          message: `Başqa hesaba aid IAP qəbzi ilə VIP əldə etmə cəhdi — uid: ${uid}, məhsul: ${productId}.`,
          targetType: "user",
          targetId: uid,
        });
        throw new HttpsError("permission-denied", "Bu alış artıq başqa hesaba bağlıdır.");
      }
      await grantPremium(uid, expiresAtMs);
      return { success: true, expiresAt: expiresAtMs };
    }

    throw new HttpsError("invalid-argument", "Naməlum platform (ios/android olmalıdır).");
  },
);

/**
 * Apple's App Store Server Notifications V2 webhook — configure this
 * URL in App Store Connect (Users and Access > Integrations > In-App
 * Purchase > your key's app > App Store Server Notifications) for
 * BOTH Production and Sandbox. Handles renewal/expiration/cancellation
 * so `premium` stays correct even if the customer never reopens the
 * app. No App Check here either, same reasoning as `epointWebhook`
 * above — Apple's server can't present one. Trust comes entirely from
 * `verifyAppleNotification`'s signature check — nothing here is
 * trusted before that passes.
 */
export const appStoreServerNotifications = onRequest({ region: "us-central1" }, async (req, res) => {
  // Before the signature work, not after: the thing being rationed is
  // the JWS verification itself, which this handler performs TWICE
  // (Production, then Sandbox) on every request including junk ones.
  // This endpoint is unauthenticated by necessity — Apple's servers
  // can't present App Check or an ID token — so the only thing
  // standing between the open internet and that crypto is this
  // counter. Keyed by IP because there is no uid to key on; generous,
  // because Apple retries failed deliveries and sends from a small,
  // shared set of addresses. A rejection here is a 429 Apple will
  // simply retry, not a lost notification.
  try {
    await enforceRateLimit("store-notify", req.ip ?? "unknown", 120, 60);
  } catch {
    res.status(429).send("rate-limited");
    return;
  }

  const signedPayload = req.body?.signedPayload as string | undefined;
  if (!signedPayload) {
    res.status(400).send("missing signedPayload");
    return;
  }

  let notification;
  try {
    notification = await verifyAppleNotification({
      signedPayload,
      bundleId: APPLE_BUNDLE_ID,
      environment: "Production",
      appAppleId: APPLE_APP_STORE_ID,
    });
  } catch {
    try {
      notification = await verifyAppleNotification({
        signedPayload,
        bundleId: APPLE_BUNDLE_ID,
        environment: "Sandbox",
        appAppleId: undefined,
      });
    } catch (e2) {
      logger.error("appStoreServerNotifications: signature verification failed", e2);
      res.status(400).send("invalid signature");
      return;
    }
  }

  const signedTransactionInfo = notification.data?.signedTransactionInfo;
  if (!signedTransactionInfo) {
    // EXTERNAL_PURCHASE_TOKEN/RESCIND_CONSENT-style notifications carry
    // no transaction info at all — nothing for VIP to react to.
    res.status(200).send("no transaction info");
    return;
  }

  const environment = notification.data?.environment === "Production" ? "Production" : "Sandbox";
  const transaction = await verifyAppleTransaction({
    signedTransactionInfo,
    bundleId: APPLE_BUNDLE_ID,
    environment,
    appAppleId: environment === "Production" ? APPLE_APP_STORE_ID : undefined,
  });

  const ownerSnap = await db.collection("iapSubscriptions").doc(transaction.originalTransactionId).get();
  const uid = ownerSnap.data()?.uid as string | undefined;
  if (!uid) {
    // A transaction verifyInAppPurchase never saw (e.g. a renewal that
    // arrived before the very first purchase's own call finished) —
    // nothing to update yet; the next renewal notification will find
    // the mapping once it exists.
    res.status(200).send("unknown transaction, no owner recorded yet");
    return;
  }

  if (transaction.revoked || (transaction.expiresDateMs !== undefined && transaction.expiresDateMs <= Date.now())) {
    await db.collection("users").doc(uid).update({ premium: false, updatedAt: FieldValue.serverTimestamp() });
  } else if (transaction.expiresDateMs !== undefined) {
    await grantPremium(uid, transaction.expiresDateMs);
  }

  res.status(200).send("ok");
});

/**
 * Google Play's Real-time Developer Notifications arrive via Pub/Sub,
 * not a plain HTTP POST — see this app's own setup instructions for
 * creating the topic and linking it in Play Console. Every
 * notification just re-fetches live status from
 * `verifyGoogleSubscription` rather than trusting the notification
 * payload's own claims (it only ever carries the purchase token,
 * nothing about status Google wants trusted without a fresh lookup).
 */
export const googlePlayRtdn = onMessagePublished(
  { topic: "peakpin-google-play-rtdn", region: "us-central1", secrets: [googlePlayServiceAccountJson] },
  async (event) => {
    const json = event.data.message.json as Record<string, unknown> | undefined;
    const purchaseToken = (json?.subscriptionNotification as Record<string, unknown> | undefined)?.purchaseToken as
      | string
      | undefined;
    if (!purchaseToken) return; // A test/one-time-product notification — nothing for VIP to react to.

    const ownerSnap = await db.collection("iapSubscriptions").doc(purchaseToken).get();
    const uid = ownerSnap.data()?.uid as string | undefined;
    if (!uid) return; // Same "not seen by verifyInAppPurchase yet" case as the Apple handler.

    const verified = await verifyGoogleSubscription({
      serviceAccountJson: googlePlayServiceAccountJson.value(),
      packageName: GOOGLE_PLAY_PACKAGE_NAME,
      purchaseToken,
    });

    if (["SUBSCRIPTION_STATE_ACTIVE", "SUBSCRIPTION_STATE_IN_GRACE_PERIOD"].includes(verified.subscriptionState)) {
      await grantPremium(uid, verified.expiryTimeMs);
    } else {
      await db.collection("users").doc(uid).update({ premium: false, updatedAt: FieldValue.serverTimestamp() });
    }
  },
);

/**
 * Safety net for `appStoreServerNotifications`/`googlePlayRtdn` — a
 * missed/failed webhook delivery would otherwise leave `premium: true`
 * forever past its real expiry. Only ever touches users with a real
 * `premiumExpiresAt` in the past; a manually-granted VIP (admin panel
 * "VIP et", no `premiumExpiresAt` at all) is never touched by this.
 */
export const expireLapsedPremium = onSchedule({ schedule: "every 24 hours", region: "europe-west1" }, async () => {
  const now = Timestamp.now();
  const snap = await db.collection("users").where("premium", "==", true).where("premiumExpiresAt", "<=", now).get();
  if (snap.empty) return;

  await Promise.all(snap.docs.map((doc) => doc.ref.update({ premium: false, updatedAt: FieldValue.serverTimestamp() })));
  logger.info("expireLapsedPremium: expired lapsed VIP subscriptions", { count: snap.docs.length });
});

/**
 * Venue counterpart to `expireLapsedPremium` (users/VIP) — flips
 * `Venue.isPremium` back to `false` once `premiumExpiresAt` passes.
 * UNLIKE the users version, this ALSO sends a one-time "N gün sonra
 * bitir" reminder push 3-5 days before expiry, deduped by
 * `premiumExpiryReminderSent` (reset to `false` by
 * `applyPaymentOutcome`'s `venue_premium` branch on every new
 * payment, so a renewed venue gets a fresh reminder for its new
 * expiry). No auto-renewal exists (Epoint's `card_uid` token model
 * requires a fresh user-present checkout every time) — the reminder is
 * purely informational, pointing the owner at
 * `VenuePremiumInfoScreen`'s "erkən yenilə" button.
 */
export const expireVenuePremium = onSchedule({ schedule: "every 24 hours", region: "europe-west1" }, async () => {
  const now = Timestamp.now();

  const expiredSnap = await db.collection("venues").where("isPremium", "==", true).where("premiumExpiresAt", "<=", now).get();
  if (!expiredSnap.empty) {
    await Promise.all(
      expiredSnap.docs.map((doc) => doc.ref.update({ isPremium: false, updatedAt: FieldValue.serverTimestamp() })),
    );
    logger.info("expireVenuePremium: expired lapsed venue premium", { count: expiredSnap.docs.length });
  }

  const windowStart = Timestamp.fromMillis(now.toMillis() + 3 * 24 * 60 * 60 * 1000);
  const windowEnd = Timestamp.fromMillis(now.toMillis() + 5 * 24 * 60 * 60 * 1000);
  const reminderSnap = await db
    .collection("venues")
    .where("isPremium", "==", true)
    .where("premiumExpiresAt", ">=", windowStart)
    .where("premiumExpiresAt", "<=", windowEnd)
    .where("premiumExpiryReminderSent", "==", false)
    .get();

  for (const doc of reminderSnap.docs) {
    const venue = doc.data();
    const ownerId = venue.ownerId as string | undefined;
    if (!ownerId) continue;
    const expiresAt = (venue.premiumExpiresAt as Timestamp).toDate();
    const daysLeft = Math.max(1, Math.round((expiresAt.getTime() - now.toMillis()) / (24 * 60 * 60 * 1000)));
    const name = (venue.name as string | undefined) ?? "";
    const quoted = name ? `"${name}"` : "Məkanınızın";
    await notifyUser({
      uid: ownerId,
      category: "account",
      type: "venuePremiumExpiringSoon",
      title: "Premium statusunuz bitir",
      body: `${quoted} premium statusu ${daysLeft} gün sonra bitir.`,
      params: { name, daysLeft },
      targetId: doc.id,
      targetType: "venue",
    });
    await doc.ref.update({ premiumExpiryReminderSent: true, updatedAt: FieldValue.serverTimestamp() });
  }
  if (reminderSnap.docs.length > 0) {
    logger.info("expireVenuePremium: sent premium expiry reminders", { count: reminderSnap.docs.length });
  }
});
