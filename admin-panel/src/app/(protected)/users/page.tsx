import { redirect } from "next/navigation";

import { UsersFilters } from "@/components/users/users-filters";
import { UsersTable } from "@/components/users/users-table";
import { hasPermission } from "@/lib/auth/permissions";
import { getCurrentAdmin } from "@/lib/auth/server";
import { listUsers, type VerifiedFilter, type VipFilter } from "@/lib/data/users";

function parseVerified(value: string | undefined): VerifiedFilter {
  return value === "verified" || value === "unverified" ? value : "all";
}

function parseVip(value: string | undefined): VipFilter {
  return value === "vip" || value === "free" ? value : "all";
}

export default async function UsersPage({
  searchParams,
}: {
  searchParams: Promise<{ q?: string; verified?: string; vip?: string }>;
}) {
  const admin = await getCurrentAdmin();
  // Sidebar already hides this module for moderators (see nav-items.ts)
  // — this is the actual enforcement, since a hidden link doesn't stop
  // a direct URL visit. Matches the spec's "moderator: dəyişiklik yoxdur
  // istifadəçi idarəetməsinə" as no access at all, not read-only.
  if (!admin || !hasPermission(admin.role, "manageUsers")) {
    redirect("/dashboard");
  }

  const params = await searchParams;
  const search = params.q ?? "";
  const verifiedFilter = parseVerified(params.verified);
  const vipFilter = parseVip(params.vip);

  const users = await listUsers({ search, verifiedFilter, vipFilter });

  return (
    <div className="space-y-6">
      <div>
        <h1 className="text-2xl font-semibold tracking-tight">İstifadəçilər</h1>
        <p className="text-sm text-muted-foreground">
          {users.length} istifadəçi (son {200} qeydiyyat arasından süzülüb)
        </p>
      </div>

      <UsersFilters initialSearch={search} initialVerified={verifiedFilter} initialVip={vipFilter} />

      <UsersTable users={users} />
    </div>
  );
}
