import Link from "next/link";
import { AlertTriangle, Flag, MapPin, Tag, Users } from "lucide-react";

import { Badge } from "@/components/ui/badge";
import { Card, CardContent, CardDescription, CardHeader, CardTitle } from "@/components/ui/card";
import { StatCard } from "@/components/dashboard/stat-card";
import { RegistrationsChart } from "@/components/dashboard/registrations-chart";
import { hasPermission } from "@/lib/auth/permissions";
import { getCurrentAdmin } from "@/lib/auth/server";
import { getDashboardStats, getRegistrationsLast7Days } from "@/lib/data/dashboard";
import { listReports } from "@/lib/data/reports";

function formatDate(iso: string | null): string {
  if (!iso) return "—";
  return new Date(iso).toLocaleDateString("az-AZ", { year: "numeric", month: "short", day: "numeric" });
}

/**
 * One shared dashboard for both roles rather than a separate
 * "moderator dashboard" route — the sidebar already scopes what each
 * role can reach (see nav-items.ts), so the meaningful difference
 * between an admin's and a moderator's view is which stat cards/quick
 * lists are relevant to them, not a whole parallel page. Moderators
 * see everything here except nothing is hidden today since every
 * stat/list on this page is either role-agnostic (totals) or backed by
 * a permission both roles hold (`moderateVenues`/`moderateOffers`/
 * `manageFeedback`).
 */
export default async function DashboardPage() {
  const admin = await getCurrentAdmin();
  const [stats, registrations, pendingReports] = await Promise.all([
    getDashboardStats(),
    getRegistrationsLast7Days(),
    hasPermission(admin?.role, "manageFeedback") ? listReports({ status: "pending" }) : Promise.resolve([]),
  ]);

  return (
    <div className="space-y-6">
      <div>
        <h1 className="text-2xl font-semibold tracking-tight">Dashboard</h1>
        <p className="text-sm text-muted-foreground">Kim Var-ın ümumi vəziyyətinə baxış.</p>
      </div>

      <div className="grid gap-4 sm:grid-cols-2 lg:grid-cols-5">
        <StatCard label="Cəmi istifadəçi" value={stats.totalUsers} icon={Users} />
        <StatCard label="Aktiv məkan" value={stats.activeVenues} icon={MapPin} />
        <StatCard label="Aktiv təklif" value={stats.activeOffers} icon={Tag} />
        <StatCard
          label="Gözləyən moderasiya"
          value={stats.pendingModeration}
          icon={AlertTriangle}
          hint={stats.pendingModeration === 0 ? "Məkan/təklif təsdiq növbəsi boşdur" : undefined}
        />
        <StatCard label="Gözləyən şikayət" value={stats.pendingReports} icon={Flag} />
      </div>

      <div className="grid gap-4 lg:grid-cols-2">
        <RegistrationsChart data={registrations} />

        {hasPermission(admin?.role, "manageFeedback") && (
          <Card>
            <CardHeader>
              <CardTitle>Son şikayətlər</CardTitle>
              <CardDescription>Gözləyən şikayətlər — ilk 5</CardDescription>
            </CardHeader>
            <CardContent className="space-y-3">
              {pendingReports.length === 0 ? (
                <p className="text-sm text-muted-foreground">Gözləyən şikayət yoxdur.</p>
              ) : (
                pendingReports.slice(0, 5).map((report) => (
                  <Link
                    key={report.id}
                    href={`/feedback/${report.id}`}
                    className="flex items-center justify-between rounded-lg border p-3 text-sm hover:bg-muted/50"
                  >
                    <div>
                      <p className="font-medium">{report.reportedUserName}</p>
                      <p className="line-clamp-1 text-muted-foreground">{report.reason}</p>
                    </div>
                    <Badge variant="secondary" className="shrink-0">
                      {formatDate(report.createdAt)}
                    </Badge>
                  </Link>
                ))
              )}
            </CardContent>
          </Card>
        )}
      </div>
    </div>
  );
}
