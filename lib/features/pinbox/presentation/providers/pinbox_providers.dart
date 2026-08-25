import 'dart:io';

import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart' as fb;
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';

import '../../../../core/utils/app_logger.dart';
import '../../../location/presentation/providers/location_providers.dart';
import '../../../offers/presentation/providers/offer_providers.dart' show selectedOfferCategoryFilterProvider;
import '../../../profile/presentation/providers/profile_providers.dart';
import '../../../venues/domain/entities/venue.dart' show VenueCategory;
import '../../data/datasources/firebase_pinbox_remote_datasource.dart';
import '../../data/datasources/pinbox_remote_datasource.dart';
import '../../data/repositories/firebase_pinbox_repository.dart';
import '../../domain/entities/pinbox.dart';
import '../../domain/entities/pinbox_order.dart';
import '../../domain/pinbox_failure.dart';
import '../../domain/repositories/pinbox_repository.dart';
import '../../domain/usecases/create_pinbox_usecase.dart';
import '../../domain/usecases/update_pinbox_usecase.dart';

export '../../domain/repositories/pinbox_repository.dart' show PinBoxWithDistance;

final pinboxRemoteDatasourceProvider = Provider<PinBoxRemoteDatasource>((ref) => FirebasePinBoxRemoteDatasource());

final pinboxRepositoryProvider = Provider<PinBoxRepository>((ref) {
  return FirebasePinBoxRepository(datasource: ref.watch(pinboxRemoteDatasourceProvider));
});

final createPinBoxUseCaseProvider = Provider<CreatePinBoxUseCase>((ref) {
  return CreatePinBoxUseCase(ref.watch(pinboxRepositoryProvider));
});

final updatePinBoxUseCaseProvider = Provider<UpdatePinBoxUseCase>((ref) {
  return UpdatePinBoxUseCase(ref.watch(pinboxRepositoryProvider));
});

String? _currentUid() => fb.FirebaseAuth.instance.currentUser?.uid;

final pinboxByIdProvider = StreamProvider.family<PinBox?, String>((ref, pinboxId) {
  return ref.watch(pinboxRepositoryProvider).watchPinBox(pinboxId);
});

/// Backs PinBox Faza 8's ticket screen — live status, `qrToken`/
/// `qrTokenExpiresAt` as last written by `generatePinBoxQrToken`.
final pinboxOrderByIdProvider = StreamProvider.autoDispose.family<PinBoxOrder?, String>((ref, orderId) {
  return ref.watch(pinboxRepositoryProvider).watchPinBoxOrder(orderId);
});

/// Every PinBox the signed-in user has published — mirrors `myOffersProvider`.
/// Backs Qutularım's "Yaratdıqlarım" (PinBox Faza 11).
final myPinBoxesProvider = StreamProvider.autoDispose<List<PinBox>>((ref) {
  final uid = _currentUid();
  if (uid == null) return Stream.value(const []);
  return ref.watch(pinboxRepositoryProvider).watchMyPinBoxes(uid);
});

/// Every order the signed-in user has bought — backs Qutularım's
/// "Aldıqlarım" (PinBox Faza 11).
final myPinBoxOrdersProvider = StreamProvider.autoDispose<List<PinBoxOrder>>((ref) {
  final uid = _currentUid();
  if (uid == null) return Stream.value(const []);
  return ref.watch(pinboxRepositoryProvider).watchMyOrders(uid);
});

/// Drives PinBox creation — same "log internally, callback the UI a
/// typed outcome" contract as `OfferController`.
class PinBoxController {
  PinBoxController(this._ref);

  final Ref _ref;

  Future<String?> createPinBox({
    required String venueId,
    required String venueName,
    String? venuePhotoUrl,
    required double lat,
    required double lng,
    required String address,
    String? country,
    required VenueCategory category,
    required String title,
    required String description,
    required File? photo,
    required double? originalPrice,
    required double? pinboxPrice,
    required int? stockTotal,
    required DateTime? pickupWindowStart,
    required DateTime? pickupWindowEnd,
    required void Function(List<PinBoxFieldError> missing) onValidationError,
    required void Function() onError,
    ValueChanged<double>? onUploadProgress,
    ValueChanged<VoidCallback>? onUploadTaskReady,
  }) async {
    final uid = _currentUid();
    if (uid == null) return null;

    try {
      final pinboxId = await _ref.read(createPinBoxUseCaseProvider).call(
            ownerId: uid,
            venueId: venueId,
            venueName: venueName,
            venuePhotoUrl: venuePhotoUrl,
            lat: lat,
            lng: lng,
            address: address,
            country: country,
            category: category,
            title: title,
            description: description,
            photo: photo,
            originalPrice: originalPrice,
            pinboxPrice: pinboxPrice,
            stockTotal: stockTotal,
            pickupWindowStart: pickupWindowStart,
            pickupWindowEnd: pickupWindowEnd,
            onUploadProgress: onUploadProgress,
            onUploadTaskReady: onUploadTaskReady,
          );
      return pinboxId;
    } on PinBoxValidationException catch (e) {
      onValidationError(e.missingFields);
      return null;
    } catch (e, st) {
      logError('pinbox_providers.createPinBox', e, st);
      onError();
      return null;
    }
  }

  Future<bool> updatePinBox({
    required String pinboxId,
    required String title,
    required String description,
    required File? photo,
    required bool hasExistingPhoto,
    required double? originalPrice,
    required double? pinboxPrice,
    required DateTime? pickupWindowStart,
    required DateTime? pickupWindowEnd,
    required void Function(List<PinBoxFieldError> missing) onValidationError,
    required void Function() onError,
    ValueChanged<double>? onUploadProgress,
    ValueChanged<VoidCallback>? onUploadTaskReady,
  }) async {
    try {
      await _ref.read(updatePinBoxUseCaseProvider).call(
            pinboxId: pinboxId,
            title: title,
            description: description,
            photo: photo,
            hasExistingPhoto: hasExistingPhoto,
            originalPrice: originalPrice,
            pinboxPrice: pinboxPrice,
            pickupWindowStart: pickupWindowStart,
            pickupWindowEnd: pickupWindowEnd,
            onUploadProgress: onUploadProgress,
            onUploadTaskReady: onUploadTaskReady,
          );
      return true;
    } on PinBoxValidationException catch (e) {
      onValidationError(e.missingFields);
      return false;
    } catch (e, st) {
      logError('pinbox_providers.updatePinBox', e, st);
      onError();
      return false;
    }
  }

  Future<bool> deletePinBox(String pinboxId, {required void Function() onError}) async {
    try {
      await _ref.read(pinboxRepositoryProvider).deletePinBox(pinboxId);
      return true;
    } catch (e, st) {
      logError('pinbox_providers.deletePinBox', e, st);
      onError();
      return false;
    }
  }

  /// Called right after a successful [updatePinBox] on an `active`
  /// PinBox — mirrors `VenueController.resubmitVenue`'s "best-effort,
  /// don't fail the whole save" contract.
  Future<bool> resubmitPinBox(String pinboxId) async {
    try {
      await _ref.read(pinboxRepositoryProvider).resubmitPinBox(pinboxId);
      return true;
    } catch (e, st) {
      logError('pinbox_providers.resubmitPinBox', e, st);
      return false;
    }
  }
}

final pinboxControllerProvider = Provider<PinBoxController>((ref) => PinBoxController(ref));

/// [PinBoxReserveOutcome.soldOut]/[PinBoxReserveOutcome.expired] are the
/// two failures the UI needs to tell apart from a generic error — sold
/// out to someone else, or the pickup window closed, between the buyer
/// opening Checkout and pressing "Ödə" (the Cloud Function's own
/// transaction is the actual guard against both races; this just
/// surfaces its `failed-precondition` reason distinctly).
enum PinBoxReserveOutcome { success, soldOut, expired, error }

/// On [PinBoxReserveOutcome.success], the order is `awaiting_payment` —
/// stock is already held, but [orderId] only becomes redeemable once
/// [checkoutUrl] (via `presentEpointCheckout`, keyed by [paymentId]) is
/// completed and `epointWebhook` confirms the charge.
typedef PinBoxReserveResult = ({
  PinBoxReserveOutcome outcome,
  String? orderId,
  String? checkoutUrl,
  double? feeAmount,
  String? paymentId,
});

/// Drives PinBox Faza 7 checkout — a thin wrapper over the
/// `reservePinBoxOrder` Cloud Function (see that function's own doc
/// comment for why order creation/stock decrement never happens as a
/// raw client write).
class PinBoxCheckoutController {
  PinBoxCheckoutController(this._ref);

  final Ref _ref;

  Future<PinBoxReserveResult> reserveOrder(String pinboxId, {int quantity = 1}) async {
    final uid = _currentUid();
    if (uid == null) {
      return (outcome: PinBoxReserveOutcome.error, orderId: null, checkoutUrl: null, feeAmount: null, paymentId: null);
    }

    try {
      final result = await _ref.read(pinboxRepositoryProvider).reservePinBoxOrder(pinboxId: pinboxId, quantity: quantity);
      return (
        outcome: PinBoxReserveOutcome.success,
        orderId: result.orderId,
        checkoutUrl: result.checkoutUrl,
        feeAmount: result.feeAmount,
        paymentId: result.paymentId,
      );
    } on FirebaseFunctionsException catch (e, st) {
      if (e.code == 'failed-precondition') {
        return (
          outcome: e.message == 'pickup-window-ended' ? PinBoxReserveOutcome.expired : PinBoxReserveOutcome.soldOut,
          orderId: null,
          checkoutUrl: null,
          feeAmount: null,
          paymentId: null,
        );
      }
      logError('pinbox_providers.reserveOrder', e, st);
      return (outcome: PinBoxReserveOutcome.error, orderId: null, checkoutUrl: null, feeAmount: null, paymentId: null);
    } catch (e, st) {
      logError('pinbox_providers.reserveOrder', e, st);
      return (outcome: PinBoxReserveOutcome.error, orderId: null, checkoutUrl: null, feeAmount: null, paymentId: null);
    }
  }
}

final pinboxCheckoutControllerProvider = Provider<PinBoxCheckoutController>((ref) => PinBoxCheckoutController(ref));

/// [PinBoxRedeemOutcome.invalidCode] covers both "wrong code" and
/// "right code, too late" — `redeemPinBoxOrder`'s own doc comment
/// explains why those two are deliberately indistinguishable from the
/// error alone.
enum PinBoxRedeemOutcome { success, invalidCode, error }

typedef PinBoxRedeemResult = ({PinBoxRedeemOutcome outcome, String? pinboxTitle, int? quantity});

/// Drives PinBox Faza 9's venue-side redemption screen — a thin wrapper
/// over the `redeemPinBoxOrder` Cloud Function.
class PinBoxRedeemController {
  PinBoxRedeemController(this._ref);

  final Ref _ref;

  Future<PinBoxRedeemResult> redeem({required String venueId, required String code}) async {
    try {
      final result = await _ref.read(pinboxRepositoryProvider).redeemPinBoxOrder(venueId: venueId, code: code);
      return (outcome: PinBoxRedeemOutcome.success, pinboxTitle: result.pinboxTitle, quantity: result.quantity);
    } on FirebaseFunctionsException catch (e, st) {
      if (e.code == 'not-found') return (outcome: PinBoxRedeemOutcome.invalidCode, pinboxTitle: null, quantity: null);
      logError('pinbox_providers.redeem', e, st);
      return (outcome: PinBoxRedeemOutcome.error, pinboxTitle: null, quantity: null);
    } catch (e, st) {
      logError('pinbox_providers.redeem', e, st);
      return (outcome: PinBoxRedeemOutcome.error, pinboxTitle: null, quantity: null);
    }
  }
}

final pinboxRedeemControllerProvider = Provider<PinBoxRedeemController>((ref) => PinBoxRedeemController(ref));

List<PinBoxWithDistance> _withDistanceFrom(List<PinBox> pinboxes, Position position) {
  return pinboxes
      .map(
        (pinbox) => (
          pinbox: pinbox,
          distanceMeters: Geolocator.distanceBetween(position.latitude, position.longitude, pinbox.lat, pinbox.lng),
        ),
      )
      .toList();
}

/// Backs Kəşf et → Fürsətlər's PinBox chip — reuses the EXACT same
/// radius system as İnsanlar/Məkanlar/Təkliflər
/// ([selectedDiscoverModeProvider]), per the explicit product decision
/// that PinBox does NOT get its own radius model. One-shot fetch, not a
/// live stream, same reasoning as `nearbyOffersProvider`. Also mirrors
/// `nearbyOffersProvider` in reading the Fürsətlər filter sheet's
/// [selectedOfferCategoryFilterProvider] — the repository/datasource
/// already supported a `category` param end-to-end, it just wasn't
/// being passed from here.
final nearbyPinBoxesProvider = FutureProvider.autoDispose<List<PinBoxWithDistance>>((ref) async {
  final position = ref.watch(locationControllerProvider).valueOrNull;
  final selection = ref.watch(selectedDiscoverModeProvider);
  final category = ref.watch(selectedOfferCategoryFilterProvider);
  final repository = ref.watch(pinboxRepositoryProvider);

  if (position == null) return const [];

  switch (selection.mode) {
    case DiscoverRadiusMode.distance:
      return repository.fetchPinBoxesWithinRadius(
        lat: position.latitude,
        lng: position.longitude,
        radiusKm: selection.km!,
        category: category,
      );
    case DiscoverRadiusMode.country:
      final myCountry = ref.watch(profileControllerProvider.select((p) => p.country));
      if (myCountry == null) return const [];
      final pinboxes = await repository.fetchPinBoxesByCountry(myCountry, category: category);
      return _withDistanceFrom(pinboxes, position);
    case DiscoverRadiusMode.world:
      final pinboxes = await repository.fetchAllActivePinBoxes(category: category);
      return _withDistanceFrom(pinboxes, position);
  }
});
