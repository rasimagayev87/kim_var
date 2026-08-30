import { redirect } from "next/navigation";

import { LogsTable } from "@/components/logs/logs-table";
import { hasPermission } from "@/lib/auth/permissions";
import { getCurrentAdmin } from "@/lib/auth/server";
import { listModerationLogs } from "@/lib/data/moderation-logs";

/**
 * NEWLY GUARDED in the five-role revision — this page previously had no
 * permission check at all, on the reasoning that the audit trail's
 * purpose is accountability and every teammate should see the team's
 * own history. That still holds for admin, moderator, finance and
 * support, all of whom keep access.
 *
 * `analyst` is the exception and the reason a gate now exists: each log
 * row carries an actor e-mail, a target uid and a free-text note (see
 * `logModerationAction`), which is exactly the personal data that role
 * is defined not to see. Excluding one role required introducing a
 * check where there had been none — a behaviour change worth noticing,
 * not a regression.
 */
export default async function LogsPage() {
  const admin = await getCurrentAdmin();
  if (!admin || !hasPermission(admin.role, "viewAuditLogs")) {
    redirect("/unauthorized");
  }

  const logs = await listModerationLogs();

  return (
    <div className="space-y-6">
      <div>
        <h1 className="text-2xl font-semibold tracking-tight">Moderator logları</h1>
        <p className="text-sm text-muted-foreground">
          {logs.length} qeyd (son 200 arasından) — kim, nə vaxt, nə etdi.
        </p>
      </div>

      <LogsTable logs={logs} />
    </div>
  );
}
