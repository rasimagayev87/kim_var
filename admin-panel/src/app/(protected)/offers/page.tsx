import { redirect } from "next/navigation";

import { OffersFilters } from "@/components/offers/offers-filters";
import { OffersTable } from "@/components/offers/offers-table";
import { hasPermission } from "@/lib/auth/permissions";
import { getCurrentAdmin } from "@/lib/auth/server";
import { listOffers, type OfferStatusFilter } from "@/lib/data/offers";

function parseStatus(value: string | undefined): OfferStatusFilter {
  return value === "pending" || value === "active" || value === "rejected" ? value : "all";
}

export default async function OffersPage({
  searchParams,
}: {
  searchParams: Promise<{ q?: string; status?: string }>;
}) {
  const admin = await getCurrentAdmin();
  if (!admin || !hasPermission(admin.role, "moderateOffers")) {
    redirect("/dashboard");
  }

  const params = await searchParams;
  const search = params.q ?? "";
  const status = parseStatus(params.status);

  const offers = await listOffers({ status, search });

  return (
    <div className="space-y-6">
      <div>
        <h1 className="text-2xl font-semibold tracking-tight">Təkliflər</h1>
        <p className="text-sm text-muted-foreground">{offers.length} təklif (son 200 arasından süzülüb)</p>
      </div>

      <OffersFilters initialSearch={search} initialStatus={status} />

      <OffersTable offers={offers} />
    </div>
  );
}
