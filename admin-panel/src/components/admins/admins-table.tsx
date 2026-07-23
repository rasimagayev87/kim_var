import { Badge } from "@/components/ui/badge";
import { Table, TableBody, TableCell, TableHead, TableHeader, TableRow } from "@/components/ui/table";
import type { AdminRosterRow } from "@/lib/data/admins";
import { AdminRowActions } from "./admin-row-actions";

function formatDate(iso: string | null): string {
  if (!iso) return "—";
  return new Date(iso).toLocaleDateString("az-AZ", { year: "numeric", month: "short", day: "numeric" });
}

export function AdminsTable({ admins, currentUid }: { admins: AdminRosterRow[]; currentUid: string }) {
  if (admins.length === 0) {
    return (
      <div className="flex h-40 items-center justify-center rounded-lg border border-dashed text-sm text-muted-foreground">
        Heç bir admin/moderator yoxdur.
      </div>
    );
  }

  return (
    <div className="rounded-lg border">
      <Table>
        <TableHeader>
          <TableRow>
            <TableHead>Email</TableHead>
            <TableHead>Rol</TableHead>
            <TableHead>Əlavə edilmə tarixi</TableHead>
            <TableHead className="w-10" />
          </TableRow>
        </TableHeader>
        <TableBody>
          {admins.map((admin) => (
            <TableRow key={admin.uid}>
              <TableCell className="text-sm">
                {admin.email}
                {admin.uid === currentUid && (
                  <span className="ml-2 text-xs text-muted-foreground">(siz)</span>
                )}
              </TableCell>
              <TableCell>
                <Badge variant={admin.role === "admin" ? "default" : "secondary"} className="capitalize">
                  {admin.role}
                </Badge>
              </TableCell>
              <TableCell className="text-sm text-muted-foreground">{formatDate(admin.addedAt)}</TableCell>
              <TableCell>{admin.uid !== currentUid && <AdminRowActions admin={admin} />}</TableCell>
            </TableRow>
          ))}
        </TableBody>
      </Table>
    </div>
  );
}
