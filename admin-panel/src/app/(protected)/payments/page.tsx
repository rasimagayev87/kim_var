import { redirect } from "next/navigation";

import { PaymentsFilters } from "@/components/payments/payments-filters";
import { PaymentsTable } from "@/components/payments/payments-table";
import { hasPermission } from "@/lib/auth/permissions";
import { getCurrentAdmin } from "@/lib/auth/server";
import { listPayments, type PaymentStatusFilter } from "@/lib/data/payments";

function parseStatus(value: string | undefined): PaymentStatusFilter {
  return value === "pending" ||
    value === "completed" ||
    value === "revision_pending" ||
    value === "refund_pending" ||
    value === "refunded"
    ? value
    : "refund_pending";
}

export default async function PaymentsPage({
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

  const payments = await listPayments({ status });

  return (
    <div className="space-y-6">
      <div>
        <h1 className="text-2xl font-semibold tracking-tight">Ödənişlər</h1>
        <p className="text-sm text-muted-foreground">
          Ödəniş provayderi hələ qurulmayıb — &quot;Geri qaytarılmalı&quot; siyahısı geri qaytarmaların əl ilə izlənməsi
          üçündür. {payments.length} nəticə.
        </p>
      </div>

      <PaymentsFilters initialStatus={status} />

      <PaymentsTable payments={payments} />
    </div>
  );
}
