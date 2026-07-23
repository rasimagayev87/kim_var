import Link from "next/link";

import { Avatar, AvatarFallback, AvatarImage } from "@/components/ui/avatar";
import { StatusBadge } from "@/components/moderation/status-badge";
import { Table, TableBody, TableCell, TableHead, TableHeader, TableRow } from "@/components/ui/table";
import type { AdminOfferRow } from "@/lib/data/offers";

function formatDate(iso: string | null): string {
  if (!iso) return "—";
  return new Date(iso).toLocaleDateString("az-AZ", { year: "numeric", month: "short", day: "numeric" });
}

export function OffersTable({ offers }: { offers: AdminOfferRow[] }) {
  if (offers.length === 0) {
    return (
      <div className="flex h-40 items-center justify-center rounded-lg border border-dashed text-sm text-muted-foreground">
        Bu filtrlərə uyğun təklif tapılmadı.
      </div>
    );
  }

  return (
    <div className="rounded-lg border">
      <Table>
        <TableHeader>
          <TableRow>
            <TableHead>Təklif</TableHead>
            <TableHead>Məkan</TableHead>
            <TableHead>Bitmə tarixi</TableHead>
            <TableHead>Status</TableHead>
          </TableRow>
        </TableHeader>
        <TableBody>
          {offers.map((offer) => (
            <TableRow key={offer.id}>
              <TableCell>
                <Link href={`/offers/${offer.id}`} className="font-medium hover:underline">
                  {offer.title}
                </Link>
              </TableCell>
              <TableCell>
                <Link href={`/venues/${offer.venueId}`} className="flex items-center gap-2 text-sm hover:underline">
                  <Avatar className="size-7 rounded-md">
                    <AvatarImage src={offer.venuePhotoUrl ?? undefined} alt={offer.venueName} className="object-cover" />
                    <AvatarFallback className="rounded-md text-xs">
                      {offer.venueName.charAt(0).toUpperCase() || "?"}
                    </AvatarFallback>
                  </Avatar>
                  {offer.venueName}
                </Link>
              </TableCell>
              <TableCell className="text-sm text-muted-foreground">{formatDate(offer.endDate)}</TableCell>
              <TableCell>
                <StatusBadge status={offer.status} />
              </TableCell>
            </TableRow>
          ))}
        </TableBody>
      </Table>
    </div>
  );
}
