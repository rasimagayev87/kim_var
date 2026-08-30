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
import { ADMIN_ROLES, isAdminRole, type AdminRole } from "../../admin-panel/src/lib/auth/roles";

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
