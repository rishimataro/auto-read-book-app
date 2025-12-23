import 'package:equatable/equatable.dart';

abstract class ConnectionState extends Equatable {
  @override
  List<Object?> get props => [];
}

class ConnectionInitial extends ConnectionState {}

class ConnectionScanning extends ConnectionState {}

class ConnectionConnecting extends ConnectionState {
  final String ip;
  ConnectionConnecting(this.ip);
}

class ConnectionSuccess extends ConnectionState {
  final String ip;
  ConnectionSuccess(this.ip);
}

class ConnectionEstablished extends ConnectionState {}

class ConnectionReceivingData extends ConnectionState {
  final String text;
  ConnectionReceivingData(this.text);
}

class ConnectionFailure extends ConnectionState {
  final String message;
  ConnectionFailure(this.message);
}

class ConnectionError extends ConnectionState {
  final String message;
  ConnectionError(this.message);
}



