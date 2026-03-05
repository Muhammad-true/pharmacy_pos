// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'multi_receipt_notifier.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

String _$multiReceiptStateHash() => r'859f57b4beffe033bad34d01e675f3fbb764be9e';

/// Состояние нескольких активных чеков
///
/// Copied from [MultiReceiptState].
@ProviderFor(MultiReceiptState)
final multiReceiptStateProvider =
    NotifierProvider<MultiReceiptState, Map<String, ActiveReceipt>>.internal(
      MultiReceiptState.new,
      name: r'multiReceiptStateProvider',
      debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
          ? null
          : _$multiReceiptStateHash,
      dependencies: null,
      allTransitiveDependencies: null,
    );

typedef _$MultiReceiptState = Notifier<Map<String, ActiveReceipt>>;
// ignore_for_file: type=lint
// ignore_for_file: subtype_of_sealed_class, invalid_use_of_internal_member, invalid_use_of_visible_for_testing_member, deprecated_member_use_from_same_package
