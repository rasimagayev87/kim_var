import { LogsTable } from "@/components/logs/logs-table";
import { listModerationLogs } from "@/lib/data/moderation-logs";

/**
 * Visible to both admin and moderator (no permission gate, same as
 * Dashboard) — the audit trail's whole point is accountability, and
 * that includes moderators being able to see the team's own history,
 * not just admins overseeing them.
 */
export default async function LogsPage() {
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
