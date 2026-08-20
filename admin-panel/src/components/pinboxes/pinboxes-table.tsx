import Link from "next/link";

import { Avatar, AvatarFallback, AvatarImage } from "@/components/ui/avatar";
import { StatusBadge } from "@/components/moderation/status-badge";
import { Table, TableBody, TableCell, TableHead, TableHeader, TableRow } from "@/components/ui/table";
import type { AdminPinBoxRow } from "@/lib/data/pinboxes";

function formatDate(iso: string | null): string {
  if (!iso) return "—";
  return new Date(iso).toLocaleDateString("az-AZ", { year: "numeric", month: "short", day: "numeric" });
}

function formatPrice(amount: number): string {
  return `${amount.toLocaleString("az-AZ", { minimumFractionDigits: 2, maximumFractionDigits: 2 })} AZN`;
}

export function PinBoxesTable({ pinboxes }: { pinboxes: AdminPinBoxRow[] }) {
  if (pinboxes.length === 0) {
    return (
      <div className="flex h-40 items-center justify-center rounded-lg border border-dashed text-sm text-muted-foreground">
        Bu filtrlərə uyğun PinBox tapılmadı.
      </div>
    );
  }

  return (
    <div className="rounded-lg border">
      <Table>
        <TableHeader>
          <TableRow>
            <TableHead>Qutu</TableHead>
            <TableHead>Məkan</TableHead>
            <TableHead>Qiymət</TableHead>
            <TableHead>Stok</TableHead>
            <TableHead>Yaradılma tarixi</TableHead>
            <TableHead>Status</TableHead>
          </TableRow>
        </TableHeader>
        <TableBody>
          {pinboxes.map((pinbox) => (
            <TableRow key={pinbox.id}>
              <TableCell>
                <Link href={`/pinboxes/${pinbox.id}`} className="font-medium hover:underline">
                  {pinbox.title}
                </Link>
              </TableCell>
              <TableCell>
                <Link href={`/venues/${pinbox.venueId}`} className="flex items-center gap-2 text-sm hover:underline">
                  <Avatar className="size-7 rounded-md">
                    <AvatarImage src={pinbox.venuePhotoUrl ?? undefined} alt={pinbox.venueName} className="object-cover" />
                    <AvatarFallback className="rounded-md text-xs">
                      {pinbox.venueName.charAt(0).toUpperCase() || "?"}
                    </AvatarFallback>
                  </Avatar>
                  {pinbox.venueName}
                </Link>
              </TableCell>
              <TableCell className="text-sm">{formatPrice(pinbox.pinboxPrice)}</TableCell>
              <TableCell className="text-sm text-muted-foreground">
                {pinbox.stockRemaining}/{pinbox.stockTotal}
              </TableCell>
              <TableCell className="text-sm text-muted-foreground">{formatDate(pinbox.createdAt)}</TableCell>
              <TableCell>
                <StatusBadge status={pinbox.status} />
              </TableCell>
            </TableRow>
          ))}
        </TableBody>
      </Table>
    </div>
  );
}
