import 'package:equatable/equatable.dart';

/// Domain-level error. Layers return [Failure] via Result instead of throwing.
sealed class Failure extends Equatable {
  const Failure(this.message);
  final String message;

  @override
  List<Object?> get props => [message];
}

class PermissionFailure extends Failure {
  const PermissionFailure([super.message = 'Storage permission denied']);
}

class StorageFailure extends Failure {
  const StorageFailure([super.message = 'Could not access storage']);
}

class DatabaseFailure extends Failure {
  const DatabaseFailure([super.message = 'Database error']);
}

class PlaybackFailure extends Failure {
  const PlaybackFailure([super.message = 'This media could not be played']);
}

class SecurityFailure extends Failure {
  const SecurityFailure([super.message = 'Authentication failed']);
}

class UnexpectedFailure extends Failure {
  const UnexpectedFailure([super.message = 'Something went wrong']);
}
