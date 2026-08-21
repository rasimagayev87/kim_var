/**
 * Apple App Store / Google Play in-app purchase verification — VIP
 * (`users/{uid}.premium`, `premiumExpiresAt`), fully separate from the
 * Epoint module: Apple/Google are the payment processors here, this
 * app never sees card data or a receipt from Epoint for these.
 *
 * Apple: uses Apple's own official Node SDK
 * (@apple/app-store-server-library) rather than hand-rolling JWS
 * signature/certificate-chain verification — that's exactly the kind
 * of crypto code a subtle bug in makes a forged transaction look
 * valid. `serverVerificationData` from the `in_app_purchase` Flutter
 * package on iOS is StoreKit2's signed transaction JWS directly (see
 * that package's own source comment: "receiptData is the JWS
 * representation of the transaction") — not a legacy base64 receipt,
 * so `verifyAndDecodeTransaction` is the right call, not the older
 * verifyReceipt endpoint.
 *
 * Google: uses Google's own official API client (googleapis), whose
 * `androidpublisher` service handles the OAuth2 service-account
 * exchange itself — no hand-rolled JWT signing needed there either.
 */
import { readFileSync } from "fs";
import { join } from "path";
import { Environment as AppleEnvironment, SignedDataVerifier } from "@apple/app-store-server-library";
import { google } from "googleapis";

/**
 * Apple's own publicly-published root CA (downloaded from
 * apple.com/certificateauthority/, not a secret) — the trust anchor
 * `SignedDataVerifier` chains every transaction/notification's
 * certificate up to. Bundled as a file rather than fetched at runtime
 * so a transient network blip can't stop this app from verifying
 * purchases.
 */
const appleRootCertificate = readFileSync(join(__dirname, "certs", "AppleRootCA-G3.cer"));

export interface AppleVerifiedTransaction {
  productId: string;
  transactionId: string;
  originalTransactionId: string;
  /** Milliseconds since epoch — undefined for a non-subscription (one-time) product, never the case for VIP's own SKUs. */
  expiresDateMs: number | undefined;
  revoked: boolean;
}

function appleVerifier(bundleId: string, environment: "Sandbox" | "Production", appAppleId: number | undefined): SignedDataVerifier {
  return new SignedDataVerifier(
    [appleRootCertificate],
    true,
    environment === "Production" ? AppleEnvironment.PRODUCTION : AppleEnvironment.SANDBOX,
    bundleId,
    appAppleId,
  );
}

/** Verifies a StoreKit2 signed transaction (the client's `serverVerificationData`) came from Apple, unmodified, for THIS app. Throws `VerificationException` if not. */
export async function verifyAppleTransaction(params: {
  signedTransactionInfo: string;
  bundleId: string;
  environment: "Sandbox" | "Production";
  appAppleId: number | undefined;
}): Promise<AppleVerifiedTransaction> {
  const decoded = await appleVerifier(params.bundleId, params.environment, params.appAppleId).verifyAndDecodeTransaction(
    params.signedTransactionInfo,
  );
  return {
    productId: decoded.productId ?? "",
    transactionId: decoded.transactionId ?? "",
    originalTransactionId: decoded.originalTransactionId ?? "",
    expiresDateMs: decoded.expiresDate,
    revoked: decoded.revocationDate !== undefined,
  };
}

/** Verifies an incoming App Store Server Notifications V2 `signedPayload` and decodes it — the RTDN webhook's entire trust boundary. */
export async function verifyAppleNotification(params: {
  signedPayload: string;
  bundleId: string;
  environment: "Sandbox" | "Production";
  appAppleId: number | undefined;
}) {
  return appleVerifier(params.bundleId, params.environment, params.appAppleId).verifyAndDecodeNotification(params.signedPayload);
}

export interface GoogleVerifiedSubscription {
  productId: string;
  /** Milliseconds since epoch. */
  expiryTimeMs: number;
  /** e.g. "SUBSCRIPTION_STATE_ACTIVE", "SUBSCRIPTION_STATE_CANCELED", "SUBSCRIPTION_STATE_EXPIRED" — see Google's own `SubscriptionState` enum. */
  subscriptionState: string;
}

/**
 * Confirms a Google Play purchase token is real and current — always
 * hits Google's live `subscriptionsv2.get` (never trusts the token's
 * mere presence), which is also how `googlePlayRtdn` re-confirms
 * status on every renewal/cancellation notification rather than
 * trusting whatever the notification payload itself claims.
 */
export async function verifyGoogleSubscription(params: {
  serviceAccountJson: string;
  packageName: string;
  purchaseToken: string;
}): Promise<GoogleVerifiedSubscription> {
  const credentials = JSON.parse(params.serviceAccountJson);
  const auth = new google.auth.GoogleAuth({ credentials, scopes: ["https://www.googleapis.com/auth/androidpublisher"] });
  const androidpublisher = google.androidpublisher({ version: "v3", auth });
  const res = await androidpublisher.purchases.subscriptionsv2.get({ packageName: params.packageName, token: params.purchaseToken });

  const lineItem = res.data.lineItems?.[0];
  const expiryTimeMs = lineItem?.expiryTime ? new Date(lineItem.expiryTime).getTime() : 0;
  return {
    productId: lineItem?.productId ?? "",
    expiryTimeMs,
    subscriptionState: res.data.subscriptionState ?? "",
  };
}
