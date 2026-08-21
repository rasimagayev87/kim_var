import Image from "next/image";
import Link from "next/link";
import { notFound, redirect } from "next/navigation";
import { ArrowLeft } from "lucide-react";

import { Avatar, AvatarFallback, AvatarImage } from "@/components/ui/avatar";
import { Card, CardContent, CardHeader, CardTitle } from "@/components/ui/card";
import { StatusBadge } from "@/components/moderation/status-badge";
import { PinBoxStatusActions } from "@/components/pinboxes/pinbox-status-actions";
import { hasPermission } from "@/lib/auth/permissions";
import { getCurrentAdmin } from "@/lib/auth/server";
import { getPinBoxDetail } from "@/lib/data/pinboxes";

function formatDate(iso: string | null): string {
  if (!iso) return "Naməlum";
  return new Date(iso).toLocaleDateString("az-AZ", { year: "numeric", month: "long", day: "numeric" });
}

function formatTime(iso: string | null): string {
  if (!iso) return "—";
  return new Date(iso).toLocaleTimeString("az-AZ", { hour: "2-digit", minute: "2-digit" });
}

function formatPrice(amount: number): string {
  return `${amount.toLocaleString("az-AZ", { minimumFractionDigits: 2, maximumFractionDigits: 2 })} AZN`;
}

export default async function PinBoxDetailPage({ params }: { params: Promise<{ id: string }> }) {
  const admin = await getCurrentAdmin();
  if (!admin || !hasPermission(admin.role, "moderateOffers")) {
    redirect("/dashboard");
  }

  const { id } = await params;
  const pinbox = await getPinBoxDetail(id);
  if (!pinbox) notFound();

  return (
    <div className="mx-auto max-w-2xl space-y-6">
      <Link href="/pinboxes" className="inline-flex items-center gap-1.5 text-sm text-muted-foreground hover:text-foreground">
        <ArrowLeft className="size-4" />
        PinBox-lara qayıt
      </Link>

      <Card>
        <CardHeader>
          <div className="flex items-center gap-4">
            <Avatar className="size-16 rounded-lg">
              <AvatarImage src={pinbox.imageUrl ?? undefined} alt={pinbox.title} className="object-cover" />
              <AvatarFallback className="rounded-lg text-lg">{pinbox.title.charAt(0).toUpperCase()}</AvatarFallback>
            </Avatar>
            <div>
              <CardTitle className="text-xl">{pinbox.title}</CardTitle>
              <Link href={`/venues/${pinbox.venueId}`} className="text-sm text-muted-foreground hover:underline">
                {pinbox.venueName}
              </Link>
              <div className="mt-2">
                <StatusBadge status={pinbox.status} />
              </div>
            </div>
          </div>
        </CardHeader>
        <CardContent className="space-y-4">
          {pinbox.reviewNote && (
            <p className="rounded-lg border bg-muted/50 p-3 text-sm">
              <span className="font-medium">Qeyd: </span>
              {pinbox.reviewNote}
            </p>
          )}

          {pinbox.imageUrl && (
            <div className="relative aspect-video w-full overflow-hidden rounded-lg border bg-muted">
              <Image src={pinbox.imageUrl} alt={pinbox.title} fill className="object-cover" unoptimized />
            </div>
          )}

          <div>
            <p className="text-sm text-muted-foreground">Təsvir</p>
            <p className="mt-1 whitespace-pre-wrap text-sm">{pinbox.description || "—"}</p>
          </div>

          <dl className="grid grid-cols-2 gap-4 text-sm">
            <div>
              <dt className="text-muted-foreground">Sahib</dt>
              <dd>
                <Link href={`/users/${pinbox.ownerId}`} className="font-medium hover:underline">
                  {pinbox.ownerName}
                </Link>
              </dd>
            </div>
            <div>
              <dt className="text-muted-foreground">Ünvan</dt>
              <dd className="font-medium">{pinbox.address ?? "—"}</dd>
            </div>
            <div>
              <dt className="text-muted-foreground">Yaradılma tarixi</dt>
              <dd className="font-medium">{formatDate(pinbox.createdAt)}</dd>
            </div>
            <div>
              <dt className="text-muted-foreground">Qiymət</dt>
              <dd className="font-medium">
                {formatPrice(pinbox.pinboxPrice)}{" "}
                <span className="text-muted-foreground line-through">{formatPrice(pinbox.originalPrice)}</span>
              </dd>
            </div>
            <div>
              <dt className="text-muted-foreground">Stok</dt>
              <dd className="font-medium">
                {pinbox.stockRemaining}/{pinbox.stockTotal}
              </dd>
            </div>
            <div>
              <dt className="text-muted-foreground">Təhvil pəncərəsi</dt>
              <dd className="font-medium">
                {formatTime(pinbox.pickupWindowStart)} - {formatTime(pinbox.pickupWindowEnd)}
              </dd>
            </div>
            <div>
              <dt className="text-muted-foreground">PinBox ID</dt>
              <dd className="font-mono text-xs">{pinbox.id}</dd>
            </div>
          </dl>
        </CardContent>
      </Card>

      <Card>
        <CardHeader>
          <CardTitle className="text-base">Moderasiya</CardTitle>
        </CardHeader>
        <CardContent>
          <PinBoxStatusActions id={pinbox.id} status={pinbox.status} />
        </CardContent>
      </Card>
    </div>
  );
}
