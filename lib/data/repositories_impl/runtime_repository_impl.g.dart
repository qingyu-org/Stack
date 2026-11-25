// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'runtime_repository_impl.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

String _$runtimeRepositoryHash() => r'51e7ffc8a6a55e12c734d37d17046e52f866e3e6';

/// 基于当前激活服务器的仓库 Provider。
///
/// Copied from [runtimeRepository].
@ProviderFor(runtimeRepository)
final runtimeRepositoryProvider =
    AutoDisposeFutureProvider<RuntimeRepository>.internal(
  runtimeRepository,
  name: r'runtimeRepositoryProvider',
  debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
      ? null
      : _$runtimeRepositoryHash,
  dependencies: <ProviderOrFamily>[activeServerIdProvider],
  allTransitiveDependencies: <ProviderOrFamily>{
    activeServerIdProvider,
    ...?activeServerIdProvider.allTransitiveDependencies
  },
);

typedef RuntimeRepositoryRef = AutoDisposeFutureProviderRef<RuntimeRepository>;
// ignore_for_file: type=lint
// ignore_for_file: subtype_of_sealed_class, invalid_use_of_internal_member, invalid_use_of_visible_for_testing_member
