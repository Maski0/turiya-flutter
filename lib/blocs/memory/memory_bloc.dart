import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:equatable/equatable.dart';
import '../../services/backend_api_service.dart';

// Events
abstract class MemoryEvent extends Equatable {
  const MemoryEvent();
  @override
  List<Object?> get props => [];
}

class MemoriesRequested extends MemoryEvent {
  const MemoriesRequested();
}

class MemoryDeleted extends MemoryEvent {
  final String memoryId;
  const MemoryDeleted(this.memoryId);
  @override
  List<Object?> get props => [memoryId];
}

class AllMemoriesDeleted extends MemoryEvent {
  const AllMemoriesDeleted();
}

// States
abstract class MemoryState extends Equatable {
  const MemoryState();
  @override
  List<Object?> get props => [];
}

class MemoryInitial extends MemoryState {
  const MemoryInitial();
}

class MemoryLoading extends MemoryState {
  final String? message;
  const MemoryLoading({this.message});
  @override
  List<Object?> get props => [message];
}

class MemoryLoaded extends MemoryState {
  final List<Memory> memories;

  const MemoryLoaded(this.memories);

  @override
  List<Object?> get props => [memories];
}

class MemoryError extends MemoryState {
  final String message;

  const MemoryError(this.message);

  @override
  List<Object?> get props => [message];
}

// Model
class Memory {
  final String id;
  final String memory;
  final String hash;
  final DateTime createdAt;
  final DateTime? updatedAt;
  final Map<String, dynamic>? metadata;
  final String userId;

  Memory({
    required this.id,
    required this.memory,
    required this.hash,
    required this.createdAt,
    this.updatedAt,
    this.metadata,
    required this.userId,
  });

  factory Memory.fromJson(Map<String, dynamic> json) {
    return Memory(
      id: json['id'],
      memory: json['memory'],
      hash: json['hash'],
      createdAt: DateTime.parse(json['created_at']),
      updatedAt:
          json['updated_at'] != null ? DateTime.parse(json['updated_at']) : null,
      metadata: json['metadata'],
      userId: json['user_id'],
    );
  }
}

// BLoC
class MemoryBloc extends Bloc<MemoryEvent, MemoryState> {
  final BackendApiService _backendApi;

  MemoryBloc({BackendApiService? backendApi})
      : _backendApi = backendApi ?? BackendApiService(),
        super(const MemoryInitial()) {
    on<MemoriesRequested>(_onMemoriesRequested);
    on<MemoryDeleted>(_onMemoryDeleted);
    on<AllMemoriesDeleted>(_onAllMemoriesDeleted);
  }

  Future<void> _onMemoriesRequested(
    MemoriesRequested event,
    Emitter<MemoryState> emit,
  ) async {
    emit(const MemoryLoading(message: 'Loading memories...'));

    try {
      final data = await _backendApi.listMemories();
      final memories = data.map((json) => Memory.fromJson(json)).toList();

      emit(MemoryLoaded(memories));
    } catch (e) {
      emit(MemoryError(e.toString().replaceAll('Exception: ', '')));
    }
  }

  Future<void> _onMemoryDeleted(
    MemoryDeleted event,
    Emitter<MemoryState> emit,
  ) async {
    emit(const MemoryLoading(message: 'Deleting memory...'));

    try {
      await _backendApi.deleteMemory(event.memoryId);

      // Reload memories
      final data = await _backendApi.listMemories();
      final memories = data.map((json) => Memory.fromJson(json)).toList();

      emit(MemoryLoaded(memories));
    } catch (e) {
      emit(MemoryError(e.toString().replaceAll('Exception: ', '')));
    }
  }

  Future<void> _onAllMemoriesDeleted(
    AllMemoriesDeleted event,
    Emitter<MemoryState> emit,
  ) async {
    emit(const MemoryLoading(message: 'Deleting all memories...'));

    try {
      await _backendApi.deleteAllMemories();
      emit(const MemoryLoaded([]));
    } catch (e) {
      emit(MemoryError(e.toString().replaceAll('Exception: ', '')));
    }
  }
}

