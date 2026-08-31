import Link from "next/link";
import { redirect } from "next/navigation";

import { SubscriptionsTable } from "@/components/subscriptions/subscriptions-table";
import { hasPermission } from "@/lib/auth/permissions";
import { getCurrentAdmin } from "@/lib/auth/server";
import {
  isSubscriptionStatus,
  listSubscriptions,
  SUBSCRIPTION_STATUSES,
  type SubscriptionStatusFilter,
} from "@/lib/data/subscriptions";

const FILTER_LABELS: Record<string, string> = {
  all: "Hamısı",
  approved: "Aktiv",
  subscription_overdue: "Borclu",
  awaiting_payment: "Ödəniş gözlənilir",
};

/**
 * Venue subscriptions, read-only. No action controls anywhere on this
 * screen; billing is driven by `renewVenueSubscriptions` and paid
 * through Epoint, and an admin button that "marks a subscription paid"
 * would be a way to hand out free months with no payment record.
 *
 * `viewSubscriptions` opens the page for every role — but that
 * permission is true for everyone precisely because it describes
 * subscription STATE, not money. The amounts on this screen are gated
 * separately on `viewRevenue`, and gated in the QUERY: a role without
 * it gets rows with no fee and no payment date, and its session never
 * touches the `payments` collection. Same shape as `/premium-payments`
 * moving to the payments axis.
 *
 * COST: one `venues` query capped at 200 documents, plus — only for
 * roles that may see money — one `payments` query also capped at 200.
 */
export default async function SubscriptionsPage({
  searchParams,
}: {
  searchParams: Promise<{ status?: string }>;
}) {
  const admin = await getCurrentAdmin();
  if (!admin || !hasPermission(admin.role, "viewSubscriptions")) {
    redirect("/unauthorized");
  }

  const showMoney = hasPermission(admin.role, "viewRevenue");
  const { status: rawStatus } = await searchParams;
  const status: SubscriptionStatusFilter = isSubscriptionStatus(rawStatus) ? rawStatus : "all";

  const subscriptions = await listSubscriptions({ status, includeMoney: showMoney });

  return (
    <div className="space-y-6">
      <div>
        <h1 className="text-2xl font-semibold tracking-tight">Abunəliklər</h1>
        <p className="text-sm text-muted-foreground">
          Məkan abunələri, növbəti ödəniş tarixinə görə sıralanıb. {subscriptions.length} nəticə.
          {showMoney ? null : " Məbləğ sütunları rolunuza görə göstərilmir."}
        </p>
      </div>

      <div className="flex flex-wrap gap-2">
        {(["all", ...SUBSCRIPTION_STATUSES] as const).map((value) => (
          <Link
            key={value}
            href={value === "all" ? "/subscriptions" : `/subscriptions?status=${value}`}
            className={`rounded-full border px-3 py-1 text-sm ${
              status === value ? "bg-primary text-primary-foreground" : "hover:bg-muted"
            }`}
          >
            {FILTER_LABELS[value]}
          </Link>
        ))}
      </div>

      <SubscriptionsTable subscriptions={subscriptions} showMoney={showMoney} />
    </div>
  );
}
