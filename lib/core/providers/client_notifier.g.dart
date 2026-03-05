// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'client_notifier.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

String _$clientReceiptsHistoryHash() =>
    r'b376c84126b4567be89e053c4aebbb23dfa99948';

/// Copied from Dart SDK
class _SystemHash {
  _SystemHash._();

  static int combine(int hash, int value) {
    // ignore: parameter_assignments
    hash = 0x1fffffff & (hash + value);
    // ignore: parameter_assignments
    hash = 0x1fffffff & (hash + ((0x0007ffff & hash) << 10));
    return hash ^ (hash >> 6);
  }

  static int finish(int hash) {
    // ignore: parameter_assignments
    hash = 0x1fffffff & (hash + ((0x03ffffff & hash) << 3));
    // ignore: parameter_assignments
    hash = hash ^ (hash >> 11);
    return 0x1fffffff & (hash + ((0x00003fff & hash) << 15));
  }
}

/// Провайдер для истории чеков клиента
///
/// Copied from [clientReceiptsHistory].
@ProviderFor(clientReceiptsHistory)
const clientReceiptsHistoryProvider = ClientReceiptsHistoryFamily();

/// Провайдер для истории чеков клиента
///
/// Copied from [clientReceiptsHistory].
class ClientReceiptsHistoryFamily
    extends Family<AsyncValue<List<ReceiptHistory>>> {
  /// Провайдер для истории чеков клиента
  ///
  /// Copied from [clientReceiptsHistory].
  const ClientReceiptsHistoryFamily();

  /// Провайдер для истории чеков клиента
  ///
  /// Copied from [clientReceiptsHistory].
  ClientReceiptsHistoryProvider call(int clientId) {
    return ClientReceiptsHistoryProvider(clientId);
  }

  @override
  ClientReceiptsHistoryProvider getProviderOverride(
    covariant ClientReceiptsHistoryProvider provider,
  ) {
    return call(provider.clientId);
  }

  static const Iterable<ProviderOrFamily>? _dependencies = null;

  @override
  Iterable<ProviderOrFamily>? get dependencies => _dependencies;

  static const Iterable<ProviderOrFamily>? _allTransitiveDependencies = null;

  @override
  Iterable<ProviderOrFamily>? get allTransitiveDependencies =>
      _allTransitiveDependencies;

  @override
  String? get name => r'clientReceiptsHistoryProvider';
}

/// Провайдер для истории чеков клиента
///
/// Copied from [clientReceiptsHistory].
class ClientReceiptsHistoryProvider
    extends AutoDisposeFutureProvider<List<ReceiptHistory>> {
  /// Провайдер для истории чеков клиента
  ///
  /// Copied from [clientReceiptsHistory].
  ClientReceiptsHistoryProvider(int clientId)
    : this._internal(
        (ref) =>
            clientReceiptsHistory(ref as ClientReceiptsHistoryRef, clientId),
        from: clientReceiptsHistoryProvider,
        name: r'clientReceiptsHistoryProvider',
        debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
            ? null
            : _$clientReceiptsHistoryHash,
        dependencies: ClientReceiptsHistoryFamily._dependencies,
        allTransitiveDependencies:
            ClientReceiptsHistoryFamily._allTransitiveDependencies,
        clientId: clientId,
      );

  ClientReceiptsHistoryProvider._internal(
    super._createNotifier, {
    required super.name,
    required super.dependencies,
    required super.allTransitiveDependencies,
    required super.debugGetCreateSourceHash,
    required super.from,
    required this.clientId,
  }) : super.internal();

  final int clientId;

  @override
  Override overrideWith(
    FutureOr<List<ReceiptHistory>> Function(ClientReceiptsHistoryRef provider)
    create,
  ) {
    return ProviderOverride(
      origin: this,
      override: ClientReceiptsHistoryProvider._internal(
        (ref) => create(ref as ClientReceiptsHistoryRef),
        from: from,
        name: null,
        dependencies: null,
        allTransitiveDependencies: null,
        debugGetCreateSourceHash: null,
        clientId: clientId,
      ),
    );
  }

  @override
  AutoDisposeFutureProviderElement<List<ReceiptHistory>> createElement() {
    return _ClientReceiptsHistoryProviderElement(this);
  }

  @override
  bool operator ==(Object other) {
    return other is ClientReceiptsHistoryProvider && other.clientId == clientId;
  }

  @override
  int get hashCode {
    var hash = _SystemHash.combine(0, runtimeType.hashCode);
    hash = _SystemHash.combine(hash, clientId.hashCode);

    return _SystemHash.finish(hash);
  }
}

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
mixin ClientReceiptsHistoryRef
    on AutoDisposeFutureProviderRef<List<ReceiptHistory>> {
  /// The parameter `clientId` of this provider.
  int get clientId;
}

class _ClientReceiptsHistoryProviderElement
    extends AutoDisposeFutureProviderElement<List<ReceiptHistory>>
    with ClientReceiptsHistoryRef {
  _ClientReceiptsHistoryProviderElement(super.provider);

  @override
  int get clientId => (origin as ClientReceiptsHistoryProvider).clientId;
}

String _$clientStateHash() => r'56f8a8dcc76893b1984283aa1e9e77e649940cf8';

/// Состояние клиента
///
/// Copied from [ClientState].
@ProviderFor(ClientState)
final clientStateProvider =
    AutoDisposeNotifierProvider<ClientState, Client?>.internal(
      ClientState.new,
      name: r'clientStateProvider',
      debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
          ? null
          : _$clientStateHash,
      dependencies: null,
      allTransitiveDependencies: null,
    );

typedef _$ClientState = AutoDisposeNotifier<Client?>;
// ignore_for_file: type=lint
// ignore_for_file: subtype_of_sealed_class, invalid_use_of_internal_member, invalid_use_of_visible_for_testing_member, deprecated_member_use_from_same_package
