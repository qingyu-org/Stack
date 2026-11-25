// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'cronjob_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

String _$cronjobControllerHash() => r'2e02662decdfd84db809a27b106ba12c0b9abde9';

/// See also [CronjobController].
@ProviderFor(CronjobController)
final cronjobControllerProvider =
    AutoDisposeAsyncNotifierProvider<CronjobController, CronjobState>.internal(
  CronjobController.new,
  name: r'cronjobControllerProvider',
  debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
      ? null
      : _$cronjobControllerHash,
  dependencies: <ProviderOrFamily>[cronjobRepositoryProvider],
  allTransitiveDependencies: <ProviderOrFamily>{
    cronjobRepositoryProvider,
    ...?cronjobRepositoryProvider.allTransitiveDependencies
  },
);

typedef _$CronjobController = AutoDisposeAsyncNotifier<CronjobState>;
// ignore_for_file: type=lint
// ignore_for_file: subtype_of_sealed_class, invalid_use_of_internal_member, invalid_use_of_visible_for_testing_member
