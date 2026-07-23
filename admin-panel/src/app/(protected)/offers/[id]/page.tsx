import Link from "next/link";
import { notFound, redirect } from "next/navigation";
import { ArrowLeft } from "lucide-react";

import { Avatar, AvatarFallback, AvatarImage } from "@/components/ui/avatar";
import { Card, CardContent, CardHeader, CardTitle } from "@/components/ui/card";
import { StatusBadge } from "@/components/moderation/status-badge";
import { OfferStatusActions } from "@/components/offers/offer-status-actions";
import { hasPermission } from "@/lib/auth/permissions";
import { getCurrentAdmin } from "@/lib/auth/server";
import { getOfferDetail } from "@/lib/data/offers";

function formatDate(iso: string | null): string {
  if (!iso) return "Naməlum";
  return new Date(iso).toLocaleDateString("az-AZ", { year: "numeric", month: "long", day: "numeric" });
}

export default async function OfferDetailPage({ params }: { params: Promise<{ id: string }> }) {
  const admin = await getCurrentAdmin();
  if (!admin || !hasPermission(admin.role, "moderateOffers")) {
    redirect("/dashboard");
  }

  const { id } = await params;
  const offer = await getOfferDetail(id);
  if (!offer) notFound();

  return (
    <div className="mx-auto max-w-2xl space-y-6">
      <Link href="/offers" className="inline-flex items-center gap-1.5 text-sm text-muted-foreground hover:text-foreground">
        <ArrowLeft className="size-4" />
        Təkliflərə qayıt
      </Link>

      <Card>
        <CardHeader>
          <div className="flex items-center gap-4">
            <Avatar className="size-16 rounded-lg">
              <AvatarImage src={offer.venuePhotoUrl ?? undefined} alt={offer.venueName} className="object-cover" />
              <AvatarFallback className="rounded-lg text-lg">{offer.title.charAt(0).toUpperCase()}</AvatarFallback>
            </Avatar>
            <div>
              <CardTitle className="text-xl">{offer.title}</CardTitle>
              <Link href={`/venues/${offer.venueId}`} className="text-sm text-muted-foreground hover:underline">
                {offer.venueName}
              </Link>
              <div className="mt-2">
                <StatusBadge status={offer.status} />
              </div>
            </div>
          </div>
        </CardHeader>
        <CardContent className="space-y-4">
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

      <Card>
        <CardHeader>
          <CardTitle className="text-base">Moderasiya</CardTitle>
        </CardHeader>
        <CardContent>
          <OfferStatusActions id={offer.id} status={offer.status} />
        </CardContent>
      </Card>
    </div>
  );
}
