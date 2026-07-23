import { redirect } from "next/navigation";

import { AppHeader } from "@/components/layout/app-header";
import { AppSidebar } from "@/components/layout/app-sidebar";
import { getCurrentAdmin } from "@/lib/auth/server";

/**
 * Shared chrome (sidebar + header) for every real admin-panel screen.
 * Proxy already keeps unauthenticated requests out of this route
 * group, but this re-checks anyway — the same "don't trust Proxy
 * alone" reasoning as everywhere else in the auth layer — and it's
 * also just how the admin identity gets down to AppHeader/AppSidebar.
 */
export default async function ProtectedLayout({ children }: { children: React.ReactNode }) {
  const admin = await getCurrentAdmin();
  if (!admin) {
    redirect("/login");
  }

  return (
    <div className="flex min-h-screen flex-1">
      <AppSidebar role={admin.role} />
      <div className="flex flex-1 flex-col">
        <AppHeader admin={admin} />
        <main className="flex-1 bg-muted/30 p-6">{children}</main>
      </div>
    </div>
  );
}
