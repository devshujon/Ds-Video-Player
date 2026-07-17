import '../error/failures.dart';

/// Lightweight Either. Crossing a layer boundary returns a [Result] so callers
/// handle both paths explicitly instead of try/catching everywhere.
sealed class Result<T> {
  const Result();

  R fold<R>(
    R Function(Failure failure) onFailure,
    R Function(T value) onSuccess,
  ) {
    final self = this;
    return self is Success<T>
        ? onSuccess(self.value)
        : onFailure((self as FailureResult<T>).failure);
  }

  bool get isSuccess => this is Success<T>;
  T? get valueOrNull => this is Success<T> ? (this as Success<T>).value : null;
}

class Success<T> extends Result<T> {
  const Success(this.value);
  final T value;
}

class FailureResult<T> extends Result<T> {
  const FailureResult(this.failure);
  final Failure failure;
}
