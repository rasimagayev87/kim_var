import Link from "next/link";

import { Avatar, AvatarFallback, AvatarImage } from "@/components/ui/avatar";
import { StatusBadge } from "@/components/moderation/status-badge";
import { Table, TableBody, TableCell, TableHead, TableHeader, TableRow } from "@/components/ui/table";
import type { AdminVenueRow } from "@/lib/data/venues";
import { VENUE_CATEGORY_LABELS } from "@/lib/data/venues";

function formatDate(iso: string | null): string {
  if (!iso) return "—";
  return new Date(iso).toLocaleDateString("az-AZ", { year: "numeric", month: "short", day: "numeric" });
}

export function VenuesTable({ venues }: { venues: AdminVenueRow[] }) {
  if (venues.length === 0) {
    return (
      <div className="flex h-40 items-center justify-center rounded-lg border border-dashed text-sm text-muted-foreground">
        Bu filtrlərə uyğun məkan tapılmadı.
      </div>
    );
  }

  return (
    <div className="rounded-lg border">
      <Table>
        <TableHeader>
          <TableRow>
            <TableHead>Məkan</TableHead>
            <TableHead>Kateqoriya</TableHead>
            <TableHead>Sahib</TableHead>
            <TableHead>Tarix</TableHead>
            <TableHead>Status</TableHead>
          </TableRow>
        </TableHeader>
        <TableBody>
          {venues.map((venue) => (
            <TableRow key={venue.id} className="cursor-pointer">
              <TableCell>
                <Link href={`/venues/${venue.id}`} className="flex items-center gap-3 hover:underline">
                  <Avatar className="size-9 rounded-md">
                    <AvatarImage src={venue.photoUrl ?? undefined} alt={venue.name} className="object-cover" />
                    <AvatarFallback className="rounded-md">{venue.name.charAt(0).toUpperCase() || "?"}</AvatarFallback>
                  </Avatar>
                  <span className="font-medium">{venue.name}</span>
                </Link>
              </TableCell>
              <TableCell className="text-sm text-muted-foreground">
                {VENUE_CATEGORY_LABELS[venue.category] ?? venue.category}
              </TableCell>
              <TableCell>
                <Link href={`/users/${venue.ownerId}`} className="text-sm hover:underline">
                  {venue.ownerName}
                  {venue.ownerUsername ? <span className="text-muted-foreground"> · @{venue.ownerUsername}</span> : null}
                </Link>
              </TableCell>
              <TableCell className="text-sm text-muted-foreground">{formatDate(venue.createdAt)}</TableCell>
              <TableCell>
                <StatusBadge status={venue.status} />
              </TableCell>
            </TableRow>
          ))}
        </TableBody>
      </Table>
    </div>
  );
}
