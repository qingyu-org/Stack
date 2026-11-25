// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'network_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

String _$networkControllerHash() => r'7660f1e9928add21a407d810fe28c279ea258177';

/// See also [NetworkController].
@ProviderFor(NetworkController)
final networkControllerProvider =
    AutoDisposeAsyncNotifierProvider<NetworkController, NetworkState>.internal(
  NetworkController.new,
  name: r'networkControllerProvider',
  debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
      ? null
      : _$networkControllerHash,
  dependencies: <ProviderOrFamily>[containerRepositoryProvider],
  allTransitiveDependencies: <ProviderOrFamily>{
    containerRepositoryProvider,
    ...?containerRepositoryProvider.allTransitiveDependencies
  },
);

typedef _$NetworkController = AutoDisposeAsyncNotifier<NetworkState>;
// ignore_for_file: type=lint
// ignore_for_file: subtype_of_sealed_class, invalid_use_of_internal_member, invalid_use_of_visible_for_testing_member
