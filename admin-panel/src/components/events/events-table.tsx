import Link from "next/link";

import { Avatar, AvatarFallback, AvatarImage } from "@/components/ui/avatar";
import { EventUrgencyBadge } from "@/components/events/event-urgency-badge";
import { Table, TableBody, TableCell, TableHead, TableHeader, TableRow } from "@/components/ui/table";
import type { AdminEventRow, EventStatus } from "@/lib/data/events";

const STATUS_LABELS: Record<EventStatus, { label: string; tone: string }> = {
  pending: { label: "Baxış gözləyir", tone: "bg-amber-100 text-amber-800" },
  upcoming: { label: "Yayımlanıb", tone: "bg-emerald-100 text-emerald-800" },
  live: { label: "Canlı", tone: "bg-blue-100 text-blue-800" },
  ended: { label: "Bitib", tone: "bg-muted text-muted-foreground" },
  cancelled: { label: "Ləğv edilib", tone: "bg-muted text-muted-foreground" },
  rejected: { label: "Rədd edilib", tone: "bg-red-100 text-red-700" },
};

function formatDateTime(iso: string | null): string {
  if (!iso) return "—";
  return new Date(iso).toLocaleString("az-AZ", {
    month: "short", day: "numeric", hour: "2-digit", minute: "2-digit",
  });
}

export function EventsTable({ events }: { events: AdminEventRow[] }) {
  if (events.length === 0) {
    return (
      <div className="flex h-40 items-center justify-center rounded-lg border border-dashed text-sm text-muted-foreground">
        Bu filtrlərə uyğun tədbir tapılmadı.
      </div>
    );
  }

  return (
    <div className="rounded-lg border">
      <Table>
        <TableHeader>
          <TableRow>
            <TableHead>Tədbir</TableHead>
            <TableHead>Məkan</TableHead>
            <TableHead>Başlama</TableHead>
            <TableHead>Status</TableHead>
          </TableRow>
        </TableHeader>
        <TableBody>
          {events.map((event) => (
            <TableRow key={event.id}>
              <TableCell>
                <div className="flex flex-col">
                  <Link href={`/events/${event.id}`} className="font-medium hover:underline">
                    {event.title}
                  </Link>
                  {/* Only renders for pending events — see
                      `event-urgency.ts` for why this queue needs a
                      countdown at all. */}
                  <EventUrgencyBadge status={event.status} startAt={event.startAt} />
                </div>
              </TableCell>
              <TableCell>
                <Link href={`/venues/${event.venueId}`} className="flex items-center gap-2 text-sm hover:underline">
                  <Avatar className="size-7 rounded-md">
                    <AvatarImage src={event.venuePhotoUrl ?? undefined} alt={event.venueName} className="object-cover" />
                    <AvatarFallback className="rounded-md text-xs">
                      {event.venueName.charAt(0).toUpperCase() || "?"}
                    </AvatarFallback>
                  </Avatar>
                  <span className="flex flex-col">
                    {event.venueName}
                    {/* How far this venue is from earning its way out of
                        review — the number the threshold is measured
                        against, so "first event ever" and "third" are
                        distinguishable at a glance. */}
                    {event.status === "pending" && (
                      <span className="text-[11px] text-muted-foreground">
                        {event.venuePublishedEventCount}/3 yayımlanmış
                      </span>
                    )}
                  </span>
                </Link>
              </TableCell>
              <TableCell className="text-sm text-muted-foreground">{formatDateTime(event.startAt)}</TableCell>
              <TableCell>
                <span
                  className={`inline-flex items-center rounded-full px-2.5 py-0.5 text-xs font-medium ${STATUS_LABELS[event.status].tone}`}
                >
                  {STATUS_LABELS[event.status].label}
                </span>
              </TableCell>
            </TableRow>
          ))}
        </TableBody>
      </Table>
    </div>
  );
}
