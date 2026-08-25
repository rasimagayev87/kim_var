"use client";

import { useEffect } from "react";
import { CheckCircle2 } from "lucide-react";

import { buttonVariants } from "@/components/ui/button";
import { Card, CardContent, CardDescription, CardHeader, CardTitle } from "@/components/ui/card";
import { cn } from "@/lib/utils";

/**
 * Epoint's `success_redirect_url`. The card checkout now opens in an
 * in-app WebView (`EpointCardCheckoutScreen`, `epoint_checkout.dart`),
 * which intercepts navigation to this exact URL and pops with its own
 * `EpointPaymentResultScreen` instead of ever letting this page render
 * inside the app — so on a current app build, a real customer never
 * actually sees this page. It's kept live (rather than deleted) as the
 * fallback for any pre-update app still doing the old external-browser
 * redirect, and as the plain landing page if this URL is ever opened
 * outside the app at all. The actual payment confirmation already
 * happened server-side (`epointWebhook` → `applyPaymentOutcome` → a
 * push notification, see that function's own doc comment) before this
 * page ever loads — this page's only job is to not be a 404 and to
 * try getting the customer back into the app, not to confirm anything
 * itself.
 *
 * Attempts the `peakpin://` custom scheme on load (see
 * `ios/Runner/Info.plist` / `deep_link_handler.dart` — an unrecognized
 * bare scheme is a safe no-op if the app doesn't handle it, and does
 * nothing at all if the app isn't installed) so most of the time the
 * browser tab is never even the thing the customer looks at again.
 * The button is the fallback for browsers that block an automatic
 * scheme navigation without a user gesture.
 */
export default function PaymentSuccessPage() {
  useEffect(() => {
    window.location.href = "peakpin://";
  }, []);

  return (
    <div className="flex flex-1 items-center justify-center bg-muted/30 p-6">
      <Card className="w-full max-w-sm text-center">
        <CardHeader>
          <CheckCircle2 className="mx-auto mb-2 h-12 w-12 text-green-600" />
          <CardTitle>Ödəniş uğurla tamamlandı</CardTitle>
          <CardDescription>PeakPin tətbiqinə qayıdın — dəyişiklik artıq orada görünəcək.</CardDescription>
        </CardHeader>
        <CardContent>
          <a href="peakpin://" className={cn(buttonVariants({ variant: "default" }), "w-full")}>
            PeakPin tətbiqini aç
          </a>
        </CardContent>
      </Card>
    </div>
  );
}
