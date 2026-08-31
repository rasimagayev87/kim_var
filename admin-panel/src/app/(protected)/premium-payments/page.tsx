import { redirect } from "next/navigation";

import { PremiumPaymentsTable } from "@/components/payments/premium-payments-table";
import { hasPermission } from "@/lib/auth/permissions";
import { getCurrentAdmin } from "@/lib/auth/server";
import { listPayments } from "@/lib/data/payments";

export default async function PremiumPaymentsPage() {
  const admin = await getCurrentAdmin();
  // `viewPayments`, not `viewSubscriptions`. This screen lists money
  // that moved — premium purchases with amounts and dates — so it
  // belongs on the payments axis, where `moderator` is excluded (the
  // separation P0 / H-7 exists to enforce). `viewSubscriptions`
  // describes the VIP/subscription STATE a moderator legitimately
  // needs to see on a venue, and it is true for every role, which
  // would have left this screen open to moderators.
  if (!admin || !hasPermission(admin.role, "viewPayments")) {
    redirect("/dashboard");
  }

  const payments = await listPayments({ status: "all", type: "venue_premium" });

  return (
    <div className="space-y-6">
      <div>
        <h1 className="text-2xl font-semibold tracking-tight">Premium Biznes Ödənişləri</h1>
        <p className="text-sm text-muted-foreground">
          &quot;Məkanı premium et&quot; vasitəsilə edilən bütün Epoint ödənişləri. {payments.length} nəticə.
        </p>
      </div>

      <PremiumPaymentsTable payments={payments} />
    </div>
  );
}
