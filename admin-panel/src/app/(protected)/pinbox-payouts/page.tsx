import { redirect } from "next/navigation";

import { PinBoxPayoutsFilters } from "@/components/pinbox-payouts/pinbox-payouts-filters";
import { PinBoxPayoutsTable } from "@/components/pinbox-payouts/pinbox-payouts-table";
import { hasPermission } from "@/lib/auth/permissions";
import { getCurrentAdmin } from "@/lib/auth/server";
import { listPinBoxPayouts, type PinBoxPayoutStatusFilter } from "@/lib/data/pinbox-payouts";
import { isLastDayOfBakuMonth } from "@/lib/pinbox-payout-window";

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
  const canMarkPaid = isLastDayOfBakuMonth();

  return (
    <div className="space-y-6">
      <div>
        <h1 className="text-2xl font-semibold tracking-tight">PinBox Öhdəlikləri</h1>
        <p className="text-sm text-muted-foreground">
          Hər uğurlu PinBox ödənişindən dərhal sonra məkanın 85%-lik payı burada &quot;Gözləyən&quot; kimi görünür (15%
          PeakPin komissiyası). Bank köçürməsi əl ilə edilir — &quot;Ödənildi&quot; düyməsi yalnız ayın son günü
          aktivdir. {payouts.length} nəticə.
        </p>
      </div>

      <PinBoxPayoutsFilters initialStatus={status} />

      <PinBoxPayoutsTable payouts={payouts} canMarkPaid={canMarkPaid} />
    </div>
  );
}
