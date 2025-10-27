import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:equatable/equatable.dart';
import '../../services/backend_api_service.dart';

// Events
abstract class CreditsEvent extends Equatable {
  const CreditsEvent();
  @override
  List<Object?> get props => [];
}

class CreditsRequested extends CreditsEvent {
  const CreditsRequested();
}

class CreditsRefreshed extends CreditsEvent {
  const CreditsRefreshed();
}

// States
abstract class CreditsState extends Equatable {
  const CreditsState();
  @override
  List<Object?> get props => [];
}

class CreditsInitial extends CreditsState {
  const CreditsInitial();
}

class CreditsLoading extends CreditsState {
  const CreditsLoading();
}

class CreditsLoaded extends CreditsState {
  final int currentCredits;
  final int purchasedCredits;
  final int totalCredits;
  final String planType;
  final bool hasCredits;

  const CreditsLoaded({
    required this.currentCredits,
    required this.purchasedCredits,
    required this.totalCredits,
    required this.planType,
    required this.hasCredits,
  });

  @override
  List<Object?> get props => [
        currentCredits,
        purchasedCredits,
        totalCredits,
        planType,
        hasCredits,
      ];

  bool get isPro => planType == 'pro';
  bool get isFree => planType == 'free';
}

class CreditsError extends CreditsState {
  final String message;

  const CreditsError(this.message);

  @override
  List<Object?> get props => [message];
}

// BLoC
class CreditsBloc extends Bloc<CreditsEvent, CreditsState> {
  final BackendApiService _backendApi;

  CreditsBloc({BackendApiService? backendApi})
      : _backendApi = backendApi ?? BackendApiService(),
        super(const CreditsInitial()) {
    on<CreditsRequested>(_onCreditsRequested);
    on<CreditsRefreshed>(_onCreditsRefreshed);
  }

  Future<void> _onCreditsRequested(
    CreditsRequested event,
    Emitter<CreditsState> emit,
  ) async {
    emit(const CreditsLoading());
    await _fetchCredits(emit);
  }

  Future<void> _onCreditsRefreshed(
    CreditsRefreshed event,
    Emitter<CreditsState> emit,
  ) async {
    await _fetchCredits(emit);
  }

  Future<void> _fetchCredits(Emitter<CreditsState> emit) async {
    try {
      final data = await _backendApi.getCreditsStatus();

      emit(CreditsLoaded(
        currentCredits: data['current_credits'] ?? 0,
        purchasedCredits: data['purchased_credits'] ?? 0,
        totalCredits: data['total_credits'] ?? 0,
        planType: data['plan_type'] ?? 'free',
        hasCredits: data['has_credits'] ?? false,
      ));
    } catch (e) {
      emit(CreditsError(e.toString().replaceAll('Exception: ', '')));
    }
  }
}

