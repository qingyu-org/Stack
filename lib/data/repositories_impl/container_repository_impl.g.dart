// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'container_repository_impl.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

String _$containerRepositoryHash() =>
    r'501140c22b92863404dcc867f87009799cb4e569';

/// 基于当前激活服务器的容器仓库 Provider。
///
/// Copied from [containerRepository].
@ProviderFor(containerRepository)
final containerRepositoryProvider =
    AutoDisposeFutureProvider<ContainerRepository>.internal(
  containerRepository,
  name: r'containerRepositoryProvider',
  debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
      ? null
      : _$containerRepositoryHash,
  dependencies: <ProviderOrFamily>[activeServerIdProvider],
  allTransitiveDependencies: <ProviderOrFamily>{
    activeServerIdProvider,
    ...?activeServerIdProvider.allTransitiveDependencies
  },
);

typedef ContainerRepositoryRef
    = AutoDisposeFutureProviderRef<ContainerRepository>;
// ignore_for_file: type=lint
// ignore_for_file: subtype_of_sealed_class, invalid_use_of_internal_member, invalid_use_of_visible_for_testing_member
