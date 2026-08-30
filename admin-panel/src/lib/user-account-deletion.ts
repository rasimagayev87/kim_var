import "server-only";

import { FieldValue } from "firebase-admin/firestore";

import { chatMediaPathForMessage } from "@/lib/chat-media-path";
import { getAdminAuth, getAdminDb, getAdminStorage } from "@/lib/firebase/admin";

/**
 * Admin-panel equivalent of the mobile app's own `deleteAccount`
 * (functions/src/index.ts) — same cleanup steps, re-implemented here
 * rather than shared, because `functions/` and `admin-panel/` are
 * separate Node projects with no shared package (this codebase already
 * accepts that "duplicate table, two runtimes" shape elsewhere, e.g.
 * `RESERVED_USERNAMES`'s own doc comment there).
 *
 * Exists because deleting a user from the Firebase Console's
 * Authentication tab ONLY removes the Auth record — it does not call
 * `deleteAccount` (that's an `onCall`, only reachable from a
 * signed-in client) and there is no `beforeUserDeleted`/`onDelete`
 * Auth trigger wired up, so a console-only deletion leaves every
 * Firestore document (profile, chats, follows, posts, venues, …)
 * fully intact — exactly the bug this function exists to close for
 * admin-initiated deletions from now on.
 *
 * Two deliberate differences from `deleteAccount`:
 *  1. No "signed in within the last N minutes" freshness check — that
 *     guards a user deleting their OWN account from a stolen session;
 *     meaningless for an admin acting on someone else's account.
 *  2. Every Auth-SDK call is wrapped to tolerate the account already
 *     being gone (the exact scenario that motivated this file) — an
 *     admin using this AFTER already deleting from the Console must
 *     still be able to finish the Firestore-side cleanup.
 */
export async function deleteUserAccountPermanently(uid: string): Promise<void> {
  const auth = getAdminAuth();
  const db = getAdminDb();

  let phoneNumber: string | undefined;
  try {
    const authUser = await auth.getUser(uid);
    phoneNumber = authUser.phoneNumber ?? undefined;
    await auth.revokeRefreshTokens(uid);
  } catch {
    // Auth record already gone (the Console-deletion case this
    // function exists for) — nothing to revoke, no phone number to
    // read back; `releasePhoneNumberReservation` below just no-ops.
  }

  await replaceMessagesWithPlaceholder(uid);
  await archiveCreatedEvents(uid);
  await leaveJoinedEvents(uid);
  await deleteFollows(uid);
  await scrubFromOthersBlockLists(uid);
  await deleteStories(uid);
  await deleteUserPosts(uid);
  // Both run BEFORE `deleteUserVenues`, which removes the venue
  // documents `anonymizeUserVenueEvents` resolves events through.
  await anonymizeUserPinBoxes(uid);
  await anonymizeUserVenueEvents(uid);
  await deleteUserVenues(uid);
  await deleteUserOffers(uid);
  await anonymizePinBoxOrders(uid);
  await releasePhoneNumberReservation(uid, phoneNumber);
  await releaseUsernameReservation(uid);
  await deleteIdentityVerifications(uid);
  await deleteUserDocAndSubcollections(uid);
  await deleteStoragePrefix(`profile_photos/${uid}/`);
  await deleteStoragePrefix(`stories/${uid}/`);
  await deleteStoragePrefix(`posts/${uid}/`);
  // F-4 — owner-scoped listing imagery. `deleteUserVenues`/
  // `deleteUserOffers` above delete `venue_photos/{venueId}.jpg` and
  // `offer_photos/{offerId}.jpg`, which is the PRE-Prompt-3 flat
  // layout; uploads have written `{prefix}/{ownerUid}/{id}.jpg` since
  // that migration, so in practice those photos survived every account
  // deletion. `pinbox_photos/` and `event_covers/` were never touched
  // at all. That is not stray-file hygiene — it is data a user was told
  // was deleted still sitting in the bucket, reachable by anyone
  // holding its download URL. A prefix delete covers every object the
  // uid owns without needing to know individual ids, and the per-id
  // flat deletes above stay for the legacy objects still on the old
  // paths (see storage.rules' transition block).
  await deleteStoragePrefix(`venue_photos/${uid}/`);
  await deleteStoragePrefix(`offer_photos/${uid}/`);
  await deleteStoragePrefix(`pinbox_photos/${uid}/`);
  await deleteStoragePrefix(`event_covers/${uid}/`);
  await db.collection("accountDeletions").add({ uid, deletedAt: FieldValue.serverTimestamp(), deletedByAdmin: true });
  // Ban tombstone, removed LAST — see `deleteAccount`
  // (functions/src/index.ts) for the ordering argument: removing it
  // while `users/{uid}` still exists would flip a banned account back
  // to "active" (`isActiveUser` = user exists AND no tombstone) for the
  // rest of the sequence.
  await db.collection("bannedUsers").doc(uid).delete();

  try {
    await auth.deleteUser(uid);
  } catch {
    // Already gone — the point of this whole function.
  }
}

const DELETED_SENDER_PLACEHOLDER = "Bu istifadəçi hesabını silib";

async function replaceMessagesWithPlaceholder(uid: string): Promise<void> {
  const db = getAdminDb();
  const chatsSnap = await db.collection("chats").where("participants", "array-contains", uid).get();
  for (const chatDoc of chatsSnap.docs) {
    const messagesSnap = await chatDoc.ref.collection("messages").where("senderId", "==", uid).get();
    await Promise.all(
      messagesSnap.docs.map(async (messageDoc) => {
        // F-1 — the path is recomputed from (chatId, this message's own
        // id, its rules-pinned `senderId`, its `type`), NOT parsed out
        // of the client-written `mediaUrl`. See
        // [chatMediaPathForMessage] for the arbitrary-object-deletion
        // vector that replaced.
        const mediaPath = chatMediaPathForMessage(chatDoc.id, messageDoc.id, messageDoc.data());
        if (mediaPath) await deleteStorageFile(mediaPath);
        await messageDoc.ref.update({ text: DELETED_SENDER_PLACEHOLDER, mediaUrl: FieldValue.delete(), deletedSender: true });
      }),
    );
  }
}

/** PinBox listings owned by this user — anonymized and closed, not
 * deleted. Mirrors `anonymizeUserPinBoxes` in functions/src/index.ts;
 * see that function for the full reasoning (buyers' `pinboxOrders` and
 * `venuePayouts` rows point at these documents, so deleting them would
 * strip the meaning out of records that must survive).
 *
 * Boxes still holding paid, un-redeemed orders raise an admin
 * notification — that money cannot be honoured any more. */
async function anonymizeUserPinBoxes(uid: string): Promise<void> {
  const db = getAdminDb();
  const snap = await db.collection("pinboxes").where("ownerId", "==", uid).get();
  if (snap.empty) return;

  await Promise.all(
    snap.docs.map((doc) => doc.ref.update({ ownerDeleted: true, status: "inactive", updatedAt: FieldValue.serverTimestamp() })),
  );

  const counts = await Promise.all(
    snap.docs.map(async (doc) => {
      const orders = await db
        .collection("pinboxOrders")
        .where("pinboxId", "==", doc.id)
        .where("status", "==", "reserved")
        .get();
      return { title: (doc.data().title as string | undefined) ?? doc.id, count: orders.size };
    }),
  );
  const stranded = counts.filter((r) => r.count > 0);
  if (stranded.length === 0) return;

  const total = stranded.reduce((sum, r) => sum + r.count, 0);
  await db.collection("adminNotifications").add({
    type: "pinbox.orphaned_reserved_orders",
    message:
      `Hesab silindi (${uid}) — sahibsiz qalan PinBox-larda ${total} ödənilmiş, təhvil verilməmiş sifariş var: ` +
      stranded.map((r) => `"${r.title}" (${r.count})`).join(", ") +
      ". Bu sifarişlər artıq təhvil verilə bilməz, əl ilə geri qaytarılmalıdır.",
    targetType: "user",
    targetId: uid,
    read: false,
    createdAt: FieldValue.serverTimestamp(),
  });
}

/** Venue events at this user's venues — cancelled and anonymized.
 * Mirrors `anonymizeUserVenueEvents` in functions/src/index.ts. */
async function anonymizeUserVenueEvents(uid: string): Promise<void> {
  const db = getAdminDb();
  const venuesSnap = await db.collection("venues").where("ownerId", "==", uid).get();
  const venueIds = venuesSnap.docs.map((d) => d.id);
  if (venueIds.length === 0) return;

  for (let i = 0; i < venueIds.length; i += 30) {
    const chunk = venueIds.slice(i, i + 30);
    const eventsSnap = await db.collection("venueEvents").where("venueId", "in", chunk).get();
    await Promise.all(eventsSnap.docs.map((doc) => doc.ref.update({ ownerDeleted: true, status: "cancelled" })));
  }
}

async function anonymizePinBoxOrders(uid: string): Promise<void> {
  const snap = await getAdminDb().collection("pinboxOrders").where("buyerId", "==", uid).get();
  await Promise.all(snap.docs.map((doc) => doc.ref.update({ buyerDeleted: true })));
}

async function archiveCreatedEvents(uid: string): Promise<void> {
  const snap = await getAdminDb().collection("events").where("creatorId", "==", uid).get();
  await Promise.all(snap.docs.map((doc) => doc.ref.update({ creatorDeleted: true })));
}

async function leaveJoinedEvents(uid: string): Promise<void> {
  const snap = await getAdminDb().collection("events").where("participants", "array-contains", uid).get();
  await Promise.all(
    snap.docs.filter((doc) => doc.data().creatorId !== uid).map((doc) => doc.ref.update({ participants: FieldValue.arrayRemove(uid) })),
  );
}

async function deleteFollows(uid: string): Promise<void> {
  const db = getAdminDb();
  const [asFollower, asFollowee] = await Promise.all([
    db.collection("follows").where("followerId", "==", uid).get(),
    db.collection("follows").where("followeeId", "==", uid).get(),
  ]);
  await Promise.all([...asFollower.docs, ...asFollowee.docs].map((doc) => doc.ref.delete()));
}

async function scrubFromOthersBlockLists(uid: string): Promise<void> {
  const snap = await getAdminDb().collection("users").where("blockedUsers", "array-contains", uid).get();
  await Promise.all(snap.docs.map((doc) => doc.ref.update({ blockedUsers: FieldValue.arrayRemove(uid) })));
}

async function deleteStories(uid: string): Promise<void> {
  const snap = await getAdminDb().collection("stories").where("creatorId", "==", uid).get();
  await Promise.all(
    snap.docs.map(async (storyDoc) => {
      const viewsSnap = await storyDoc.ref.collection("views").get();
      await Promise.all(viewsSnap.docs.map((viewDoc) => viewDoc.ref.delete()));
      await storyDoc.ref.delete();
    }),
  );
}

/** Post docs only — `onPostDeleted` (functions/src/index.ts) is a
 * Firestore trigger, fires regardless of which codebase performed the
 * delete, and already sweeps each post's `likes`/`comments`
 * subcollections on its own. */
async function deleteUserPosts(uid: string): Promise<void> {
  const snap = await getAdminDb().collection("posts").where("userId", "==", uid).get();
  await Promise.all(snap.docs.map((doc) => doc.ref.delete()));
}

async function deleteUserVenues(uid: string): Promise<void> {
  const db = getAdminDb();
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

async function deleteUserOffers(uid: string): Promise<void> {
  const db = getAdminDb();
  const snap = await db.collection("offers").where("ownerId", "==", uid).get();
  for (const doc of snap.docs) {
    const redemptionsSnap = await doc.ref.collection("redemptions").get();
    await Promise.all(redemptionsSnap.docs.map((d) => d.ref.delete()));
    await doc.ref.delete();
    await deleteStorageFile(`offer_photos/${doc.id}.jpg`);
  }
}

async function releasePhoneNumberReservation(uid: string, phoneNumber: string | undefined): Promise<void> {
  if (!phoneNumber) return;
  const ref = getAdminDb().collection("phoneNumbers").doc(phoneNumber);
  const snap = await ref.get();
  if (snap.exists && snap.data()?.uid === uid) await ref.delete();
}

/** Must run BEFORE `deleteUserDocAndSubcollections` — reads `users/{uid}.username` itself. */
async function releaseUsernameReservation(uid: string): Promise<void> {
  const db = getAdminDb();
  const userSnap = await db.collection("users").doc(uid).get();
  const username = userSnap.data()?.username as string | undefined;
  if (!username) return;
  const ref = db.collection("usernames").doc(username.toLowerCase());
  const snap = await ref.get();
  if (snap.exists && snap.data()?.uid === uid) await ref.delete();
}

async function deleteIdentityVerifications(uid: string): Promise<void> {
  const snap = await getAdminDb().collection("identityVerifications").where("userId", "==", uid).get();
  await Promise.all(snap.docs.map((doc) => doc.ref.delete()));
  await deleteStoragePrefix(`identity_verifications/${uid}/`);
}

/** Deliberately excludes `payments` — a financial/audit record, kept
 * for reconciliation the same way `deleteAccount` keeps it. */
async function deleteUserDocAndSubcollections(uid: string): Promise<void> {
  const userRef = getAdminDb().collection("users").doc(uid);
  // F-3 — `likedPosts`, `reposts` and `notifiedEvents` were missing
  // from this list (and from `deleteAccount`'s identical one), so every
  // account deletion left three subcollections behind. `firestore.rules`
  // declares eleven subcollections under `users/{uid}`; these ten plus
  // the deliberately-kept `payments` is the complete set.
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

async function deleteStorageFile(path: string): Promise<void> {
  try {
    await getAdminStorage().bucket().file(path).delete();
  } catch (e) {
    // F-2 — logged rather than swallowed. Every path this function is
    // given is now SERVER-computed, so an unexpected miss means a real
    // bug worth seeing; the bare `catch {}` this replaces is also what
    // made the old URL-based deletion silently probeable.
    console.warn("deleteStorageFile: delete failed (path may not exist)", { path, error: String(e) });
  }
}

async function deleteStoragePrefix(prefix: string): Promise<void> {
  try {
    await getAdminStorage().bucket().deleteFiles({ prefix });
  } catch {
    // Best-effort — a missing folder isn't a failure.
  }
}
