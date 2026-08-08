"use client";

import { ReactNode } from "react";
import { toast } from "sonner";

/** Small badge to drop into a panel header for anything not wired to real data yet. */
export function ComingSoonBadge() {
  return (
    <span className="text-[10px] font-mono uppercase tracking-wider text-amber-500 bg-amber/15 px-1.5 py-0.5 rounded">
      Tezliklə
    </span>
  );
}

/**
 * Wraps any button — clicking anything not built yet just shows a toast.
 * Reuses the app's existing `sonner` Toaster (already mounted once in the
 * root layout) instead of a bespoke provider, so nothing new needs wiring
 * into any layout.
 */
export function ComingSoonButton({
  children,
  className,
}: {
  children: ReactNode;
  className?: string;
}) {
  return (
    <button type="button" className={className} onClick={() => toast("Tezliklə əlavə olunacaq")}>
      {children}
    </button>
  );
}
