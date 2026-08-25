import 'book.dart';

class BookOfMonthWinner {
  final Book? book;
  final int voteCount;
  final int totalVotes;

  const BookOfMonthWinner({required this.book, required this.voteCount, required this.totalVotes});

  factory BookOfMonthWinner.fromJson(Map<String, dynamic> json) {
    return BookOfMonthWinner(
      book: json['book'] != null ? Book.fromJson(json['book'] as Map<String, dynamic>) : null,
      voteCount: json['voteCount'] as int,
      totalVotes: json['totalVotes'] as int,
    );
  }
}

class MyBookOfMonthVote {
  final String bookId;
  final Book book;

  const MyBookOfMonthVote({required this.bookId, required this.book});

  factory MyBookOfMonthVote.fromJson(Map<String, dynamic> json) {
    return MyBookOfMonthVote(
      bookId: json['bookId'] as String,
      book: Book.fromJson(json['book'] as Map<String, dynamic>),
    );
  }
}
