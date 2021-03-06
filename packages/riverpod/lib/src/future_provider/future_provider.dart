import 'dart:async';

import '../builders.dart';
import '../common.dart';
import '../framework/framework.dart';
import '../provider/provider.dart';
import '../stream_provider/stream_provider.dart';

part 'auto_dispose_future_provider.dart';

/// The state of a [FutureProvider].
class FutureProviderDependency<T> extends ProviderDependencyImpl<Future<T>> {
  FutureProviderDependency._(Future<T> future) : super(future);
}

/// {@template riverpod.futureprovider}
/// Asynchronously creates a single immutable value.
///
/// [FutureProvider] can be considered as a combination of [Provider] and
/// `FutureBuilder`.
/// By using [FutureProvider], the UI will be able to read the state of the
/// future syncronously, handle the loading/error states, and rebuild when the
/// future completes.
///
/// A common use-case for [FutureProvider] is to represent an asynchronous operation
/// such as reading a file or making an HTTP request, that is then listened by the UI.
///
/// It can then be combined with:
/// - [family], for parametrizing the http request based on external parameters,
///   such as fetching a `User` from its id.
/// - [autoDispose], to cancel the HTTP request when the UI leaves the screen,
///   or to restart the HTTP request if failed.
///
/// ## Usage example: reading a configuration file
///
/// [FutureProvider] can be a convenient way to expose a `Configuration` object
/// created by reading a JSON file.
///
/// Creating the configuration would be done with your typical async/await
/// syntax, but inside the provider.
/// Using Flutter's asset system, this would be:
///
/// ```dart
/// final configProvider = FutureProvider<Configuration>((ref) async {
///   final content = json.decode(
///     await rootBundle.loadString('assets/configurations.json'),
///   ) as Map<String, dynamic>;
///
///   return Configuration.fromJson(content);
/// });
/// ```
///
/// Then, the UI can listen to configurations like so:
///
/// ```dart
/// Widget build(BuildContext) {
///   AsyncValue<Configuration> config = useProvider(configProvider);
///
///   return config.when(
///     loading: () => const CircularProgressIndicator(),
///     error: (err, stack) => Text('Error: $err'),
///     data: (config) {
///       return Text(config.host);
///     },
///   );
/// }
/// ```
///
/// This will automatically rebuild the UI when the [Future] completes.
///
/// As you can see, listening to a [FutureProvider] inside a widget returns
/// an [AsyncValue] – which allows handling the error/loading states.
///
/// See also:
///
/// - [Provider], a provider that synchronously creates an immutable value
/// - [StreamProvider], a provider that asynchronously expose a value which
///   can change over time.
/// - [family], to create a [FutureProvider] from external parameters
/// - [autoDispose], to destroy the state of a [FutureProvider] when no-longer needed.
/// {@endtemplate}
class FutureProvider<Res> extends AlwaysAliveProviderBase<
    FutureProviderDependency<Res>, AsyncValue<Res>> {
  /// {@macro riverpod.futureprovider}
  FutureProvider(this._create, {String name}) : super(name);

  /// {@macro riverpod.family}
  static const family = FutureProviderFamilyBuilder();

  /// {@macro riverpod.autoDispose}
  static const autoDispose = AutoDisposeFutureProviderBuilder();

  final Create<Future<Res>, ProviderReference> _create;

  @override
  _FutureProviderState<Res> createState() {
    return _FutureProviderState<Res>();
  }

  /// A test utility to override a [FutureProvider] with a synchronous value.
  ///
  /// Overriding a [FutureProvider] with an [AsyncValue.data]/[AsyncValue.error]
  /// bypass the loading step that most streams have, which simplifies the test.
  ///
  /// It is possible to change the state emitted by changing the override
  /// on [ProviderStateOwner]/`ProviderScope`.
  ///
  /// Once an [AsyncValue.data]/[AsyncValue.error] was emitted, it is no longer
  /// possible to change the value exposed.
  ///
  /// This will create a made up [Future] for [ProviderDependency.value].
  Override debugOverrideWithValue(AsyncValue<Res> value) {
    ProviderOverride res;
    assert(() {
      res = overrideAs(
        _DebugValueFutureProvider(value),
      );
      return true;
    }(), '');
    return res;
  }
}

mixin _FutureProviderStateMixin<Res,
        P extends ProviderBase<FutureProviderDependency<Res>, AsyncValue<Res>>>
    on ProviderStateBase<FutureProviderDependency<Res>, AsyncValue<Res>, P> {
  Future<Res> _future;

  AsyncValue<Res> _state;
  @override
  AsyncValue<Res> get state => _state;
  set state(AsyncValue<Res> state) {
    _state = state;
    markMayHaveChanged();
  }

  Future<Res> create();

  @override
  void initState() {
    _state = const AsyncValue.loading();
    _future = create();
    // may update the value synchronously if the future is a SynchronousFuture from flutter
    _listen();
  }

  Future<void> _listen() async {
    try {
      final value = await _future;
      if (mounted) {
        state = AsyncValue.data(value);
      }
    } catch (err, stack) {
      if (mounted) {
        state = AsyncValue.error(err, stack);
      }
    }
  }

  @override
  FutureProviderDependency<Res> createProviderDependency() {
    return FutureProviderDependency._(_future);
  }
}

class _FutureProviderState<Res> extends ProviderStateBase<
        FutureProviderDependency<Res>, AsyncValue<Res>, FutureProvider<Res>>
    with _FutureProviderStateMixin<Res, FutureProvider<Res>> {
  @override
  Future<Res> create() {
    // ignore: invalid_use_of_visible_for_testing_member
    return provider._create(ProviderReference(this));
  }
}

class _DebugValueFutureProvider<Res> extends AlwaysAliveProviderBase<
    FutureProviderDependency<Res>, AsyncValue<Res>> {
  _DebugValueFutureProvider(this._value, {String name}) : super(name);

  final AsyncValue<Res> _value;

  @override
  _DebugValueFutureProviderState<Res> createState() {
    _DebugValueFutureProviderState<Res> result;
    assert(() {
      result = _DebugValueFutureProviderState<Res>();
      return true;
    }(), '');
    return result;
  }
}

class _DebugValueFutureProviderState<Res> extends ProviderStateBase<
    FutureProviderDependency<Res>,
    AsyncValue<Res>,
    _DebugValueFutureProvider<Res>> {
  final _completer = Completer<Res>();

  AsyncValue<Res> _state;
  @override
  AsyncValue<Res> get state => _state;
  set state(AsyncValue<Res> state) {
    _state = state;
    markMayHaveChanged();
  }

  @override
  void initState() {
    provider._value.when(
      data: _completer.complete,
      loading: () {},
      error: _completer.completeError,
    );

    _state = provider._value;
  }

  @override
  void didUpdateProvider(_DebugValueFutureProvider<Res> oldProvider) {
    super.didUpdateProvider(oldProvider);

    if (provider._value != oldProvider._value) {
      oldProvider._value.maybeWhen(
        loading: () {},
        orElse: () => throw UnsupportedError(
          'Once an overide was built with a data/error, its state cannot change',
        ),
      );

      provider._value.when(
        data: (value) {
          state = AsyncValue.data(value);
          _completer.complete(value);
        },
        // Never reached. Either it doesn't enter the if, or it throws before
        loading: () {},
        error: (err, stack) {
          state = AsyncValue.error(err, stack);
          _completer.completeError(err, stack);
        },
      );
    }
  }

  @override
  FutureProviderDependency<Res> createProviderDependency() {
    return FutureProviderDependency._(_completer.future);
  }
}

/// Creates a [FutureProvider] from external parameters.
///
/// See also:
///
/// - [Provider.family], which contains an explanation of what a families are.
class FutureProviderFamily<Result, A>
    extends Family<FutureProvider<Result>, A> {
  /// Creates a [FutureProvider] from external parameters.
  FutureProviderFamily(
      Future<Result> Function(ProviderReference ref, A a) create)
      : super((a) => FutureProvider((ref) => create(ref, a)));

  /// Overrides the behavior of a family for a part of the application.
  Override overrideAs(
    Future<Result> Function(ProviderReference ref, A value) override,
  ) {
    return FamilyOverride(
      this,
      (value) => FutureProvider<Result>((ref) => override(ref, value as A)),
    );
  }
}
