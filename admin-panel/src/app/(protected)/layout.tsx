import { redirect } from "next/navigation";

import { Sidebar } from "@/components/dashboard/Sidebar";
import { Topbar } from "@/components/dashboard/Topbar";
import { getCurrentAdmin } from "@/lib/auth/server";

/**
 * Shared chrome (sidebar + header) for every real admin-panel screen.
 * Proxy already keeps unauthenticated requests out of this route
 * group, but this re-checks anyway — the same "don't trust Proxy
 * alone" reasoning as everywhere else in the auth layer — and it's
 * also just how the admin identity gets down to Topbar/Sidebar.
 *
 * Previously used AppSidebar/AppHeader (still in
 * components/layout/, now unused) — replaced with the dark-theme
 * Sidebar/Topbar pair so the whole admin panel matches the approved
 * mockup, not just the Dashboard page's own content.
 */
export default async function ProtectedLayout({ children }: { children: React.ReactNode }) {
  const admin = await getCurrentAdmin();
  if (!admin) {
    redirect("/login");
  }

  return (
    <div className="min-h-screen bg-canvas dark:bg-canvas-dark">
      <Sidebar role={admin.role} />
      <div className="flex flex-1 flex-col lg:pl-64">
        <Topbar adminEmail={admin.email} adminRole={admin.role} />
        <main className="flex-1 p-6">{children}</main>
      </div>
    </div>
  );
}
