import { redirect } from "next/navigation";

import { IdentityVerificationsFilters } from "@/components/identity-verifications/identity-verifications-filters";
import { IdentityVerificationsTable } from "@/components/identity-verifications/identity-verifications-table";
import { hasPermission } from "@/lib/auth/permissions";
import { getCurrentAdmin } from "@/lib/auth/server";
import { listIdentityVerifications, type IdentityVerificationStatusFilter } from "@/lib/data/identity-verifications";

function parseStatus(value: string | undefined): IdentityVerificationStatusFilter {
  return value === "pending" || value === "approved" || value === "rejected" ? value : "pending";
}

export default async function IdentityVerificationsPage({
  searchParams,
}: {
  searchParams: Promise<{ status?: string }>;
}) {
  const admin = await getCurrentAdmin();
  if (!admin || !hasPermission(admin.role, "moderateIdentityVerifications")) {
    redirect("/dashboard");
  }

  const params = await searchParams;
  // Defaults to "pending", unlike Venues/Offers' "all" default — this
  // is a review queue admins work through, not a browsable directory,
  // so opening the page should show what needs action right now.
  const status = parseStatus(params.status);

  const rows = await listIdentityVerifications(status);

  return (
    <div className="space-y-6">
      <div>
        <h1 className="text-2xl font-semibold tracking-tight">Kimlik doğrulama müraciətləri</h1>
        <p className="text-sm text-muted-foreground">{rows.length} müraciət (son 200 arasından süzülüb)</p>
      </div>

      <IdentityVerificationsFilters initialStatus={status} />

      <IdentityVerificationsTable rows={rows} />
    </div>
  );
}
