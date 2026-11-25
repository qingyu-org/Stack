// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'firewall_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

String _$firewallBaseInfoHash() => r'27a40c62f7f6ee7f9ce0689e47d05eff82b73a7b';

/// See also [firewallBaseInfo].
@ProviderFor(firewallBaseInfo)
final firewallBaseInfoProvider =
    AutoDisposeFutureProvider<FirewallBaseInfoDto>.internal(
  firewallBaseInfo,
  name: r'firewallBaseInfoProvider',
  debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
      ? null
      : _$firewallBaseInfoHash,
  dependencies: <ProviderOrFamily>[
    firewallRepositoryProvider,
    activeServerIdProvider
  ],
  allTransitiveDependencies: <ProviderOrFamily>{
    firewallRepositoryProvider,
    ...?firewallRepositoryProvider.allTransitiveDependencies,
    activeServerIdProvider,
    ...?activeServerIdProvider.allTransitiveDependencies
  },
);

typedef FirewallBaseInfoRef = AutoDisposeFutureProviderRef<FirewallBaseInfoDto>;
String _$firewallPortRulesControllerHash() =>
    r'39859e2abfde90c0e0d8f2eb00131df3cb86ba0c';

/// See also [FirewallPortRulesController].
@ProviderFor(FirewallPortRulesController)
final firewallPortRulesControllerProvider = AutoDisposeAsyncNotifierProvider<
    FirewallPortRulesController, FirewallPortRulesState>.internal(
  FirewallPortRulesController.new,
  name: r'firewallPortRulesControllerProvider',
  debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
      ? null
      : _$firewallPortRulesControllerHash,
  dependencies: <ProviderOrFamily>[
    firewallRepositoryProvider,
    activeServerIdProvider
  ],
  allTransitiveDependencies: <ProviderOrFamily>{
    firewallRepositoryProvider,
    ...?firewallRepositoryProvider.allTransitiveDependencies,
    activeServerIdProvider,
    ...?activeServerIdProvider.allTransitiveDependencies
  },
);

typedef _$FirewallPortRulesController
    = AutoDisposeAsyncNotifier<FirewallPortRulesState>;
String _$firewallIpRulesControllerHash() =>
    r'b0ad37a6d76b4531cf8854c49879e7658df24dc1';

/// See also [FirewallIpRulesController].
@ProviderFor(FirewallIpRulesController)
final firewallIpRulesControllerProvider = AutoDisposeAsyncNotifierProvider<
    FirewallIpRulesController, FirewallIpRulesState>.internal(
  FirewallIpRulesController.new,
  name: r'firewallIpRulesControllerProvider',
  debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
      ? null
      : _$firewallIpRulesControllerHash,
  dependencies: <ProviderOrFamily>[
    firewallRepositoryProvider,
    activeServerIdProvider
  ],
  allTransitiveDependencies: <ProviderOrFamily>{
    firewallRepositoryProvider,
    ...?firewallRepositoryProvider.allTransitiveDependencies,
    activeServerIdProvider,
    ...?activeServerIdProvider.allTransitiveDependencies
  },
);

typedef _$FirewallIpRulesController
    = AutoDisposeAsyncNotifier<FirewallIpRulesState>;
// ignore_for_file: type=lint
// ignore_for_file: subtype_of_sealed_class, invalid_use_of_internal_member, invalid_use_of_visible_for_testing_member
