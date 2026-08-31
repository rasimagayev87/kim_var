/**
 * The two decisions behind "this payment's listing is gone", kept free
 * of any SDK import so they can be asserted without an emulator.
 *
 * Both are one comparison, which is exactly the kind of logic that
 * disappears in a later refactor without anything looking broken —
 * the same reason `geo.ts` exists.
 */

/** One thing a payment could have been for. */
export interface PaymentTarget {
  /** Whether this payment type points at this kind of document at all. */
  applies: boolean;
  /** Whether that document was found. Meaningless when [applies] is false. */
  exists: boolean;
}

/**
 * Whether a SUCCEEDED payment has lost the thing it paid for.
 *
 * Only succeeded payments are judged. A failed charge against a
 * deleted venue is simply a failed charge: nobody is owed anything and
 * there is nothing to refund, so it takes the ordinary failure path.
 *
 * A target that does not apply to this payment type is ignored rather
 * than treated as missing — `venue_subscription` says nothing about
 * whether some offer exists.
 */
export function isPaymentTargetMissing(succeeded: boolean, targets: readonly PaymentTarget[]): boolean {
  if (!succeeded) return false;
  return targets.some((t) => t.applies && !t.exists);
}

/**
 * Whether deleting a listing should cancel a payment in this state.
 *
 * ONLY `pending`. The rest are deliberate:
 *
 * - `completed` is a record of money that actually moved. It has to
 *   outlive the venue it paid for — that is what makes it an audit
 *   trail rather than a cache of current state.
 * - `failed`, `cancelled` and `orphan_target` are already terminal.
 * - `superseded` belongs to the retry flow: another payment doc has
 *   taken over, and that one is the `pending` one this will catch.
 */
export function isCancellableOnListingDelete(status: unknown): boolean {
  return status === "pending";
}
