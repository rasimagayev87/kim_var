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
 * Confirmed against Epoint's own official docs page (their
 * ParamTable/PHP example for this exact endpoint) AND their newer
 * official PHP SDK (github.com/rafoabbas/epoint-php,
 * `WidgetRequest`/`EpointClient::post`) — `/token/widget` (a path
 * segment, not `/token-widget`), POST with the exact same
 * `data`/`signature` form-urlencoded body every other endpoint in
 * this file uses (their own docs show a GET with query params, which
 * 405s in practice — POST is what actually works). Was rejected with
 * `{"status":"error","message":"You don't have access to this
 * operation"}` earlier in this project's life; Epoint has since
 * enabled it for this merchant account (confirmed live: a real
 * `widget_url` comes back now).
 *
 * The returned widget page's own inline HTML/JS (inspected directly)
 * carries BOTH Apple Pay (ApplePaySession, merchant id
 * `merchant.az.epoint.applepay`) and Google Pay (Google's Pay JS,
 * `merchantId: 'BCR2DN4TY3DITOZH'`) buttons — both under EPOINT's own
 * merchant accounts, not this project's. Nothing needs registering on
 * PeakPin's side for either platform; the widget shows whichever
 * button the visiting device/browser actually supports.
 */
const EPOINT_TOKEN_WIDGET_PATH = "/token/widget";

/**
 * Requests an Apple Pay/Google Pay "Token Widget" URL for one order —
 * the client embeds the returned `widgetUrl` in a WebView, the
 * customer completes payment inside it, and the result reaches this
 * app the same way a card checkout's does: Epoint calls `epointWebhook`
 * with the same order_id/signature.
 */
export async function createEpointTokenWidget(req: EpointTokenWidgetRequest): Promise<EpointTokenWidgetResult> {
  const { data, signature } = signPayload(req.privateKey, {
    public_key: req.publicKey,
    amount: req.amount.toFixed(2),
    order_id: req.orderId,
    description: req.description,
  });

  const response = await fetch(`${EPOINT_BASE_URL}${EPOINT_TOKEN_WIDGET_PATH}`, {
    method: "POST",
    headers: { "Content-Type": "application/x-www-form-urlencoded" },
    body: new URLSearchParams({ data, signature }).toString(),
  });
  const body = (await response.json()) as Record<string, unknown>;
  const widgetUrl = body.widget_url as string | undefined;
  if (!response.ok || body.status !== "success" || !widgetUrl) {
    throw new Error(`Epoint token widget request failed: ${response.status} ${JSON.stringify(body)}`);
  }

  return { widgetUrl };
}

export interface EpointReverseRequest {
  publicKey: string;
  privateKey: string;
  /** Epoint's own transaction id (the webhook callback's `transaction`
   * field, captured at confirmed-success time — NOT the merchant's own
   * `order_id`) — the only identifier `/reverse` accepts. */
  epointTransaction: string;
  /** Omitted → Epoint reverses the transaction's full original amount
   * (per the official docs, `amount` is optional here); passed anyway
   * whenever the caller has it, so a partial-refund need later doesn't
   * silently default to "reverse everything". */
  amount?: number;
  currency?: string;
  language?: "az" | "en" | "ru";
}

export interface EpointReverseResult {
  succeeded: boolean;
  message?: string;
}

/**
 * "Əməliyyatların ləğv edilməsi" (cancel/reverse a transaction) —
 * confirmed against the official Epoint API PDF (epoint-api-az.pdf,
 * "Əməliyyatların ləğv edilməsi" section): POST to `/reverse` with
 * `transaction` (Epoint's id, the doc's field name literally has a typo,
 * "transation", but the JSON key IS `transaction` per its own worked
 * example) + `currency`, `amount` optional. Distinct from `/refund-
 * request`, which the SAME doc's preceding section shows requires a
 * `card_uid` — that endpoint only applies to the saved-card/
 * card-registration flow this app never uses, so `/reverse` is the only
 * endpoint that actually applies to a normal one-off checkout payment.
 * Response is just `{status, message}` — no transaction/rrn/card
 * details to relay back, unlike every other endpoint in this file.
 */
export async function reverseEpointTransaction(req: EpointReverseRequest): Promise<EpointReverseResult> {
  const { data, signature } = signPayload(req.privateKey, {
    public_key: req.publicKey,
    language: req.language ?? "az",
    transaction: req.epointTransaction,
    ...(req.amount !== undefined ? { amount: req.amount.toFixed(2) } : {}),
    currency: req.currency ?? "AZN",
  });

  const response = await fetch(`${EPOINT_BASE_URL}/reverse`, {
    method: "POST",
    headers: { "Content-Type": "application/x-www-form-urlencoded" },
    body: new URLSearchParams({ data, signature }).toString(),
  });

  const body = (await response.json()) as Record<string, unknown>;
  const succeeded = response.ok && body.status === "success";
  return { succeeded, message: body.message as string | undefined };
}
