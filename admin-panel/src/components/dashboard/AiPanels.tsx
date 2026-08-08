import { ShieldAlert } from "lucide-react";
import { ComingSoonBadge, ComingSoonButton } from "@/components/dashboard/ComingSoon";

export function AiModerationPanel() {
  return (
    <div className="rounded-card border border-dash-border dark:border-dash-border-dark bg-surface dark:bg-surface-dark p-4 flex-1 min-h-0 flex flex-col">
      <div className="flex items-center gap-2 mb-3">
        <h3 className="text-sm font-medium text-ink dark:text-ink-dark">AI Moderasiya Xəbərdarlığı</h3>
        <ComingSoonBadge />
        <ComingSoonButton className="ml-auto text-[11px] text-cyan hover:underline">Hamısına bax</ComingSoonButton>
      </div>

      <div className="flex-1 flex items-center justify-center py-6">
        <div className="text-center">
          <ShieldAlert className="w-5 h-5 text-ink-muted dark:text-ink-muted-dark mx-auto mb-2" strokeWidth={1.5} />
          <p className="text-xs text-ink-muted dark:text-ink-muted-dark">Aşkarlanan risk yoxdur</p>
        </div>
      </div>
    </div>
  );
}

export function AiSummaryPanel() {
  return (
    <div className="rounded-card border border-dash-border dark:border-dash-border-dark bg-surface dark:bg-surface-dark p-4 flex-1 min-h-0 flex flex-col">
      <div className="flex items-center gap-2 mb-3">
        <h3 className="text-sm font-medium text-ink dark:text-ink-dark">AI Summary (24 saat)</h3>
        <ComingSoonBadge />
      </div>

      <ul className="space-y-1.5 text-xs text-ink-muted dark:text-ink-muted-dark flex-1">
        <li>+1 Yeni istifadəçi</li>
        <li>+0 Yeni məkan</li>
        <li>+0 Yeni abunəlik</li>
        <li>0 AZN Gəlir</li>
        <li>0 Açıq report</li>
        <li>0 Spam hesab bloklandı</li>
      </ul>
    </div>
  );
}
