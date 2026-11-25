// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'download_manager_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

String _$downloadManagerHash() => r'bfba81e04acf2c95bfafeb48cc428c849cd83e61';

/// See also [DownloadManager].
@ProviderFor(DownloadManager)
final downloadManagerProvider =
    NotifierProvider<DownloadManager, List<DownloadTask>>.internal(
  DownloadManager.new,
  name: r'downloadManagerProvider',
  debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
      ? null
      : _$downloadManagerHash,
  dependencies: <ProviderOrFamily>[appLocalizationsProvider],
  allTransitiveDependencies: <ProviderOrFamily>{
    appLocalizationsProvider,
    ...?appLocalizationsProvider.allTransitiveDependencies
  },
);

typedef _$DownloadManager = Notifier<List<DownloadTask>>;
// ignore_for_file: type=lint
// ignore_for_file: subtype_of_sealed_class, invalid_use_of_internal_member, invalid_use_of_visible_for_testing_member
