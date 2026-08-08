"use client";

import { AreaChart, Area, ResponsiveContainer, YAxis } from "recharts";
import type { AnalyticsSeries } from "@/lib/types";

export function AnalyticsCard({ series, tone = "#00D4E6" }: { series: AnalyticsSeries; tone?: string }) {
  const hasEnoughHistory = series.points.length >= 3;

  return (
    <div className="rounded-card border border-dash-border dark:border-dash-border-dark bg-surface dark:bg-surface-dark p-4">
      <div className="flex items-start justify-between">
        <p className="text-xs text-ink-muted dark:text-ink-muted-dark">{series.label}</p>
        {series.changePct !== undefined && (
          <span
            className={`text-[11px] font-mono font-medium ${
              series.changePct >= 0 ? "text-success" : "text-danger"
            }`}
          >
            {series.changePct >= 0 ? "+" : ""}
            {series.changePct.toFixed(1)}%
          </span>
        )}
      </div>

      <p className="mt-1 font-mono text-xl font-semibold text-ink dark:text-ink-dark tabular-nums">
        {series.points.at(-1)?.value.toLocaleString("az-AZ") ?? "—"}
        {series.unit && <span className="text-sm font-normal text-ink-muted dark:text-ink-muted-dark ml-1">{series.unit}</span>}
      </p>

      <div className="mt-2 h-14">
        {hasEnoughHistory ? (
          <ResponsiveContainer width="100%" height="100%">
            <AreaChart data={series.points}>
              <defs>
                <linearGradient id={`grad-${series.id}`} x1="0" y1="0" x2="0" y2="1">
                  <stop offset="0%" stopColor={tone} stopOpacity={0.25} />
                  <stop offset="100%" stopColor={tone} stopOpacity={0} />
                </linearGradient>
              </defs>
              <YAxis hide domain={["dataMin", "dataMax"]} />
              <Area
                type="monotone"
                dataKey="value"
                stroke={tone}
                strokeWidth={1.75}
                fill={`url(#grad-${series.id})`}
                isAnimationActive={false}
              />
            </AreaChart>
          </ResponsiveContainer>
        ) : (
          <div className="h-full flex items-center text-[11px] text-ink-muted dark:text-ink-muted-dark">
            Qrafik üçün kifayət qədər tarixçə yoxdur ({series.points.length} nöqtə)
          </div>
        )}
      </div>
    </div>
  );
}
