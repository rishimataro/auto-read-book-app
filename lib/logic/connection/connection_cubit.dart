import 'dart:async';

import 'package:demo/data/repositories/pi_repository.dart';
import 'connection_state.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

class ConnectionCubit extends Cubit<ConnectionState> {
  final PiRepository _repository;
  StreamSubscription? _textSubscription;

  ConnectionCubit(this._repository) : super(ConnectionInitial());

  Future<void> findDevice() async {
    emit(ConnectionScanning());
    try {
      final ip = await _repository.findRaspberryPi();
      if (ip != null) {
        emit(ConnectionSuccess(ip));
      } else {
        emit(ConnectionFailure("Không tìm thấy thiết bị. Vui lòng thử lại!"));
      }
    } catch (e) {
      emit(ConnectionFailure(e.toString()));
    }
  }

  void connect(String ip) {
    emit(ConnectionConnecting(ip));
    try {
      _repository.connectWebSocket(ip);
      _textSubscription = _repository.textStream.listen(
        (text) {
          emit(ConnectionReceivingData(text));
        },
        onError: (error) {
          emit(ConnectionError(error.toString()));
        },
        onDone: () {
          emit(ConnectionFailure("Kết nối đã đóng"));
        },
      );
      emit(ConnectionEstablished());
    } catch (e) {
      emit(ConnectionError(e.toString()));
    }
  }

  void disconnect() {
    _textSubscription?.cancel();
    _repository.close();
    emit(ConnectionInitial());
  }

  @override
  Future<void> close() {
    disconnect();
    return super.close();
  }
}