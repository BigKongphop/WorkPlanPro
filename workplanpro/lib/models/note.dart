class Note {
  final String date;
  String title;
  String content;
  int rating;

  Note({
    required this.date,
    required this.title,
    required this.content,
    required this.rating,
  });

  Map<String, dynamic> toJson() {
    return {
      'date': date,
      'title': title,
      'content': content,
      'rating': rating,
    };
  }

  factory Note.fromJson(Map<String, dynamic> json) {
    return Note(
      date: json['date'] as String,
      title: json['title'] as String,
      content: json['content'] as String,
      rating: json['rating'] as int,
    );
  }
}
