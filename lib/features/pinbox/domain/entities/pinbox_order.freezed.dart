// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'pinbox_order.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

T _$identity<T>(T value) => value;

final _privateConstructorUsedError = UnsupportedError(
  'It seems like you constructed your class using `MyClass._()`. This constructor is only meant to be used by freezed and you are not supposed to need it nor use it.\nPlease check the documentation here for more information: https://github.com/rrousselGit/freezed#adding-getters-and-methods-to-our-models',
);

PinBoxOrder _$PinBoxOrderFromJson(Map<String, dynamic> json) {
  return _PinBoxOrder.fromJson(json);
}

/// @nodoc
mixin _$PinBoxOrder {
  String get id => throw _privateConstructorUsedError;
  String get pinboxId => throw _privateConstructorUsedError;
  String get venueId => throw _privateConstructorUsedError;
  String get buyerId => throw _privateConstructorUsedError;
  int get quantity => throw _privateConstructorUsedError;
  double get amountPaid => throw _privateConstructorUsedError;
  @PinBoxOrderStatusConverter()
  PinBoxOrderStatus get status => throw _privateConstructorUsedError;

  /// Short-lived, signed — regenerated on demand by a Cloud Function
  /// while the order is still 'reserved' and inside the pickup
  /// window, NOT a static value baked in at order-creation time (see
  /// PinBox Faza 8's QR-refresh doc comment for why a static token
  /// would defeat the whole point of the screenshot-resistance
  /// requirement). Null once [status] is no longer 'reserved'.
  String? get qrToken => throw _privateConstructorUsedError;
  @NullableTimestampConverter()
  DateTime? get qrTokenExpiresAt => throw _privateConstructorUsedError;
  @TimestampConverter()
  DateTime get createdAt => throw _privateConstructorUsedError;

  /// Set once, when [status] flips to 'completed' via the venue-side
  /// redemption scan/confirm (PinBox Faza 9). Null otherwise.
  @NullableTimestampConverter()
  DateTime? get redeemedAt => throw _privateConstructorUsedError;

  /// Serializes this PinBoxOrder to a JSON map.
  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;

  /// Create a copy of PinBoxOrder
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $PinBoxOrderCopyWith<PinBoxOrder> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $PinBoxOrderCopyWith<$Res> {
  factory $PinBoxOrderCopyWith(
    PinBoxOrder value,
    $Res Function(PinBoxOrder) then,
  ) = _$PinBoxOrderCopyWithImpl<$Res, PinBoxOrder>;
  @useResult
  $Res call({
    String id,
    String pinboxId,
    String venueId,
    String buyerId,
    int quantity,
    double amountPaid,
    @PinBoxOrderStatusConverter() PinBoxOrderStatus status,
    String? qrToken,
    @NullableTimestampConverter() DateTime? qrTokenExpiresAt,
    @TimestampConverter() DateTime createdAt,
    @NullableTimestampConverter() DateTime? redeemedAt,
  });
}

/// @nodoc
class _$PinBoxOrderCopyWithImpl<$Res, $Val extends PinBoxOrder>
    implements $PinBoxOrderCopyWith<$Res> {
  _$PinBoxOrderCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of PinBoxOrder
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? pinboxId = null,
    Object? venueId = null,
    Object? buyerId = null,
    Object? quantity = null,
    Object? amountPaid = null,
    Object? status = null,
    Object? qrToken = freezed,
    Object? qrTokenExpiresAt = freezed,
    Object? createdAt = null,
    Object? redeemedAt = freezed,
  }) {
    return _then(
      _value.copyWith(
            id: null == id
                ? _value.id
                : id // ignore: cast_nullable_to_non_nullable
                      as String,
            pinboxId: null == pinboxId
                ? _value.pinboxId
                : pinboxId // ignore: cast_nullable_to_non_nullable
                      as String,
            venueId: null == venueId
                ? _value.venueId
                : venueId // ignore: cast_nullable_to_non_nullable
                      as String,
            buyerId: null == buyerId
                ? _value.buyerId
                : buyerId // ignore: cast_nullable_to_non_nullable
                      as String,
            quantity: null == quantity
                ? _value.quantity
                : quantity // ignore: cast_nullable_to_non_nullable
                      as int,
            amountPaid: null == amountPaid
                ? _value.amountPaid
                : amountPaid // ignore: cast_nullable_to_non_nullable
                      as double,
            status: null == status
                ? _value.status
                : status // ignore: cast_nullable_to_non_nullable
                      as PinBoxOrderStatus,
            qrToken: freezed == qrToken
                ? _value.qrToken
                : qrToken // ignore: cast_nullable_to_non_nullable
                      as String?,
            qrTokenExpiresAt: freezed == qrTokenExpiresAt
                ? _value.qrTokenExpiresAt
                : qrTokenExpiresAt // ignore: cast_nullable_to_non_nullable
                      as DateTime?,
            createdAt: null == createdAt
                ? _value.createdAt
                : createdAt // ignore: cast_nullable_to_non_nullable
                      as DateTime,
            redeemedAt: freezed == redeemedAt
                ? _value.redeemedAt
                : redeemedAt // ignore: cast_nullable_to_non_nullable
                      as DateTime?,
          )
          as $Val,
    );
  }
}

/// @nodoc
abstract class _$$PinBoxOrderImplCopyWith<$Res>
    implements $PinBoxOrderCopyWith<$Res> {
  factory _$$PinBoxOrderImplCopyWith(
    _$PinBoxOrderImpl value,
    $Res Function(_$PinBoxOrderImpl) then,
  ) = __$$PinBoxOrderImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call({
    String id,
    String pinboxId,
    String venueId,
    String buyerId,
    int quantity,
    double amountPaid,
    @PinBoxOrderStatusConverter() PinBoxOrderStatus status,
    String? qrToken,
    @NullableTimestampConverter() DateTime? qrTokenExpiresAt,
    @TimestampConverter() DateTime createdAt,
    @NullableTimestampConverter() DateTime? redeemedAt,
  });
}

/// @nodoc
class __$$PinBoxOrderImplCopyWithImpl<$Res>
    extends _$PinBoxOrderCopyWithImpl<$Res, _$PinBoxOrderImpl>
    implements _$$PinBoxOrderImplCopyWith<$Res> {
  __$$PinBoxOrderImplCopyWithImpl(
    _$PinBoxOrderImpl _value,
    $Res Function(_$PinBoxOrderImpl) _then,
  ) : super(_value, _then);

  /// Create a copy of PinBoxOrder
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? pinboxId = null,
    Object? venueId = null,
    Object? buyerId = null,
    Object? quantity = null,
    Object? amountPaid = null,
    Object? status = null,
    Object? qrToken = freezed,
    Object? qrTokenExpiresAt = freezed,
    Object? createdAt = null,
    Object? redeemedAt = freezed,
  }) {
    return _then(
      _$PinBoxOrderImpl(
        id: null == id
            ? _value.id
            : id // ignore: cast_nullable_to_non_nullable
                  as String,
        pinboxId: null == pinboxId
            ? _value.pinboxId
            : pinboxId // ignore: cast_nullable_to_non_nullable
                  as String,
        venueId: null == venueId
            ? _value.venueId
            : venueId // ignore: cast_nullable_to_non_nullable
                  as String,
        buyerId: null == buyerId
            ? _value.buyerId
            : buyerId // ignore: cast_nullable_to_non_nullable
                  as String,
        quantity: null == quantity
            ? _value.quantity
            : quantity // ignore: cast_nullable_to_non_nullable
                  as int,
        amountPaid: null == amountPaid
            ? _value.amountPaid
            : amountPaid // ignore: cast_nullable_to_non_nullable
                  as double,
        status: null == status
            ? _value.status
            : status // ignore: cast_nullable_to_non_nullable
                  as PinBoxOrderStatus,
        qrToken: freezed == qrToken
            ? _value.qrToken
            : qrToken // ignore: cast_nullable_to_non_nullable
                  as String?,
        qrTokenExpiresAt: freezed == qrTokenExpiresAt
            ? _value.qrTokenExpiresAt
            : qrTokenExpiresAt // ignore: cast_nullable_to_non_nullable
                  as DateTime?,
        createdAt: null == createdAt
            ? _value.createdAt
            : createdAt // ignore: cast_nullable_to_non_nullable
                  as DateTime,
        redeemedAt: freezed == redeemedAt
            ? _value.redeemedAt
            : redeemedAt // ignore: cast_nullable_to_non_nullable
                  as DateTime?,
      ),
    );
  }
}

/// @nodoc
@JsonSerializable()
class _$PinBoxOrderImpl extends _PinBoxOrder {
  const _$PinBoxOrderImpl({
    required this.id,
    required this.pinboxId,
    required this.venueId,
    required this.buyerId,
    required this.quantity,
    required this.amountPaid,
    @PinBoxOrderStatusConverter() this.status = PinBoxOrderStatus.reserved,
    this.qrToken,
    @NullableTimestampConverter() this.qrTokenExpiresAt,
    @TimestampConverter() required this.createdAt,
    @NullableTimestampConverter() this.redeemedAt,
  }) : super._();

  factory _$PinBoxOrderImpl.fromJson(Map<String, dynamic> json) =>
      _$$PinBoxOrderImplFromJson(json);

  @override
  final String id;
  @override
  final String pinboxId;
  @override
  final String venueId;
  @override
  final String buyerId;
  @override
  final int quantity;
  @override
  final double amountPaid;
  @override
  @JsonKey()
  @PinBoxOrderStatusConverter()
  final PinBoxOrderStatus status;

  /// Short-lived, signed — regenerated on demand by a Cloud Function
  /// while the order is still 'reserved' and inside the pickup
  /// window, NOT a static value baked in at order-creation time (see
  /// PinBox Faza 8's QR-refresh doc comment for why a static token
  /// would defeat the whole point of the screenshot-resistance
  /// requirement). Null once [status] is no longer 'reserved'.
  @override
  final String? qrToken;
  @override
  @NullableTimestampConverter()
  final DateTime? qrTokenExpiresAt;
  @override
  @TimestampConverter()
  final DateTime createdAt;

  /// Set once, when [status] flips to 'completed' via the venue-side
  /// redemption scan/confirm (PinBox Faza 9). Null otherwise.
  @override
  @NullableTimestampConverter()
  final DateTime? redeemedAt;

  @override
  String toString() {
    return 'PinBoxOrder(id: $id, pinboxId: $pinboxId, venueId: $venueId, buyerId: $buyerId, quantity: $quantity, amountPaid: $amountPaid, status: $status, qrToken: $qrToken, qrTokenExpiresAt: $qrTokenExpiresAt, createdAt: $createdAt, redeemedAt: $redeemedAt)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$PinBoxOrderImpl &&
            (identical(other.id, id) || other.id == id) &&
            (identical(other.pinboxId, pinboxId) ||
                other.pinboxId == pinboxId) &&
            (identical(other.venueId, venueId) || other.venueId == venueId) &&
            (identical(other.buyerId, buyerId) || other.buyerId == buyerId) &&
            (identical(other.quantity, quantity) ||
                other.quantity == quantity) &&
            (identical(other.amountPaid, amountPaid) ||
                other.amountPaid == amountPaid) &&
            (identical(other.status, status) || other.status == status) &&
            (identical(other.qrToken, qrToken) || other.qrToken == qrToken) &&
            (identical(other.qrTokenExpiresAt, qrTokenExpiresAt) ||
                other.qrTokenExpiresAt == qrTokenExpiresAt) &&
            (identical(other.createdAt, createdAt) ||
                other.createdAt == createdAt) &&
            (identical(other.redeemedAt, redeemedAt) ||
                other.redeemedAt == redeemedAt));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(
    runtimeType,
    id,
    pinboxId,
    venueId,
    buyerId,
    quantity,
    amountPaid,
    status,
    qrToken,
    qrTokenExpiresAt,
    createdAt,
    redeemedAt,
  );

  /// Create a copy of PinBoxOrder
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$PinBoxOrderImplCopyWith<_$PinBoxOrderImpl> get copyWith =>
      __$$PinBoxOrderImplCopyWithImpl<_$PinBoxOrderImpl>(this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$$PinBoxOrderImplToJson(this);
  }
}

abstract class _PinBoxOrder extends PinBoxOrder {
  const factory _PinBoxOrder({
    required final String id,
    required final String pinboxId,
    required final String venueId,
    required final String buyerId,
    required final int quantity,
    required final double amountPaid,
    @PinBoxOrderStatusConverter() final PinBoxOrderStatus status,
    final String? qrToken,
    @NullableTimestampConverter() final DateTime? qrTokenExpiresAt,
    @TimestampConverter() required final DateTime createdAt,
    @NullableTimestampConverter() final DateTime? redeemedAt,
  }) = _$PinBoxOrderImpl;
  const _PinBoxOrder._() : super._();

  factory _PinBoxOrder.fromJson(Map<String, dynamic> json) =
      _$PinBoxOrderImpl.fromJson;

  @override
  String get id;
  @override
  String get pinboxId;
  @override
  String get venueId;
  @override
  String get buyerId;
  @override
  int get quantity;
  @override
  double get amountPaid;
  @override
  @PinBoxOrderStatusConverter()
  PinBoxOrderStatus get status;

  /// Short-lived, signed — regenerated on demand by a Cloud Function
  /// while the order is still 'reserved' and inside the pickup
  /// window, NOT a static value baked in at order-creation time (see
  /// PinBox Faza 8's QR-refresh doc comment for why a static token
  /// would defeat the whole point of the screenshot-resistance
  /// requirement). Null once [status] is no longer 'reserved'.
  @override
  String? get qrToken;
  @override
  @NullableTimestampConverter()
  DateTime? get qrTokenExpiresAt;
  @override
  @TimestampConverter()
  DateTime get createdAt;

  /// Set once, when [status] flips to 'completed' via the venue-side
  /// redemption scan/confirm (PinBox Faza 9). Null otherwise.
  @override
  @NullableTimestampConverter()
  DateTime? get redeemedAt;

  /// Create a copy of PinBoxOrder
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$PinBoxOrderImplCopyWith<_$PinBoxOrderImpl> get copyWith =>
      throw _privateConstructorUsedError;
}
