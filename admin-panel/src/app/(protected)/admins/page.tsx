import { redirect } from "next/navigation";

import { AddAdminDialog } from "@/components/admins/add-admin-dialog";
import { AdminsTable } from "@/components/admins/admins-table";
import { hasPermission } from "@/lib/auth/permissions";
import { getCurrentAdmin } from "@/lib/auth/server";
import { listAdmins } from "@/lib/data/admins";

export default async function AdminsPage() {
  const admin = await getCurrentAdmin();
  if (!admin || !hasPermission(admin.role, "manageAdmins")) {
    redirect("/dashboard");
  }

  const admins = await listAdmins();

  return (
    <div className="space-y-6">
      <div className="flex items-center justify-between">
        <div>
          <h1 className="text-2xl font-semibold tracking-tight">Admin idarəetməsi</h1>
          <p className="text-sm text-muted-foreground">{admins.length} admin/moderator</p>
        </div>
        <AddAdminDialog />
      </div>

      <AdminsTable admins={admins} currentUid={admin.uid} />
    </div>
  );
}
