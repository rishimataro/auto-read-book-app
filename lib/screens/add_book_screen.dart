
import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'read_book_screen.dart';

class AddBookScreen extends StatefulWidget {
  const AddBookScreen({super.key});

  @override
  State<AddBookScreen> createState() => _AddBookScreenState();
}

class _AddBookScreenState extends State<AddBookScreen> {
  String _title = "Tên của sách";
  String _author = "Tác giả";
  String _category = "Thể loại";
  String? _imagePath;

  bool _isEditing = false;
  bool _isFavorited = false;
  final _titleController = TextEditingController();
  final _authorController = TextEditingController();
  final _categoryController = TextEditingController();

  bool get _isDefaultBook => _title == "Tên của sách" && _author == "Tác giả";

  @override
  void initState() {
    super.initState();
    _loadBookData();
  }

  @override
  void dispose() {
    _titleController.dispose();
    _authorController.dispose();
    _categoryController.dispose();
    super.dispose();
  }

  Future<void> _loadBookData() async {
    final prefs = await SharedPreferences.getInstance();
    if (!mounted) return;

    final title = prefs.getString('book_title') ?? "Tên của sách";
    final favoriteBooks = prefs.getStringList('favorite_books') ?? [];

    setState(() {
      _title = title;
      _author = prefs.getString('book_author') ?? "Tác giả";
      _category = prefs.getString('book_category') ?? "Thể loại";
      _imagePath = prefs.getString('book_imagePath');
      _isFavorited = favoriteBooks.contains(_title); // Check if book is in favorites

      _titleController.text = _title;
      _authorController.text = _author;
      _categoryController.text = _category;
    });
  }

  Future<void> _saveBookData() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('book_title', _title);
    await prefs.setString('book_author', _author);
    await prefs.setString('book_category', _category);
    if (_imagePath != null) {
      await prefs.setString('book_imagePath', _imagePath!);
    } else {
      await prefs.remove('book_imagePath');
    }
  }

  Future<void> _addBookToLibraryAndReset() async {
    if (_isDefaultBook) {
      await _resetBookData();
      return;
    }

    final prefs = await SharedPreferences.getInstance();
    final List<String> readBooksJson = prefs.getStringList('read_books') ?? [];

    final bookData = {
      'title': _title,
      'author': _author,
      'imagePath': _imagePath,
    };

    readBooksJson.add(json.encode(bookData));
    await prefs.setStringList('read_books', readBooksJson);

    await _resetBookData();
  }

  Future<void> _resetBookData() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('book_title');
    await prefs.remove('book_author');
    await prefs.remove('book_category');
    await prefs.remove('book_imagePath');

    if (!mounted) return;
    setState(() {
      _title = "Tên của sách";
      _author = "Tác giả";
      _category = "Thể loại";
      _imagePath = null;
      _isEditing = false;
      _isFavorited = false;
      _updateControllers();
    });
  }

  void _updateControllers() {
    _titleController.text = _title;
    _authorController.text = _author;
    _categoryController.text = _category;
  }

  void _toggleEditMode() {
    if (_isDefaultBook && !_isEditing) {
      setState(() {
        _title = '';
        _author = '';
        _category = '';
        _isEditing = true;
        _updateControllers();
      });
      return;
    }

    setState(() {
      if (_isEditing) {
        _title = _titleController.text.isNotEmpty ? _titleController.text : "Tên của sách";
        _author = _authorController.text.isNotEmpty ? _authorController.text : "Tác giả";
        _category = _categoryController.text.isNotEmpty ? _categoryController.text : "Thể loại";
        _saveBookData();
      }
      _isEditing = !_isEditing;
    });
  }

  // --- START: FIXED FUNCTION ---
  Future<void> _toggleFavorite() async {
    if (_isDefaultBook || _isEditing) return;

    // Immediately update the UI optimistically
    setState(() {
      _isFavorited = !_isFavorited;
    });

    // Then, handle the persistence logic asynchronously.
    final prefs = await SharedPreferences.getInstance();
    final favoriteBooks = prefs.getStringList('favorite_books') ?? [];

    // Use the now-updated _isFavorited state to guide persistence
    if (_isFavorited) {
      if (!favoriteBooks.contains(_title)) {
        favoriteBooks.add(_title);
      }
    } else {
      favoriteBooks.remove(_title);
    }

    await prefs.setStringList('favorite_books', favoriteBooks);
  }
  // --- END: FIXED FUNCTION ---

  Future<void> _pickImage() async {
    if (!_isEditing) return;
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(source: ImageSource.gallery);
    if (pickedFile != null) {
      setState(() {
        _imagePath = pickedFile.path;
      });
    }
  }

  Future<void> _navigateToReadScreen() async {
    if (_isEditing) return;
    final bool? hasFinishedReading = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ReadBookScreen(
          title: _title,
          author: _author,
        ),
      ),
    );

    if (hasFinishedReading == true) {
      await _addBookToLibraryAndReset();
    }
  }

  @override
  Widget build(BuildContext context) {
    final Size screenSize = MediaQuery.of(context).size;
    final isBookLoaded = !_isDefaultBook || _isEditing;

    return Scaffold(
      backgroundColor: const Color(0xFFF6F6F6),
      body: Stack(
        children: [
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            height: screenSize.height * 0.3,
            child: Container(
              decoration: const BoxDecoration(
                color: Color(0xFF426A80),
                borderRadius: BorderRadius.only(
                  bottomLeft: Radius.circular(30),
                  bottomRight: Radius.circular(30),
                ),
              ),
            ),
          ),
          if (isBookLoaded)
            Positioned(
              top: 40,
              left: 16,
              child: IconButton(
                icon: const Icon(Icons.arrow_back_ios, color: Colors.white),
                onPressed: _resetBookData,
              ),
            ),
          // --- START: FAVORITE BUTTON WIDGET ---
          if (isBookLoaded && !_isEditing)
            Positioned(
              top: 40,
              right: 16,
              child: IconButton(
                icon: Icon(
                  _isFavorited ? Icons.star : Icons.star_border,
                  color: _isFavorited ? Colors.yellow : Colors.white,
                  size: 30,
                ),
                onPressed: _toggleFavorite,
              ),
            ),
          // --- END: FAVORITE BUTTON WIDGET ---
          Positioned(
            top: 50,
            left: 0,
            right: 0,
            child: Text(
              _isEditing ? "Chỉnh sửa sách" : (_isDefaultBook ? "Thêm mới" : ""),
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          Positioned.fill(
            child: SingleChildScrollView(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Column(
                  children: [
                    SizedBox(height: screenSize.height * 0.15),
                    GestureDetector(
                      onTap: _pickImage,
                      child: Container(
                        width: 160,
                        height: 220,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(15),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.15),
                              blurRadius: 10,
                              offset: const Offset(0, 5),
                            ),
                          ],
                          image: _imagePath != null
                              ? DecorationImage(
                            image: FileImage(File(_imagePath!)),
                            fit: BoxFit.cover,
                          )
                              : null,
                        ),
                        child: _imagePath == null
                            ? Center(
                          child: Icon(Icons.add, size: 60, color: const Color(0xFF426A80).withOpacity(0.7)),
                        )
                            : null,
                      ),
                    ),
                    const SizedBox(height: 30),
                    if (_isEditing) ...[
                      TextField(
                        controller: _titleController,
                        textAlign: TextAlign.center,
                        style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                        decoration: const InputDecoration(hintText: "Tên của sách", border: InputBorder.none),
                      ),
                      const SizedBox(height: 8),
                      TextField(
                        controller: _authorController,
                        textAlign: TextAlign.center,
                        style: const TextStyle(fontSize: 16, color: Colors.grey),
                        decoration: const InputDecoration(hintText: "Tác giả", border: InputBorder.none),
                      ),
                      const SizedBox(height: 4),
                      TextField(
                        controller: _categoryController,
                        textAlign: TextAlign.center,
                        style: const TextStyle(fontSize: 16, color: Colors.grey),
                        decoration: const InputDecoration(hintText: "Thể loại", border: InputBorder.none),
                      ),
                    ] else ...[
                      Text(
                        _title,
                        style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.black87),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        _author,
                        style: const TextStyle(fontSize: 16, color: Colors.grey),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        _category,
                        style: const TextStyle(fontSize: 16, color: Colors.grey),
                      ),
                    ],
                    const SizedBox(height: 40),
                    if (!_isDefaultBook)
                      ElevatedButton(
                        onPressed: _toggleEditMode,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.white,
                          foregroundColor: const Color(0xFF9C7350),
                          side: const BorderSide(color: Color(0xFF9C7350), width: 1.5),
                          padding: const EdgeInsets.symmetric(horizontal: 70, vertical: 16),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
                          elevation: 2,
                        ),
                        child: Text(
                          _isEditing ? "Lưu" : "Chỉnh sửa",
                          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
                        ),
                      ),
                    const SizedBox(height: 12),
                    ElevatedButton(
                      onPressed: _isEditing ? null : _navigateToReadScreen,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF426A80),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 70, vertical: 16),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
                        elevation: 2,
                      ),
                      child: const Text(
                        "Đọc sách",
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
                      ),
                    ),
                    const SizedBox(height: 100),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}