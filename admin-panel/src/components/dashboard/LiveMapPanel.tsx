"use client";

import { useState } from "react";
import { Plus, Minus, LocateFixed, Users, Store, Tag, Flag } from "lucide-react";
import { cn } from "@/lib/utils";
import { ComingSoonBadge, ComingSoonButton } from "@/components/dashboard/ComingSoon";

const LAYERS = [
  { key: "users", label: "İstifadəçilər", icon: Users, color: "#7C3AED" },
  { key: "venues", label: "Məkanlar", icon: Store, color: "#00D4E6" },
  { key: "offers", label: "Təkliflər", icon: Tag, color: "#10B981" },
  { key: "reports", label: "Reports", icon: Flag, color: "#EF4444" },
] as const;

export function LiveMapPanel() {
  const [enabled, setEnabled] = useState<Record<string, boolean>>({
    users: true,
    venues: true,
    offers: true,
    reports: true,
  });

  return (
    <div className="rounded-card border border-dash-border dark:border-dash-border-dark bg-surface dark:bg-surface-dark overflow-hidden h-full flex flex-col">
      <div className="flex items-center gap-2 px-4 py-3 border-b border-dash-border dark:border-dash-border-dark">
        <h3 className="text-sm font-medium text-ink dark:text-ink-dark">Canlı Xəritə</h3>
        <span className="flex items-center gap-1.5 text-[11px] text-ink-muted dark:text-ink-muted-dark">
          <span className="w-1.5 h-1.5 rounded-full bg-ink-muted dark:bg-ink-muted-dark" />
          real-time
        </span>
        <ComingSoonBadge />
      </div>

      <div className="relative flex-1 min-h-[320px] bg-canvas dark:bg-[#0B0D12]">
        {/* Map surface placeholder — mount Mapbox/Leaflet here, keeping this
            same container + legend/controls markup, once clustering exists. */}
        <div className="absolute inset-0 opacity-40 dark:opacity-25 bg-[radial-gradient(circle_at_30%_30%,rgba(0,212,230,0.15),transparent_50%),radial-gradient(circle_at_70%_60%,rgba(124,58,237,0.12),transparent_50%)]" />

        <div className="absolute inset-0 flex items-center justify-center">
          <p className="text-xs text-ink-muted dark:text-ink-muted-dark">
            Canlı marker axını hələ qoşulmayıb
          </p>
        </div>

        {/* Legend */}
        <div className="absolute top-3 right-3 w-44 rounded-lg border border-dash-border dark:border-dash-border-dark bg-surface/95 dark:bg-surface-dark/95 backdrop-blur-sm p-2.5 space-y-1.5">
          {LAYERS.map((layer) => {
            const Icon = layer.icon;
            return (
              <label
                key={layer.key}
                className="flex items-center gap-2 text-[11px] text-ink dark:text-ink-dark cursor-pointer"
              >
                <input
                  type="checkbox"
                  checked={enabled[layer.key]}
                  onChange={() =>
                    setEnabled((prev) => ({ ...prev, [layer.key]: !prev[layer.key] }))
                  }
                  className="w-3.5 h-3.5 rounded accent-cyan"
                />
                <Icon className="w-3 h-3" style={{ color: layer.color }} strokeWidth={2} />
                {layer.label}
              </label>
            );
          })}
        </div>

        {/* Zoom / locate controls */}
        <div className="absolute bottom-3 right-3 flex flex-col gap-1.5">
          <button className="w-8 h-8 rounded-lg border border-dash-border dark:border-dash-border-dark bg-surface dark:bg-surface-dark flex items-center justify-center text-ink-muted dark:text-ink-muted-dark hover:text-ink dark:hover:text-ink-dark transition">
            <Plus className="w-4 h-4" />
          </button>
          <button className="w-8 h-8 rounded-lg border border-dash-border dark:border-dash-border-dark bg-surface dark:bg-surface-dark flex items-center justify-center text-ink-muted dark:text-ink-muted-dark hover:text-ink dark:hover:text-ink-dark transition">
            <Minus className="w-4 h-4" />
          </button>
          <button className="w-8 h-8 rounded-lg border border-dash-border dark:border-dash-border-dark bg-surface dark:bg-surface-dark flex items-center justify-center text-ink-muted dark:text-ink-muted-dark hover:text-ink dark:hover:text-ink-dark transition">
            <LocateFixed className="w-4 h-4" />
          </button>
        </div>

        {/* Bottom-left mini legend, matches mockup's marker-type key */}
        <div className="absolute bottom-3 left-3 flex items-center gap-3 text-[11px] text-ink-muted dark:text-ink-muted-dark bg-surface/95 dark:bg-surface-dark/95 backdrop-blur-sm rounded-lg border border-dash-border dark:border-dash-border-dark px-2.5 py-1.5">
          {LAYERS.map((layer) => (
            <span key={layer.key} className="flex items-center gap-1">
              <span className={cn("w-2 h-2 rounded-full")} style={{ backgroundColor: layer.color }} />
              {layer.label}
            </span>
          ))}
        </div>
      </div>

      <div className="px-4 py-2.5 border-t border-dash-border dark:border-dash-border-dark">
        <ComingSoonButton className="text-xs text-cyan hover:underline">
          Xəritədə Tam Ekran
        </ComingSoonButton>
      </div>
    </div>
  );
}
