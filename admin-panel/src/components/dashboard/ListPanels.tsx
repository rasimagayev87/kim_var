import Link from "next/link";
import type { TopVenue, SubscriptionRow } from "@/lib/types";
import { ComingSoonButton } from "@/components/dashboard/ComingSoon";

function Avatar({ name, url }: { name: string; url?: string }) {
  return (
    <div className="w-7 h-7 rounded-full bg-canvas dark:bg-surface-raised-dark border border-dash-border dark:border-dash-border-dark flex items-center justify-center text-[11px] font-medium text-ink-muted dark:text-ink-muted-dark overflow-hidden shrink-0">
      {url ? (
        // eslint-disable-next-line @next/next/no-img-element
        <img src={url} alt={name} className="w-full h-full object-cover" />
      ) : (
        name.charAt(0)
      )}
    </div>
  );
}

export function TopVenuesPanel({ venues }: { venues: TopVenue[] }) {
  return (
    <div className="rounded-card border border-dash-border dark:border-dash-border-dark bg-surface dark:bg-surface-dark p-4">
      <div className="flex items-center justify-between mb-3">
        <h3 className="text-sm font-medium text-ink dark:text-ink-dark">Ən Populyar Məkanlar</h3>
        <Link href="/venues" className="text-[11px] text-cyan hover:underline">Hamısına bax</Link>
      </div>

      {venues.length === 0 ? (
        <p className="text-xs text-ink-muted dark:text-ink-muted-dark py-3">Hələ baxış datası yoxdur.</p>
      ) : (
        <ol className="space-y-2.5">
          {venues.map((v, i) => (
            <li key={v.id} className="flex items-center gap-2.5">
              <span className="w-4 text-[11px] font-mono text-ink-muted dark:text-ink-muted-dark text-right">
                {i + 1}
              </span>
              <Avatar name={v.name} url={v.avatarUrl} />
              <span className="flex-1 text-xs text-ink dark:text-ink-dark truncate">{v.name}</span>
              <span className="text-[11px] font-mono text-ink-muted dark:text-ink-muted-dark">
                {v.visits.toLocaleString("az-AZ")} baxış
              </span>
            </li>
          ))}
        </ol>
      )}
    </div>
  );
}

export function SubscriptionsPanel({ subscriptions }: { subscriptions: SubscriptionRow[] }) {
  return (
    <div className="rounded-card border border-dash-border dark:border-dash-border-dark bg-surface dark:bg-surface-dark p-4">
      <div className="flex items-center justify-between mb-3">
        <h3 className="text-sm font-medium text-ink dark:text-ink-dark">Abunəliklər</h3>
        <ComingSoonButton className="text-[11px] text-cyan hover:underline">Hamısına bax</ComingSoonButton>
      </div>

      {subscriptions.length === 0 ? (
        <p className="text-xs text-ink-muted dark:text-ink-muted-dark py-3">Aktiv abunəlik yoxdur.</p>
      ) : (
        <ul className="space-y-2.5">
          {subscriptions.map((s) => (
            <li key={s.id} className="flex items-center gap-2.5">
              <Avatar name={s.venueName} url={s.avatarUrl} />
              <span className="flex-1 text-xs text-ink dark:text-ink-dark truncate">{s.venueName}</span>
              <span
                className={`text-[10px] font-mono px-1.5 py-0.5 rounded ${
                  s.plan === "PRO"
                    ? "bg-purple-soft text-purple dark:bg-purple/10"
                    : "bg-canvas dark:bg-surface-raised-dark text-ink-muted dark:text-ink-muted-dark"
                }`}
              >
                {s.plan}
              </span>
              <span className="text-[11px] font-mono text-ink-muted dark:text-ink-muted-dark whitespace-nowrap">
                {s.renewsInDays} gün
              </span>
            </li>
          ))}
        </ul>
      )}
    </div>
  );
}
