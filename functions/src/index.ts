import { initializeApp } from "firebase-admin/app";
import { FieldValue, getFirestore, GeoPoint, Timestamp } from "firebase-admin/firestore";
import { getAuth } from "firebase-admin/auth";
import { getStorage } from "firebase-admin/storage";
import { BatchResponse, getMessaging } from "firebase-admin/messaging";
import { HttpsError, onCall, onRequest } from "firebase-functions/v2/https";
import { onDocumentCreated, onDocumentDeleted, onDocumentUpdated, onDocumentWritten } from "firebase-functions/v2/firestore";
import { onMessagePublished } from "firebase-functions/v2/pubsub";
import { onSchedule } from "firebase-functions/v2/scheduler";
import { beforeEmailSent, beforeUserSignedIn } from "firebase-functions/v2/identity";
import { defineSecret } from "firebase-functions/params";
import * as logger from "firebase-functions/logger";
import { createHash, randomInt } from "crypto";
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
// Re-enable only after DeviceCheck registration is confirmed actually
// working end-to-end (Firebase Console → App Check → this iOS app must
// show real, un-rejected tokens flowing in) — not just re-flipped back
// to `true` on faith.
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

/**
 * Sends a plain notification email via Resend's REST API (not SMTP —
 * this is app-triggered mail, unrelated to Firebase Auth's own
 * CUSTOM_SMTP config for sign-in emails). Never throws: a failed send
 * shouldn't fail the report-creation write it's reacting to, since the
 * report itself is already safely in Firestore either way.
 */
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
    if (!request.auth?.uid) {
      throw new HttpsError("unauthenticated", "Bu əməliyyat üçün daxil olmalısınız.");
    }

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
  await deleteUserVenues(uid);
  await deleteUserOffers(uid);
  await releasePhoneNumberReservation(uid, authUser.phoneNumber);
  await deleteUserDocAndSubcollections(uid);
  await deleteStoragePrefix(`profile_photos/${uid}/`);
  await deleteStoragePrefix(`stories/${uid}/`);
  await deleteStoragePrefix(`posts/${uid}/`);
  await db.collection("accountDeletions").add({ uid, deletedAt: FieldValue.serverTimestamp() });
  await auth.deleteUser(uid);

  return { success: true };
});

// Mirrors the client's own `_countryCandidatesProvider`/
// `_worldCandidatesProvider` queries — kept in exact sync with
// `lib/features/location/presentation/providers/location_providers.dart`.
const DISCOVER_COUNTRY_CANDIDATES_LIMIT = 300;
const DISCOVER_WORLD_CANDIDATES_LIMIT = 500;

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
 * `lastSeen`/`birthDate` are sent back as epoch-millis, not Firestore
 * `Timestamp`s — the callable wire format doesn't round-trip those —
 * the client reconstructs `Timestamp`s from them so the rest of
 * `nearbyUsersProvider`'s parsing stays unchanged.
 */
export const getDiscoverCandidates = onCall({ region: "us-central1", enforceAppCheck: false }, async (request) => {
  const uid = request.auth?.uid;
  if (!uid) {
    throw new HttpsError("unauthenticated", "Bu əməliyyat üçün daxil olmalısınız.");
  }

  const mode = request.data?.mode as string | undefined;
  if (mode !== "country" && mode !== "world") {
    throw new HttpsError("invalid-argument", "invalid-mode");
  }

  const callerSnap = await db.collection("users").doc(uid).get();
  if (callerSnap.data()?.premium !== true) {
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

  const snap = await query.get();
  const candidates = snap.docs.map((doc) => {
    const data = doc.data();
    const lastSeen = data.lastSeen instanceof Timestamp ? data.lastSeen.toMillis() : null;
    const birthDate = data.birthDate instanceof Timestamp ? data.birthDate.toMillis() : null;
    return { ...data, uid: doc.id, lastSeen, birthDate };
  });

  return { candidates };
});

/** Chat messages this user sent — replaced, not deleted, so the other
 * participant's chat history stays intact. Same scope also owns Storage
 * cleanup: each message's own `mediaUrl` (image/video/audio) is deleted
 * from Storage right before the field itself is cleared, using the exact
 * `senderId == uid` set already being queried here — never the whole
 * `{chatId}` folder, since that would also delete the OTHER
 * participant's media. */
async function replaceMessagesWithPlaceholder(uid: string): Promise<void> {
  const chatsSnap = await db.collection("chats").where("participants", "array-contains", uid).get();

  for (const chatDoc of chatsSnap.docs) {
    const messagesSnap = await chatDoc.ref.collection("messages").where("senderId", "==", uid).get();
    await Promise.all(
      messagesSnap.docs.map(async (messageDoc) => {
        const mediaUrl = messageDoc.data().mediaUrl as string | undefined;
        if (mediaUrl) await deleteStorageObjectByUrl(mediaUrl);
        await messageDoc.ref.update({
          text: DELETED_SENDER_PLACEHOLDER,
          mediaUrl: FieldValue.delete(),
          deletedSender: true,
        });
      })
    );
  }
}

/** Events this user created — archived (kept for other participants'
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
  const subcollections = ["media", "notifications", "favoriteOffers", "notifiedVenues", "sessions", "profileViews"];
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

async function deleteStorageFile(path: string): Promise<void> {
  try {
    await storage.bucket().file(path).delete();
  } catch {
    // Best-effort — no file at this path (e.g. never uploaded) isn't a failure.
  }
}

/** Resolves a Firebase Storage download URL
 * (`.../o/{encodedPath}?alt=media&token=...`) back to its bucket object
 * path and deletes it. The Admin SDK has no `refFromURL` — that's a
 * client-SDK-only convenience — so this mirrors what the Flutter client's
 * own `deleteMessageForEveryone` already does with
 * `_storage.refFromURL(mediaUrl).delete()`. A URL that doesn't match the
 * expected `/o/` shape is silently skipped; an already-missing object is
 * handled by `deleteStorageFile`'s own best-effort catch. */
async function deleteStorageObjectByUrl(url: string): Promise<void> {
  const marker = "/o/";
  const markerIndex = url.indexOf(marker);
  if (markerIndex === -1) return;

  const pathStart = markerIndex + marker.length;
  const queryIndex = url.indexOf("?", pathStart);
  const encodedPath = queryIndex === -1 ? url.substring(pathStart) : url.substring(pathStart, queryIndex);
  await deleteStorageFile(decodeURIComponent(encodedPath));
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
  const userData = userSnap.data();
  if (!userData) return;

  const prefs = (userData.notificationPreferences ?? {}) as Record<string, boolean>;
  if (prefs[params.category] === false) return;

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
  const tokens = (userData.fcmTokens ?? []) as string[];
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
    await db.collection("users").doc(uid).update({ fcmTokens: FieldValue.arrayRemove(...staleTokens) });
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
 * Fires on `premium` false -> true, whichever path caused it — today
 * that's only the admin panel's manual "VIP et" grant (Server Action,
 * Admin SDK write), since real purchases aren't wired to anything yet
 * (see `isPremiumProvider`'s doc comment in premium_providers.dart).
 * Watching the field itself instead of notifying from the admin
 * action means a future RevenueCat webhook flipping the same field
 * gets this notification for free, with no second call site to keep
 * in sync.
 */
export const onUserUpdated = onDocumentUpdated("users/{userId}", async (event) => {
  const before = event.data?.before.data();
  const after = event.data?.after.data();
  if (!before || !after) return;

  if (before.premium !== true && after.premium === true) {
    await notifyUser({
      uid: event.params.userId,
      category: "venueUpdates",
      type: "vipGranted",
      title: "VIP statusu aktivləşdi",
      body: "Siz artıq VIP istifadəçi statusundasınız.",
      params: {},
    });
  }

  // `security` — the app's "email" field is a contact address on
  // `users/{uid}` (see `FirebaseAccountRepository.updateEmail`), not
  // the actual Firebase Auth sign-in credential (that's a synthetic,
  // never-shown address derived from the username, unrelated to this
  // field — see that repository's own doc comment), so this is a
  // plain Firestore field watch, not an Auth-level hook. `before.email
  // !== undefined` excludes setting it for the very first time
  // (onboarding) — that's not a "change" to alert about, there was
  // nothing to compare against yet.
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
 * clears the denormalized `users/{uid}.activeCheckinVenueId` pointer,
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
          const userRef = db.collection("users").doc(uid);
          const userSnap = await tx.get(userRef);
          if (userSnap.exists && userSnap.data()?.activeCheckinVenueId === venueId) {
            tx.update(userRef, { activeCheckinVenueId: null });
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
function haversineMeters(lat1: number, lng1: number, lat2: number, lng2: number): number {
  const earthRadiusMeters = 6371000;
  const toRad = (deg: number) => (deg * Math.PI) / 180;
  const dLat = toRad(lat2 - lat1);
  const dLng = toRad(lng2 - lng1);
  const a =
    Math.sin(dLat / 2) ** 2 + Math.cos(toRad(lat1)) * Math.cos(toRad(lat2)) * Math.sin(dLng / 2) ** 2;
  return 2 * earthRadiusMeters * Math.asin(Math.sqrt(a));
}

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
    if (haversineMeters(lat, lng, user.lat, user.lng) <= radiusKm * 1000) count++;
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

    const [venuesSnap, activeUsersSnap] = await Promise.all([
      db.collection("venues").where("status", "==", "approved").get(),
      db.collection("users").where("lastSeen", ">", activeCutoff).get(),
    ]);
    if (venuesSnap.empty) return;

    const activeUsers: AudienceUserDoc[] = activeUsersSnap.docs.map((d) => d.data() as AudienceUserDoc);

    // Lazily fetched — only venues actually configured for 'country'/
    // 'world' mode ever touch these (the uncommon case; most venues
    // default to 'distance'), cached per run so N venues sharing a
    // country only cost one extra query, not N.
    const onlineByCountry = new Map<string, number>();
    let onlineWorldwide = -1;

    for (const venueDoc of venuesSnap.docs) {
      const venue = venueDoc.data();
      const mode = (venue.audienceRadiusMode as string | undefined) ?? "distance";

      if (mode === "country" && venue.country && !onlineByCountry.has(venue.country as string)) {
        const snap = await db
          .collection("users")
          .where("country", "==", venue.country)
          .where("online", "==", true)
          .get();
        onlineByCountry.set(
          venue.country as string,
          snap.docs.filter((d) => !d.data().ghostModeEnabled).length,
        );
      }
      if (mode === "world" && onlineWorldwide === -1) {
        const snap = await db.collection("users").where("online", "==", true).get();
        onlineWorldwide = snap.docs.filter((d) => !d.data().ghostModeEnabled).length;
      }

      const count = computeAudienceCount(venue, activeUsers, onlineByCountry, onlineWorldwide === -1 ? 0 : onlineWorldwide);

      // One read of the whole subcollection (capped at ~7 days x 96
      // ticks/day ≈ 672 docs) instead of two separate range queries —
      // splits into "same hour, still in-window" (this venue's usual
      // baseline) vs "past the 7-day window" (swept below) in memory.
      const historySnap = await venueDoc.ref.collection("audienceHistory").get();
      const sameHourCounts: number[] = [];
      const staleDocs: FirebaseFirestore.QueryDocumentSnapshot[] = [];
      for (const doc of historySnap.docs) {
        const data = doc.data();
        const ts = data.timestamp as Timestamp | undefined;
        if (!ts) continue;
        if (ts.toMillis() < historyCutoffMs) {
          staleDocs.push(doc);
          continue;
        }
        if (data.hour === hour) sameHourCounts.push(data.count as number);
      }

      if (sameHourCounts.length > 0) {
        const average = sameHourCounts.reduce((a, b) => a + b, 0) / sameHourCounts.length;
        const isPeak = average > 0 && count >= average * AUDIENCE_PEAK_THRESHOLD_MULTIPLIER;

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
      await Promise.all(staleDocs.map((d) => d.ref.delete()));
    }
  },
);

// ── Birthday offers ───────────────────────────────────────────────────

/** Defensive cap on how many opted-in birthday users one run considers — see this function's own doc comment on the geohash follow-up. */
const BIRTHDAY_CANDIDATE_LIMIT = 1000;

interface BirthdayUserDoc {
  uid: string;
  lat?: number;
  lng?: number;
  country?: string;
  discoverRadiusMode?: string;
  discoverRadiusKm?: number;
}

/**
 * Daily at 00:05 Azerbaijan time (`Asia/Baku` — see `timeZone` below,
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
 * `birthdayMatches/{date}_{venueId}` doc per
 * venue that matched at least one user, plus a push nudging the owner
 * to create a birthday offer (`targetType: 'birthday_match'` — the
 * pre-filled Create Offer deep link itself lands with that flow, see
 * `NotificationType.birthdayMatch`'s doc comment client-side).
 *
 * Full collection scans for now (bounded by the `birthdayOffersOptIn`/
 * `birthdayNotificationsEnabled` filters already, plus
 * [BIRTHDAY_CANDIDATE_LIMIT] defensively) — per product decision, this
 * ships and gets tested against a small real dataset before any
 * geohash-sharded query work, so a venue base too large for a daily
 * full scan isn't a problem this build needs to solve yet.
 */
export const computeBirthdayMatches = onSchedule(
  { schedule: "5 0 * * *", timeZone: "Asia/Baku", region: "europe-west1" },
  async () => {
    const bakuParts = new Intl.DateTimeFormat("en-CA", {
      timeZone: "Asia/Baku",
      year: "numeric",
      month: "2-digit",
      day: "2-digit",
    }).formatToParts(new Date());
    const bakuYear = bakuParts.find((p) => p.type === "year")?.value ?? "";
    const bakuMonth = bakuParts.find((p) => p.type === "month")?.value ?? "";
    const bakuDay = bakuParts.find((p) => p.type === "day")?.value ?? "";
    const bakuDateKey = `${bakuYear}-${bakuMonth}-${bakuDay}`;

    const [optedInUsersSnap, eligibleVenuesSnap] = await Promise.all([
      db.collection("users").where("birthdayOffersOptIn", "==", true).limit(BIRTHDAY_CANDIDATE_LIMIT).get(),
      db
        .collection("venues")
        .where("status", "==", "approved")
        .where("birthdayNotificationsEnabled", "==", true)
        .get(),
    ]);
    if (optedInUsersSnap.empty || eligibleVenuesSnap.empty) return;

    const birthdayUsers: BirthdayUserDoc[] = [];
    for (const doc of optedInUsersSnap.docs) {
      const data = doc.data();
      if (data.ghostModeEnabled) continue;
      const birthDate = data.birthDate as Timestamp | undefined;
      if (!birthDate) continue;
      const bd = birthDate.toDate();
      const bdMonth = String(bd.getUTCMonth() + 1).padStart(2, "0");
      const bdDay = String(bd.getUTCDate()).padStart(2, "0");
      if (bdMonth !== bakuMonth || bdDay !== bakuDay) continue;
      birthdayUsers.push({
        uid: doc.id,
        lat: data.lat,
        lng: data.lng,
        country: data.country,
        discoverRadiusMode: data.discoverRadiusMode,
        discoverRadiusKm: data.discoverRadiusKm,
      });
    }
    if (birthdayUsers.length === 0) return;

    for (const venueDoc of eligibleVenuesSnap.docs) {
      const venue = venueDoc.data();
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
      const matchRef = db.collection("birthdayMatches").doc(`${bakuDateKey}_${venueDoc.id}`);
      if ((await matchRef.get()).exists) continue;

      await matchRef.set({
        venueId: venueDoc.id,
        date: bakuDateKey,
        matchedUserIds,
        count: matchedUserIds.length,
        notified: false,
        offerCreated: false,
        createdAt: FieldValue.serverTimestamp(),
      });

      const ownerId = venue.ownerId as string | undefined;
      if (!ownerId) continue;

      await notifyUser({
        uid: ownerId,
        category: "venueUpdates",
        type: "birthdayMatch",
        title: "🎂 Ad günü fürsəti",
        body: `Bugün yaxınlığınızda ${matchedUserIds.length} PeakPin istifadəçisinin doğum günüdür. Onlara xüsusi təklif yarat!`,
        params: { count: matchedUserIds.length },
        targetId: matchRef.id,
        targetType: "birthday_match",
      });
      await matchRef.update({ notified: true });
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
  const caption = post.caption as string | undefined;
  if (!authorId || !caption) return;

  await notifyMentionedUsers({ text: caption, authorId, postId: event.params.postId });
});

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
    category: "venueUpdates",
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
      category: "venueUpdates",
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
        category: "venueUpdates",
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
      category: "venueOffers",
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
      await notifyBirthdayTargetUsers(event.params.offerId, after);
    } else if (after.offerType !== "happyHour" || after.happyHourActive === true) {
      await notifyNearbyUsersOfNewOffer(event.params.offerId, after, ownerId);
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

  const venueId = request.data?.venueId as string | undefined;
  if (!venueId) throw new HttpsError("invalid-argument", "venueId tələb olunur.");

  const partySize = request.data?.partySize as number | undefined;
  if (!Number.isInteger(partySize) || (partySize as number) < 1 || (partySize as number) > 10) {
    throw new HttpsError("invalid-argument", "partySize 1-10 aralığında tam ədəd olmalıdır.");
  }

  const phoneNumber = (request.data?.phoneNumber as string | undefined)?.trim();
  if (!phoneNumber) throw new HttpsError("invalid-argument", "phoneNumber tələb olunur.");

  const note = request.data?.note as string | undefined;
  if (note !== undefined && typeof note !== "string") {
    throw new HttpsError("invalid-argument", "note sətir olmalıdır.");
  }

  const venueSnap = await db.collection("venues").doc(venueId).get();
  if (!venueSnap.exists) throw new HttpsError("not-found", "Məkan tapılmadı.");

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
          category: "venueUpdates",
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
        category: "venueUpdates",
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
 * A `birthday` offer's approval fanout — every uid in
 * `Offer.targetUserIds` (the matched birthday users from
 * `computeBirthdayMatches`) gets its own push, NOT the radius-based
 * `notifyNearbyUsersOfNewOffer` fanout every other approved offer
 * gets. A birthday offer is only ever meant for these specific users
 * (see `nearbyOffersProvider`'s client-side filter, which hides it
 * from everyone else) — notifying by proximity instead would both
 * miss the point and leak it to people it was never meant for.
 */
async function notifyBirthdayTargetUsers(offerId: string, offer: FirebaseFirestore.DocumentData): Promise<void> {
  const targetUserIds = (offer.targetUserIds as string[] | undefined) ?? [];
  if (targetUserIds.length === 0) return;
  const venueName = (offer.venueName as string | undefined) ?? "";

  await Promise.all(
    targetUserIds.map((uid) =>
      notifyUser({
        uid,
        category: "venueOffers",
        type: "birthdayOffer",
        title: "🎉 Sənə xüsusi ad günü təklifi!",
        body: venueName
          ? `${venueName} sənin ad günün üçün xüsusi təklif hazırladı!`
          : "Sənin ad günün üçün xüsusi təklif hazırlandı!",
        params: { venueName },
        targetId: offerId,
        targetType: "offer",
      }),
    ),
  );
}

/** Minimum time between two "new offer" pushes for the same (user,
 * venue) pair — a venue publishing several offers in one day only
 * pings a nearby user once, not once per offer. */
const OFFER_NOTIFY_THROTTLE_MS = 24 * 60 * 60 * 1000;

/** Defensive cap on how many candidate users a single fanout reads —
 * plenty of headroom at this app's current scale; revisit with a
 * paginated/batched fanout (or a real geohash-sharded query) if the
 * user base grows into the thousands. */
const OFFER_NOTIFY_CANDIDATE_LIMIT = 1000;

/**
 * Candidate `users` docs to notify about a new offer/event from
 * [venueId] — shared by `notifyNearbyUsersOfNewOffer` and
 * `...NewEvent`. The SOURCE pool AND the geographic gate both differ
 * by category, per "Fərdi Prodakşn/Sənətçi"'s own venue-level follow
 * feature ("İzlə"): an `independentArtist` venue notifies its
 * followers (`venues/{venueId}/followers`) unconditionally — no
 * geographic gate at all, matching `LiveFeedService.
 * fetchFollowedVenueItems`, which shows a followed venue's items the
 * exact same way. Every other category draws from the app-wide
 * `users` scan and is gated by each recipient's OWN chosen Discover
 * radius (see [isWithinRecipientDiscoverRadius]).
 *
 * `venue.audienceRadiusMode`/`audienceRadiusKm` is deliberately NOT
 * read by either branch — that field is scoped to the owner-only
 * "Ətrafda N istifadəçi" live counter (`computeAudienceCount`) ONLY,
 * not a reach ceiling. Reusing it as one here was the actual bug: an
 * `independentArtist` follower's notification eligibility used to
 * depend on a setting they never saw and that means something else
 * entirely, and for every other category it silently let an owner's
 * counter-radius choice exclude a recipient who'd otherwise have been
 * within their OWN chosen Discover radius.
 */
async function resolveNotifyCandidates(
  venueId: string,
  venue: FirebaseFirestore.DocumentData,
  limit: number,
): Promise<FirebaseFirestore.DocumentSnapshot[]> {
  if (venue.category === "independentArtist") {
    const followerSnaps = await db.collection("venues").doc(venueId).collection("followers").limit(limit).get();
    const followerDocs = await Promise.all(followerSnaps.docs.map((d) => db.collection("users").doc(d.id).get()));
    return followerDocs.filter((d) => d.exists);
  }

  const sourceDocs = (await db.collection("users").limit(limit).get()).docs;
  const venueLat = venue.lat as number | undefined;
  const venueLng = venue.lng as number | undefined;
  const venueCountry = venue.country as string | undefined;
  return sourceDocs.filter((d) => isWithinRecipientDiscoverRadius(d.data() ?? {}, venueLat, venueLng, venueCountry));
}

/**
 * Push + in-app notification when one of the venue's offers goes
 * live — see `resolveNotifyCandidates` for exactly who that reaches
 * (everyone within their OWN chosen Discover radius for most
 * categories, all followers unconditionally for `independentArtist`).
 * Deliberately does NOT filter by recent activity the way the
 * audience counter does — reaching
 * someone who isn't currently in the app is the entire point of a
 * push notification. Throttled per (user, venue) at 24h via
 * `users/{uid}/notifiedVenues/{venueId}`.
 */
async function notifyNearbyUsersOfNewOffer(
  offerId: string,
  offer: FirebaseFirestore.DocumentData,
  ownerId: string,
): Promise<void> {
  const venueId = offer.venueId as string | undefined;
  if (!venueId) return;
  const venueSnap = await db.collection("venues").doc(venueId).get();
  const venue = venueSnap.data();
  if (!venue) return;

  const candidateDocs = await resolveNotifyCandidates(venueId, venue, OFFER_NOTIFY_CANDIDATE_LIMIT);
  // Faza 3: "Fərdi Prodakşn/Sənətçi" followers get their own type —
  // see resolveNotifyCandidates' doc comment for why this category's
  // candidate pool is already radius-unrestricted followers only.
  const isProduction = venue.category === "independentArtist";

  const venueName = (venue.name as string | undefined) ?? "";
  const offerTitle = (offer.title as string | undefined) ?? "";

  await Promise.all(
    candidateDocs.map(async (userDoc) => {
      const uid = userDoc.id;
      const userData = userDoc.data();
      if (!userData) return;
      if (uid === ownerId) return;
      if (userData.ghostModeEnabled) return;

      const throttleRef = db.collection("users").doc(uid).collection("notifiedVenues").doc(venueId);
      const throttleSnap = await throttleRef.get();
      const lastNotifiedAt = (throttleSnap.data()?.lastNotifiedAt as Timestamp | undefined)?.toMillis() ?? 0;
      if (Date.now() - lastNotifiedAt < OFFER_NOTIFY_THROTTLE_MS) return;

      await notifyUser({
        uid,
        category: "venueOffers",
        type: isProduction ? "productionPost" : "venueOffer",
        title: isProduction
          ? (venueName ? `🎬 ${venueName} yeni paylaşım etdi` : "Yeni paylaşım")
          : (venueName ? `☕ ${venueName} yaxınlığınızda` : "Yaxınlığınızda yeni təklif"),
        body: offerTitle,
        params: { venueName, offerTitle },
        targetId: offerId,
        targetType: "offer",
      });
      await throttleRef.set({ lastNotifiedAt: FieldValue.serverTimestamp() }, { merge: true });
    }),
  );
}

/**
 * PinBox equivalent of `notifyNearbyUsersOfNewOffer` — same candidate
 * pool/radius/throttle rules, fired from `onPinBoxUpdated` the moment a
 * box reaches `active` (PinBox's own "now visible to discovery"
 * transition, same role `status === 'approved'` plays for offers).
 * Shares the SAME per-(user, venue) throttle doc as offers — a venue
 * that publishes an offer and a PinBox on the same day still only
 * pings a given nearby user once, not once per listing type.
 */
async function notifyNearbyUsersOfNewPinBox(
  pinboxId: string,
  pinbox: FirebaseFirestore.DocumentData,
  ownerId: string,
): Promise<void> {
  const venueId = pinbox.venueId as string | undefined;
  if (!venueId) return;
  const venueSnap = await db.collection("venues").doc(venueId).get();
  const venue = venueSnap.data();
  if (!venue) return;

  const candidateDocs = await resolveNotifyCandidates(venueId, venue, OFFER_NOTIFY_CANDIDATE_LIMIT);
  const venueName = (venue.name as string | undefined) ?? "";
  const pinboxTitle = (pinbox.title as string | undefined) ?? "";

  await Promise.all(
    candidateDocs.map(async (userDoc) => {
      const uid = userDoc.id;
      const userData = userDoc.data();
      if (!userData) return;
      if (uid === ownerId) return;
      if (userData.ghostModeEnabled) return;

      const throttleRef = db.collection("users").doc(uid).collection("notifiedVenues").doc(venueId);
      const throttleSnap = await throttleRef.get();
      const lastNotifiedAt = (throttleSnap.data()?.lastNotifiedAt as Timestamp | undefined)?.toMillis() ?? 0;
      if (Date.now() - lastNotifiedAt < OFFER_NOTIFY_THROTTLE_MS) return;

      await notifyUser({
        uid,
        category: "venueOffers",
        type: "pinboxNearby",
        title: venueName ? `📦 ${venueName} yaxınlığınızda` : "Yaxınlığınızda yeni PinBox",
        body: pinboxTitle,
        params: { venueName, pinboxTitle },
        targetId: pinboxId,
        targetType: "pinbox",
      });
      await throttleRef.set({ lastNotifiedAt: FieldValue.serverTimestamp() }, { merge: true });
    }),
  );
}

// ── Venue events (auto-approved, no moderation gate) ─────────────────

/** Same bound as `OFFER_NOTIFY_CANDIDATE_LIMIT` — how many `users` docs
 * the radius/country/world scan considers before filtering. */
const EVENT_NOTIFY_CANDIDATE_LIMIT = 1000;

/**
 * Fires the instant a `venueEvents/{eventId}` doc is created — unlike
 * `notifyNearbyUsersOfNewOffer`, there's no `status` transition to wait
 * for, since events are auto-approved and start `upcoming` immediately
 * (see `VenueEvent`'s doc comment). Same radius/country/world dispatch
 * and Haversine filtering as the offer version — GeoFlutterFire Plus
 * itself is a Flutter/client package, so this server-side fanout uses
 * the same manual-distance-filter approach this codebase already
 * established for offers, not a literal GeoFlutterFire call.
 *
 * Dedup is permanent, not a rolling throttle like offers' 24h window —
 * an event only ever gets ONE publish moment, so
 * `users/{uid}/notifiedEvents/{eventId}` existing at all is enough to
 * skip a user, covering a retried function invocation.
 */
export const notifyNearbyUsersOfNewEvent = onDocumentCreated("venueEvents/{eventId}", async (event) => {
  const data = event.data?.data();
  if (!data) return;

  const venueId = data.venueId as string | undefined;
  if (!venueId) return;
  const venueSnap = await db.collection("venues").doc(venueId).get();
  const venue = venueSnap.data();
  if (!venue) return;

  const ownerId = venue.ownerId as string | undefined;
  const candidateDocs = await resolveNotifyCandidates(venueId, venue, EVENT_NOTIFY_CANDIDATE_LIMIT);
  const isProduction = venue.category === "independentArtist";

  const venueName = (venue.name as string | undefined) ?? "";
  const eventTitle = (data.title as string | undefined) ?? "";
  const eventId = event.params.eventId;

  await Promise.all(
    candidateDocs.map(async (userDoc) => {
      const uid = userDoc.id;
      const userData = userDoc.data();
      if (!userData) return;
      if (uid === ownerId) return;
      if (userData.ghostModeEnabled) return;

      const dedupRef = db.collection("users").doc(uid).collection("notifiedEvents").doc(eventId);
      const dedupSnap = await dedupRef.get();
      if (dedupSnap.exists) return;

      await notifyUser({
        uid,
        category: "venueOffers",
        type: isProduction ? "productionPost" : "venueEvent",
        title: isProduction
          ? (venueName ? `🎬 ${venueName} yeni paylaşım etdi` : "Yeni paylaşım")
          : (venueName ? `🎤 ${venueName}-də bu axşam` : "🎤 Yaxınlığınızda tədbir"),
        body: eventTitle,
        params: { venueName, eventTitle },
        targetId: eventId,
        targetType: "event",
      });
      await dedupRef.set({ sentAt: FieldValue.serverTimestamp() });
    })
  );
});

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
function revertRevisionPayment(tx: FirebaseFirestore.Transaction, paymentId: string | undefined): void {
  if (!paymentId) return;
  tx.update(db.collection("payments").doc(paymentId), {
    status: "completed",
    updatedAt: FieldValue.serverTimestamp(),
  });
}

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
 */
export const resubmitVenue = onCall({ region: "us-central1", enforceAppCheck: false }, async (request) => {
  const uid = request.auth?.uid;
  if (!uid) throw new HttpsError("unauthenticated", "Bu əməliyyat üçün daxil olmalısınız.");

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

/** Offer equivalent of `resubmitVenue` — same contract (`needs_revision`
 * OR `approved` → `pending`), same reasoning. */
export const resubmitOffer = onCall({ region: "us-central1", enforceAppCheck: false }, async (request) => {
  const uid = request.auth?.uid;
  if (!uid) throw new HttpsError("unauthenticated", "Bu əməliyyat üçün daxil olmalısınız.");

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
 * PinBox equivalent of `resubmitVenue`/`resubmitOffer` — two distinct
 * callers: `needs_revision` → the admin sent it back with a reason, the
 * owner fixed it and is resubmitting for review; `active` → an owner
 * editing an already-live PinBox, which re-enters moderation the same
 * "no silent content swap on a live listing" way `resubmitVenue`'s
 * `approved` branch does. No `revisionDeadline`/`paymentId` fields
 * exist on PinBox (no flat listing fee — see `PinBox`'s own doc
 * comment), so there's nothing equivalent to `revertRevisionPayment` to
 * call here.
 */
export const resubmitPinBox = onCall({ region: "us-central1", enforceAppCheck: false }, async (request) => {
  const uid = request.auth?.uid;
  if (!uid) throw new HttpsError("unauthenticated", "Bu əməliyyat üçün daxil olmalısınız.");

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
    category: "venueOffers",
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
      category: "venueOffers",
      ...notification,
      targetId: event.params.pinboxId,
      targetType: "pinbox",
    });
  }

  if (after.status === "active") {
    await notifyNearbyUsersOfNewPinBox(event.params.pinboxId, after, ownerId);
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
      category: "venueUpdates",
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
    category: "venueUpdates",
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
  { document: "payments/{paymentId}", secrets: [epointPublicKey, epointPrivateKey] },
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

/**
 * Independently declared copy of `_venueListingFeeFor` in
 * `lib/features/venues/data/repositories/firebase_venue_repository.dart`
 * — Cloud Functions can't import that Dart file, so this table is kept
 * in sync by hand. Exhaustive on purpose (see that file's own doc
 * comment for why) — a `switch` with no default here would silently
 * fall through to `undefined` for a category added on the Flutter side
 * but forgotten here, so this uses a plain lookup object instead and
 * `renewVenueSubscriptions` treats a missing entry as a bug to log, not
 * a 0 AZN charge.
 */
const venueSubscriptionFeeByCategory: Record<string, number> = {
  restaurant: 30, pub: 30, coffeeShop: 25, fastFood: 25, teaHouse: 15, sweetsShop: 20,
  hotel: 30, motel: 20, cinema: 30, karaoke: 30, gameHall: 30, nightClub: 30,
  fitness: 30, gym: 30, spa: 30, footballField: 25, clinic: 30, beautySalon: 30,
  barbershop: 20, cosmetology: 30, tattoo: 20, photoStudio: 20, kidsEntertainment: 30,
  pharmacyOptics: 30, dentalClinic: 30, perfumeryCosmetics: 25, carWash: 20, carRepair: 20,
  supermarket: 30, bookstoreStationery: 20, petStore: 20, tailor: 15, dryCleaning: 25,
  applianceRepair: 20, tutoringCenter: 25,
  independentArtist: 30, other: 25,
};

const SUBSCRIPTION_CYCLE_MS = 30 * 24 * 60 * 60 * 1000;

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
async function ensurePendingSubscriptionPayment(
  venueId: string,
  ownerId: string,
  category: string,
  venueName: string,
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
    return { ref: latest.ref, amount: latest.data().amount as number, isNew: false };
  }
  if (latest && latest.data().status === "pending" && latest.data().checkoutStartedAt) {
    await latest.ref.update({ status: "failed", updatedAt: FieldValue.serverTimestamp() });
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
  { schedule: "every 24 hours", region: "europe-west1", secrets: [epointPublicKey, epointPrivateKey] },
  async () => {
    const now = new Date();
    const snap = await db
      .collection("venues")
      .where("status", "==", "approved")
      .where("subscriptionRenewsAt", "<=", Timestamp.fromDate(now))
      .get();

    if (snap.empty) return;

    let invoiced = 0;
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
      if (!isNew) continue;

      try {
        await startEpointCheckoutForPayment(paymentRef.id, amount, `Məkan abunəliyi — ${venueName}`);
      } catch (e) {
        logger.error("renewVenueSubscriptions: Epoint checkout failed", { venueId: doc.id, error: e });
        // Payment doc stays 'pending' regardless — the owner's own
        // "Ödə" button (retryVenueSubscriptionPayment) tries again.
      }

      await notifyUser({
        uid: ownerId,
        category: "venueUpdates",
        type: "venueSubscriptionDue",
        title: "Məkan abunəliyi ödənişi tələb olunur",
        body: venueName ? `"${venueName}" üçün abunəlik ödənişini tamamlayın.` : "Abunəlik ödənişini tamamlayın.",
        params: { venueName, amount },
        targetId: doc.id,
        targetType: "venue_subscription_due",
      });
      invoiced++;
    }

    if (invoiced > 0) logger.info("renewVenueSubscriptions: invoiced venue subscriptions", { invoiced });
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
  { region: "us-central1", secrets: [epointPublicKey, epointPrivateKey], enforceAppCheck: false },
  async (request) => {
    const uid = request.auth?.uid;
    if (!uid) throw new HttpsError("unauthenticated", "Bu əməliyyat üçün daxil olmalısınız.");

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

    const venueName = (venue.name as string | undefined) ?? "";
    const { ref: paymentRef, amount } = await ensurePendingSubscriptionPayment(venueId, uid, category, venueName);
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
  { region: "us-central1", secrets: [epointPublicKey, epointPrivateKey], enforceAppCheck: false },
  async (request) => {
    const uid = request.auth?.uid;
    if (!uid) throw new HttpsError("unauthenticated", "Bu əməliyyat üçün daxil olmalısınız.");

    // The ONLY gate on "can this account create a venue" — a self-service
    // toggle in Privacy/Security ("Biznes fəaliyyəti"), default 'active'
    // for every account (same default `firestore.rules`' old
    // `isBusinessUser` used, `.get('businessStatus', 'active')`). That
    // rule was the sole enforcement point before venue creation moved
    // server-side; this replicates it here now that the rule itself is
    // `allow create: if false`.
    const requesterSnap = await db.collection("users").doc(uid).get();
    if ((requesterSnap.data()?.businessStatus as string | undefined) === "none") {
      throw new HttpsError("permission-denied", "Məkan yaratmaq üçün Ayarlar → Biznes fəaliyyəti bölməsindən aktiv edin.");
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
      throw new HttpsError("invalid-argument", "Tələb olunan sahələr çatışmır.");
    }

    const fee = venueSubscriptionFeeByCategory[category];
    if (fee === undefined) {
      logger.error("submitVenue: no subscription fee tier for category", { category });
      throw new HttpsError("failed-precondition", "Bu məkan kateqoriyası üçün haqq cədvəli tapılmadı.");
    }

    const venueRef = db.collection("venues").doc(clientVenueId);
    if ((await venueRef.get()).exists) {
      throw new HttpsError("already-exists", "Bu ID artıq istifadə olunub.");
    }

    const { ref: paymentRef, amount } = await ensurePendingSubscriptionPayment(clientVenueId, uid, category, name);

    await venueRef.set({
      ownerId: uid,
      name,
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
      audienceRadiusKm: (data.audienceRadiusKm as number | undefined) ?? 1.0,
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
  { region: "us-central1", secrets: [epointPublicKey, epointPrivateKey], enforceAppCheck: false },
  async (request) => {
    const uid = request.auth?.uid;
    if (!uid) throw new HttpsError("unauthenticated", "Bu əməliyyat üçün daxil olmalısınız.");

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
      await paymentDoc.ref.update({ status: "failed", updatedAt: FieldValue.serverTimestamp() });
      targetRef = db.collection("payments").doc();
      await targetRef.set({
        ownerId: uid,
        listingType: "venue",
        listingId: venueId,
        type: "venue_subscription",
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
  { region: "us-central1", secrets: [epointPublicKey, epointPrivateKey], enforceAppCheck: false },
  async (request) => {
    const uid = request.auth?.uid;
    if (!uid) throw new HttpsError("unauthenticated", "Bu əməliyyat üçün daxil olmalısınız.");

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

/**
 * Cleans up a deleted post's `likes`/`comments` subcollections —
 * Firestore doesn't cascade-delete them, and the client CAN'T (each
 * like/comment doc's own rule only lets its own author delete it, not
 * the post owner). Admin SDK bypasses that, same as deleteAccount.
 */
export const onPostDeleted = onDocumentDeleted("posts/{postId}", async (event) => {
  const postRef = event.data?.ref;
  if (!postRef) return;

  const [likesSnap, commentsSnap] = await Promise.all([
    postRef.collection("likes").get(),
    postRef.collection("comments").get(),
  ]);

  await Promise.all([...likesSnap.docs, ...commentsSnap.docs].map((doc) => doc.ref.delete()));
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

    const chatSnap = await db.collection("chats").doc(chatId).get();
    const mutedBy = (chatSnap.data()?.mutedBy ?? {}) as Record<string, boolean>;
    if (mutedBy[receiverId] === true) return;

    const [senderSnap, receiverSnap] = await Promise.all([
      db.collection("users").doc(senderId).get(),
      db.collection("users").doc(receiverId).get(),
    ]);
    const receiverData = receiverSnap.data();
    if (!receiverData) return;

    // Receiver has this exact chat open right now (foreground) — see
    // `activeChatId` on `users/{uid}`, set/cleared by
    // ChatConversationScreen. A push while they're already looking at
    // the conversation would just be noise (and could double-count as
    // an unread badge blip); the in-app message list itself is the
    // real-time signal in that case.
    if (receiverData.activeChatId === chatId) return;

    const prefs = receiverData.notificationPreferences ?? {};
    const pushEnabled = prefs.pushEnabled ?? true;
    const messagesEnabled = prefs.messages ?? true;
    if (!pushEnabled || !messagesEnabled) return;

    const tokens = (receiverData.fcmTokens ?? []) as string[];
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
      `<p><strong>Şikayətçi:</strong> ${reporter.name} (${reporterId})</p>
       <p><strong>Şikayət olunan:</strong> ${reported.name} (${reportedUserId})</p>
       <p><strong>Səbəb:</strong> ${reason}</p>
       ${data.chatId ? `<p><strong>Söhbət ID:</strong> ${data.chatId}</p>` : ""}
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
      `<p><strong>Şikayətçi:</strong> ${reporter.name} (${reportedBy})</p>
       <p><strong>Tədbir:</strong> ${eventTitle} (${eventId})</p>
       <p><strong>Səbəb:</strong> ${reason}</p>
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
      `<p><strong>Şikayətçi:</strong> ${reporter.name} (${reporterId})</p>
       <p><strong>Rəy:</strong> ${reviewComment} (${reviewId})</p>
       <p><strong>Səbəb:</strong> ${reason}</p>
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

// Stable marker embedded in the blocking error's message — Firebase
// Auth's client SDKs don't reliably surface the HttpsError *code*
// through a blocking-function rejection (it typically lands as a
// generic FirebaseAuthException), but the message text does come
// through intact. AuthScreen/DeleteAccountRow's error handlers grep
// for this to show the friendly rate-limit copy instead of the
// generic "sign-in failed" one.
const RATE_LIMIT_MARKER = "RATE_LIMIT_EXCEEDED";

const EMAIL_SEND_MIN_INTERVAL_MS = 60 * 1000; // 1 link per email per 60s
const EMAIL_SEND_HOURLY_MAX = 5; // 5 links per email per hour
const IP_WINDOW_MS = 10 * 60 * 1000; // 10 minutes
const IP_DISTINCT_EMAIL_MAX = 5; // 5 distinct emails per IP per window

const SPIKE_WINDOW_MS = 10 * 60 * 1000; // 10 minutes
const SPIKE_ALERT_THRESHOLD = 100; // project-wide EMAIL_SIGN_IN attempts in that window
const SPIKE_ALERT_COOLDOWN_MS = 30 * 60 * 1000; // don't re-alert for the same ongoing spike more than once per 30min

/**
 * Faza 6 — best-effort project-wide anomaly alert, reusing the same
 * Resend-backed email helper `onUserReportCreated` already sends
 * moderation notices through (no separate monitoring stack). Counts
 * every EMAIL_SIGN_IN *attempt* (blocked or not) — a real attack shows
 * up as request volume regardless of how much of it the per-email/IP
 * limits above actually let through. Never throws: a failure here
 * must never block or unblock a send decision that's already been made.
 */
async function checkEmailSendSpike(): Promise<void> {
  try {
    const now = Date.now();
    const spikeRef = db.collection("rateLimits").doc("global:emailSignInSpike");
    await db.runTransaction(async (tx) => {
      const snap = await tx.get(spikeRef);
      const data = snap.data();
      const timestamps: number[] = (data?.timestamps ?? []).filter((t: number) => now - t < SPIKE_WINDOW_MS);
      timestamps.push(now);

      const lastAlertAt: number | undefined = data?.lastAlertAt;
      const coolingDown = lastAlertAt !== undefined && now - lastAlertAt < SPIKE_ALERT_COOLDOWN_MS;

      if (timestamps.length >= SPIKE_ALERT_THRESHOLD && !coolingDown) {
        tx.set(spikeRef, { timestamps, lastAlertAt: now });
        // Fires after the transaction would normally commit, but
        // Firestore doesn't support side effects mid-transaction —
        // acceptable here since a duplicate alert is harmless and the
        // cooldown above already prevents the common case.
        await sendPrivacyNotificationEmail(
          "⚠️ Qeyri-adi yüksək giriş-linki trafiki — PeakPin",
          `<p>Son ${SPIKE_WINDOW_MS / 60000} dəqiqədə <strong>${timestamps.length}</strong> e-poçt giriş linki sorğusu qeydə alındı (hədd: ${SPIKE_ALERT_THRESHOLD}).</p>
           <p>Bu, sui-istifadə/bot hücumu cəhdi ola bilər. Firebase Console → Authentication → Usage bölümündən yoxlayın.</p>
           <p>Növbəti xəbərdarlıq ən tez ${SPIKE_ALERT_COOLDOWN_MS / 60000} dəqiqə sonra göndəriləcək (davam edən bir hadisə üçün təkrar-təkrar bildiriş göndərilmir).</p>`
        );
      } else {
        tx.set(spikeRef, { timestamps, lastAlertAt: lastAlertAt ?? null });
      }
    });
  } catch (e) {
    logger.error("checkEmailSendSpike failed", e);
  }
}

/**
 * Server-side gate for the app's passwordless email sign-in link (see
 * `sendEmailSignInLink`/`sendReauthEmailLink` in the Flutter client) —
 * a Blocking Function fires here automatically, before Firebase sends
 * ANY auth email, for every provider/platform, with no client-side
 * change needed. Deliberately ignores `PASSWORD_RESET` (the admin
 * panel's separate email+password login) — this task is scoped to the
 * email *link* flow only.
 *
 * Firestore-backed sliding-window counters, not a queue or cache
 * service — `rateLimits/{key}` docs store recent-send timestamps and
 * self-prune (anything outside the window is dropped on the next
 * write), per the task's own "no new backend infra" constraint.
 *
 * Must run in us-central1 — Identity Platform blocking functions are
 * restricted to that region regardless of where the rest of this
 * codebase's functions are deployed.
 */
export const enforceEmailLinkRateLimit = beforeEmailSent(
  { region: "us-central1" },
  async (event) => {
    if (event.emailType !== "EMAIL_SIGN_IN") return;

    // NOT event.data?.email — that's undefined for a not-yet-existing
    // account (the common case: someone's first-ever sign-in link).
    // Confirmed via a live debug log dump of the raw event.
    const email = (event.additionalUserInfo?.email ?? "").toLowerCase().trim();
    const ip = event.ipAddress || "unknown";
    if (!email) return;

    await checkEmailSendSpike();

    const now = Date.now();
    const emailRef = db.collection("rateLimits").doc(`email:${email}`);
    const ipRef = db.collection("rateLimits").doc(`ip:${ip}`);

    await db.runTransaction(async (tx) => {
      const [emailSnap, ipSnap] = await Promise.all([tx.get(emailRef), tx.get(ipRef)]);

      const emailTimestamps: number[] = (emailSnap.data()?.timestamps ?? []).filter(
        (t: number) => now - t < 60 * 60 * 1000
      );
      const lastSend = emailTimestamps[emailTimestamps.length - 1];
      if (lastSend && now - lastSend < EMAIL_SEND_MIN_INTERVAL_MS) {
        throw new HttpsError("resource-exhausted", RATE_LIMIT_MARKER);
      }
      if (emailTimestamps.length >= EMAIL_SEND_HOURLY_MAX) {
        throw new HttpsError("resource-exhausted", RATE_LIMIT_MARKER);
      }

      const ipEntries: { email: string; ts: number }[] = (ipSnap.data()?.entries ?? []).filter(
        (e: { ts: number }) => now - e.ts < IP_WINDOW_MS
      );
      const distinctEmails = new Set(ipEntries.map((e) => e.email));
      distinctEmails.add(email);
      if (distinctEmails.size > IP_DISTINCT_EMAIL_MAX) {
        throw new HttpsError("resource-exhausted", RATE_LIMIT_MARKER);
      }

      tx.set(emailRef, { timestamps: [...emailTimestamps, now] });
      tx.set(ipRef, { entries: [...ipEntries.filter((e) => e.email !== email), { email, ts: now }] });
    });
  }
);

/** How many recent device signatures to remember per account — an
 * older one just quietly ages out (LRU-ish, most-recent-first) rather
 * than growing the array forever. */
const KNOWN_DEVICE_SIGNATURE_LIMIT = 8;

/**
 * Fires before every sign-in, across every provider/platform — same
 * "no client-side change needed" Blocking Function pattern as
 * `enforceEmailLinkRateLimit` above, and (unlike that one) purely
 * observational: this NEVER throws, so a bug here can never lock
 * anyone out of their own account — the entire body is wrapped in
 * try/catch specifically because blocking a sign-in is a far worse
 * failure mode than silently missing one security alert.
 *
 * Keys a "known devices" list on `users/{uid}.knownDeviceSignatures`
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
 * Must run in us-central1 — same Identity Platform region restriction
 * `enforceEmailLinkRateLimit` documents.
 */
export const notifyOnNewDeviceSignIn = beforeUserSignedIn({ region: "us-central1" }, async (event) => {
  try {
    const uid = event.data?.uid;
    if (!uid) return;

    const signature = createHash("sha256").update(event.userAgent || "unknown").digest("hex").slice(0, 16);

    const userRef = db.collection("users").doc(uid);
    const userSnap = await userRef.get();
    const known = (userSnap.data()?.knownDeviceSignatures as string[] | undefined) ?? [];

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

    await userRef.set(
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
  { region: "us-central1", secrets: [epointPublicKey, epointPrivateKey], enforceAppCheck: false },
  async (request) => {
    const uid = request.auth?.uid;
    if (!uid) throw new HttpsError("unauthenticated", "Bu əməliyyat üçün daxil olmalısınız.");

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

export const generatePinBoxQrToken = onCall({ region: "us-central1", enforceAppCheck: false }, async (request) => {
  const uid = request.auth?.uid;
  if (!uid) throw new HttpsError("unauthenticated", "Bu əməliyyat üçün daxil olmalısınız.");

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
export const redeemPinBoxOrder = onCall({ region: "us-central1", enforceAppCheck: false }, async (request) => {
  const uid = request.auth?.uid;
  if (!uid) throw new HttpsError("unauthenticated", "Bu əməliyyat üçün daxil olmalısınız.");

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
  { region: "us-central1", secrets: [epointPublicKey, epointPrivateKey], enforceAppCheck: false },
  async (request) => {
    const uid = request.auth?.uid;
    if (!uid) throw new HttpsError("unauthenticated", "Bu əməliyyat üçün daxil olmalısınız.");

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
      ...(data.birthdayMatchId ? { birthdayMatchId: data.birthdayMatchId } : {}),
      ...((data.targetUserIds as string[] | undefined)?.length ? { targetUserIds: data.targetUserIds } : {}),
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
  { region: "us-central1", secrets: [epointPublicKey, epointPrivateKey], enforceAppCheck: false },
  async (request) => {
    const uid = request.auth?.uid;
    if (!uid) throw new HttpsError("unauthenticated", "Bu əməliyyat üçün daxil olmalısınız.");

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
      await paymentDoc.ref.update({ status: "failed", updatedAt: FieldValue.serverTimestamp() });
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
): Promise<boolean> {
  const paymentRef = db.collection("payments").doc(orderId);
  const paymentSnap = await paymentRef.get();
  const payment = paymentSnap.data();
  if (!payment) {
    logger.error("applyPaymentOutcome: unknown payment", { orderId });
    return false;
  }
  if (payment.status !== "pending") return false;

  await db.runTransaction(async (tx) => {
    // Firestore transactions need every read before any write — the
    // venue_subscription branch needs the venue's current
    // subscriptionRenewsAt to compute the next cycle, a FAILED
    // pinbox_order needs its own order doc (for pinboxId/quantity, to
    // release the stock it held), and a SUCCEEDED pinbox_order needs
    // both the order (pinboxId) and the pinbox/venue docs (title/name)
    // to write the venuePayouts obligation row below — all reads
    // happen up front regardless of which payment type this actually is.
    const venueRef =
      succeeded && payment.type === "venue_subscription" && payment.listingType === "venue"
        ? db.collection("venues").doc(payment.listingId as string)
        : null;
    const venueSnap = venueRef ? await tx.get(venueRef) : null;

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
      const offerRef = db.collection("offers").doc(payment.listingId as string);
      if (succeeded) {
        tx.update(offerRef, {
          status: "pending",
          paymentId: paymentRef.id,
          updatedAt: FieldValue.serverTimestamp(),
        });
      }
      // On failure the offer just stays `awaiting_payment` —
      // `retryOfferPayment` is the owner's way back in; nothing to
      // undo here since the offer was never made visible.
    } else if (payment.type === "venue_subscription" && payment.listingType === "venue" && venueRef) {
      if (succeeded) {
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
          });
        } else {
          const prevRenewsAt = (venueSnap?.data()?.subscriptionRenewsAt as Timestamp | undefined)?.toDate() ?? new Date();
          const nextRenewsAt = new Date(prevRenewsAt.getTime() + SUBSCRIPTION_CYCLE_MS);
          tx.update(venueRef, {
            paymentId: paymentRef.id,
            subscriptionRenewsAt: Timestamp.fromDate(nextRenewsAt),
            updatedAt: FieldValue.serverTimestamp(),
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
        tx.update(db.collection("offers").doc(payment.listingId as string), {
          boostedUntil: Timestamp.fromDate(new Date(Date.now() + hours * 60 * 60 * 1000)),
          updatedAt: FieldValue.serverTimestamp(),
        });
      }
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
        const commissionAmount = Math.round(grossAmount * PINBOX_PAYOUT_COMMISSION_RATE * 100) / 100;
        const payoutAmount = Math.round((grossAmount - commissionAmount) * 100) / 100;
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
          category: "venueOffers",
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
          category: "venueOffers",
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
        category: "venueUpdates",
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
    } else if (payment.type === "pinbox_order") {
      const freshOrderSnap = await db.collection("pinboxOrders").doc(payment.listingId as string).get();
      const pinboxId = freshOrderSnap.data()?.pinboxId as string | undefined;
      const freshPinboxSnap = pinboxId ? await db.collection("pinboxes").doc(pinboxId).get() : null;
      const title = (freshPinboxSnap?.data()?.title as string | undefined) ?? "";
      const owner = await getUserDisplayInfo(ownerId);
      const quoted = title ? `"${title}"` : "PinBox";
      await notifyUser({
        uid: ownerId,
        category: "venueOffers",
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
    } else if (payment.type === "venue_subscription") {
      const freshVenueSnap = await db.collection("venues").doc(payment.listingId as string).get();
      name = (freshVenueSnap.data()?.name as string | undefined) ?? "";
      targetType = "venue";
    } else if (payment.type === "pinbox_order") {
      targetType = "pinbox_order";
    }
    await notifyUser({
      uid: ownerId,
      category: "venueOffers",
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
  { region: "us-central1", secrets: [epointPublicKey, epointPrivateKey] },
  async (req, res) => {
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

    const paymentSnap = await db.collection("payments").doc(orderId).get();
    if (paymentSnap.exists) {
      const applied = await applyPaymentOutcome(
        orderId,
        succeeded,
        failureDetail,
        succeeded ? (decoded.transaction as string | undefined) : undefined,
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
  { region: "us-central1", secrets: [epointPublicKey, epointPrivateKey], enforceAppCheck: false },
  async (request) => {
    const uid = request.auth?.uid;
    if (!uid) throw new HttpsError("unauthenticated", "Bu əməliyyat üçün daxil olmalısınız.");

    const paymentId = request.data?.paymentId as string | undefined;
    if (!paymentId) throw new HttpsError("invalid-argument", "paymentId tələb olunur.");

    const payment = await loadOwnedPendingPayment(uid, paymentId);
    const { widgetUrl } = await createEpointTokenWidget({
      publicKey: epointPublicKeyValue(),
      privateKey: epointPrivateKeyValue(),
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
  { region: "us-central1", secrets: [epointPublicKey, epointPrivateKey], enforceAppCheck: false },
  async (request) => {
    const uid = request.auth?.uid;
    if (!uid) throw new HttpsError("unauthenticated", "Bu əməliyyat üçün daxil olmalısınız.");

    const cardRef = db.collection("savedCards").doc();
    await cardRef.set({ ownerId: uid, status: "pending", createdAt: FieldValue.serverTimestamp() });

    const { redirectUrl } = await createEpointCardRegistration({
      publicKey: epointPublicKeyValue(),
      privateKey: epointPrivateKeyValue(),
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
  { region: "us-central1", secrets: [epointPublicKey, epointPrivateKey], enforceAppCheck: false },
  async (request) => {
    const uid = request.auth?.uid;
    if (!uid) throw new HttpsError("unauthenticated", "Bu əməliyyat üçün daxil olmalısınız.");

    const paymentId = request.data?.paymentId as string | undefined;
    const cardId = request.data?.cardId as string | undefined;
    if (!paymentId || !cardId) throw new HttpsError("invalid-argument", "paymentId və cardId tələb olunur.");

    const payment = await loadOwnedPendingPayment(uid, paymentId);
    const card = await loadOwnedActiveCard(uid, cardId);

    const result = await chargeEpointSavedCard({
      publicKey: epointPublicKeyValue(),
      privateKey: epointPrivateKeyValue(),
      epointCardId: card.epointCardId as string,
      amount: payment.amount as number,
      orderId: `${paymentId}-sc`,
      description: (payment.description as string | undefined) ?? "PeakPin",
    });

    await applyPaymentOutcome(
      paymentId,
      result.succeeded,
      result.succeeded ? undefined : { message: result.message },
      result.succeeded ? result.transaction : undefined,
    );

    return { succeeded: result.succeeded, failureMessage: result.succeeded ? undefined : result.message };
  },
);

export const deleteSavedCard = onCall({ region: "us-central1", enforceAppCheck: false }, async (request) => {
  const uid = request.auth?.uid;
  if (!uid) throw new HttpsError("unauthenticated", "Bu əməliyyat üçün daxil olmalısınız.");

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

export const setDefaultSavedCard = onCall({ region: "us-central1", enforceAppCheck: false }, async (request) => {
  const uid = request.auth?.uid;
  if (!uid) throw new HttpsError("unauthenticated", "Bu əməliyyat üçün daxil olmalısınız.");

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
 * carries a Firebase uid. `verifyInAppPurchase` records the mapping
 * the moment it first grants premium so `appStoreServerNotifications`/
 * `googlePlayRtdn` can resolve who to update later; `platform`/
 * `productId` ride along so those handlers don't have to re-derive
 * them.
 */
async function recordIapSubscriptionOwner(
  key: string,
  uid: string,
  platform: "ios" | "android",
  productId: string,
): Promise<void> {
  await db.collection("iapSubscriptions").doc(key).set(
    { uid, platform, productId, updatedAt: FieldValue.serverTimestamp() },
    { merge: true },
  );
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
  { region: "us-central1", secrets: [googlePlayServiceAccountJson], enforceAppCheck: false },
  async (request) => {
    const uid = request.auth?.uid;
    if (!uid) throw new HttpsError("unauthenticated", "Bu əməliyyat üçün daxil olmalısınız.");

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
        verified = await verifyAppleTransaction({
          signedTransactionInfo: receiptData,
          bundleId: APPLE_BUNDLE_ID,
          environment: "Sandbox",
          appAppleId: undefined,
        });
      }

      if (verified.revoked) throw new HttpsError("failed-precondition", "Bu alış geri qaytarılıb.");
      if (verified.productId !== productId) throw new HttpsError("failed-precondition", "Product ID uyğun gəlmir.");

      const expiresAtMs = verified.expiresDateMs ?? Date.now() + VIP_PRODUCT_DURATIONS_MS[productId];
      await grantPremium(uid, expiresAtMs);
      await recordIapSubscriptionOwner(verified.originalTransactionId, uid, "ios", productId);
      return { success: true, expiresAt: expiresAtMs };
    }

    if (platform === "android") {
      const verified = await verifyGoogleSubscription({
        serviceAccountJson: googlePlayServiceAccountJson.value(),
        packageName: GOOGLE_PLAY_PACKAGE_NAME,
        purchaseToken: receiptData,
      });

      if (verified.productId !== productId) throw new HttpsError("failed-precondition", "Product ID uyğun gəlmir.");
      if (!["SUBSCRIPTION_STATE_ACTIVE", "SUBSCRIPTION_STATE_IN_GRACE_PERIOD"].includes(verified.subscriptionState)) {
        throw new HttpsError("failed-precondition", "Abunəlik aktiv deyil.");
      }

      const expiresAtMs = verified.expiryTimeMs || Date.now() + VIP_PRODUCT_DURATIONS_MS[productId];
      await grantPremium(uid, expiresAtMs);
      await recordIapSubscriptionOwner(receiptData, uid, "android", productId);
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
