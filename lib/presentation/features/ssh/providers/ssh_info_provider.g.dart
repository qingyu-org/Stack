// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'ssh_info_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

String _$sshInfoControllerHash() => r'14d0482d114ec7efa7791f00ea2fa643a7b61d1d';

/// See also [SshInfoController].
@ProviderFor(SshInfoController)
final sshInfoControllerProvider =
    AutoDisposeAsyncNotifierProvider<SshInfoController, SshInfoDto>.internal(
  SshInfoController.new,
  name: r'sshInfoControllerProvider',
  debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
      ? null
      : _$sshInfoControllerHash,
  dependencies: <ProviderOrFamily>[activeServerIdProvider],
  allTransitiveDependencies: <ProviderOrFamily>{
    activeServerIdProvider,
    ...?activeServerIdProvider.allTransitiveDependencies
  },
);

typedef _$SshInfoController = AutoDisposeAsyncNotifier<SshInfoDto>;
// ignore_for_file: type=lint
// ignore_for_file: subtype_of_sealed_class, invalid_use_of_internal_member, invalid_use_of_visible_for_testing_member
