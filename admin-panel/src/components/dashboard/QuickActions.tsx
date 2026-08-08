import { Send, PlusCircle, Megaphone, FileDown } from "lucide-react";
import { ComingSoonButton } from "@/components/dashboard/ComingSoon";

/**
 * The zip's original version marked "Yeni Məkan Əlavə Et" as wired to
 * `/venues/new`, assuming that route already existed. It doesn't — the
 * Məkanlar module here is view/moderate-only (`venues-filters.tsx` +
 * `venues-table.tsx`, no create form or route), venues are only ever
 * created from the mobile app. So every action below is currently
 * "Tezliklə" until a real destination exists — moving this one back to
 * ComingSoon rather than linking to a 404.
 */
const ACTIONS = [
  { icon: Send, label: "Push Bildiriş Göndər" },
  { icon: PlusCircle, label: "Yeni Məkan Əlavə Et" },
  { icon: Megaphone, label: "Kampaniya Yarat" },
  { icon: FileDown, label: "Hesabat İxrac Et" },
];

export function QuickActions() {
  return (
    <div className="rounded-card border border-dash-border dark:border-dash-border-dark bg-surface dark:bg-surface-dark p-4">
      <h3 className="text-sm font-medium text-ink dark:text-ink-dark mb-3">Sürətli Əməliyyatlar</h3>
      <div className="space-y-1.5">
        {ACTIONS.map((action) => {
          const Icon = action.icon;
          return (
            <ComingSoonButton
              key={action.label}
              className="w-full flex items-center gap-2.5 px-3 py-2 rounded-lg text-xs text-ink dark:text-ink-dark bg-canvas dark:bg-surface-raised-dark hover:bg-cyan-soft dark:hover:bg-cyan/10 hover:text-cyan transition-colors text-left"
            >
              <Icon className="w-3.5 h-3.5 shrink-0" strokeWidth={1.75} />
              {action.label}
            </ComingSoonButton>
          );
        })}
      </div>
    </div>
  );
}
