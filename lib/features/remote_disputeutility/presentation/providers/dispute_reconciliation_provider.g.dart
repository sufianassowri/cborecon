// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'dispute_reconciliation_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(RemoteDisputeNotifier)
final remoteDisputeProvider = RemoteDisputeNotifierProvider._();

final class RemoteDisputeNotifierProvider extends $AsyncNotifierProvider<
    RemoteDisputeNotifier, List<DisputeReconciliationRow>> {
  RemoteDisputeNotifierProvider._()
      : super(
          from: null,
          argument: null,
          retry: null,
          name: r'remoteDisputeProvider',
          isAutoDispose: true,
          dependencies: null,
          $allTransitiveDependencies: null,
        );

  @override
  String debugGetCreateSourceHash() => _$remoteDisputeNotifierHash();

  @$internal
  @override
  RemoteDisputeNotifier create() => RemoteDisputeNotifier();
}

String _$remoteDisputeNotifierHash() =>
    r'4b3670f5e5d0ce101f200a296d2bfe222b17a816';

abstract class _$RemoteDisputeNotifier
    extends $AsyncNotifier<List<DisputeReconciliationRow>> {
  FutureOr<List<DisputeReconciliationRow>> build();
  @$mustCallSuper
  @override
  void runBuild() {
    final ref = this.ref as $Ref<AsyncValue<List<DisputeReconciliationRow>>,
        List<DisputeReconciliationRow>>;
    final element = ref.element as $ClassProviderElement<
        AnyNotifier<AsyncValue<List<DisputeReconciliationRow>>,
            List<DisputeReconciliationRow>>,
        AsyncValue<List<DisputeReconciliationRow>>,
        Object?,
        Object?>;
    element.handleCreate(ref, build);
  }
}
