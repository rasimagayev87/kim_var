#!/usr/bin/env bash
# Runs the Firestore/Storage rules regression suite against the local
# emulators. See README.md for what this covers and why.
set -euo pipefail
cd "$(dirname "$0")"

# JAVA_HOME workaround — the emulators are JVM-based and this machine's
# system `java` has been observed missing/broken ("Unable to locate a
# Java Runtime"). Android Studio ships its own bundled JRE that works
# fine for this purpose; fall back to it ONLY if JAVA_HOME isn't already
# set AND that bundled JRE actually exists. On a machine with a normal
# working Java install (most CI runners, e.g. standard GitHub Actions
# Ubuntu images already have `java`), this block does nothing — no
# workaround needed there.
if [ -z "${JAVA_HOME:-}" ] && [ -d "/Applications/Android Studio.app/Contents/jbr/Contents/Home" ]; then
  export JAVA_HOME="/Applications/Android Studio.app/Contents/jbr/Contents/Home"
  export PATH="$JAVA_HOME/bin:$PATH"
fi

if ! command -v firebase >/dev/null 2>&1; then
  echo "firebase-tools CLI not found on PATH — install it globally first: npm install -g firebase-tools" >&2
  exit 1
fi

npm install --no-save

# `demo-` prefix is load-bearing, not decorative — the Firebase CLI/SDK
# never associates a `demo-*` project id with a real GCP project, so
# there is no code path here that could reach production even by
# accident. Do not change this to the real project id.
firebase emulators:exec \
  --project=demo-peakpin-rules-test \
  --only firestore,storage \
  --config ../../firebase.json \
  "npx tsx --test *.test.ts"
