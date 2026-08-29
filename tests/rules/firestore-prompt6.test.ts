// Düzəliş Prompt 6 — Pul İtkisi, Refund və Entitlement Ləğvi. Bu
// promptun əksər məntiqi (K-10/K-11/PAY-4/PAY-5 superseded/refund/
// TOCTOU/amount-mismatch) Cloud Function DAXİLİ məntiqdir və Firestore
// emulator rules testləri ilə sınana bilməz — bax planın "Testlər"
// bölməsindəki qərar (rules-səviyyəli əhatə + manual doğrulama).
// Burada YALNIZ rules-səviyyəli hissə sınanır:
//   - INFRA-5: `offers`/`pinboxes` üçün yeni məzmun-sahə kilidi
//     (əvvəllər bu sahələr blocklist-də deyildi — dəyişdirilmiş bir
//     client birbaşa Firestore yazısı ilə `resubmitOffer`/
//     `resubmitPinBox`-u heç vaxt çağırmadan approved/active bir elanın
//     məzmununu sakitcə əvəz edə bilərdi).
//   - K-11: `venuePayouts`/`pinboxOrders`-un yeni status literalları
//     (`cancelled`/`cancelled_after_payout`/`debt`, `refunded`) yalnız
//     Admin SDK ilə yazılır — mövcud `allow write: if false` bunun üçün
//     əlavə qayda tələb etmir, bu testlər bunu təsdiqləyir.
import { after, before, describe, test } from "node:test";
import { assertFails, assertSucceeds, RulesTestEnvironment } from "@firebase/rules-unit-testing";
import { doc, setDoc, updateDoc } from "firebase/firestore";
import { createTestEnv, userFixture } from "./helpers.ts";

let testEnv: RulesTestEnvironment;

before(async () => {
  testEnv = await createTestEnv();
});

after(async () => {
  await testEnv.cleanup();
});

async function seed(fn: (fs: ReturnType<RulesTestEnvironment["unauthenticatedContext"]>["firestore"]) => Promise<void>) {
  await testEnv.withSecurityRulesDisabled(async (ctx) => fn(ctx.firestore()));
}

function offerFixture(ownerId: string, overrides: Record<string, unknown> = {}) {
  return {
    ownerId,
    venueId: "venue-1",
    category: "restaurant",
    title: "Original title",
    description: "Original description",
    offerType: "discount",
    status: "approved",
    createdAt: new Date(),
    ...overrides,
  };
}

function pinboxFixture(ownerId: string, overrides: Record<string, unknown> = {}) {
  return {
    ownerId,
    venueId: "venue-1",
    category: "restaurant",
    title: "Original title",
    description: "Original description",
    originalPrice: 10,
    pinboxPrice: 5,
    stockTotal: 3,
    stockRemaining: 3,
    status: "active",
    createdAt: new Date(),
    ...overrides,
  };
}

describe("INFRA-5 — offers/{offerId} məzmun sahələri artıq kilidlidir", () => {
  test("sahib `title`-ı birbaşa yazmağa çalışır — rədd edilir", async () => {
    const owner = "p6-offer-owner-a";
    const offerId = "p6-offer-a";
    await seed(async (fs) => {
      await setDoc(doc(fs, "users", owner), userFixture(owner));
      await setDoc(doc(fs, "offers", offerId), offerFixture(owner));
    });

    const db = testEnv.authenticatedContext(owner).firestore();
    await assertFails(updateDoc(doc(db, "offers", offerId), { title: "Dəyişdirilmiş başlıq" }));
  });

  test("digər məzmun sahələri (description/offerType/discountValue/startDate/endDate/terms/activeHours/activeDays/imageUrl/category) də rədd edilir", async () => {
    const owner = "p6-offer-owner-b";
    const offerId = "p6-offer-b";
    await seed(async (fs) => {
      await setDoc(doc(fs, "users", owner), userFixture(owner));
      await setDoc(doc(fs, "offers", offerId), offerFixture(owner));
    });

    const db = testEnv.authenticatedContext(owner).firestore();
    await assertFails(updateDoc(doc(db, "offers", offerId), { description: "Yeni təsvir" }));
    await assertFails(updateDoc(doc(db, "offers", offerId), { offerType: "gift" }));
    await assertFails(updateDoc(doc(db, "offers", offerId), { discountValue: 50 }));
    await assertFails(updateDoc(doc(db, "offers", offerId), { imageUrl: "https://example.com/new.jpg" }));
    await assertFails(updateDoc(doc(db, "offers", offerId), { category: "pub" }));
  });

  test("blocklist-də olmayan sahə (məs. `updatedAt`) hələ də yazıla bilir — kilid tam bloklama deyil, yalnız məzmun sahələridir", async () => {
    const owner = "p6-offer-owner-c";
    const offerId = "p6-offer-c";
    await seed(async (fs) => {
      await setDoc(doc(fs, "users", owner), userFixture(owner));
      await setDoc(doc(fs, "offers", offerId), offerFixture(owner));
    });

    const db = testEnv.authenticatedContext(owner).firestore();
    await assertSucceeds(updateDoc(doc(db, "offers", offerId), { updatedAt: new Date() }));
  });
});

describe("INFRA-5 — pinboxes/{pinboxId} məzmun sahələri artıq kilidlidir", () => {
  test("sahib `title`-ı birbaşa yazmağa çalışır — rədd edilir", async () => {
    const owner = "p6-pinbox-owner-a";
    const pinboxId = "p6-pinbox-a";
    await seed(async (fs) => {
      await setDoc(doc(fs, "users", owner), userFixture(owner));
      await setDoc(doc(fs, "pinboxes", pinboxId), pinboxFixture(owner));
    });

    const db = testEnv.authenticatedContext(owner).firestore();
    await assertFails(updateDoc(doc(db, "pinboxes", pinboxId), { title: "Dəyişdirilmiş başlıq" }));
  });

  test("digər məzmun sahələri (description/originalPrice/pinboxPrice/pickupWindowStart/pickupWindowEnd/imageUrl) də rədd edilir", async () => {
    const owner = "p6-pinbox-owner-b";
    const pinboxId = "p6-pinbox-b";
    await seed(async (fs) => {
      await setDoc(doc(fs, "users", owner), userFixture(owner));
      await setDoc(doc(fs, "pinboxes", pinboxId), pinboxFixture(owner));
    });

    const db = testEnv.authenticatedContext(owner).firestore();
    await assertFails(updateDoc(doc(db, "pinboxes", pinboxId), { description: "Yeni təsvir" }));
    await assertFails(updateDoc(doc(db, "pinboxes", pinboxId), { originalPrice: 20 }));
    await assertFails(updateDoc(doc(db, "pinboxes", pinboxId), { pinboxPrice: 8 }));
    await assertFails(updateDoc(doc(db, "pinboxes", pinboxId), { imageUrl: "https://example.com/new.jpg" }));
  });

  test("blocklist-də olmayan sahə (məs. `updatedAt`) hələ də yazıla bilir", async () => {
    const owner = "p6-pinbox-owner-c";
    const pinboxId = "p6-pinbox-c";
    await seed(async (fs) => {
      await setDoc(doc(fs, "users", owner), userFixture(owner));
      await setDoc(doc(fs, "pinboxes", pinboxId), pinboxFixture(owner));
    });

    const db = testEnv.authenticatedContext(owner).firestore();
    await assertSucceeds(updateDoc(doc(db, "pinboxes", pinboxId), { updatedAt: new Date() }));
  });
});

describe("K-11 — venuePayouts/pinboxOrders yeni status literalları yalnız Admin SDK ilə yazıla bilər", () => {
  test("venuePayouts sənədinə `cancelled`/`debt` statusu ilə belə client birbaşa yaza bilmir", async () => {
    const owner = "p6-payout-owner";
    const payoutId = "p6-payout-a";
    await seed(async (fs) => {
      await setDoc(doc(fs, "users", owner), userFixture(owner));
      await setDoc(doc(fs, "venuePayouts", payoutId), { ownerId: owner, status: "pending", payoutAmount: 100 });
    });

    const db = testEnv.authenticatedContext(owner).firestore();
    await assertFails(updateDoc(doc(db, "venuePayouts", payoutId), { status: "cancelled" }));
    await assertFails(
      setDoc(doc(db, "venuePayouts", "p6-payout-debt-row"), { ownerId: owner, status: "debt", payoutAmount: -50 }),
    );
  });

  test("pinboxOrders sənədinə `refunded` statusu ilə belə alıcı birbaşa yaza bilmir", async () => {
    const buyer = "p6-order-buyer";
    const orderId = "p6-order-a";
    await seed(async (fs) => {
      await setDoc(doc(fs, "users", buyer), userFixture(buyer));
      await setDoc(doc(fs, "pinboxOrders", orderId), { buyerId: buyer, status: "confirmed" });
    });

    const db = testEnv.authenticatedContext(buyer).firestore();
    await assertFails(updateDoc(doc(db, "pinboxOrders", orderId), { status: "refunded" }));
  });
});
