import { redirect } from "next/navigation";

import { PermissionMatrixTable } from "@/components/roles/permission-matrix-table";
import { hasPermission } from "@/lib/auth/permissions";
import { getCurrentAdmin } from "@/lib/auth/server";

/**
 * The permission matrix as a reference screen.
 *
 * Gated on `manageAdmins`, i.e. admin only — the same permission that
 * governs `/admins`. Who can do what is internal structure: it tells a
 * reader exactly which role to compromise for a given capability, so
 * it belongs with role assignment rather than being visible to every
 * signed-in admin user.
 *
 * Reads nothing from Firestore. The table is rendered from the
 * in-process `PERMISSION_MATRIX`, so this page costs zero reads and
 * cannot drift from the values actually enforced.
 */
export default async function RolesPage() {
  const admin = await getCurrentAdmin();
  if (!admin || !hasPermission(admin.role, "manageAdmins")) {
    redirect("/unauthorized");
  }

  return (
    <div className="space-y-6">
      <div>
        <h1 className="text-2xl font-semibold tracking-tight">Rollar və İcazələr</h1>
        <p className="text-sm text-muted-foreground">
          Beş rolun tam icazə matrisi — kodda tətbiq edilən dəyərlərdən birbaşa oxunur. Yalnız
          məlumat üçündür; rol təyinatı <strong>Adminlər</strong> səhifəsindədir.
        </p>
      </div>

      <div className="rounded-lg border bg-muted/30 p-4 text-sm">
        <p className="font-medium">İki bildiriş anlayışı ayrıdır</p>
        <p className="mt-1 text-muted-foreground">
          <code>viewBroadcasts</code> — istifadəçilərə kütləvi bildiriş göndərmə ekranı.{" "}
          <code>viewAdminNotifications</code> — hər səhifədə görünən zəng ikonu. Maliyyə rolu
          birincini görmür, ikincini görür: ödəniş xəbərdarlıqları məhz ona lazımdır, moderasiya
          bildirişləri isə tip üzrə süzülür. Analitik rolu heç birini görmür.
        </p>
      </div>

      <PermissionMatrixTable currentRole={admin.role} />
    </div>
  );
}
