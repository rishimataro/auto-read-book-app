class BookResponse {
  final String status;
  final String rawText;
  final String cleanText;
  final String message;

  BookResponse({
    required this.status,
    this.rawText = '',
    this.cleanText = '',
    this.message = '',
  });

  factory BookResponse.fromJson(Map<String, dynamic> json) {
    return BookResponse(
      status: json['status'] ?? 'unknown',
      rawText: json['raw_text'] ?? '',
      cleanText: json['clean_text'] ?? '',
      message: json['message'] ?? '',
    );
  }
}