import 'package:cloud_functions/cloud_functions.dart';

/// Shared options for every `httpsCallable` in the app.
///
/// Firebase's default callable timeout is SIXTY SECONDS, and none of
/// the 39 call sites overrode it. Any callable that could not reach the
/// backend therefore spun a progress indicator for a full minute before
/// failing — which is what "the payment screen spins forever" was.
///
/// It is not a hypothetical: the same day this was written, the app was
/// measured being cut off from the network in the background (Android's
/// RESTRICTED standby bucket, `isBlocked=true` in `netd`), and
/// `getDiscoverCandidates` was observed returning UNAVAILABLE on a
/// device with working Wi-Fi.
///
/// Twenty seconds is chosen against the flows a user is WATCHING: a
/// checkout confirmation, a profile save, a venue submission. Past
/// roughly ten seconds a spinner reads as broken, so the ceiling exists
/// to produce an error message people can act on rather than an
/// indefinite wait. Every callable in this app is a short request —
/// none does long server-side work — so a legitimate call has finished
/// long before this.
const kCallableTimeout = Duration(seconds: 20);

/// Longer ceiling for the few calls that legitimately wait on a THIRD
/// PARTY rather than on our own backend — the Epoint checkout and
/// saved-card charge both make an outbound payment-gateway request
/// inside the function. Still bounded: an unbounded payment spinner is
/// the worst of the set, because the user cannot tell whether their
/// money moved.
const kPaymentCallableTimeout = Duration(seconds: 40);

HttpsCallableOptions callableOptions([Duration timeout = kCallableTimeout]) =>
    HttpsCallableOptions(timeout: timeout);
