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
};

export function StatusBadge({ status }: { status: string }) {
  return <Badge variant={STATUS_VARIANTS[status] ?? "outline"}>{STATUS_LABELS[status] ?? status}</Badge>;
}
