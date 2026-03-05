// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'receipt_notifier.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

String _$receiptStateHash() => r'308b9e171a6fb4a78599444bc379ba236bf7e62f';

/// Состояние чека (работает с текущим активным чеком из multiReceiptStateProvider)
///
/// Copied from [ReceiptState].
@ProviderFor(ReceiptState)
final receiptStateProvider =
    AutoDisposeNotifierProvider<ReceiptState, Receipt>.internal(
      ReceiptState.new,
      name: r'receiptStateProvider',
      debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
          ? null
          : _$receiptStateHash,
      dependencies: null,
      allTransitiveDependencies: null,
    );

typedef _$ReceiptState = AutoDisposeNotifier<Receipt>;
// ignore_for_file: type=lint
// ignore_for_file: subtype_of_sealed_class, invalid_use_of_internal_member, invalid_use_of_visible_for_testing_member, deprecated_member_use_from_same_package
