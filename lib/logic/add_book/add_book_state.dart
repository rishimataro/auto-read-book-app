part of 'add_book_cubit.dart';

abstract class AddBookState extends Equatable {
  const AddBookState();

  @override
  List<Object?> get props => [];
}

class AddBookInitial extends AddBookState {}

class AddBookForm extends AddBookState {
  final String? imagePath;
  final String title;
  final String author;
  final String description;

  const AddBookForm({
    this.imagePath,
    required this.title,
    required this.author,
    this.description = '',
  });

  @override
  List<Object?> get props => [imagePath, title, author, description];
}

class AddBookSaving extends AddBookState {}

class AddBookSuccess extends AddBookState {}

class AddBookFailure extends AddBookState {
  final String message;
  final String? imagePath;
  final String title;
  final String author;
  final String description;

  const AddBookFailure(
    this.message, {
    this.imagePath,
    required this.title,
    required this.author,
    this.description = '',
  });

  @override
  List<Object?> get props => [message, imagePath, title, author, description];
}

