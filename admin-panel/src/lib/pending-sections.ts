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
  identityVerifications: number;
  reports: number;
  eventReports: number;
  payments: number;
  pinboxPayouts: number;
}

export const PENDING_SECTION_META: { key: keyof PendingCounts; label: string; href: string }[] = [
  { key: "identityVerifications", label: "Kimlik doğrulama", href: "/identity-verifications" },
  { key: "venues", label: "Məkanlar", href: "/venues" },
  { key: "payments", label: "Ödənişlər", href: "/payments" },
  { key: "pinboxPayouts", label: "PinBox ödənişləri", href: "/pinbox-payouts" },
  { key: "offers", label: "Təkliflər", href: "/offers" },
  { key: "reports", label: "Şikayətlər", href: "/feedback" },
  { key: "eventReports", label: "Tədbir şikayətləri", href: "/event-reports" },
];
