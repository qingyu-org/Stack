// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'websites_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

String _$websitesControllerHash() =>
    r'02b4b21d83dba3319785b59db477354d073af632';

/// See also [WebsitesController].
@ProviderFor(WebsitesController)
final websitesControllerProvider = AutoDisposeAsyncNotifierProvider<
    WebsitesController, WebsitesViewState>.internal(
  WebsitesController.new,
  name: r'websitesControllerProvider',
  debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
      ? null
      : _$websitesControllerHash,
  dependencies: <ProviderOrFamily>[
    websiteRepositoryProvider,
    appRepositoryProvider
  ],
  allTransitiveDependencies: <ProviderOrFamily>{
    websiteRepositoryProvider,
    ...?websiteRepositoryProvider.allTransitiveDependencies,
    appRepositoryProvider,
    ...?appRepositoryProvider.allTransitiveDependencies
  },
);

typedef _$WebsitesController = AutoDisposeAsyncNotifier<WebsitesViewState>;
// ignore_for_file: type=lint
// ignore_for_file: subtype_of_sealed_class, invalid_use_of_internal_member, invalid_use_of_visible_for_testing_member
