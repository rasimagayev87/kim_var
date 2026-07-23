import Link from "next/link";
import { notFound, redirect } from "next/navigation";
import { ArrowLeft } from "lucide-react";

import { Avatar, AvatarFallback, AvatarImage } from "@/components/ui/avatar";
import { Card, CardContent, CardHeader, CardTitle } from "@/components/ui/card";
import { StatusBadge } from "@/components/moderation/status-badge";
import { VenueStatusActions } from "@/components/venues/venue-status-actions";
import { hasPermission } from "@/lib/auth/permissions";
import { getCurrentAdmin } from "@/lib/auth/server";
import { getVenueDetail, VENUE_CATEGORY_LABELS } from "@/lib/data/venues";

function formatDate(iso: string | null): string {
  if (!iso) return "Naməlum";
  return new Date(iso).toLocaleDateString("az-AZ", { year: "numeric", month: "long", day: "numeric" });
}

export default async function VenueDetailPage({ params }: { params: Promise<{ id: string }> }) {
  const admin = await getCurrentAdmin();
  if (!admin || !hasPermission(admin.role, "moderateVenues")) {
    redirect("/dashboard");
  }

  const { id } = await params;
  const venue = await getVenueDetail(id);
  if (!venue) notFound();

  return (
    <div className="mx-auto max-w-2xl space-y-6">
      <Link href="/venues" className="inline-flex items-center gap-1.5 text-sm text-muted-foreground hover:text-foreground">
        <ArrowLeft className="size-4" />
        Məkanlara qayıt
      </Link>

      <Card>
        <CardHeader>
          <div className="flex items-center gap-4">
            <Avatar className="size-16 rounded-lg">
              <AvatarImage src={venue.photoUrl ?? undefined} alt={venue.name} className="object-cover" />
              <AvatarFallback className="rounded-lg text-lg">{venue.name.charAt(0).toUpperCase()}</AvatarFallback>
            </Avatar>
            <div>
              <CardTitle className="text-xl">{venue.name}</CardTitle>
              <p className="text-sm text-muted-foreground">{VENUE_CATEGORY_LABELS[venue.category] ?? venue.category}</p>
              <div className="mt-2">
                <StatusBadge status={venue.status} />
              </div>
            </div>
          </div>
        </CardHeader>
        <CardContent className="space-y-4">
          <dl className="grid grid-cols-2 gap-4 text-sm">
            <div>
              <dt className="text-muted-foreground">Sahib</dt>
              <dd>
                <Link href={`/users/${venue.ownerId}`} className="font-medium hover:underline">
                  {venue.ownerName}
                  {venue.ownerUsername ? ` · @${venue.ownerUsername}` : ""}
                </Link>
              </dd>
            </div>
            <div>
              <dt className="text-muted-foreground">Yaradılma tarixi</dt>
              <dd className="font-medium">{formatDate(venue.createdAt)}</dd>
            </div>
            <div>
              <dt className="text-muted-foreground">Venue ID</dt>
              <dd className="font-mono text-xs">{venue.id}</dd>
            </div>
          </dl>
        </CardContent>
      </Card>

      <Card>
        <CardHeader>
          <CardTitle className="text-base">Moderasiya</CardTitle>
        </CardHeader>
        <CardContent>
          <VenueStatusActions id={venue.id} status={venue.status} />
        </CardContent>
      </Card>
    </div>
  );
}
