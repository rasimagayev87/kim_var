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

/**
 * Epoint has only ever exposed one real API host — no distinct
 * sandbox/test base URL is documented anywhere, or has ever been
 * found working against this merchant account (see this file's own
 * top doc comment on how the signature scheme itself was confirmed:
 * no public REST reference exists beyond a merchant-portal PDF and a
 * working PHP SDK, and neither mentions a second environment).
 * "Environment" here is therefore a fail-safe CONFIRMATION gate, not
 * a URL switch the way Stripe/PayPal's sandbox-vs-production split
 * works — `env` must be explicitly `"production"` (the `EPOINT_ENV`
 * secret) before any real checkout/charge/reverse call is allowed to
 * run at all. Anything else (unset, a typo, "sandbox" left over from
 * local dev) throws immediately, before any network request — this
 * is what actually prevents accidentally processing a real payment
 * with a not-yet-verified key pair, since the key VALUES themselves
 * (`EPOINT_PUBLIC_KEY`/`EPOINT_PRIVATE_KEY`) are the only thing that
 * otherwise distinguishes "test" from "real" money on Epoint's side.
 */
function resolveEpointBaseUrl(env: string): string {
  if (env !== "production") {
    throw new Error(
      `EPOINT_ENV must be explicitly "production" to process a real Epoint request (got: ${JSON.stringify(env)}). ` +
        "This is a deliberate fail-safe, not a real sandbox/production URL switch (Epoint has no separate " +
        "sandbox host) — set the EPOINT_ENV secret to \"production\" once EPOINT_PUBLIC_KEY/EPOINT_PRIVATE_KEY " +
        "are confirmed to be real production merchant credentials.",
    );
  }
  return "https://epoint.az/api/1";
}

export interface EpointCheckoutRequest {
  publicKey: string;
  privateKey: string;
  /** Must be `"production"` — see [resolveEpointBaseUrl]'s doc comment. */
  env: string;
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
  /** Must be `"production"` — see [resolveEpointBaseUrl]'s doc comment. */
  env: string;
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
  const baseUrl = resolveEpointBaseUrl(req.env);
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

  const response = await fetch(`${baseUrl}/request`, {
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
  const baseUrl = resolveEpointBaseUrl(req.env);
  const { data, signature } = signPayload(req.privateKey, {
    public_key: req.publicKey,
    amount: req.amount.toFixed(2),
    order_id: req.orderId,
    description: req.description,
  });

  const response = await fetch(`${baseUrl}${EPOINT_TOKEN_WIDGET_PATH}`, {
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

export interface EpointCardRegistrationRequest {
  publicKey: string;
  privateKey: string;
  /** Must be `"production"` — see [resolveEpointBaseUrl]'s doc comment. */
  env: string;
  orderId: string;
  description: string;
  successRedirectUrl: string;
  errorRedirectUrl: string;
  language?: "az" | "en" | "ru";
}

export interface EpointCardRegistrationResult {
  redirectUrl: string;
  epointCardId?: string;
}

/**
 * Confirmed against Epoint's own official PHP SDK
 * (github.com/rafoabbas/epoint-php, `CardRegistrationRequest`) — POST
 * `/card-registration` with `refund: '0'` (a `'1'` registers a
 * refund-receiving card instead, which this app has no use for).
 * Returns a `redirect_url` to Epoint's OWN hosted card-entry page
 * (PashaBank ecomm) — same PCI boundary as every other checkout in
 * this file, nothing new. Completion reaches `epointWebhook` the same
 * way every other flow's does (Epoint has one callback URL per
 * merchant account, not one per request).
 */
export async function createEpointCardRegistration(
  req: EpointCardRegistrationRequest,
): Promise<EpointCardRegistrationResult> {
  const baseUrl = resolveEpointBaseUrl(req.env);
  const { data, signature } = signPayload(req.privateKey, {
    public_key: req.publicKey,
    language: req.language ?? "az",
    refund: "0",
    description: req.description,
    order_id: req.orderId,
    success_redirect_url: req.successRedirectUrl,
    error_redirect_url: req.errorRedirectUrl,
  });

  const response = await fetch(`${baseUrl}/card-registration`, {
    method: "POST",
    headers: { "Content-Type": "application/x-www-form-urlencoded" },
    body: new URLSearchParams({ data, signature }).toString(),
  });
  const body = (await response.json()) as Record<string, unknown>;
  const redirectUrl = body.redirect_url as string | undefined;
  if (!response.ok || body.status !== "success" || !redirectUrl) {
    throw new Error(`Epoint card registration failed: ${response.status} ${JSON.stringify(body)}`);
  }

  return { redirectUrl, epointCardId: body.card_id as string | undefined };
}

export interface EpointSavedCardPaymentRequest {
  publicKey: string;
  privateKey: string;
  /** Must be `"production"` — see [resolveEpointBaseUrl]'s doc comment. */
  env: string;
  epointCardId: string;
  amount: number;
  orderId: string;
  description: string;
  currency?: string;
  language?: "az" | "en" | "ru";
}

export interface EpointSavedCardPaymentResult {
  succeeded: boolean;
  transaction?: string;
  message?: string;
}

/**
 * POST `/execute-pay` — charges a card already registered via
 * [createEpointCardRegistration], no redirect/webview involved: the
 * response IS the final outcome, synchronously. Confirmed against the
 * SDK's `SavedCardPaymentRequest`.
 */
export async function chargeEpointSavedCard(
  req: EpointSavedCardPaymentRequest,
): Promise<EpointSavedCardPaymentResult> {
  const baseUrl = resolveEpointBaseUrl(req.env);
  const { data, signature } = signPayload(req.privateKey, {
    public_key: req.publicKey,
    language: req.language ?? "az",
    currency: req.currency ?? "AZN",
    card_id: req.epointCardId,
    amount: req.amount.toFixed(2),
    order_id: req.orderId,
    description: req.description,
  });

  const response = await fetch(`${baseUrl}/execute-pay`, {
    method: "POST",
    headers: { "Content-Type": "application/x-www-form-urlencoded" },
    body: new URLSearchParams({ data, signature }).toString(),
  });
  const body = (await response.json()) as Record<string, unknown>;
  const succeeded = response.ok && body.status === "success";

  return { succeeded, transaction: body.transaction as string | undefined, message: body.message as string | undefined };
}

export interface EpointCardStatusRequest {
  publicKey: string;
  privateKey: string;
  /** Must be `"production"` — see [resolveEpointBaseUrl]'s doc comment. */
  env: string;
  epointCardId: string;
}

export interface EpointCardStatusResult {
  mask?: string;
  expiredDate?: string;
}

/**
 * POST `/get-status-card` — the only Epoint endpoint that returns a
 * saved card's expiry date (`expired_date`); the card-registration
 * webhook payload itself doesn't include it. Called once, right after
 * a registration is confirmed, to fill in the saved card's expiry.
 */
export async function getEpointCardStatus(req: EpointCardStatusRequest): Promise<EpointCardStatusResult> {
  const baseUrl = resolveEpointBaseUrl(req.env);
  const { data, signature } = signPayload(req.privateKey, {
    public_key: req.publicKey,
    card_id: req.epointCardId,
  });

  const response = await fetch(`${baseUrl}/get-status-card`, {
    method: "POST",
    headers: { "Content-Type": "application/x-www-form-urlencoded" },
    body: new URLSearchParams({ data, signature }).toString(),
  });
  const body = (await response.json()) as Record<string, unknown>;

  return { mask: body.mask as string | undefined, expiredDate: body.expired_date as string | undefined };
}

export interface EpointReverseRequest {
  publicKey: string;
  privateKey: string;
  /** Must be `"production"` — see [resolveEpointBaseUrl]'s doc comment. */
  env: string;
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
  const baseUrl = resolveEpointBaseUrl(req.env);
  const { data, signature } = signPayload(req.privateKey, {
    public_key: req.publicKey,
    language: req.language ?? "az",
    transaction: req.epointTransaction,
    ...(req.amount !== undefined ? { amount: req.amount.toFixed(2) } : {}),
    currency: req.currency ?? "AZN",
  });

  const response = await fetch(`${baseUrl}/reverse`, {
    method: "POST",
    headers: { "Content-Type": "application/x-www-form-urlencoded" },
    body: new URLSearchParams({ data, signature }).toString(),
  });

  const body = (await response.json()) as Record<string, unknown>;
  const succeeded = response.ok && body.status === "success";
  return { succeeded, message: body.message as string | undefined };
}
