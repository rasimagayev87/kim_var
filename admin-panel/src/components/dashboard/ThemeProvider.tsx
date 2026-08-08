"use client";

import { createContext, useContext, useEffect, useState, ReactNode } from "react";

type Theme = "light" | "dark";

const ThemeContext = createContext<{ theme: Theme; toggleTheme: () => void }>({
  theme: "light",
  toggleTheme: () => {},
});

export function ThemeProvider({ children }: { children: ReactNode }) {
  // Dark is the default look for the admin panel (matches the approved
  // mockup) — light mode is still fully available via the Topbar
  // toggle. Deliberately NOT read from localStorage via a lazy
  // useState initializer: that runs during the client's first render,
  // which would disagree with the server-rendered HTML (server has no
  // localStorage, so it always renders "dark") the moment a visitor
  // had actually chosen "light" — a real hydration mismatch on
  // anything that branches on `theme` (Topbar's Sun/Moon icon does).
  // Reading it in a mount effect instead means server and first
  // client render always agree ("dark"), and the correction to
  // whatever's actually stored happens in the one extra render right
  // after hydration — the known-safe shape for this exact problem,
  // despite react-hooks/set-state-in-effect's general advice against
  // setState-in-effect.
  const [theme, setTheme] = useState<Theme>("dark");

  useEffect(() => {
    const stored = localStorage.getItem("peakpin-admin-theme") as Theme | null;
    // eslint-disable-next-line react-hooks/set-state-in-effect -- see comment above
    setTheme(stored ?? "dark");
  }, []);

  useEffect(() => {
    document.documentElement.classList.toggle("dark", theme === "dark");
    localStorage.setItem("peakpin-admin-theme", theme);
  }, [theme]);

  return (
    <ThemeContext.Provider
      value={{ theme, toggleTheme: () => setTheme((t) => (t === "dark" ? "light" : "dark")) }}
    >
      {children}
    </ThemeContext.Provider>
  );
}

export const useTheme = () => useContext(ThemeContext);
