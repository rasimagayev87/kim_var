import { initializeApp } from "firebase-admin/app";
import { FieldValue, getFirestore, Timestamp } from "firebase-admin/firestore";
import { getAuth } from "firebase-admin/auth";
import { getStorage } from "firebase-admin/storage";
import { BatchResponse, getMessaging } from "firebase-admin/messaging";
import { HttpsError, onCall } from "firebase-functions/v2/https";
import { onDocumentCreated, onDocumentDeleted, onDocumentUpdated, onDocumentWritten } from "firebase-functions/v2/firestore";
import { onSchedule } from "firebase-functions/v2/scheduler";
import { defineSecret } from "firebase-functions/params";
import * as logger from "firebase-functions/logger";

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

// Twilio Verify credentials — set once via:
//   firebase functions:secrets:set TWILIO_ACCOUNT_SID
//   firebase functions:secrets:set TWILIO_AUTH_TOKEN
//   firebase functions:secrets:set TWILIO_VERIFY_SERVICE_SID
// Never embedded in the Flutter app — sendOtp/verifyOtp below are the
// only things allowed to hold them. Firebase prompts for each value
// interactively and stores it in Secret Manager, not in plain env vars
// or source control.
const twilioAccountSid = defineSecret("TWILIO_ACCOUNT_SID");
const twilioAuthToken = defineSecret("TWILIO_AUTH_TOKEN");
const twilioVerifyServiceSid = defineSecret("TWILIO_VERIFY_SERVICE_SID");

// otpRateLimits/{phoneNumber} guards Twilio Verify spend and SMS abuse:
// at most 1 send per minute and 5 per rolling hour, per number.
const OTP_MIN_INTERVAL_MS = 60 * 1000;
const OTP_MAX_PER_HOUR = 5;
const OTP_WINDOW_MS = 60 * 60 * 1000;

/**
 * Mints short-lived (1 hour) Cloudflare Realtime TURN credentials for
 * the CALLING signed-in user. The Flutter app calls this right before
 * starting or accepting a call and passes the returned `iceServers`
 * straight to its WebRTC PeerConnection config — this function is the
 * only place the actual Cloudflare API token ever touches.
 */
export const getTurnCredentials = onCall(
  { region: "us-central1", secrets: [cloudflareTurnKeyId, cloudflareTurnApiToken] },
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
export const deleteAccount = onCall({ region: "us-central1" }, async (request) => {
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

/**
 * Marks the CALLING user's own account as phone-verified, server-side.
 * firestore.rules blocks the client from ever writing `isVerified` or
 * `phoneNumber` on its own users/{uid} doc directly — otherwise a raw
 * Firestore write (bypassing the app's UI entirely) could self-grant
 * verification with no real SMS OTP involved. This function is the
 * only path to setting those fields, and it trusts Firebase Auth's OWN
 * `phoneNumber` claim — set only by a real `linkWithCredential()` call
 * against a verified OTP, which this function itself can't be tricked
 * into faking — never anything the client passes in as an argument.
 */
export const markPhoneVerified = onCall({ region: "us-central1" }, async (request) => {
  const uid = request.auth?.uid;
  if (!uid) {
    throw new HttpsError("unauthenticated", "Bu əməliyyat üçün daxil olmalısınız.");
  }

  const authUser = await auth.getUser(uid);
  const phoneNumber = authUser.phoneNumber;
  if (!phoneNumber) {
    throw new HttpsError("failed-precondition", "no-linked-phone");
  }

  await db.collection("users").doc(uid).update({
    isVerified: true,
    phoneNumber: phoneNumber,
    updatedAt: FieldValue.serverTimestamp(),
  });

  // Reserve the phone → uid mapping so a later "Parolu unutdum" lookup
  // (FirebaseAuthRepository.isPhoneNumberTaken) can find this account
  // without needing to be signed in first — mirrors what the client
  // used to write itself before this field moved server-side.
  await db.collection("phoneNumbers").doc(phoneNumber).set({ uid });

  return { phoneNumber };
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
export const getDiscoverCandidates = onCall({ region: "us-central1" }, async (request) => {
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

/**
 * Checks and records one OTP-send attempt for `phoneNumber` against the
 * rate limits above, inside a transaction so concurrent calls (e.g. a
 * double-tap) can't both slip through. Throws `resource-exhausted` when
 * the caller should back off; otherwise records the attempt and returns.
 */
async function checkAndRecordOtpRateLimit(phoneNumber: string): Promise<void> {
  const ref = db.collection("otpRateLimits").doc(phoneNumber);
  await db.runTransaction(async (tx) => {
    const snap = await tx.get(ref);
    const now = Date.now();
    const attempts: number[] = snap.exists ? (snap.data()?.attempts as number[] | undefined) ?? [] : [];
    const recentAttempts = attempts.filter((ts) => now - ts < OTP_WINDOW_MS);

    const lastAttempt = recentAttempts[recentAttempts.length - 1];
    if (lastAttempt && now - lastAttempt < OTP_MIN_INTERVAL_MS) {
      throw new HttpsError("resource-exhausted", "too-soon");
    }
    if (recentAttempts.length >= OTP_MAX_PER_HOUR) {
      throw new HttpsError("resource-exhausted", "hourly-limit");
    }

    recentAttempts.push(now);
    tx.set(ref, { attempts: recentAttempts, updatedAt: FieldValue.serverTimestamp() });
  });
}

/**
 * Starts a Twilio Verify SMS challenge for `phoneNumber`. Rate-limited
 * to 1/minute and 5/hour per number (see [checkAndRecordOtpRateLimit])
 * so a script can't run up Twilio spend or spam a number. Doesn't
 * require the caller to be signed in — this is also meant to cover a
 * pre-auth, phone-first flow, not just the already-authenticated
 * account-verification screen.
 */
export const sendOtp = onCall(
  { region: "us-central1", secrets: [twilioAccountSid, twilioAuthToken, twilioVerifyServiceSid] },
  async (request) => {
    const phoneNumber = request.data?.phoneNumber as string | undefined;
    if (!phoneNumber || !/^\+\d{7,15}$/.test(phoneNumber)) {
      throw new HttpsError("invalid-argument", "invalid-phone-number");
    }

    await checkAndRecordOtpRateLimit(phoneNumber);

    const accountSid = twilioAccountSid.value();
    const resp = await fetch(
      `https://verify.twilio.com/v2/Services/${twilioVerifyServiceSid.value()}/Verifications`,
      {
        method: "POST",
        headers: {
          Authorization: `Basic ${Buffer.from(`${accountSid}:${twilioAuthToken.value()}`).toString("base64")}`,
          "Content-Type": "application/x-www-form-urlencoded",
        },
        body: new URLSearchParams({ To: phoneNumber, Channel: "sms" }),
      }
    );

    if (!resp.ok) {
      // Twilio's error body (code/message/more_info) is the only way to
      // tell a bad phone format (21211) apart from a blocked region
      // (21408), a wrong Verify Service SID (20404/60200), a still-Trial
      // account silently not sending to unverified numbers, etc. — none
      // of that was visible before this log line existed.
      const body = await resp.text();
      logger.error("sendOtp: Twilio Verify send failed", { status: resp.status, body });
      throw new HttpsError("internal", `Twilio Verify send failed: ${resp.status}`);
    }

    // A 2xx here doesn't guarantee the SMS actually arrives — a still-
    // Trial Twilio account returns `status: "pending"` same as a real
    // send, then silently never delivers to an unverified number. This
    // is the only place that distinction is visible at all right now.
    const okBody = (await resp.json()) as { status?: string; sid?: string };
    logger.info("sendOtp: Twilio Verify send accepted", { status: okBody.status, sid: okBody.sid });

    return { success: true };
  }
);

/**
 * Confirms a Twilio Verify code for `phoneNumber` and, if approved,
 * finishes the same server-side steps [markPhoneVerified] used to do
 * for the old Firebase-native flow — sets `isVerified`/`phoneNumber` on
 * users/{tempUserId} (blocked from direct client writes by
 * firestore.rules) and reserves the phoneNumbers/ lookup doc — then
 * mints a custom token so the client can call `signInWithCustomToken`.
 *
 * `tempUserId` is trusted only as far as Twilio's own code check goes:
 * a caller without the real SMS code can't do anything with it. As
 * defense in depth, if the call DOES carry Firebase Auth context (the
 * account-verification screen's case — the user is already signed in
 * before verifying their phone), that uid must match `tempUserId`.
 */
export const verifyOtp = onCall(
  { region: "us-central1", secrets: [twilioAccountSid, twilioAuthToken, twilioVerifyServiceSid] },
  async (request) => {
    const phoneNumber = request.data?.phoneNumber as string | undefined;
    const code = request.data?.code as string | undefined;
    const tempUserId = request.data?.tempUserId as string | undefined;
    if (!phoneNumber || !code || !tempUserId) {
      throw new HttpsError("invalid-argument", "missing-fields");
    }
    if (request.auth?.uid && request.auth.uid !== tempUserId) {
      throw new HttpsError("permission-denied", "uid-mismatch");
    }

    const accountSid = twilioAccountSid.value();
    const resp = await fetch(
      `https://verify.twilio.com/v2/Services/${twilioVerifyServiceSid.value()}/VerificationCheck`,
      {
        method: "POST",
        headers: {
          Authorization: `Basic ${Buffer.from(`${accountSid}:${twilioAuthToken.value()}`).toString("base64")}`,
          "Content-Type": "application/x-www-form-urlencoded",
        },
        body: new URLSearchParams({ To: phoneNumber, Code: code }),
      }
    );

    if (!resp.ok) {
      const body = await resp.text();
      logger.error("verifyOtp: Twilio Verify check failed", { status: resp.status, body });
      throw new HttpsError("internal", `Twilio Verify check failed: ${resp.status}`);
    }
    const result = (await resp.json()) as { status?: string };
    if (result.status !== "approved") {
      throw new HttpsError("invalid-argument", "otp-invalid-or-expired");
    }

    await auth.updateUser(tempUserId, { phoneNumber });
    await db.collection("users").doc(tempUserId).update({
      isVerified: true,
      phoneNumber,
      updatedAt: FieldValue.serverTimestamp(),
    });
    await db.collection("phoneNumbers").doc(phoneNumber).set({ uid: tempUserId });

    const customToken = await auth.createCustomToken(tempUserId);
    return { phoneNumber, customToken };
  }
);

/** Chat messages this user sent — replaced, not deleted, so the other
 * participant's chat history stays intact. */
async function replaceMessagesWithPlaceholder(uid: string): Promise<void> {
  const chatsSnap = await db.collection("chats").where("participants", "array-contains", uid).get();

  for (const chatDoc of chatsSnap.docs) {
    const messagesSnap = await chatDoc.ref.collection("messages").where("senderId", "==", uid).get();
    await Promise.all(
      messagesSnap.docs.map((messageDoc) =>
        messageDoc.ref.update({
          text: DELETED_SENDER_PLACEHOLDER,
          mediaUrl: FieldValue.delete(),
          deletedSender: true,
        })
      )
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

export const onPostLikeCreated = onDocumentCreated("posts/{postId}/likes/{uid}", async (event) => {
  await bumpPostCounter(event.params.postId, "likesCount", 1);

  const likerId = event.params.uid;
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
 * which of those birthday users fall within THAT venue's own audience
 * radius — the exact same mode-aware distance/country/world logic
 * `computeAudienceCount` already uses for the live audience counter,
 * reused here rather than duplicated (a venue set to "Dünya üzrə"
 * matches every opted-in birthday user worldwide, "Ölkə üzrə" matches
 * same-country ones, "məsafə üzrə" matches ones within
 * `audienceRadiusKm`). One `birthdayMatches/{date}_{venueId}` doc per
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
      const mode = (venue.audienceRadiusMode as string | undefined) ?? "distance";
      const venueLat = venue.lat as number | undefined;
      const venueLng = venue.lng as number | undefined;
      const venueCountry = venue.country as string | undefined;
      let venueMatched: BirthdayUserDoc[];

      if (mode === "country") {
        venueMatched = venueCountry ? birthdayUsers.filter((u) => u.country === venueCountry) : [];
      } else if (mode === "world") {
        venueMatched = birthdayUsers;
      } else {
        const radiusKm = (venue.audienceRadiusKm as number | undefined) ?? 1;
        venueMatched =
          venueLat === undefined || venueLng === undefined
            ? []
            : birthdayUsers
                .filter((u) => u.lat !== undefined && u.lng !== undefined)
                .filter((u) => haversineMeters(venueLat, venueLng, u.lat!, u.lng!) <= radiusKm * 1000);
      }

      // Same recipient-radius rule as `resolveNotifyCandidates` — the
      // venue's own audience radius is a ceiling, not the only gate.
      // No independentArtist-follow exception here: birthday matching
      // isn't follow-based, every candidate above is a generic
      // opted-in user, not someone who chose to follow this venue.
      const matchedUserIds = venueMatched
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

export const onPostCommentCreated = onDocumentCreated("posts/{postId}/comments/{commentId}", async (event) => {
  await bumpPostCounter(event.params.postId, "commentsCount", 1);

  const comment = event.data?.data();
  if (!comment) return;
  const commenterId = comment.userId as string | undefined;
  const replyToCommentId = comment.replyToCommentId as string | undefined;
  if (!commenterId) return;

  const commenter = await getUserDisplayInfo(commenterId);
  const commentText = (comment.text as string | undefined) ?? "";
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
  }
});

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
 * `...NewEvent`. The venue's own `audienceRadiusMode`/`audienceRadiusKm`/
 * `country` is ALWAYS the final filter (the ceiling), but the SOURCE
 * pool differs by category, per "Fərdi Prodakşn/Sənətçi"'s own
 * venue-level follow feature ("İzlə"): an `independentArtist` venue
 * notifies ONLY its followers (`venues/{venueId}/followers`) — never
 * the app-wide `users` scan every other category still uses. Either
 * way, a candidate outside the venue's radius/country/mode gets
 * nothing — an `independentArtist` follower who lives outside the
 * radius the owner chose is excluded exactly like a random stranger
 * would be.
 *
 * For every category EXCEPT `independentArtist`, a candidate must
 * ALSO fall within their OWN chosen Discover radius (see
 * [isWithinRecipientDiscoverRadius]) — the venue's radius is a
 * ceiling, not the only gate. `independentArtist` followers are the
 * one deliberate exception: following a venue means wanting its posts
 * regardless of distance, matching how `LiveFeedService.
 * fetchFollowedVenueItems` already bypasses the viewer's own radius
 * for the exact same category/reason.
 */
async function resolveNotifyCandidates(
  venueId: string,
  venue: FirebaseFirestore.DocumentData,
  limit: number,
): Promise<FirebaseFirestore.DocumentSnapshot[]> {
  const mode = (venue.audienceRadiusMode as string | undefined) ?? "distance";
  const isFollowBased = venue.category === "independentArtist";

  let sourceDocs: FirebaseFirestore.DocumentSnapshot[];
  if (isFollowBased) {
    const followerSnaps = await db.collection("venues").doc(venueId).collection("followers").limit(limit).get();
    sourceDocs = await Promise.all(followerSnaps.docs.map((d) => db.collection("users").doc(d.id).get()));
    sourceDocs = sourceDocs.filter((d) => d.exists);
  } else {
    sourceDocs = (await db.collection("users").limit(limit).get()).docs;
  }

  let venueFiltered: FirebaseFirestore.DocumentSnapshot[];
  if (mode === "country") {
    const country = venue.country as string | undefined;
    venueFiltered = country ? sourceDocs.filter((d) => d.data()?.country === country) : [];
  } else if (mode === "world") {
    venueFiltered = sourceDocs;
  } else {
    const lat = venue.lat as number | undefined;
    const lng = venue.lng as number | undefined;
    const radiusKm = (venue.audienceRadiusKm as number | undefined) ?? 1;
    venueFiltered =
      lat === undefined || lng === undefined
        ? []
        : sourceDocs.filter((d) => {
            const userLat = d.data()?.lat as number | undefined;
            const userLng = d.data()?.lng as number | undefined;
            if (userLat === undefined || userLng === undefined) return false;
            return haversineMeters(lat, lng, userLat, userLng) <= radiusKm * 1000;
          });
  }

  if (isFollowBased) return venueFiltered;

  const venueLat = venue.lat as number | undefined;
  const venueLng = venue.lng as number | undefined;
  const venueCountry = venue.country as string | undefined;
  return venueFiltered.filter((d) => isWithinRecipientDiscoverRadius(d.data() ?? {}, venueLat, venueLng, venueCountry));
}

/**
 * Push + in-app notification when one of the venue's offers goes
 * live — see `resolveNotifyCandidates` for exactly who that reaches
 * (everyone within the venue's own audience radius/mode for most
 * categories, only `independentArtist` followers within that same
 * radius for that one category). Deliberately does NOT filter by
 * recent activity the way the audience counter does — reaching
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
        type: "venueOffer",
        title: venueName ? `☕ ${venueName} yaxınlığınızda` : "Yaxınlığınızda yeni təklif",
        body: offerTitle,
        params: { venueName, offerTitle },
        targetId: offerId,
        targetType: "offer",
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
        type: "venueEvent",
        title: venueName ? `🎤 ${venueName}-də bu axşam` : "🎤 Yaxınlığınızda tədbir",
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
  kind: "venue" | "offer",
  name: string,
  status: unknown,
  reviewNote: unknown,
  // Only ever true for venue listings today (offers have no payment
  // concept yet) — appends the 7-day/refund-timeline wording that only
  // makes sense when a real `payments/{paymentId}` doc is attached.
  hasPayment = false,
): { type: string; title: string; body: string; params: Record<string, unknown> } | null {
  const noun = kind === "venue" ? "Məkanınız" : "Təklifiniz";
  const quoted = name ? `"${name}"` : kind === "venue" ? "Məkanınız" : "Təklifiniz";
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
 * Owner resubmits a `needs_revision` venue after editing it — the only
 * way `status` can move back to `pending` once reviewed, since
 * firestore.rules blocks the owner from writing `status` directly.
 * Client flow: `updateVenue` (normal field edit, owner-permitted) then
 * this callable. Rejects anything not currently `needs_revision` so a
 * stray call can't un-reject or re-pending an already-approved venue.
 */
export const resubmitVenue = onCall({ region: "us-central1" }, async (request) => {
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
    if (data.status !== "needs_revision") throw new HttpsError("failed-precondition", "not-needs-revision");

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

/** Offer equivalent of `resubmitVenue` — same contract, same rules. */
export const resubmitOffer = onCall({ region: "us-central1" }, async (request) => {
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
    if (data.status !== "needs_revision") throw new HttpsError("failed-precondition", "not-needs-revision");

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
 * Fires whenever a `payments/{paymentId}` doc's `status` newly becomes
 * `refund_pending` (from admin rejection, or `expireListingRevisionDeadlines`
 * below auto-rejecting an expired revision window) — NOT on every write,
 * so resubmitting (which flips a doc from `revision_pending` back to
 * `completed`) or the admin's own "mark as refunded" action (which flips
 * it to `refunded`) never re-triggers this. Shared by both venue and
 * offer listings (`listingType` on the doc), same as everything else
 * downstream of `payments/{paymentId}`.
 *
 * No payment provider (Epoint/Payriff/LEOpay) is wired yet, so this
 * deliberately does NOT call a real refund API and does NOT advance
 * `status` to `refunded` itself — it just logs enough for the admin
 * panel's payments page (manual-tracking queue, filtered on
 * `refund_pending`) to be the source of truth until a provider exists.
 * Swapping in the real call later is a change to this one function
 * only — the state machine, admin UI, and notifications around it stay
 * the same.
 */
export const processPaymentRefund = onDocumentUpdated("payments/{paymentId}", async (event) => {
  const before = event.data?.before.data();
  const after = event.data?.after.data();
  if (!before || !after) return;
  if (before.status === "refund_pending" || after.status !== "refund_pending") return;

  logger.info("processPaymentRefund: refund needed, awaiting manual processing", {
    paymentId: event.params.paymentId,
    ownerId: after.ownerId,
    listingType: after.listingType,
    listingId: after.listingId,
    amount: after.amount,
    currency: after.currency,
  });

  // TODO: Epoint/Payriff/LEOpay inteqrasiyası tamamlananda burada
  // provayderin real REFUND/CANCEL endpoint-inə server-side sorğu
  // göndəriləcək (əməliyyat ID-si + məbləğ ilə), və uğurlu cavabdan
  // sonra bu sənədin statusu 'refunded' ediləcək. Hələlik status
  // 'refund_pending'də qalır — admin panelindəki Ödənişlər səhifəsi
  // bunları əl ilə izləmək üçündür.
});

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

    const type = message.type as string | undefined;
    const body =
      type && type !== "text"
        ? CHAT_PREVIEW_LABELS[type] ?? "Yeni mesaj"
        : ((message.text as string | undefined) || "Yeni mesaj");

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
