import "server-only";

import { getAdminDb } from "@/lib/firebase/admin";

/** Mirrors `VenueCategory` in the Flutter app's venue.dart exactly —
 * same enum values, since they're the literal strings stored on the
 * Firestore doc. */
export const VENUE_CATEGORY_LABELS: Record<string, string> = {
  restaurant: "Restoran",
  pub: "Pub",
  coffeeShop: "Kofe evi",
  fastFood: "Fast food",
  teaHouse: "Çayxana",
  sweetsShop: "Şirniyyat",
  hotel: "Otel",
  motel: "Motel",
  cinema: "Kinoteatr",
  karaoke: "Karaoke",
  gameHall: "Oyun zalı",
  nightClub: "Gecə klubu",
  fitness: "Fitness",
  gym: "İdman zalı",
  spa: "Spa",
  footballField: "Futbol meydançası",
  clinic: "Klinika",
  beautySalon: "Gözəllik salonu",
  barbershop: "Bərbərxana",
  cosmetology: "Kosmetologiya",
  tattoo: "Tatu",
  photoStudio: "Foto studiya",
  kidsEntertainment: "Uşaq əyləncəsi",
  pharmacyOptics: "Aptek və Optika",
  dentalClinic: "Stomatoloji klinika",
  perfumeryCosmetics: "Parfumeriya və kosmetika",
  carWash: "Avtoyuma",
  carRepair: "Avtotəmir",
  supermarket: "Mini, Super və Hiper Marketlər",
  bookstoreStationery: "Kitab evi – Dəftərxana",
  petStore: "Zoomağaza",
  tailor: "Dərzi",
  dryCleaning: "Quru təmizləmə – Camaşırxana",
  applianceRepair: "Məişət və texnika təmiri",
  tutoringCenter: "Məşğələ və kurs mərkəzləri",
  independentArtist: "Fərdi Prodakşn/Sənətçi",
  other: "Digər",
};

/** `inactive` is a manual admin toggle (hide an already-approved venue)
 * — separate from the moderation pipeline below, unaffected by it.
 * `awaiting_payment` is `submitVenue`'s (functions/src/index.ts) initial
 * status before the first subscription charge succeeds — was missing
 * here entirely (post-launch QA finding), which meant `parseStatus`
 * below silently coerced it to `approved`, showing an unpaid venue as
 * "Aktiv" in the admin UI. */
export type VenueStatus = "approved" | "pending" | "needs_revision" | "rejected" | "inactive" | "awaiting_payment";
export type VenueStatusFilter = "all" | VenueStatus;

export interface VenueDayHours {
  open: string;
  close: string;
}

export interface VenueOpeningHours {
  is24h: boolean;
  /** Keyed "0".."6" (Monday-first, matches the Flutter app's own
   * `OpeningHours.schedule` weekday index) — a missing/null entry
   * means closed that day. */
  schedule: Record<string, VenueDayHours | null>;
}

export interface VenueSocialLinks {
  whatsapp: string | null;
  instagram: string | null;
  tiktok: string | null;
}

export interface AdminVenueRow {
  id: string;
  name: string;
  category: string;
  photoUrl: string | null;
  address: string | null;
  country: string | null;
  openingHours: VenueOpeningHours | null;
  socialLinks: VenueSocialLinks | null;
  status: VenueStatus;
  reviewNote: string | null;
  verified: boolean;
  isPremium: boolean;
  ownerId: string;
  ownerName: string;
  ownerUsername: string | null;
  createdAt: string | null;
  /** Only set while `status === 'needs_revision'` — see `setVenueStatus`. */
  revisionDeadline: string | null;
  /** Backing `payments/{paymentId}` doc, if any — see `Venue.paymentId`
   * in the Flutter app. Null for venues created before that field
   * existed. */
  paymentId: string | null;
  /** Next `venue_subscription` billing date — see `Venue
   * .subscriptionRenewsAt`'s own doc comment. Null for venues created
   * before this field existed (not yet caught up by
   * `backfill-venue-subscriptions`). */
  subscriptionRenewsAt: string | null;
}

const FETCH_LIMIT = 200;

function parseStatus(value: unknown): VenueStatus {
  return value === "pending" ||
    value === "needs_revision" ||
    value === "rejected" ||
    value === "inactive" ||
    value === "awaiting_payment"
    ? value
    : "approved";
}

export async function listVenues({
  status,
  search,
}: {
  status: VenueStatusFilter;
  search: string;
}): Promise<AdminVenueRow[]> {
  const db = getAdminDb();
  let query: FirebaseFirestore.Query = db.collection("venues");
  if (status !== "all") {
    query = query.where("status", "==", status);
  }

  const snap = await query.orderBy("createdAt", "desc").limit(FETCH_LIMIT).get();
  let rows = await attachOwners(snap.docs);

  // "Hamısı" (the default filter, no explicit status chosen) deliberately
  // excludes `awaiting_payment` — an unpaid venue isn't a moderation
  // decision waiting to happen the way `pending`/`needs_revision` are, so
  // it shouldn't clutter the default view. It's still fully visible, just
  // one intentional click away via the dedicated "Ödəniş gözlənilir" filter.
  if (status === "all") {
    rows = rows.filter((row) => row.status !== "awaiting_payment");
  }

  const key = search.trim().toLowerCase();
  if (key) {
    rows = rows.filter((row) => row.name.toLowerCase().includes(key) || row.ownerName.toLowerCase().includes(key));
  }

  return rows;
}

export async function getVenueDetail(id: string): Promise<AdminVenueRow | null> {
  const doc = await getAdminDb().collection("venues").doc(id).get();
  if (!doc.exists) return null;
  const [row] = await attachOwners([doc as FirebaseFirestore.QueryDocumentSnapshot]);
  return row;
}

async function attachOwners(
  docs: FirebaseFirestore.QueryDocumentSnapshot[],
): Promise<AdminVenueRow[]> {
  const db = getAdminDb();
  const ownerIds = [...new Set(docs.map((doc) => doc.data().ownerId as string))];
  const ownerDocs = await Promise.all(ownerIds.map((uid) => db.collection("users").doc(uid).get()));
  const ownerByUid = new Map(ownerDocs.map((doc) => [doc.id, doc.data()]));

  return docs.map((doc) => {
    const data = doc.data();
    const owner = ownerByUid.get(data.ownerId as string);
    const createdAt = data.createdAt as FirebaseFirestore.Timestamp | undefined;
    const revisionDeadline = data.revisionDeadline as FirebaseFirestore.Timestamp | undefined;
    const subscriptionRenewsAt = data.subscriptionRenewsAt as FirebaseFirestore.Timestamp | undefined;
    return {
      id: doc.id,
      name: (data.name as string) ?? "",
      category: (data.category as string) ?? "other",
      photoUrl: (data.photoUrl as string) ?? null,
      address: (data.address as string) || null,
      country: (data.country as string) || null,
      openingHours: (data.openingHours as VenueOpeningHours | undefined) ?? null,
      socialLinks: (data.socialLinks as VenueSocialLinks | undefined) ?? null,
      status: parseStatus(data.status),
      reviewNote: (data.reviewNote as string) || null,
      verified: (data.verified as boolean) ?? false,
      isPremium: (data.isPremium as boolean) ?? false,
      ownerId: data.ownerId as string,
      ownerName: owner ? `${owner.firstName ?? ""} ${owner.lastName ?? ""}`.trim() || "Naməlum" : "Naməlum",
      ownerUsername: (owner?.username as string) ?? null,
      createdAt: createdAt ? createdAt.toDate().toISOString() : null,
      revisionDeadline: revisionDeadline ? revisionDeadline.toDate().toISOString() : null,
      paymentId: (data.paymentId as string) || null,
      subscriptionRenewsAt: subscriptionRenewsAt ? subscriptionRenewsAt.toDate().toISOString() : null,
    };
  });
}
