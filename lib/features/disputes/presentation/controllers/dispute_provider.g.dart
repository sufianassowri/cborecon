// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'dispute_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(DisputeList)
final disputeListProvider = DisputeListProvider._();

final class DisputeListProvider
    extends $AsyncNotifierProvider<DisputeList, List<DisputeTrxn>> {
  DisputeListProvider._()
      : super(
          from: null,
          argument: null,
          retry: null,
          name: r'disputeListProvider',
          isAutoDispose: true,
          dependencies: null,
          $allTransitiveDependencies: null,
        );

  @override
  String debugGetCreateSourceHash() => _$disputeListHash();

  @$internal
  @override
  DisputeList create() => DisputeList();
}

String _$disputeListHash() => r'6a2895e7b67b9d94890f68aed2e88eb13111c453';

abstract class _$DisputeList extends $AsyncNotifier<List<DisputeTrxn>> {
  FutureOr<List<DisputeTrxn>> build();
  @$mustCallSuper
  @override
  void runBuild() {
    final ref =
        this.ref as $Ref<AsyncValue<List<DisputeTrxn>>, List<DisputeTrxn>>;
    final element = ref.element as $ClassProviderElement<
        AnyNotifier<AsyncValue<List<DisputeTrxn>>, List<DisputeTrxn>>,
        AsyncValue<List<DisputeTrxn>>,
        Object?,
        Object?>;
    element.handleCreate(ref, build);
  }
}
