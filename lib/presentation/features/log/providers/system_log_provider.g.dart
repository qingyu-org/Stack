// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'system_log_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

String _$systemLogControllerHash() =>
    r'3bb935a0b00139efe9491731141953a1734b45ad';

/// See also [SystemLogController].
@ProviderFor(SystemLogController)
final systemLogControllerProvider = AutoDisposeAsyncNotifierProvider<
    SystemLogController, SystemLogState>.internal(
  SystemLogController.new,
  name: r'systemLogControllerProvider',
  debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
      ? null
      : _$systemLogControllerHash,
  dependencies: <ProviderOrFamily>[
    logRepositoryProvider,
    activeServerIdProvider
  ],
  allTransitiveDependencies: <ProviderOrFamily>{
    logRepositoryProvider,
    ...?logRepositoryProvider.allTransitiveDependencies,
    activeServerIdProvider,
    ...?activeServerIdProvider.allTransitiveDependencies
  },
);

typedef _$SystemLogController = AutoDisposeAsyncNotifier<SystemLogState>;
// ignore_for_file: type=lint
// ignore_for_file: subtype_of_sealed_class, invalid_use_of_internal_member, invalid_use_of_visible_for_testing_member
