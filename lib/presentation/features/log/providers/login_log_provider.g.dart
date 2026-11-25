// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'login_log_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

String _$loginLogControllerHash() =>
    r'73b94bef8d411185e6db31193f736facfd5a5ce0';

/// See also [LoginLogController].
@ProviderFor(LoginLogController)
final loginLogControllerProvider = AutoDisposeAsyncNotifierProvider<
    LoginLogController, LoginLogState>.internal(
  LoginLogController.new,
  name: r'loginLogControllerProvider',
  debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
      ? null
      : _$loginLogControllerHash,
  dependencies: <ProviderOrFamily>[logRepositoryProvider],
  allTransitiveDependencies: <ProviderOrFamily>{
    logRepositoryProvider,
    ...?logRepositoryProvider.allTransitiveDependencies
  },
);

typedef _$LoginLogController = AutoDisposeAsyncNotifier<LoginLogState>;
// ignore_for_file: type=lint
// ignore_for_file: subtype_of_sealed_class, invalid_use_of_internal_member, invalid_use_of_visible_for_testing_member
