/**
 * Client-safe half of the pending-counts system: the `PendingCounts`
 * shape and each field's display label/href. Lives outside
 * `lib/data/pending-counts.ts` (which is `import "server-only"`)
 * specifically so client components like `NotificationBell` can import
 * `PENDING_SECTION_META` as a real value without pulling the Admin SDK
 * into the browser bundle.
 */
export interface PendingCounts {
  venues: number;
  offers: number;
  pinboxes: number;
  identityVerifications: number;
  reports: number;
  eventReports: number;
  reviewReports: number;
  payments: number;
  pinboxPayouts: number;
}

export const PENDING_SECTION_META: { key: keyof PendingCounts; label: string; href: string }[] = [
  { key: "identityVerifications", label: "Kimlik doğrulama", href: "/identity-verifications" },
  { key: "venues", label: "Məkanlar", href: "/venues" },
  { key: "payments", label: "Ödənişlər", href: "/payments" },
  { key: "pinboxPayouts", label: "PinBox öhdəlikləri", href: "/pinbox-payouts" },
  { key: "offers", label: "Təkliflər", href: "/offers" },
  { key: "pinboxes", label: "PinBox", href: "/pinboxes" },
  { key: "reports", label: "Şikayətlər", href: "/feedback" },
  { key: "eventReports", label: "Tədbir şikayətləri", href: "/event-reports" },
  { key: "reviewReports", label: "Rəy şikayətləri", href: "/review-reports" },
];
