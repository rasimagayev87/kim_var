import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Was the gate every "requires a verified account" action went
/// through, back when a separate phone-OTP verification step existed.
/// That step is gone (Faza 1 of the auth rewrite) — every caller still
/// invokes this, so it stays as a permanent pass-through until Faza 3
/// removes all 28 call sites outright, rather than touching every one
/// of them in this same change.
Future<bool> requireVerified(BuildContext context, WidgetRef ref) async => true;
