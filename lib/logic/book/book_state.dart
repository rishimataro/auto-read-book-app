import 'package:equatable/equatable.dart';

abstract class BookState extends Equatable {
  @override
  List<Object> get props => [];
}
class BookInitial extends BookState {}
class BookLoading extends BookState {
  final String message;
  BookLoading(this.message);
}
class BookLoaded extends BookState {
  final String text;
  final String? statusMessage;
  BookLoaded(this.text, {this.statusMessage});
}
class BookError extends BookState {
  final String message;
  BookError(this.message);
}