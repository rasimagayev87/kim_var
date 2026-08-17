/// Matches the stable marker `enforceEmailLinkRateLimit` (Cloud
/// Functions' `beforeEmailSent` blocking function) embeds in its
/// `HttpsError` message — the specific error *code* doesn't reliably
/// survive a blocking-function rejection through to the client SDK,
/// but the message text does.
bool isRateLimitError(Object error) => error.toString().contains('RATE_LIMIT_EXCEEDED');
