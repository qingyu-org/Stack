// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'file_recycle_bin_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

String _$fileRecycleBinControllerHash() =>
    r'd25f39cb3e7347346d268fae94d55557b3fa50de';

/// See also [FileRecycleBinController].
@ProviderFor(FileRecycleBinController)
final fileRecycleBinControllerProvider = AutoDisposeAsyncNotifierProvider<
    FileRecycleBinController, List<RecycleBinDto>>.internal(
  FileRecycleBinController.new,
  name: r'fileRecycleBinControllerProvider',
  debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
      ? null
      : _$fileRecycleBinControllerHash,
  dependencies: <ProviderOrFamily>[
    fileRepositoryProvider,
    settingRepositoryProvider,
    appLocalizationsProvider
  ],
  allTransitiveDependencies: <ProviderOrFamily>{
    fileRepositoryProvider,
    ...?fileRepositoryProvider.allTransitiveDependencies,
    settingRepositoryProvider,
    ...?settingRepositoryProvider.allTransitiveDependencies,
    appLocalizationsProvider,
    ...?appLocalizationsProvider.allTransitiveDependencies
  },
);

typedef _$FileRecycleBinController
    = AutoDisposeAsyncNotifier<List<RecycleBinDto>>;
// ignore_for_file: type=lint
// ignore_for_file: subtype_of_sealed_class, invalid_use_of_internal_member, invalid_use_of_visible_for_testing_member
