// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'dio_client_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

String _$nodeDioClientHash() => r'644a891b037c3095d716083c1c7f240f33a7fcfe';

/// Copied from Dart SDK
class _SystemHash {
  _SystemHash._();

  static int combine(int hash, int value) {
    // ignore: parameter_assignments
    hash = 0x1fffffff & (hash + value);
    // ignore: parameter_assignments
    hash = 0x1fffffff & (hash + ((0x0007ffff & hash) << 10));
    return hash ^ (hash >> 6);
  }

  static int finish(int hash) {
    // ignore: parameter_assignments
    hash = 0x1fffffff & (hash + ((0x03ffffff & hash) << 3));
    // ignore: parameter_assignments
    hash = hash ^ (hash >> 11);
    return 0x1fffffff & (hash + ((0x00003fff & hash) << 15));
  }
}

/// 单个节点的 DioClient（按 `(serverId, node)` 缓存）。
///
/// 每个节点拥有独立的连接池；切换节点只切换使用哪个客户端，不会销毁
/// 其它节点正在使用的客户端，避免中断进行中的上传/长请求。
///
/// Copied from [nodeDioClient].
@ProviderFor(nodeDioClient)
const nodeDioClientProvider = NodeDioClientFamily();

/// 单个节点的 DioClient（按 `(serverId, node)` 缓存）。
///
/// 每个节点拥有独立的连接池；切换节点只切换使用哪个客户端，不会销毁
/// 其它节点正在使用的客户端，避免中断进行中的上传/长请求。
///
/// Copied from [nodeDioClient].
class NodeDioClientFamily extends Family<AsyncValue<DioClient>> {
  /// 单个节点的 DioClient（按 `(serverId, node)` 缓存）。
  ///
  /// 每个节点拥有独立的连接池；切换节点只切换使用哪个客户端，不会销毁
  /// 其它节点正在使用的客户端，避免中断进行中的上传/长请求。
  ///
  /// Copied from [nodeDioClient].
  const NodeDioClientFamily();

  /// 单个节点的 DioClient（按 `(serverId, node)` 缓存）。
  ///
  /// 每个节点拥有独立的连接池；切换节点只切换使用哪个客户端，不会销毁
  /// 其它节点正在使用的客户端，避免中断进行中的上传/长请求。
  ///
  /// Copied from [nodeDioClient].
  NodeDioClientProvider call(
    NodeClientKey key,
  ) {
    return NodeDioClientProvider(
      key,
    );
  }

  @override
  NodeDioClientProvider getProviderOverride(
    covariant NodeDioClientProvider provider,
  ) {
    return call(
      provider.key,
    );
  }

  static const Iterable<ProviderOrFamily>? _dependencies = null;

  @override
  Iterable<ProviderOrFamily>? get dependencies => _dependencies;

  static const Iterable<ProviderOrFamily>? _allTransitiveDependencies = null;

  @override
  Iterable<ProviderOrFamily>? get allTransitiveDependencies =>
      _allTransitiveDependencies;

  @override
  String? get name => r'nodeDioClientProvider';
}

/// 单个节点的 DioClient（按 `(serverId, node)` 缓存）。
///
/// 每个节点拥有独立的连接池；切换节点只切换使用哪个客户端，不会销毁
/// 其它节点正在使用的客户端，避免中断进行中的上传/长请求。
///
/// Copied from [nodeDioClient].
class NodeDioClientProvider extends FutureProvider<DioClient> {
  /// 单个节点的 DioClient（按 `(serverId, node)` 缓存）。
  ///
  /// 每个节点拥有独立的连接池；切换节点只切换使用哪个客户端，不会销毁
  /// 其它节点正在使用的客户端，避免中断进行中的上传/长请求。
  ///
  /// Copied from [nodeDioClient].
  NodeDioClientProvider(
    NodeClientKey key,
  ) : this._internal(
          (ref) => nodeDioClient(
            ref as NodeDioClientRef,
            key,
          ),
          from: nodeDioClientProvider,
          name: r'nodeDioClientProvider',
          debugGetCreateSourceHash:
              const bool.fromEnvironment('dart.vm.product')
                  ? null
                  : _$nodeDioClientHash,
          dependencies: NodeDioClientFamily._dependencies,
          allTransitiveDependencies:
              NodeDioClientFamily._allTransitiveDependencies,
          key: key,
        );

  NodeDioClientProvider._internal(
    super._createNotifier, {
    required super.name,
    required super.dependencies,
    required super.allTransitiveDependencies,
    required super.debugGetCreateSourceHash,
    required super.from,
    required this.key,
  }) : super.internal();

  final NodeClientKey key;

  @override
  Override overrideWith(
    FutureOr<DioClient> Function(NodeDioClientRef provider) create,
  ) {
    return ProviderOverride(
      origin: this,
      override: NodeDioClientProvider._internal(
        (ref) => create(ref as NodeDioClientRef),
        from: from,
        name: null,
        dependencies: null,
        allTransitiveDependencies: null,
        debugGetCreateSourceHash: null,
        key: key,
      ),
    );
  }

  @override
  FutureProviderElement<DioClient> createElement() {
    return _NodeDioClientProviderElement(this);
  }

  @override
  bool operator ==(Object other) {
    return other is NodeDioClientProvider && other.key == key;
  }

  @override
  int get hashCode {
    var hash = _SystemHash.combine(0, runtimeType.hashCode);
    hash = _SystemHash.combine(hash, key.hashCode);

    return _SystemHash.finish(hash);
  }
}

mixin NodeDioClientRef on FutureProviderRef<DioClient> {
  /// The parameter `key` of this provider.
  NodeClientKey get key;
}

class _NodeDioClientProviderElement extends FutureProviderElement<DioClient>
    with NodeDioClientRef {
  _NodeDioClientProviderElement(super.provider);

  @override
  NodeClientKey get key => (origin as NodeDioClientProvider).key;
}

String _$dioClientHash() => r'535b4d8958f205e29bd5c50357f27e18109f1359';

/// 当前激活节点对应的 DioClient。
///
/// 所有业务 Provider 继续使用这个 Provider 即可；节点切换时它返回另一个
/// 节点客户端的 future，但不会 dispose 旧客户端（旧客户端仍由
/// [nodeDioClientProvider] 持有，供进行中的请求 / 终端继续使用）。
///
/// Copied from [dioClient].
@ProviderFor(dioClient)
const dioClientProvider = DioClientFamily();

/// 当前激活节点对应的 DioClient。
///
/// 所有业务 Provider 继续使用这个 Provider 即可；节点切换时它返回另一个
/// 节点客户端的 future，但不会 dispose 旧客户端（旧客户端仍由
/// [nodeDioClientProvider] 持有，供进行中的请求 / 终端继续使用）。
///
/// Copied from [dioClient].
class DioClientFamily extends Family<AsyncValue<DioClient>> {
  /// 当前激活节点对应的 DioClient。
  ///
  /// 所有业务 Provider 继续使用这个 Provider 即可；节点切换时它返回另一个
  /// 节点客户端的 future，但不会 dispose 旧客户端（旧客户端仍由
  /// [nodeDioClientProvider] 持有，供进行中的请求 / 终端继续使用）。
  ///
  /// Copied from [dioClient].
  const DioClientFamily();

  /// 当前激活节点对应的 DioClient。
  ///
  /// 所有业务 Provider 继续使用这个 Provider 即可；节点切换时它返回另一个
  /// 节点客户端的 future，但不会 dispose 旧客户端（旧客户端仍由
  /// [nodeDioClientProvider] 持有，供进行中的请求 / 终端继续使用）。
  ///
  /// Copied from [dioClient].
  DioClientProvider call(
    int serverId,
  ) {
    return DioClientProvider(
      serverId,
    );
  }

  @override
  DioClientProvider getProviderOverride(
    covariant DioClientProvider provider,
  ) {
    return call(
      provider.serverId,
    );
  }

  static const Iterable<ProviderOrFamily>? _dependencies = null;

  @override
  Iterable<ProviderOrFamily>? get dependencies => _dependencies;

  static const Iterable<ProviderOrFamily>? _allTransitiveDependencies = null;

  @override
  Iterable<ProviderOrFamily>? get allTransitiveDependencies =>
      _allTransitiveDependencies;

  @override
  String? get name => r'dioClientProvider';
}

/// 当前激活节点对应的 DioClient。
///
/// 所有业务 Provider 继续使用这个 Provider 即可；节点切换时它返回另一个
/// 节点客户端的 future，但不会 dispose 旧客户端（旧客户端仍由
/// [nodeDioClientProvider] 持有，供进行中的请求 / 终端继续使用）。
///
/// Copied from [dioClient].
class DioClientProvider extends FutureProvider<DioClient> {
  /// 当前激活节点对应的 DioClient。
  ///
  /// 所有业务 Provider 继续使用这个 Provider 即可；节点切换时它返回另一个
  /// 节点客户端的 future，但不会 dispose 旧客户端（旧客户端仍由
  /// [nodeDioClientProvider] 持有，供进行中的请求 / 终端继续使用）。
  ///
  /// Copied from [dioClient].
  DioClientProvider(
    int serverId,
  ) : this._internal(
          (ref) => dioClient(
            ref as DioClientRef,
            serverId,
          ),
          from: dioClientProvider,
          name: r'dioClientProvider',
          debugGetCreateSourceHash:
              const bool.fromEnvironment('dart.vm.product')
                  ? null
                  : _$dioClientHash,
          dependencies: DioClientFamily._dependencies,
          allTransitiveDependencies: DioClientFamily._allTransitiveDependencies,
          serverId: serverId,
        );

  DioClientProvider._internal(
    super._createNotifier, {
    required super.name,
    required super.dependencies,
    required super.allTransitiveDependencies,
    required super.debugGetCreateSourceHash,
    required super.from,
    required this.serverId,
  }) : super.internal();

  final int serverId;

  @override
  Override overrideWith(
    FutureOr<DioClient> Function(DioClientRef provider) create,
  ) {
    return ProviderOverride(
      origin: this,
      override: DioClientProvider._internal(
        (ref) => create(ref as DioClientRef),
        from: from,
        name: null,
        dependencies: null,
        allTransitiveDependencies: null,
        debugGetCreateSourceHash: null,
        serverId: serverId,
      ),
    );
  }

  @override
  FutureProviderElement<DioClient> createElement() {
    return _DioClientProviderElement(this);
  }

  @override
  bool operator ==(Object other) {
    return other is DioClientProvider && other.serverId == serverId;
  }

  @override
  int get hashCode {
    var hash = _SystemHash.combine(0, runtimeType.hashCode);
    hash = _SystemHash.combine(hash, serverId.hashCode);

    return _SystemHash.finish(hash);
  }
}

mixin DioClientRef on FutureProviderRef<DioClient> {
  /// The parameter `serverId` of this provider.
  int get serverId;
}

class _DioClientProviderElement extends FutureProviderElement<DioClient>
    with DioClientRef {
  _DioClientProviderElement(super.provider);

  @override
  int get serverId => (origin as DioClientProvider).serverId;
}
// ignore_for_file: type=lint
// ignore_for_file: subtype_of_sealed_class, invalid_use_of_internal_member, invalid_use_of_visible_for_testing_member
