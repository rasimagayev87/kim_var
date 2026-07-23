import Link from "next/link";
import { notFound, redirect } from "next/navigation";
import { ArrowLeft } from "lucide-react";

import { Card, CardContent, CardHeader, CardTitle } from "@/components/ui/card";
import { StatusBadge } from "@/components/moderation/status-badge";
import { ReportStatusActions } from "@/components/feedback/report-status-actions";
import { UserPostsPanel } from "@/components/content/user-posts-panel";
import { hasPermission } from "@/lib/auth/permissions";
import { getCurrentAdmin } from "@/lib/auth/server";
import { listUserPosts } from "@/lib/data/content";
import { getReportDetail } from "@/lib/data/reports";

function formatDate(iso: string | null): string {
  if (!iso) return "Naməlum";
  return new Date(iso).toLocaleDateString("az-AZ", { year: "numeric", month: "long", day: "numeric", hour: "2-digit", minute: "2-digit" });
}

export default async function ReportDetailPage({ params }: { params: Promise<{ id: string }> }) {
  const admin = await getCurrentAdmin();
  if (!admin || !hasPermission(admin.role, "manageFeedback")) {
    redirect("/dashboard");
  }

  const { id } = await params;
  const report = await getReportDetail(id);
  if (!report) notFound();

  const reportedUserPosts = await listUserPosts(report.reportedUserId);

  return (
    <div className="mx-auto max-w-2xl space-y-6">
      <Link href="/feedback" className="inline-flex items-center gap-1.5 text-sm text-muted-foreground hover:text-foreground">
        <ArrowLeft className="size-4" />
        Şikayətlərə qayıt
      </Link>

      <Card>
        <CardHeader>
          <div className="flex items-center gap-2">
            <CardTitle>Şikayət</CardTitle>
            <StatusBadge status={report.status} />
          </div>
        </CardHeader>
        <CardContent className="space-y-4">
          <dl className="grid grid-cols-2 gap-4 text-sm">
            <div>
              <dt className="text-muted-foreground">Şikayət edən</dt>
              <dd>
                <Link href={`/users/${report.reporterId}`} className="font-medium hover:underline">
                  {report.reporterName}
                </Link>
              </dd>
            </div>
            <div>
              <dt className="text-muted-foreground">Şikayət olunan</dt>
              <dd>
                <Link href={`/users/${report.reportedUserId}`} className="font-medium hover:underline">
                  {report.reportedUserName}
                </Link>
              </dd>
            </div>
            <div className="col-span-2">
              <dt className="text-muted-foreground">Səbəb</dt>
              <dd className="font-medium">{report.reason}</dd>
            </div>
            <div>
              <dt className="text-muted-foreground">Tarix</dt>
              <dd className="font-medium">{formatDate(report.createdAt)}</dd>
            </div>
            {report.chatId && (
              <div>
                <dt className="text-muted-foreground">Söhbət ID</dt>
                <dd className="font-mono text-xs">{report.chatId}</dd>
              </div>
            )}
          </dl>
        </CardContent>
      </Card>

      <Card>
        <CardHeader>
          <CardTitle className="text-base">Şikayət statusu</CardTitle>
        </CardHeader>
        <CardContent>
          <ReportStatusActions id={report.id} status={report.status} />
        </CardContent>
      </Card>

      <UserPostsPanel uid={report.reportedUserId} posts={reportedUserPosts} />
    </div>
  );
}
