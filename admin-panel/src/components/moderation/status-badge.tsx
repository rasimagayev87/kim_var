import { Badge } from "@/components/ui/badge";

const STATUS_LABELS: Record<string, string> = {
  approved: "Aktiv",
  pending: "Gözləyən",
  needs_revision: "Düzəliş tələb olunur",
  rejected: "Rədd edilib",
  inactive: "Deaktiv",
  reviewed: "Nəzərdən keçirilib",
  actioned: "Əməliyyat edilib",
  dismissed: "Rədd edilib",
  completed: "Ödənilib",
  paid: "Ödənilib",
  revision_pending: "Düzəliş gözlənilir",
  refund_pending: "Geri qaytarılmalı",
  refunded: "Geri qaytarılıb",
  open: "Açıq",
  resolved: "Həll edilib",
  cancelled: "Ləğv edilib",
  upcoming: "Gələcək",
  live: "Canlı",
  ended: "Bitib",
};

const STATUS_VARIANTS: Record<string, "default" | "secondary" | "outline" | "destructive"> = {
  approved: "default",
  pending: "secondary",
  needs_revision: "outline",
  rejected: "destructive",
  inactive: "outline",
  reviewed: "secondary",
  actioned: "default",
  dismissed: "outline",
  completed: "default",
  paid: "default",
  revision_pending: "outline",
  refund_pending: "destructive",
  refunded: "secondary",
  open: "secondary",
  resolved: "default",
  cancelled: "destructive",
  upcoming: "secondary",
  live: "default",
  ended: "outline",
};

export function StatusBadge({ status }: { status: string }) {
  return <Badge variant={STATUS_VARIANTS[status] ?? "outline"}>{STATUS_LABELS[status] ?? status}</Badge>;
}
