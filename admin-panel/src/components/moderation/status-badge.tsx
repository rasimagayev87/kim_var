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
  paid: "Ödənilmiş",
  failed: "Uğursuz",
  revision_pending: "Düzəliş gözlənilir",
  refund_pending: "Geri qaytarılmalı",
  refunded: "Geri qaytarılıb",
  open: "Açıq",
  resolved: "Həll edilib",
  cancelled: "Ləğv edilib",
  upcoming: "Gələcək",
  live: "Canlı",
  ended: "Bitib",
  active: "Aktiv",
  soldOut: "Satılıb",
  expired: "Vaxtı bitib",
  awaiting_payment: "Ödəniş gözlənilir",
  subscription_overdue: "Abunə gecikib",
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
  failed: "destructive",
  revision_pending: "outline",
  refund_pending: "destructive",
  refunded: "secondary",
  open: "secondary",
  resolved: "default",
  cancelled: "destructive",
  upcoming: "secondary",
  live: "default",
  ended: "outline",
  active: "default",
  soldOut: "secondary",
  expired: "outline",
  awaiting_payment: "outline",
  // Destructive, like `rejected` — a delinquent venue is invisible in
  // the app, so this must not read as a neutral state.
  subscription_overdue: "destructive",
};

export function StatusBadge({ status }: { status: string }) {
  return <Badge variant={STATUS_VARIANTS[status] ?? "outline"}>{STATUS_LABELS[status] ?? status}</Badge>;
}
