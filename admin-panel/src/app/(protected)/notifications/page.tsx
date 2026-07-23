import { redirect } from "next/navigation";

import { Card, CardContent, CardDescription, CardHeader, CardTitle } from "@/components/ui/card";
import { BroadcastForm } from "@/components/broadcast/broadcast-form";
import { hasPermission } from "@/lib/auth/permissions";
import { getCurrentAdmin } from "@/lib/auth/server";

export default async function NotificationsPage() {
  const admin = await getCurrentAdmin();
  if (!admin || !hasPermission(admin.role, "broadcastNotifications")) {
    redirect("/dashboard");
  }

  return (
    <div className="mx-auto max-w-xl space-y-6">
      <div>
        <h1 className="text-2xl font-semibold tracking-tight">Bildirişlər</h1>
        <p className="text-sm text-muted-foreground">İstifadəçilərə sistem bildirişi göndərin.</p>
      </div>

      <Card>
        <CardHeader>
          <CardTitle>Yeni bildiriş</CardTitle>
          <CardDescription>
            Bildiriş seçilmiş seqmentin hər üzvünün &quot;Bildirişlər&quot; siyahısında görünəcək.
          </CardDescription>
        </CardHeader>
        <CardContent>
          <BroadcastForm />
        </CardContent>
      </Card>
    </div>
  );
}
