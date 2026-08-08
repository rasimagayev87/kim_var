"use client";

import { useEffect, useState } from "react";
import {
  Users,
  UserPlus,
  Store,
  Tag,
  Wallet,
  CreditCard,
  ShieldAlert,
  Flag,
  Activity,
  ArrowUp,
  ArrowDown,
  Minus,
} from "lucide-react";
import { LineChart, Line, ResponsiveContainer } from "recharts";
import { cn } from "@/lib/utils";
import type { KpiDatum } from "@/lib/types";

const ICONS = { Users, UserPlus, Store, Tag, Wallet, CreditCard, ShieldAlert, Flag, Activity };

const TONE_CLASSES: Record<NonNullable<KpiDatum["tone"]>, string> = {
  cyan: "bg-cyan-soft text-cyan dark:bg-cyan/10",
  purple: "bg-purple-soft text-purple dark:bg-purple/10",
  pink: "bg-pink-soft text-pink dark:bg-pink/10",
  amber: "bg-amber-soft text-amber-600 dark:bg-amber/10",
  success: "bg-success-soft text-success dark:bg-success/10",
  danger: "bg-danger-soft text-danger dark:bg-danger/10",
};

const TONE_STROKE: Record<NonNullable<KpiDatum["tone"]>, string> = {
  cyan: "#00D4E6",
  purple: "#7C3AED",
  pink: "#EC4899",
  amber: "#F59E0B",
  success: "#10B981",
  danger: "#EF4444",
};

// Animates from 0 to the real value once, on mount — a controlled version of
// "animated counters" rather than a re-triggering gimmick that fires on every
// re-render (which reads as noisy, not premium).
function useCountUp(target: number, durationMs = 600) {
  const [value, setValue] = useState(0);

  useEffect(() => {
    let raf: number;
    const start = performance.now();
    const tick = (now: number) => {
      const progress = Math.min((now - start) / durationMs, 1);
      const eased = 1 - Math.pow(1 - progress, 3);
      setValue(Math.round(target * eased));
      if (progress < 1) raf = requestAnimationFrame(tick);
    };
    raf = requestAnimationFrame(tick);
    return () => cancelAnimationFrame(raf);
  }, [target, durationMs]);

  return value;
}

export function KpiCard({ data }: { data: KpiDatum }) {
  const Icon = ICONS[data.icon];
  const animatedValue = useCountUp(data.value);
  const tone = data.tone ?? "cyan";

  return (
    <div className="rounded-card border border-dash-border dark:border-dash-border-dark bg-surface dark:bg-surface-dark p-4 shadow-card dark:shadow-card-dark">
      <div className="flex items-start justify-between">
        <div className={cn("w-8 h-8 rounded-lg flex items-center justify-center", TONE_CLASSES[tone])}>
          <Icon className="w-4 h-4" strokeWidth={2} />
        </div>
        {data.changePct !== undefined && <ChangeBadge pct={data.changePct} direction={data.direction} />}
      </div>

      <p className="mt-3 text-xs text-ink-muted dark:text-ink-muted-dark">{data.label}</p>

      <div className="mt-1 flex items-end justify-between gap-2">
        <p className="font-mono text-2xl font-semibold text-ink dark:text-ink-dark tabular-nums">
          {animatedValue.toLocaleString("az-AZ")}
          {data.unit && <span className="text-sm font-normal text-ink-muted dark:text-ink-muted-dark ml-1">{data.unit}</span>}
        </p>

        {data.sparkline && data.sparkline.length > 1 ? (
          <div className="w-16 h-8 shrink-0">
            <ResponsiveContainer width="100%" height="100%">
              <LineChart data={data.sparkline.map((v, i) => ({ i, v }))}>
                <Line
                  type="monotone"
                  dataKey="v"
                  stroke={TONE_STROKE[tone]}
                  strokeWidth={1.75}
                  dot={false}
                  isAnimationActive={false}
                />
              </LineChart>
            </ResponsiveContainer>
          </div>
        ) : (
          <span className="text-[11px] text-ink-muted dark:text-ink-muted-dark shrink-0">tarixçə yığılır</span>
        )}
      </div>
    </div>
  );
}

function ChangeBadge({ pct, direction }: { pct: number; direction?: KpiDatum["direction"] }) {
  const dir = direction ?? (pct > 0 ? "up" : pct < 0 ? "down" : "flat");
  const positive = dir === "up";
  const flat = dir === "flat";

  const Icon = flat ? Minus : positive ? ArrowUp : ArrowDown;
  const colorClass = flat
    ? "text-ink-muted dark:text-ink-muted-dark bg-canvas dark:bg-surface-raised-dark"
    : positive
    ? "text-success bg-success-soft dark:bg-success/10"
    : "text-danger bg-danger-soft dark:bg-danger/10";

  return (
    <span className={cn("inline-flex items-center gap-0.5 text-[11px] font-mono font-medium px-1.5 py-0.5 rounded-pill", colorClass)}>
      <Icon className="w-3 h-3" strokeWidth={2.5} />
      {Math.abs(pct).toFixed(1)}%
    </span>
  );
}
