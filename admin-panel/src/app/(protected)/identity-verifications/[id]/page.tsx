import Link from "next/link";
import { notFound, redirect } from "next/navigation";
import { ArrowLeft } from "lucide-react";

import { Card, CardContent, CardHeader, CardTitle } from "@/components/ui/card";
import { StatusBadge } from "@/components/moderation/status-badge";
import { IdentityVerificationImages } from "@/components/identity-verifications/identity-verification-images";
import { IdentityVerificationStatusActions } from "@/components/identity-verifications/identity-verification-status-actions";
import { hasPermission } from "@/lib/auth/permissions";
import { getCurrentAdmin } from "@/lib/auth/server";
import { getIdentityVerificationDetail } from "@/lib/data/identity-verifications";

function formatDate(iso: string | null): string {
  if (!iso) return "Naməlum";
  return new Date(iso).toLocaleDateString("az-AZ", { year: "numeric", month: "long", day: "numeric" });
}

export default async function IdentityVerificationDetailPage({ params }: { params: Promise<{ id: string }> }) {
  const admin = await getCurrentAdmin();
  if (!admin || !hasPermission(admin.role, "moderateIdentityVerifications")) {
    redirect("/dashboard");
  }

  const { id } = await params;
  const request = await getIdentityVerificationDetail(id);
  if (!request) notFound();

  return (
    <div className="mx-auto max-w-2xl space-y-6">
      <Link
        href="/identity-verifications"
        className="inline-flex items-center gap-1.5 text-sm text-muted-foreground hover:text-foreground"
      >
        <ArrowLeft className="size-4" />
        Müraciətlərə qayıt
      </Link>

      <Card>
        <CardHeader>
          <div>
            <Link href={`/users/${request.userId}`} className="text-xl font-semibold hover:underline">
              {request.userName}
            </Link>
            <p className="text-sm text-muted-foreground">
              {request.userUsername ? `@${request.userUsername}` : "username yoxdur"}
            </p>
            <div className="mt-2">
              <StatusBadge status={request.status} />
            </div>
          </div>
        </CardHeader>
        <CardContent className="space-y-4">
          {request.rejectionReason && (
            <p className="rounded-lg border bg-muted/50 p-3 text-sm">
              <span className="font-medium">Səbəb: </span>
              {request.rejectionReason}
            </p>
          )}
          <dl className="grid grid-cols-2 gap-4 text-sm">
            <div>
              <dt className="text-muted-foreground">Göndərilmə tarixi</dt>
              <dd className="font-medium">{formatDate(request.submittedAt)}</dd>
            </div>
            <div>
              <dt className="text-muted-foreground">Nəzərdən keçirilmə tarixi</dt>
              <dd className="font-medium">{formatDate(request.reviewedAt)}</dd>
            </div>
          </dl>
        </CardContent>
      </Card>

      <Card>
        <CardHeader>
          <CardTitle className="text-base">Sənədlər</CardTitle>
        </CardHeader>
        <CardContent>
          <IdentityVerificationImages
            idFrontUrl={request.idFrontUrl}
            idBackUrl={request.idBackUrl}
            selfieWithIdUrl={request.selfieWithIdUrl}
          />
        </CardContent>
      </Card>

      <Card>
        <CardHeader>
          <CardTitle className="text-base">Moderasiya</CardTitle>
        </CardHeader>
        <CardContent>
          <IdentityVerificationStatusActions id={request.id} status={request.status} />
        </CardContent>
      </Card>
    </div>
  );
}
