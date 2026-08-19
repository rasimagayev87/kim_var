import { redirect } from "next/navigation";

import { PinBoxPayoutsFilters } from "@/components/pinbox-payouts/pinbox-payouts-filters";
import { PinBoxPayoutsTable } from "@/components/pinbox-payouts/pinbox-payouts-table";
import { hasPermission } from "@/lib/auth/permissions";
import { getCurrentAdmin } from "@/lib/auth/server";
import { listPinBoxPayouts, type PinBoxPayoutStatusFilter } from "@/lib/data/pinbox-payouts";

function parseStatus(value: string | undefined): PinBoxPayoutStatusFilter {
  return value === "pending" || value === "paid" || value === "all" ? value : "pending";
}

export default async function PinBoxPayoutsPage({
  searchParams,
}: {
  searchParams: Promise<{ status?: string }>;
}) {
  const admin = await getCurrentAdmin();
  if (!admin || !hasPermission(admin.role, "moderateVenues")) {
    redirect("/dashboard");
  }

  const params = await searchParams;
  const status = parseStatus(params.status);

  const payouts = await listPinBoxPayouts({ status });

  return (
    <div className="space-y-6">
      <div>
        <h1 className="text-2xl font-semibold tracking-tight">PinBox Ödənişləri</h1>
        <p className="text-sm text-muted-foreground">
          Hər ay avtomatik hesablanır (satış qiymətinin 85%-i məkana, 15%-i komissiya) — bank köçürməsi əl ilə edilir,
          göndərildikdən sonra aşağıdan &quot;Ödənildi&quot; kimi işarələyin. {payouts.length} nəticə.
        </p>
      </div>

      <PinBoxPayoutsFilters initialStatus={status} />

      <PinBoxPayoutsTable payouts={payouts} />
    </div>
  );
}
