// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'firewall_repository_impl.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

String _$firewallRepositoryHash() =>
    r'a7bbf8906c0d63a60e57103f26dddc5d21e9378d';

/// See also [firewallRepository].
@ProviderFor(firewallRepository)
final firewallRepositoryProvider =
    AutoDisposeFutureProvider<FirewallRepository>.internal(
  firewallRepository,
  name: r'firewallRepositoryProvider',
  debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
      ? null
      : _$firewallRepositoryHash,
  dependencies: <ProviderOrFamily>[activeServerIdProvider],
  allTransitiveDependencies: <ProviderOrFamily>{
    activeServerIdProvider,
    ...?activeServerIdProvider.allTransitiveDependencies
  },
);

typedef FirewallRepositoryRef
    = AutoDisposeFutureProviderRef<FirewallRepository>;
// ignore_for_file: type=lint
// ignore_for_file: subtype_of_sealed_class, invalid_use_of_internal_member, invalid_use_of_visible_for_testing_member
