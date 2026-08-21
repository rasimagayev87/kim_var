// PeakPin Admin — Dashboard-only shared types (KPI cards, analytics series,
// activity feed, list panels). Field shapes mirror what the redesigned
// Dashboard page's components consume — see app/(protected)/dashboard/page.tsx
// for how each is populated from real Firestore data.

export type TrendDirection = "up" | "down" | "flat";

export interface KpiDatum {
  id: string;
  label: string;
  value: number;
  unit?: string; // e.g. "AZN"
  changePct?: number; // e.g. 12.5 → "+12.5%". Omit if no historical baseline yet.
  direction?: TrendDirection;
  sparkline?: number[]; // last N days/hours, small array. Omit if not tracked yet.
  icon: LucideIconName;
  tone?: "cyan" | "purple" | "pink" | "amber" | "success" | "danger";
}

export type LucideIconName =
  | "Users"
  | "UserPlus"
  | "Store"
  | "Tag"
  | "Wallet"
  | "CreditCard"
  | "ShieldAlert"
  | "Flag"
  | "Activity"
  | "Calendar"
  | "Package";

export interface ActivityEvent {
  id: string;
  type:
    | "user_registered"
    | "venue_added"
    | "venue_pending"
    | "offer_approved"
    | "subscription_started"
    | "report_filed"
    | "payment_received"
    | "moderator_action";
  title: string;
  subtitle?: string;
  timestamp: string; // ISO string — render as relative time client-side
  actorAvatarUrl?: string;
}

export interface AnalyticsSeries {
  id: string;
  label: string;
  unit?: string;
  changePct?: number;
  points: { date: string; value: number }[];
}

export interface TopVenue {
  id: string;
  name: string;
  visits: number;
  avatarUrl?: string;
}

export interface SubscriptionRow {
  id: string;
  venueName: string;
  plan: "BASIC" | "PRO";
  renewsInDays: number;
  avatarUrl?: string;
}
