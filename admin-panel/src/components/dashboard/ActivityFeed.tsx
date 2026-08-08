"use client";

import {
  UserPlus,
  Store,
  Tag,
  CreditCard,
  Flag,
  Wallet,
  ShieldX,
} from "lucide-react";
import { cn } from "@/lib/utils";
import type { ActivityEvent } from "@/lib/types";
import { ComingSoonBadge } from "@/components/dashboard/ComingSoon";

const EVENT_META: Record<
  ActivityEvent["type"],
  { icon: typeof UserPlus; tone: string }
> = {
  user_registered: { icon: UserPlus, tone: "text-cyan bg-cyan-soft dark:bg-cyan/10" },
  venue_added: { icon: Store, tone: "text-purple bg-purple-soft dark:bg-purple/10" },
  venue_pending: { icon: Store, tone: "text-amber-600 bg-amber-soft dark:bg-amber/10" },
  offer_approved: { icon: Tag, tone: "text-success bg-success-soft dark:bg-success/10" },
  subscription_started: { icon: CreditCard, tone: "text-pink bg-pink-soft dark:bg-pink/10" },
  report_filed: { icon: Flag, tone: "text-danger bg-danger-soft dark:bg-danger/10" },
  payment_received: { icon: Wallet, tone: "text-success bg-success-soft dark:bg-success/10" },
  moderator_action: { icon: ShieldX, tone: "text-ink-muted bg-canvas dark:bg-surface-raised-dark" },
};

function relativeTime(iso: string): string {
  const diffMs = Date.now() - new Date(iso).getTime();
  const mins = Math.floor(diffMs / 60000);
  if (mins < 1) return "indicə";
  if (mins < 60) return `${mins} dəqiqə əvvəl`;
  const hours = Math.floor(mins / 60);
  if (hours < 24) return `${hours} saat əvvəl`;
  return `${Math.floor(hours / 24)} gün əvvəl`;
}

export function ActivityFeed({ events }: { events: ActivityEvent[] }) {
  if (events.length === 0) {
    return (
      <div className="rounded-card border border-dash-border dark:border-dash-border-dark bg-surface dark:bg-surface-dark p-5">
        <div className="flex items-center gap-2 mb-1">
          <h3 className="text-sm font-medium text-ink dark:text-ink-dark">Real-time Aktivlik</h3>
          <ComingSoonBadge />
        </div>
        <p className="text-xs text-ink-muted dark:text-ink-muted-dark mt-4">
          Hələ qeydə alınmış hadisə yoxdur.
        </p>
      </div>
    );
  }

  return (
    <div className="rounded-card border border-dash-border dark:border-dash-border-dark bg-surface dark:bg-surface-dark p-5">
      <div className="flex items-center justify-between mb-3">
        <h3 className="text-sm font-medium text-ink dark:text-ink-dark">Real-time Aktivlik</h3>
        <span className="flex items-center gap-1.5 text-[11px] text-ink-muted dark:text-ink-muted-dark">
          <span className="w-1.5 h-1.5 rounded-full bg-success animate-pulse-dot" />
          canlı
        </span>
      </div>

      <ol className="space-y-3">
        {events.map((event) => {
          const meta = EVENT_META[event.type];
          const Icon = meta.icon;
          return (
            <li key={event.id} className="flex items-start gap-3">
              <div className={cn("w-7 h-7 rounded-lg flex items-center justify-center shrink-0", meta.tone)}>
                <Icon className="w-3.5 h-3.5" strokeWidth={2} />
              </div>
              <div className="min-w-0 flex-1">
                <p className="text-xs text-ink dark:text-ink-dark truncate">{event.title}</p>
                {event.subtitle && (
                  <p className="text-[11px] text-cyan truncate">{event.subtitle}</p>
                )}
              </div>
              <span className="text-[11px] font-mono text-ink-muted dark:text-ink-muted-dark shrink-0 whitespace-nowrap">
                {relativeTime(event.timestamp)}
              </span>
            </li>
          );
        })}
      </ol>
    </div>
  );
}
