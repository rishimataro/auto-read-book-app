import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:equatable/equatable.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'dart:io';
import 'package:image_picker/image_picker.dart';
import 'package:flutter/material.dart';

part 'add_book_state.dart';

class AddBookCubit extends Cubit<AddBookState> {
  AddBookCubit() : super(AddBookInitial());

  bool _isEditing = false;
  final _titleController = TextEditingController();
  final _authorController = TextEditingController();
  final _descriptionController = TextEditingController();
  String? _imagePath;

  TextEditingController get titleController => _titleController;
  TextEditingController get authorController => _authorController;
  TextEditingController get descriptionController => _descriptionController;

  bool get isEditing => _isEditing;

  void loadBookForEditing(Map<String, dynamic> book) {
    _isEditing = true;
    _titleController.text = book['title'] ?? '';
    _authorController.text = book['author'] ?? '';
    _descriptionController.text = book['description'] ?? '';
    _imagePath = book['imagePath'];
    emit(AddBookForm(
      imagePath: _imagePath,
      title: _titleController.text,
      author: _authorController.text,
      description: _descriptionController.text,
    ));
  }

  void createNewBook() {
    _isEditing = false;
    _titleController.clear();
    _authorController.clear();
    _descriptionController.clear();
    _imagePath = null;
    emit(AddBookForm(imagePath: null, title: '', author: '', description: ''));
  }

  Future<void> pickImage() async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(source: ImageSource.gallery);
    if (pickedFile != null) {
      _imagePath = pickedFile.path;
      emit(AddBookForm(
        imagePath: _imagePath,
        title: _titleController.text,
        author: _authorController.text,
        description: _descriptionController.text,
      ));
    }
  }

  Future<void> saveBook() async {
    final title = _titleController.text.trim();
    final author = _authorController.text.trim();
    final description = _descriptionController.text.trim();

    if (title.isEmpty) {
      emit(AddBookFailure(
        "Tiêu đề không được để trống",
        imagePath: _imagePath,
        title: title,
        author: author,
        description: description,
      ));
      return;
    }

    emit(AddBookSaving());

    try {
      final prefs = await SharedPreferences.getInstance();
      final booksJson = prefs.getStringList('read_books') ?? [];

      final newBook = {
        'title': title,
        'author': author,
        'description': description,
        'imagePath': _imagePath,
      };

      if (_isEditing) {
        // Find and update existing book
        // This is complex because we need a unique ID. For now, we'll find by title.
        // A better approach would be to use a unique ID for each book.
        final index = booksJson.indexWhere((b) {
          final book = json.decode(b);
          return book['title'] == title; // Assuming title is unique for editing
        });
        if (index != -1) {
          booksJson[index] = json.encode(newBook);
        } else {
          booksJson.add(json.encode(newBook)); // Add if not found (e.g., title changed)
        }
      } else {
        booksJson.add(json.encode(newBook));
      }

      await prefs.setStringList('read_books', booksJson);
      emit(AddBookSuccess());
    } catch (e) {
      emit(AddBookFailure(
        "Lỗi khi lưu sách: $e",
        imagePath: _imagePath,
        title: title,
        author: author,
        description: description,
      ));
    }
  }

  @override
  Future<void> close() {
    _titleController.dispose();
    _authorController.dispose();
    _descriptionController.dispose();
    return super.close();
  }
}
