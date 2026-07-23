import { Avatar, AvatarFallback, AvatarImage } from "@/components/ui/avatar";
import { Badge } from "@/components/ui/badge";
import { Table, TableBody, TableCell, TableHead, TableHeader, TableRow } from "@/components/ui/table";
import type { AdminUserRow } from "@/lib/data/users";
import { UserRowActions } from "./user-row-actions";

function formatDate(iso: string | null): string {
  if (!iso) return "—";
  return new Date(iso).toLocaleDateString("az-AZ", { year: "numeric", month: "short", day: "numeric" });
}

export function UsersTable({ users }: { users: AdminUserRow[] }) {
  if (users.length === 0) {
    return (
      <div className="flex h-40 items-center justify-center rounded-lg border border-dashed text-sm text-muted-foreground">
        Bu filtrlərə uyğun istifadəçi tapılmadı.
      </div>
    );
  }

  return (
    <div className="rounded-lg border">
      <Table>
        <TableHeader>
          <TableRow>
            <TableHead>İstifadəçi</TableHead>
            <TableHead>Telefon</TableHead>
            <TableHead>Qeydiyyat tarixi</TableHead>
            <TableHead>Statuslar</TableHead>
            <TableHead className="w-10" />
          </TableRow>
        </TableHeader>
        <TableBody>
          {users.map((user) => {
            const fullName = `${user.firstName} ${user.lastName}`.trim() || "—";
            return (
              <TableRow key={user.uid}>
                <TableCell>
                  <div className="flex items-center gap-3">
                    <Avatar className="size-9">
                      <AvatarImage src={user.photoUrl ?? undefined} alt={fullName} />
                      <AvatarFallback>{fullName.charAt(0).toUpperCase() || "?"}</AvatarFallback>
                    </Avatar>
                    <div>
                      <div className="font-medium">{fullName}</div>
                      <div className="text-xs text-muted-foreground">
                        {user.username ? `@${user.username}` : "username yoxdur"}
                      </div>
                    </div>
                  </div>
                </TableCell>
                <TableCell className="text-sm text-muted-foreground">{user.phoneNumber ?? "—"}</TableCell>
                <TableCell className="text-sm text-muted-foreground">{formatDate(user.createdAt)}</TableCell>
                <TableCell>
                  <div className="flex flex-wrap gap-1.5">
                    <Badge variant={user.isVerified ? "default" : "outline"}>
                      {user.isVerified ? "Verified" : "Unverified"}
                    </Badge>
                    {user.premium && <Badge variant="secondary">VIP</Badge>}
                    {user.banned && <Badge variant="destructive">Ban edilib</Badge>}
                  </div>
                </TableCell>
                <TableCell>
                  <UserRowActions user={user} />
                </TableCell>
              </TableRow>
            );
          })}
        </TableBody>
      </Table>
    </div>
  );
}
