"use client";

import { useEffect } from "react";
import { XCircle } from "lucide-react";

import { buttonVariants } from "@/components/ui/button";
import { Card, CardContent, CardDescription, CardHeader, CardTitle } from "@/components/ui/card";
import { cn } from "@/lib/utils";

/**
 * Epoint's `error_redirect_url` — same reasoning as the success page
 * right next to this one (card checkout always opens in the external
 * browser, this is genuinely the only page the customer lands on). A
 * declined/abandoned card never reaches `applyPaymentOutcome` at all
 * unless Epoint's own webhook explicitly reports the decline, so
 * unlike the success page there's no guaranteed server-side event
 * behind this — the checkout screen's own "Ödə" retry button
 * (`retryOfferPayment`/`retryVenueSubscriptionPayment`/etc.) is what
 * actually gets the customer another attempt, this page just says so.
 */
export default function PaymentErrorPage() {
  useEffect(() => {
    window.location.href = "peakpin://";
  }, []);

  return (
    <div className="flex flex-1 items-center justify-center bg-muted/30 p-6">
      <Card className="w-full max-w-sm text-center">
        <CardHeader>
          <XCircle className="mx-auto mb-2 h-12 w-12 text-destructive" />
          <CardTitle>Ödəniş tamamlanmadı</CardTitle>
          <CardDescription>
            PeakPin tətbiqinə qayıdıb yenidən cəhd edin — kartınızdan heç bir məbləğ tutulmayıb.
          </CardDescription>
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
