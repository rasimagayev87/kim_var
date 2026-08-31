// 5 rollu RBAC — saf funksiya testləri.
//
// `permissions.ts` və `session.ts`-in rol məntiqi heç bir SDK idxal
// etmir, ona görə emulator olmadan birbaşa test olunur. Səhifə
// redirect-ləri bu dəstin əhatəsində DEYİL (admin panelin test runner-i
// yoxdur) — onlar əl ilə yoxlanılır; buradakı testlər qərarın ÖZÜNÜ,
// yəni matrisi qoruyur.
import { strict as assert } from "node:assert";
import { describe, test } from "node:test";

import {
  hasPermission,
  PERMISSIONS_BY_ROLE,
  UNIMPLEMENTED_PERMISSIONS,
  type Permission,
} from "../../admin-panel/src/lib/auth/permissions";
import { ADMIN_ROLES, isAdminRole, rosterRole, type AdminRole } from "../../admin-panel/src/lib/auth/roles";

const ALL_PERMISSIONS = Object.keys(PERMISSIONS_BY_ROLE.admin) as Permission[];

describe("RBAC — rol tanınması (fail-closed)", () => {
  test("beş rol tanınır", () => {
    for (const r of ["admin", "moderator", "finance", "support", "analyst"]) {
      assert.equal(isAdminRole(r), true, r);
    }
    assert.equal(ADMIN_ROLES.length, 5);
  });

  test("tanınmayan rol RƏDD edilir (sessiya verilmir)", () => {
    for (const bad of ["superadmin", "Admin", "ADMIN", "", "root", "owner", null, undefined, 42, {}]) {
      assert.equal(isAdminRole(bad), false, String(bad));
    }
  });

  test("hasPermission tanınmayan/boş rol üçün həmişə false", () => {
    for (const p of ALL_PERMISSIONS) {
      assert.equal(hasPermission(null, p), false, p);
      assert.equal(hasPermission(undefined, p), false, p);
      assert.equal(hasPermission("finance-manager" as AdminRole, p), false, p);
    }
  });
});

describe("RBAC — admin strict superset", () => {
  test("admin-in olmadığı heç bir icazə yoxdur", () => {
    for (const role of ADMIN_ROLES) {
      for (const p of ALL_PERMISSIONS) {
        if (hasPermission(role, p)) {
          assert.equal(hasPermission("admin", p), true, `admin-də yoxdur: ${p} (${role}-də var)`);
        }
      }
    }
  });
});

describe("RBAC — matrisin qəsdən qərarları", () => {
  test("analyst şəxsi məlumat daşıyan heç bir səthi görmür", () => {
    for (const p of ["viewUsers", "manageFeedback", "viewAuditLogs", "viewAdminNotifications"] as Permission[]) {
      assert.equal(hasPermission("analyst", p), false, p);
    }
  });

  test("analyst heç bir əməliyyat icazəsinə malik deyil", () => {
    const actions = ALL_PERMISSIONS.filter((p) => !p.startsWith("view"));
    for (const p of actions) {
      assert.equal(hasPermission("analyst", p), false, p);
    }
  });

  test("support istifadəçini görür, amma redaktə etmir və ban etmir", () => {
    assert.equal(hasPermission("support", "viewUsers"), true);
    assert.equal(hasPermission("support", "manageUsers"), false);
    assert.equal(hasPermission("support", "banUsers"), false);
    assert.equal(hasPermission("support", "deleteUsers"), false);
  });

  test("support şikayət və dəstək müraciətlərini idarə edir", () => {
    assert.equal(hasPermission("support", "manageFeedback"), true);
    assert.equal(hasPermission("support", "manageSupportMessages"), true);
    assert.equal(hasPermission("support", "broadcastNotifications"), true);
  });

  test("finance istifadəçi siyahısını və şikayətləri GÖRMÜR", () => {
    assert.equal(hasPermission("finance", "viewUsers"), false);
    assert.equal(hasPermission("finance", "manageFeedback"), false);
    assert.equal(hasPermission("finance", "moderateIdentityVerifications"), false);
  });

  test("finance ödəniş və abunəlik əməliyyatlarını edir", () => {
    for (const p of ["managePayments", "manageSubscriptions", "manageFinancials"] as Permission[]) {
      assert.equal(hasPermission("finance", p), true, p);
    }
  });

  test("moderator ödəniş səthlərini görmür (H-7 reqressiya testi)", () => {
    for (const p of ["viewPayments", "managePayments", "viewRevenue", "viewFinancials"] as Permission[]) {
      assert.equal(hasPermission("moderator", p), false, p);
    }
  });

  test("moderator istifadəçini görür və ban edir, amma silmir/redaktə etmir", () => {
    assert.equal(hasPermission("moderator", "viewUsers"), true);
    assert.equal(hasPermission("moderator", "banUsers"), true);
    assert.equal(hasPermission("moderator", "deleteUsers"), false);
    assert.equal(hasPermission("moderator", "manageUsers"), false);
  });

  test("hesab silmə yalnız admin-dədir", () => {
    for (const r of ADMIN_ROLES) {
      assert.equal(hasPermission(r, "deleteUsers"), r === "admin", r);
    }
  });

  test("KYC, admin idarəetməsi və sistem ayarları yalnız admin-dədir", () => {
    for (const p of ["moderateIdentityVerifications", "manageAdmins", "manageSystemSettings"] as Permission[]) {
      for (const r of ADMIN_ROLES) {
        assert.equal(hasPermission(r, p), r === "admin", `${p}/${r}`);
      }
    }
  });

  test("export yalnız admin və finance-dədir", () => {
    for (const r of ADMIN_ROLES) {
      assert.equal(hasPermission(r, "exportData"), r === "admin", r);
      assert.equal(hasPermission(r, "exportFinancialData"), r === "admin" || r === "finance", r);
    }
  });
});

describe("RBAC — görmə/əməliyyat ayrımı", () => {
  test("əməliyyat icazəsi olan rol həmişə uyğun görmə icazəsinə də malikdir", () => {
    const pairs: [Permission, Permission][] = [
      ["manageUsers", "viewUsers"],
      ["banUsers", "viewUsers"],
      ["deleteUsers", "viewUsers"],
      ["moderateVenues", "viewVenues"],
      ["moderateOffers", "viewOffers"],
      ["managePayments", "viewPayments"],
      ["manageSubscriptions", "viewSubscriptions"],
      ["broadcastNotifications", "viewBroadcasts"],
    ];
    for (const role of ADMIN_ROLES) {
      for (const [act, view] of pairs) {
        if (hasPermission(role, act)) {
          assert.equal(hasPermission(role, view), true, `${role}: ${act} var, ${view} yoxdur`);
        }
      }
    }
  });
});

describe("RBAC — matris bütövlüyü", () => {
  test("hər rolda eyni icazə açarları var (heç biri unudulmayıb)", () => {
    for (const role of ADMIN_ROLES) {
      const keys = Object.keys(PERMISSIONS_BY_ROLE[role]).sort();
      assert.deepEqual(keys, [...ALL_PERMISSIONS].sort(), role);
    }
  });

  test("UNIMPLEMENTED_PERMISSIONS-dakı hər ad real icazədir", () => {
    for (const p of UNIMPLEMENTED_PERMISSIONS) {
      assert.ok(ALL_PERMISSIONS.includes(p), `naməlum icazə adı: ${p}`);
    }
  });
});

describe("RBAC — /admins roster göstərişi", () => {
  // Bu, canlı simptomun kök səbəbi idi: roster oxuyucusu iki rollu
  // dövrdən qalma sabit siyahı işlədirdi, ona görə finance/support/
  // analyst "naməlum rol" görünürdü — icazələri isə tam işləyirdi,
  // çünki авторizasiya custom claim-dən oxunur, bu sahədən yox.
  test("beş rolun hamısı roster-də öz adı ilə görünür", () => {
    for (const role of ADMIN_ROLES) {
      assert.equal(rosterRole(role), role, `${role} naməlum kimi göstərildi`);
    }
  });

  test("tanınmayan dəyər null olur — 'admin' kimi göstərilmir", () => {
    // Sərtləşdirmənin özü doğrudur və qalır: pozuq bir sənəd sətri
    // tam admin kimi görünsəydi, məhz kimin nəyə icazəsi olduğunu
    // göstərən ekran ən yanlış cavabı verərdi.
    for (const bad of ["superadmin", "ADMIN", "", "owner", null, undefined, 7, {}, ["admin"]]) {
      assert.equal(rosterRole(bad), null, `${JSON.stringify(bad)} null olmalıdır`);
    }
  });

  test("rosterRole ilə isAdminRole eyni siyahını qəbul edir", () => {
    // İkisinin ayrılması məhz bu qüsuru yaratmışdı.
    for (const v of [...ADMIN_ROLES, "superadmin", "", null, 1]) {
      assert.equal(rosterRole(v) !== null, isAdminRole(v), `fərq: ${JSON.stringify(v)}`);
    }
  });
});

describe("RBAC — maliyyə səthləri moderator-a bağlıdır", () => {
  // /premium-payments və /pinbox-payouts pul hərəkətini göstərir, ona
  // görə `viewPayments` oxu — `viewSubscriptions` yox, o, hər rolda
  // true-dur və ekranı moderator-a açıq qoyardı.
  test("premium ödənişləri və PinBox öhdəlikləri: admin/finance ✅, support/analyst 👁️, moderator ❌", () => {
    for (const role of ["admin", "finance", "support", "analyst"] as AdminRole[]) {
      assert.equal(hasPermission(role, "viewPayments"), true, `${role} görməlidir`);
    }
    assert.equal(hasPermission("moderator", "viewPayments"), false);
  });

  test("əməliyyat tərəfi yalnız admin və finance-dədir", () => {
    assert.equal(hasPermission("admin", "managePayments"), true);
    assert.equal(hasPermission("finance", "managePayments"), true);
    for (const role of ["moderator", "support", "analyst"] as AdminRole[]) {
      assert.equal(hasPermission(role, "managePayments"), false, `${role} əməliyyat edə bilməz`);
    }
  });

  test("viewSubscriptions maliyyə qapısı DEYİL — hər rolda açıqdır", () => {
    // Bu testin özü sənəddir: kimsə bir ödəniş ekranını yenidən bu
    // icazə ilə qorusa, nəyi açdığını burada görəcək.
    for (const role of ADMIN_ROLES) {
      assert.equal(hasPermission(role, "viewSubscriptions"), true, role);
    }
  });
});

describe("RBAC — bildiriş: iki ayrı anlayış", () => {
  test("broadcast ekranı finance və analyst-ə bağlıdır", () => {
    assert.equal(hasPermission("finance", "viewBroadcasts"), false);
    assert.equal(hasPermission("analyst", "viewBroadcasts"), false);
    assert.equal(hasPermission("support", "broadcastNotifications"), true);
    assert.equal(hasPermission("moderator", "broadcastNotifications"), false);
  });

  test("zəng ikonu finance-də AÇIQ, analyst-də bağlı", () => {
    // Qəsdən fərqlidir: finance ödəniş xəbərdarlığına əməl edir və
    // `notification-visibility.ts` moderasiya yarısını tip üzrə
    // kəsir. analyst üçün ödəniş bildirişi belə məkan sahibinin
    // adını daşıyır.
    assert.equal(hasPermission("finance", "viewAdminNotifications"), true);
    assert.equal(hasPermission("analyst", "viewAdminNotifications"), false);
  });
});

describe("RBAC — üç yeni səhifə", () => {
  // Səhifələr Server Component-dir və `redirect()` çağırır, ona görə
  // burada yoxlanılan şey səhifənin özü deyil, onun oxuduğu qərardır:
  // hansı rol üçün `hasPermission` true qaytarır. Səhifə həmin
  // funksiyanı birbaşa çağırır — arada başqa məntiq yoxdur.

  test("/roles yalnız admin-ə açıqdır", () => {
    // Rol strukturu daxili məlumatdır: hansı rolu ələ keçirməyin nə
    // verdiyini sətir-sətir göstərir.
    assert.equal(hasPermission("admin", "manageAdmins"), true);
    for (const role of ["moderator", "finance", "support", "analyst"] as AdminRole[]) {
      assert.equal(hasPermission(role, "manageAdmins"), false, `${role} /roles görməməlidir`);
    }
  });

  test("/analytics hər rola açıqdır", () => {
    for (const role of ADMIN_ROLES) {
      assert.equal(hasPermission(role, "viewAnalytics"), true, role);
    }
  });

  test("/analytics aktivlik bloku: finance və support GÖRMÜR", () => {
    for (const role of ["admin", "moderator", "analyst"] as AdminRole[]) {
      assert.equal(hasPermission(role, "viewEngagementMetrics"), true, role);
    }
    for (const role of ["finance", "support"] as AdminRole[]) {
      assert.equal(hasPermission(role, "viewEngagementMetrics"), false, role);
    }
  });

  test("/analytics gəlir bloku: moderator və support GÖRMÜR", () => {
    for (const role of ["admin", "finance", "analyst"] as AdminRole[]) {
      assert.equal(hasPermission(role, "viewRevenue"), true, role);
    }
    for (const role of ["moderator", "support"] as AdminRole[]) {
      assert.equal(hasPermission(role, "viewRevenue"), false, role);
    }
  });

  test("/subscriptions hər rola açıqdır, məbləğ isə yalnız viewRevenue ilə", () => {
    for (const role of ADMIN_ROLES) {
      assert.equal(hasPermission(role, "viewSubscriptions"), true, `${role} səhifəni görməlidir`);
    }
    // Məbləğ sütunu — səhifə ilə eyni deyil.
    assert.equal(hasPermission("moderator", "viewRevenue"), false);
    assert.equal(hasPermission("support", "viewRevenue"), false);
    assert.equal(hasPermission("finance", "viewRevenue"), true);
  });

  test("analyst-in yeni səhifələrdə də PII səthi yoxdur", () => {
    // Analytics analyst üçün qurulub; bu, ona başqa qapı açmamalıdır.
    for (const p of ["viewUsers", "viewAuditLogs", "viewAdminNotifications", "manageFeedback"] as const) {
      assert.equal(hasPermission("analyst", p), false, p);
    }
  });

  test("üç səhifənin icazələri artıq 'səhifə yoxdur' siyahısında deyil", () => {
    for (const p of ["viewAnalytics", "viewEngagementMetrics", "viewRevenue", "viewSubscriptions", "manageAdmins"] as const) {
      assert.equal(
        UNIMPLEMENTED_PERMISSIONS.includes(p),
        false,
        `${p} üçün səhifə var, siyahıdan çıxarılmalıdır`,
      );
    }
  });
});
