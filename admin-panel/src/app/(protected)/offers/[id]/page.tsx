import Image from "next/image";
import Link from "next/link";
import { notFound, redirect } from "next/navigation";
import { ArrowLeft } from "lucide-react";

import { Avatar, AvatarFallback, AvatarImage } from "@/components/ui/avatar";
import { Card, CardContent, CardHeader, CardTitle } from "@/components/ui/card";
import { StatusBadge } from "@/components/moderation/status-badge";
import { OfferStatusActions } from "@/components/offers/offer-status-actions";
import { hasPermission } from "@/lib/auth/permissions";
import { getCurrentAdmin } from "@/lib/auth/server";
import { getOfferDetail, OFFER_TYPE_LABELS } from "@/lib/data/offers";
import { VENUE_CATEGORY_LABELS } from "@/lib/data/venues";

function formatDate(iso: string | null): string {
  if (!iso) return "Naməlum";
  return new Date(iso).toLocaleDateString("az-AZ", { year: "numeric", month: "long", day: "numeric" });
}

function daysUntil(iso: string | null): number | null {
  if (!iso) return null;
  return Math.max(0, Math.ceil((new Date(iso).getTime() - Date.now()) / (24 * 60 * 60 * 1000)));
}

function formatDiscountValue(offerType: string, discountValue: number | null): string | null {
  if (discountValue == null) return null;
  return offerType === "fixedPrice" ? `${discountValue} AZN` : `${discountValue}%`;
}

const DAY_LABELS: Record<string, string> = {
  mon: "B.e",
  tue: "Ç.a",
  wed: "Ç",
  thu: "C.a",
  fri: "C",
  sat: "Ş",
  sun: "B",
};

export default async function OfferDetailPage({ params }: { params: Promise<{ id: string }> }) {
  const admin = await getCurrentAdmin();
  if (!admin || !hasPermission(admin.role, "viewOffers")) {
    redirect("/dashboard");
  }

  const { id } = await params;
  const offer = await getOfferDetail(id);
  if (!offer) notFound();

  const discountLabel = formatDiscountValue(offer.offerType, offer.discountValue);

  return (
    <div className="mx-auto max-w-2xl space-y-6">
      <Link href="/offers" className="inline-flex items-center gap-1.5 text-sm text-muted-foreground hover:text-foreground">
        <ArrowLeft className="size-4" />
        Təkliflərə qayıt
      </Link>

      <Card>
        <CardHeader>
          <div className="flex items-start gap-4">
            <Avatar className="size-16 rounded-lg">
              <AvatarImage src={offer.imageUrl ?? undefined} alt={offer.title} className="object-cover" />
              <AvatarFallback className="rounded-lg text-lg">{offer.title.charAt(0).toUpperCase()}</AvatarFallback>
            </Avatar>
            <div>
              <CardTitle className="text-xl">{offer.title}</CardTitle>
              <div className="mt-1 flex items-center gap-2 text-sm text-muted-foreground">
                <Avatar className="size-4 rounded">
                  <AvatarImage src={offer.venuePhotoUrl ?? undefined} alt={offer.venueName} className="object-cover" />
                  <AvatarFallback className="rounded text-[8px]">{offer.venueName.charAt(0).toUpperCase()}</AvatarFallback>
                </Avatar>
                <Link href={`/venues/${offer.venueId}`} className="hover:underline">
                  {offer.venueName}
                </Link>
                <span>·</span>
                <span>{VENUE_CATEGORY_LABELS[offer.category] ?? offer.category}</span>
              </div>
              <div className="mt-2 flex flex-wrap items-center gap-2">
                <StatusBadge status={offer.status} />
                <span className="rounded-full border px-2.5 py-0.5 text-xs font-medium">
                  {OFFER_TYPE_LABELS[offer.offerType]}
                  {discountLabel ? ` · ${discountLabel}` : ""}
                </span>
              </div>
            </div>
          </div>
        </CardHeader>
        <CardContent className="space-y-4">
          {offer.reviewNote && (
            <p className="rounded-lg border bg-muted/50 p-3 text-sm">
              <span className="font-medium">Qeyd: </span>
              {offer.reviewNote}
            </p>
          )}

          {offer.imageUrl && (
            <div className="relative aspect-video w-full overflow-hidden rounded-lg border bg-muted">
              <Image src={offer.imageUrl} alt={offer.title} fill className="object-cover" unoptimized />
            </div>
          )}

          <div>
            <p className="text-sm text-muted-foreground">Təsvir</p>
            <p className="mt-1 whitespace-pre-wrap text-sm">{offer.description || "—"}</p>
          </div>

          {offer.terms && (
            <div>
              <p className="text-sm text-muted-foreground">Şərtlər</p>
              <p className="mt-1 whitespace-pre-wrap text-sm">{offer.terms}</p>
            </div>
          )}

          {offer.offerType === "happyHour" && (
            <div>
              <p className="text-sm text-muted-foreground">Happy Hour vaxtı</p>
              <p className="mt-1 text-sm">
                {offer.activeHoursStart && offer.activeHoursEnd ? `${offer.activeHoursStart} - ${offer.activeHoursEnd}` : "—"}
                {offer.activeDays.length > 0 && (
                  <span className="text-muted-foreground"> · {offer.activeDays.map((d) => DAY_LABELS[d] ?? d).join(", ")}</span>
                )}
              </p>
            </div>
          )}

          {offer.offerType === "birthday" && offer.personalMessage && (
            <div>
              <p className="text-sm text-muted-foreground">Şəxsi mesaj</p>
              <p className="mt-1 whitespace-pre-wrap text-sm">{offer.personalMessage}</p>
            </div>
          )}

          <dl className="grid grid-cols-2 gap-4 text-sm">
            <div>
              <dt className="text-muted-foreground">Sahib</dt>
              <dd>
                <Link href={`/users/${offer.ownerId}`} className="font-medium hover:underline">
                  {offer.ownerName}
                </Link>
              </dd>
            </div>
            <div>
              <dt className="text-muted-foreground">Ünvan</dt>
              <dd className="font-medium">{offer.address ?? "—"}</dd>
            </div>
            <div>
              <dt className="text-muted-foreground">Yaradılma tarixi</dt>
              <dd className="font-medium">{formatDate(offer.createdAt)}</dd>
            </div>
            <div>
              <dt className="text-muted-foreground">Başlama tarixi</dt>
              <dd className="font-medium">{formatDate(offer.startDate)}</dd>
            </div>
            <div>
              <dt className="text-muted-foreground">Bitmə tarixi</dt>
              <dd className="font-medium">{formatDate(offer.endDate)}</dd>
            </div>
            <div>
              <dt className="text-muted-foreground">Offer ID</dt>
              <dd className="font-mono text-xs">{offer.id}</dd>
            </div>
          </dl>
        </CardContent>
      </Card>

      {/* Moderation panel — `moderateOffers`. A read-only role (`finance`,
          `support`, `analyst` here) opens this page to read the
          listing, so the whole card is omitted rather than shown
          with dead buttons; `set*Status` re-checks server-side. */}
      {hasPermission(admin.role, "moderateOffers") && (
        <Card>
        <CardHeader>
          <CardTitle className="text-base">Moderasiya</CardTitle>
        </CardHeader>
        <CardContent>
          <OfferStatusActions
            id={offer.id}
            status={offer.status}
            revisionDeadlineDaysLeft={daysUntil(offer.revisionDeadline)}
          />
        </CardContent>
      </Card>
      )}
    </div>
  );
}
