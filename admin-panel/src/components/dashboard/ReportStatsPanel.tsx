"use client";

import { PieChart, Pie, Cell, ResponsiveContainer } from "recharts";
import Link from "next/link";

interface ReportBreakdown {
  label: string;
  value: number;
  color: string;
}

/**
 * The `reports` collection has no `category` field to group by yet, so a
 * real per-category breakdown isn't possible — every pending report is
 * counted under "Digər" instead of inventing a split. `pendingReports`
 * itself IS real (same `getDashboardStats().pendingReports` the KPI row
 * uses), so the center number and total always match reality even
 * though the slices can't be categorized yet.
 */
export function ReportStatsPanel({ pendingReports }: { pendingReports: number }) {
  const DATA: ReportBreakdown[] = [
    { label: "Spam", value: 0, color: "#EF4444" },
    { label: "Saxta məlumat", value: 0, color: "#F59E0B" },
    { label: "Təhlükəli məzmun", value: 0, color: "#7C3AED" },
    { label: "Digər", value: pendingReports, color: "#8B93A3" },
  ];
  const total = pendingReports;
  const chartData = total === 0 ? [{ label: "Yoxdur", value: 1, color: "#232733" }] : DATA;

  return (
    <div className="rounded-card border border-dash-border dark:border-dash-border-dark bg-surface dark:bg-surface-dark p-4">
      <div className="flex items-center justify-between mb-1">
        <h3 className="text-sm font-medium text-ink dark:text-ink-dark">Report Statistikası</h3>
        {/* This app's reports/complaints module lives at /feedback, not
            /reports — the zip's original href was wrong for this repo. */}
        <Link href="/feedback" className="text-[11px] text-cyan hover:underline">Hamısına bax</Link>
      </div>

      <div className="flex items-center gap-4">
        <div className="relative w-28 h-28 shrink-0">
          <ResponsiveContainer width="100%" height="100%">
            <PieChart>
              <Pie
                data={chartData}
                dataKey="value"
                innerRadius={38}
                outerRadius={54}
                paddingAngle={total === 0 ? 0 : 2}
                isAnimationActive={false}
              >
                {chartData.map((d, i) => (
                  <Cell key={i} fill={d.color} stroke="none" />
                ))}
              </Pie>
            </PieChart>
          </ResponsiveContainer>
          <div className="absolute inset-0 flex flex-col items-center justify-center">
            <span className="font-mono text-xl font-semibold text-ink dark:text-ink-dark tabular-nums">
              {total}
            </span>
            <span className="text-[10px] text-ink-muted dark:text-ink-muted-dark">Ümumi</span>
          </div>
        </div>

        <ul className="space-y-1.5 flex-1">
          {DATA.map((d) => (
            <li key={d.label} className="flex items-center gap-2 text-[11px]">
              <span className="w-2 h-2 rounded-full shrink-0" style={{ backgroundColor: d.color }} />
              <span className="text-ink-muted dark:text-ink-muted-dark flex-1">{d.label}</span>
              <span className="font-mono text-ink dark:text-ink-dark">
                {d.value} {total > 0 && `(${Math.round((d.value / total) * 100)}%)`}
              </span>
            </li>
          ))}
        </ul>
      </div>
    </div>
  );
}
