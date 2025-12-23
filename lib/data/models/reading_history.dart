class ReadingHistory {
  final String id;
  final String bookTitle;
  final String bookAuthor;
  final String text;
  final String? audioPath;
  final DateTime createdAt;
  final int pageNumber;

  ReadingHistory({
    required this.id,
    required this.bookTitle,
    required this.bookAuthor,
    required this.text,
    this.audioPath,
    required this.createdAt,
    this.pageNumber = 0,
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'bookTitle': bookTitle,
      'bookAuthor': bookAuthor,
      'text': text,
      'audioPath': audioPath,
      'createdAt': createdAt.toIso8601String(),
      'pageNumber': pageNumber,
    };
  }

  factory ReadingHistory.fromJson(Map<String, dynamic> json) {
    return ReadingHistory(
      id: json['id'] ?? '',
      bookTitle: json['bookTitle'] ?? '',
      bookAuthor: json['bookAuthor'] ?? '',
      text: json['text'] ?? '',
      audioPath: json['audioPath'],
      createdAt: DateTime.parse(json['createdAt']),
      pageNumber: json['pageNumber'] ?? 0,
    );
  }
}

