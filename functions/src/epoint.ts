/**
 * Epoint.az merchant API — the payment gateway Faza B's "Təklif
 * yerləşdirmə haqqı" checks out through. This is the FIRST real
 * payment gate in this codebase: every other `payments/{id}` doc today
 * (`listing_payment.dart`, `renewVenueSubscriptions`,
 * `computeMonthlyPinBoxPayouts`) is written straight to `'completed'`
 * as a stand-in — see those files' own doc comments. `submitOffer`/
 * `epointWebhook`/`retryOfferPayment` in index.ts are the first
 * producer/consumer pair that actually waits on a real webhook before
 * unlocking anything.
 *
 * Signature scheme confirmed against Epoint's own working PHP SDK
 * (github.com/TuralAsgar/epoint, MIT) rather than guessed — there is
 * no public REST reference doc, only a merchant-portal PDF this repo
 * doesn't have a copy of:
 *   data      = base64(JSON.stringify(payload))
 *   signature = base64(sha1(private_key + data + private_key))   // raw digest, not hex
 * The same formula both signs an outgoing request and verifies an
 * incoming webhook — Epoint just echoes the check back at you.
 */
import { createHash } from "crypto";

const EPOINT_BASE_URL = "https://epoint.az/api/1";

export interface EpointCheckoutRequest {
  publicKey: string;
  privateKey: string;
  orderId: string;
  amount: number;
  currency?: string;
  language?: "az" | "en" | "ru";
  description: string;
  successRedirectUrl: string;
  errorRedirectUrl: string;
}

export interface EpointCheckoutResult {
  redirectUrl: string;
  epointTransaction?: string;
}

export interface EpointTokenWidgetRequest {
  publicKey: string;
  privateKey: string;
  orderId: string;
  amount: number;
  description: string;
}

export interface EpointTokenWidgetResult {
  widgetUrl: string;
}

function signPayload(privateKey: string, jsonData: Record<string, unknown>): { data: string; signature: string } {
  const data = Buffer.from(JSON.stringify(jsonData)).toString("base64");
  const signature = createHash("sha1").update(`${privateKey}${data}${privateKey}`).digest("base64");
  return { data, signature };
}

/** Recomputes the signature the same way `signPayload` does, for verifying an inbound webhook's `data`/`signature` pair. */
export function verifyEpointSignature(privateKey: string, data: string, signature: string): boolean {
  const expected = createHash("sha1").update(`${privateKey}${data}${privateKey}`).digest("base64");
  return expected === signature;
}

/** `data` decoded back to the JSON object Epoint signed — order_id, status, transaction, etc. */
export function decodeEpointData(data: string): Record<string, unknown> {
  return JSON.parse(Buffer.from(data, "base64").toString("utf8"));
}

/**
 * Starts a card-payment checkout for one order — POSTs to Epoint's
 * `/request` endpoint and returns the hosted-checkout URL to redirect
 * the owner's browser/in-app browser to. Throws on any non-success
 * response; callers should let that fail the whole onCall rather than
 * silently leaving a `payments` doc pending forever.
 */
export async function createEpointCheckout(req: EpointCheckoutRequest): Promise<EpointCheckoutResult> {
  const { data, signature } = signPayload(req.privateKey, {
    public_key: req.publicKey,
    language: req.language ?? "az",
    amount: req.amount.toFixed(2),
    currency: req.currency ?? "AZN",
    order_id: req.orderId,
    description: req.description,
    success_redirect_url: req.successRedirectUrl,
    error_redirect_url: req.errorRedirectUrl,
  });

  const response = await fetch(`${EPOINT_BASE_URL}/request`, {
    method: "POST",
    headers: { "Content-Type": "application/x-www-form-urlencoded" },
    body: new URLSearchParams({ data, signature }).toString(),
  });

  const body = (await response.json()) as Record<string, unknown>;
  const redirectUrl = body.redirect_url as string | undefined;
  if (!response.ok || !redirectUrl) {
    throw new Error(`Epoint checkout request failed: ${response.status} ${JSON.stringify(body)}`);
  }

  return { redirectUrl, epointTransaction: body.transaction as string | undefined };
}

/**
 * The exact path Epoint's own docs (developer.epoint.az/token-payment/
 * widget) redact behind a "click to authenticate and reveal" wall —
 * everything else about this endpoint (request fields, GET-with-
 * data/signature-as-query-params shape, response shape) is confirmed
 * from their public sample code, only the literal path is not. This
 * follows their own `/api/1/{action}` convention (matches `/request`,
 * `/get-status`, etc.) as the most likely value, but MUST be verified
 * against the real docs (log into developer.epoint.az) or Epoint
 * support once real merchant credentials exist, before this is trusted
 * in production — do not assume this is correct without checking.
 */
const EPOINT_TOKEN_WIDGET_PATH = "/token-widget";

/**
 * Requests an Apple Pay/Google Pay "Token Widget" URL for one order —
 * the client embeds the returned `widgetUrl` in a WebView, the
 * customer completes payment inside it, and the result reaches this
 * app the same way a card checkout's does: Epoint calls `epointWebhook`
 * with the same order_id/signature. See this file's own doc comment on
 * `EPOINT_TOKEN_WIDGET_PATH` for the one unconfirmed part of this.
 */
export async function createEpointTokenWidget(req: EpointTokenWidgetRequest): Promise<EpointTokenWidgetResult> {
  const { data, signature } = signPayload(req.privateKey, {
    public_key: req.publicKey,
    amount: req.amount.toFixed(2),
    order_id: req.orderId,
    description: req.description,
  });

  const url = new URL(`${EPOINT_BASE_URL}${EPOINT_TOKEN_WIDGET_PATH}`);
  url.searchParams.set("data", data);
  url.searchParams.set("signature", signature);

  const response = await fetch(url.toString());
  const body = (await response.json()) as Record<string, unknown>;
  const widgetUrl = body.widget_url as string | undefined;
  if (!response.ok || body.status !== "success" || !widgetUrl) {
    throw new Error(`Epoint token widget request failed: ${response.status} ${JSON.stringify(body)}`);
  }

  return { widgetUrl };
}
