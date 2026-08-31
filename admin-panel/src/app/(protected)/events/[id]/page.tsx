import { notFound, redirect } from "next/navigation";
import Link from "next/link";

import { Avatar, AvatarFallback, AvatarImage } from "@/components/ui/avatar";
import { Card, CardContent, CardHeader, CardTitle } from "@/components/ui/card";
import { EventStatusActions } from "@/components/events/event-status-actions";
import { EventUrgencyBadge } from "@/components/events/event-urgency-badge";
import { hasPermission } from "@/lib/auth/permissions";
import { getCurrentAdmin } from "@/lib/auth/server";
import { getEventDetail } from "@/lib/data/events";
import { VENUE_CATEGORY_LABELS } from "@/lib/data/venues";

function formatDateTime(iso: string | null): string {
  if (!iso) return "Naməlum";
  return new Date(iso).toLocaleString("az-AZ", {
    year: "numeric", month: "long", day: "numeric", hour: "2-digit", minute: "2-digit",
  });
}

export default async function EventDetailPage({ params }: { params: Promise<{ id: string }> }) {
  const admin = await getCurrentAdmin();
  if (!admin || !hasPermission(admin.role, "viewEvents")) {
    redirect("/dashboard");
  }

  const { id } = await params;
  const event = await getEventDetail(id);
  if (!event) notFound();

  const canModerate = hasPermission(admin.role, "moderateEvents");

  return (
    <div className="space-y-6">
      <Card>
        <CardHeader>
          <div className="flex items-start gap-4">
            {event.coverImageUrl && (
              // eslint-disable-next-line @next/next/no-img-element
              <img
                src={event.coverImageUrl}
                alt={event.title}
                className="size-24 rounded-lg object-cover"
              />
            )}
            <div className="min-w-0 flex-1">
              <CardTitle className="text-xl">{event.title}</CardTitle>
              <div className="mt-1 flex flex-wrap items-center gap-2 text-sm text-muted-foreground">
                <Link href={`/venues/${event.venueId}`} className="flex items-center gap-2 hover:underline">
                  <Avatar className="size-6 rounded-md">
                    <AvatarImage src={event.venuePhotoUrl ?? undefined} alt={event.venueName} className="object-cover" />
                    <AvatarFallback className="rounded-md text-[10px]">
                      {event.venueName.charAt(0).toUpperCase() || "?"}
                    </AvatarFallback>
                  </Avatar>
                  {event.venueName}
                </Link>
                <span>·</span>
                <span>{VENUE_CATEGORY_LABELS[event.venueCategory] ?? event.venueCategory}</span>
              </div>
              <div className="mt-2">
                <EventUrgencyBadge status={event.status} startAt={event.startAt} />
              </div>
            </div>
          </div>
        </CardHeader>
        <CardContent className="space-y-4">
          <p className="whitespace-pre-wrap text-sm">{event.description}</p>

          <dl className="grid gap-3 text-sm sm:grid-cols-2">
            <div>
              <dt className="text-muted-foreground">Başlama</dt>
              <dd className="font-medium">{formatDateTime(event.startAt)}</dd>
            </div>
            <div>
              <dt className="text-muted-foreground">Bitmə</dt>
              <dd className="font-medium">{formatDateTime(event.endAt)}</dd>
            </div>
            <div>
              <dt className="text-muted-foreground">Yaradılıb</dt>
              <dd className="font-medium">{formatDateTime(event.createdAt)}</dd>
            </div>
            <div>
              {/* The trust counter, spelled out: this is why the event
                  is in review at all, and how close the venue is to
                  publishing without one. */}
              <dt className="text-muted-foreground">Məkanın yayımlanmış tədbiri</dt>
              <dd className="font-medium">
                {event.venuePublishedEventCount}/3
                {event.venuePublishedEventCount >= 3 && " — artıq baxışsız yayımlayır"}
              </dd>
            </div>
          </dl>

          {event.reviewNote && (
            <div className="rounded-lg border border-amber-200 bg-amber-50 p-3 text-sm">
              <span className="font-medium">Qeyd: </span>
              {event.reviewNote}
            </div>
          )}

          {canModerate && <EventStatusActions id={event.id} venueId={event.venueId} status={event.status} />}
        </CardContent>
      </Card>
    </div>
  );
}
