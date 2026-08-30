import { Badge } from "@/components/ui/badge";
import { Table, TableBody, TableCell, TableHead, TableHeader, TableRow } from "@/components/ui/table";
import type { ModerationLogRow } from "@/lib/data/moderation-logs";

const ACTION_LABELS: Record<string, string> = {
  "venue.approved": "Məkan təsdiqləndi",
  "venue.rejected": "Məkan rədd edildi",
  "venue.activated": "Məkan aktiv edildi",
  "venue.deactivated": "Məkan deaktiv edildi",
  "venue.premiumGranted": "Məkan premium edildi",
  "venue.premiumRevoked": "Məkanın premiumu ləğv edildi",
  "venue.needsRevision": "Məkan düzəlişə göndərildi",
  "payment.refunded": "Ödəniş geri qaytarıldı kimi işarələndi",
  "payment.refund_initiated": "Ödəniş üçün geri qaytarma başladıldı",
  "pinboxPayout.paid": "PinBox öhdəliyi ödənilmiş kimi işarələndi",
  "offer.approved": "Təklif təsdiqləndi",
  "offer.needsRevision": "Təklif düzəlişə göndərildi",
  "offer.rejected": "Təklif rədd edildi",
  "offer.activated": "Təklif aktiv edildi",
  "offer.deactivated": "Təklif deaktiv edildi",
  "pinbox.approved": "PinBox təsdiqləndi",
  "pinbox.needsRevision": "PinBox düzəlişə göndərildi",
  "pinbox.rejected": "PinBox rədd edildi",
  "user.banned": "İstifadəçi ban edildi",
  "user.unbanned": "Ban aradan qaldırıldı",
  "user.warned": "İstifadəçiyə xəbərdarlıq göndərildi",
  "user.verified": "İstifadəçi verified edildi",
  "user.unverified": "Verified ləğv edildi",
  "user.vipGranted": "VIP verildi",
  "user.vipRevoked": "VIP ləğv edildi",
  "user.deleted": "Hesab tam silindi",
  "post.deleted": "Post silindi",
  "comment.deleted": "Şərh silindi",
  "report.statusChanged": "Şikayət statusu dəyişdi",
  "broadcast.sent": "Bildiriş göndərildi",
  "admin.added": "Admin/moderator əlavə edildi",
  "admin.roleChanged": "Rol dəyişdirildi",
  "admin.removed": "Admin/moderator silindi",
  "identityVerification.approved": "Kimlik doğrulaması təsdiqləndi",
  "identityVerification.rejected": "Kimlik doğrulaması rədd edildi",
};

const TARGET_TYPE_LABELS: Record<string, string> = {
  user: "İstifadəçi",
  venue: "Məkan",
  offer: "Təklif",
  pinbox: "PinBox",
  post: "Post",
  comment: "Şərh",
  report: "Şikayət",
  broadcast: "Bildiriş",
  admin: "Admin/moderator",
  payment: "Ödəniş",
  venuePayout: "PinBox ödənişi",
  identityVerification: "Kimlik doğrulaması",
};

function formatDate(iso: string): string {
  return new Date(iso).toLocaleString("az-AZ", { year: "numeric", month: "short", day: "numeric", hour: "2-digit", minute: "2-digit" });
}

export function LogsTable({ logs }: { logs: ModerationLogRow[] }) {
  if (logs.length === 0) {
    return (
      <div className="flex h-40 items-center justify-center rounded-lg border border-dashed text-sm text-muted-foreground">
        Hələ heç bir moderasiya əməliyyatı qeydə alınmayıb.
      </div>
    );
  }

  return (
    <div className="rounded-lg border">
      <Table>
        <TableHeader>
          <TableRow>
            <TableHead>Kim</TableHead>
            <TableHead>Nə etdi</TableHead>
            <TableHead>Hədəf</TableHead>
            <TableHead>Tarix</TableHead>
          </TableRow>
        </TableHeader>
        <TableBody>
          {logs.map((log) => (
            <TableRow key={log.id}>
              <TableCell>
                <div className="flex items-center gap-2">
                  <span className="text-sm font-medium">{log.actorEmail}</span>
                  <Badge variant={log.actorRole === "admin" ? "default" : "secondary"} className="capitalize">
                    {log.actorRole}
                  </Badge>
                </div>
              </TableCell>
              <TableCell className="text-sm">{ACTION_LABELS[log.action] ?? log.action}</TableCell>
              <TableCell className="text-sm text-muted-foreground">
                {TARGET_TYPE_LABELS[log.targetType] ?? log.targetType}
                {log.note ? <span className="ml-1">({log.note})</span> : null}
              </TableCell>
              <TableCell className="text-sm text-muted-foreground">{formatDate(log.createdAt)}</TableCell>
            </TableRow>
          ))}
        </TableBody>
      </Table>
    </div>
  );
}
