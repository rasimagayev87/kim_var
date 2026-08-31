// Analytics səhifəsinin PII qaytarmadığının sübutu — nə qədər sübut
// edə bildiyi ilə birlikdə.
//
// NƏ SÜBUT EDİR: `lib/data/analytics.ts` oxuduğu sahələri açıq şəkildə
// elan edir və həmin siyahıda şəxsiyyət, əlaqə və ya koordinat sahəsi
// yoxdur. Kimsə oradan `email` proyeksiya etmək istəsə, sahəni
// siyahıya əlavə etməli olacaq və bu test sınacaq.
//
// NƏ SÜBUT ETMİR: icra vaxtı davranışını. Bu, saf funksiya testidir,
// emulator sorğusu deyil. Modulun sənədi ilə kodu arasındakı bağı
// qoruyur — kodun özünü Firestore-a qarşı işlətmir.
import { strict as assert } from "node:assert";
import { describe, test } from "node:test";
import { readFileSync } from "node:fs";
import { fileURLToPath } from "node:url";
import { dirname, join } from "node:path";

const here = dirname(fileURLToPath(import.meta.url));
const ANALYTICS_SOURCE = join(here, "../../admin-panel/src/lib/data/analytics.ts");
const source = readFileSync(ANALYTICS_SOURCE, "utf8");

/** Modulun özünün elan etdiyi siyahılar — mənbədən oxunur ki, test
 * `server-only` importunu işə salmasın. */
function stringArrayLiteral(name: string): string[] {
  const m = source.match(new RegExp(`${name}[^=]*=\\s*\\[([\\s\\S]*?)\\]`));
  assert.ok(m, `${name} tapılmadı`);
  return [...m[1].matchAll(/"([^"]+)"/g)].map((x) => x[1]);
}

const projections = stringArrayLiteral("ANALYTICS_FIELD_PROJECTIONS");
const denylist = stringArrayLiteral("PII_FIELD_DENYLIST");

describe("Analytics — PII sızması yoxdur", () => {
  test("elan edilən proyeksiyalar boş deyil və qadağan siyahısı ilə kəsişmir", () => {
    assert.ok(projections.length > 0);
    assert.ok(denylist.length > 0);
    for (const field of projections) {
      assert.ok(!denylist.includes(field), `proyeksiya PII sahəsidir: ${field}`);
    }
  });

  test("qadağan siyahısı əsas şəxsiyyət sahələrini örtür", () => {
    for (const required of ["uid", "email", "phoneNumber", "name", "lat", "lng"]) {
      assert.ok(denylist.includes(required), `qadağan siyahısında yoxdur: ${required}`);
    }
  });

  test("mənbədə `.select(...)` yalnız elan edilmiş sahələri işlədir", () => {
    for (const m of source.matchAll(/\.select\(([^)]*)\)/g)) {
      for (const f of [...m[1].matchAll(/"([^"]+)"/g)].map((x) => x[1])) {
        assert.ok(projections.includes(f), `elan edilməmiş proyeksiya: ${f}`);
      }
    }
  });

  test("modul heç bir istifadəçi sənədini birbaşa oxumur", () => {
    // `.doc(...)` fərdi sənəd deməkdir. Aqreqat sorğular və
    // `.select()` sorğuları buna ehtiyac duymur.
    assert.equal(/\.doc\(/.test(source), false, "analytics modulu .doc() işlədir");
  });

  test("hər sorğu ya aqreqatdır, ya da proyeksiyalıdır", () => {
    // Proyeksiyasız `.get()` tam sənəd qaytarardı.
    const bareGets = [...source.matchAll(/\n\s*\.get\(\)/g)];
    const guarded = [...source.matchAll(/(?:count\(\)|aggregate\([^)]*\)|select\([^)]*\))\s*\n?\s*\.get\(\)/g)];
    assert.equal(bareGets.length, guarded.length, "proyeksiyasız/aqreqatsız .get() var");
  });

  test("kohort funksiyası `retention` adlandırılmır", () => {
    // Ölçülən şey retention əyrisi deyil; adı da elə olmamalıdır.
    assert.equal(/getRetention|\bretentionRate\b/.test(source), false);
  });
});

describe("Analytics — kohort k-anonimlik döşəməsi", () => {
  // H-2-dəki `VENUE_AUDIENCE_MIN_REPORTABLE_COUNT` ilə eyni rəqəm və
  // eyni səbəb. Bir nəfərlik kohort statistika deyil — konkret adamdır,
  // və bu səhifə məhz şəxsi məlumat görməməli olan rol üçün qurulub.
  test("döşəmə 5-dir və previewVenueAudience ilə eyni rəqəmdir", () => {
    const m = source.match(/COHORT_MIN_REPORTABLE_COUNT\s*=\s*(\d+)/);
    assert.ok(m, "COHORT_MIN_REPORTABLE_COUNT tapılmadı");
    assert.equal(Number(m[1]), 5);
  });

  test("hədddən aşağı sətir null qaytarır — rəqəm modulu tərk etmir", () => {
    assert.match(source, /registered: null, stillActive: null, suppressed: true/);
  });

  test("suppression sətir üzrədir, sahə üzrə deyil", () => {
    // Yalnız `stillActive`-i gizlədib `registered: 1` göstərmək eyni
    // faktı sızdırardı.
    assert.equal(/stillActive: null/.test(source) && /registered: null/.test(source), true);
  });
});

describe("Analytics — bir sorğunun sınması səhifəni öldürməməlidir", () => {
  // `/analytics` ilk yüklənişində 500 verdi: `sum()` aqreqatı
  // `payments(status, createdAt, amount)` indeksini tələb edir, mövcud
  // `(status, createdAt)` indeksi kifayət etmir — və o bir rədd
  // `Promise.all` vasitəsilə bütün səhifəni apardı. İndeks əlavə
  // edildi, amma əsl qüsur ikinci hissə idi.
  test("modul degradasiya köməkçisini ixrac edir", () => {
    assert.match(source, /export async function safeAnalyticsQuery/);
  });

  test("köməkçi xətanı udmur — loglayır", () => {
    const body = source.slice(source.indexOf("safeAnalyticsQuery"));
    assert.match(body, /console\.error/);
  });

  test("sum() sorğusunun öz indeksi tələb etdiyi sənədləşdirilib", () => {
    // Bu şərh olmasa, növbəti adam eyni fərziyyəni edəcək.
    assert.match(source, /NEEDS ITS OWN INDEX/);
    assert.match(source, /payments \(status, createdAt, amount\)/);
  });
});
