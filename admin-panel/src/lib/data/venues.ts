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
  other: "Digər",
};

export type VenueStatus = "active" | "pending" | "rejected" | "inactive";
export type VenueStatusFilter = "all" | VenueStatus;

export interface AdminVenueRow {
  id: string;
  name: string;
  category: string;
  photoUrl: string | null;
  status: VenueStatus;
  verified: boolean;
  ownerId: string;
  ownerName: string;
  ownerUsername: string | null;
  createdAt: string | null;
}

const FETCH_LIMIT = 200;

function parseStatus(value: unknown): VenueStatus {
  return value === "pending" || value === "rejected" || value === "inactive" ? value : "active";
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
    return {
      id: doc.id,
      name: (data.name as string) ?? "",
      category: (data.category as string) ?? "other",
      photoUrl: (data.photoUrl as string) ?? null,
      status: parseStatus(data.status),
      verified: (data.verified as boolean) ?? false,
      ownerId: data.ownerId as string,
      ownerName: owner ? `${owner.firstName ?? ""} ${owner.lastName ?? ""}`.trim() || "Naməlum" : "Naməlum",
      ownerUsername: (owner?.username as string) ?? null,
      createdAt: createdAt ? createdAt.toDate().toISOString() : null,
    };
  });
}
