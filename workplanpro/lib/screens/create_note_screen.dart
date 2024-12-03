import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/note.dart';

class CreateNoteScreen extends StatefulWidget {
  final Note? note;

  CreateNoteScreen({this.note});

  @override
  _CreateNoteScreenState createState() => _CreateNoteScreenState();
}

class _CreateNoteScreenState extends State<CreateNoteScreen> {
  late int _rating;
  late TextEditingController titleController;
  late TextEditingController contentController;

  static const Map<int, String> ratingDescriptions = {
    1: 'Low Priority',
    2: 'Medium Priority',
    3: 'High Priority'
  };

  @override
  void initState() {
    super.initState();
    _rating = widget.note?.rating ?? 0;
    titleController = TextEditingController(text: widget.note?.title ?? '');
    contentController = TextEditingController(text: widget.note?.content ?? '');
  }

  Widget _buildRatingStars() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Importance:',
          style: TextStyle(fontSize: 18.0, fontWeight: FontWeight.bold),
        ),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: List.generate(3, (index) {
            return GestureDetector(
              onTap: () {
                setState(() {
                  _rating = index + 1;
                });
              },
              child: Padding(
                padding: EdgeInsets.all(8.0),
                child: Column(
                  children: [
                    Icon(
                      index < _rating ? Icons.star : Icons.star_border,
                      color: Color(0xFF0C5217),
                      size: 40,
                    ),
                    Text(
                      ratingDescriptions[index + 1] ?? '',
                      style: TextStyle(
                        color: Colors.grey,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
            );
          }),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    String formattedDate =
        widget.note?.date ?? DateFormat('dd MMM. yyyy').format(DateTime.now());

    return Scaffold(
      appBar: AppBar(
        backgroundColor: Color(0xFF0C5217),
        title: Text(
          widget.note != null ? 'Edit Note' : 'New Note',
          style: TextStyle(color: Colors.white),
        ),
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                formattedDate,
                style: TextStyle(
                  fontSize: 24.0,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF0C5217),
                ),
              ),
              SizedBox(height: 16.0),
              TextFormField(
                controller: titleController,
                decoration: InputDecoration(
                  labelText: 'Title',
                  labelStyle: TextStyle(color: Color(0xFF0C5217)),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10.0),
                    borderSide: BorderSide(color: Color(0xFF0C5217)),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10.0),
                    borderSide: BorderSide(
                      color: Color(0xFF0C5217),
                      width: 2.0,
                    ),
                  ),
                ),
              ),
              SizedBox(height: 16.0),
              TextFormField(
                controller: contentController,
                decoration: InputDecoration(
                  labelText: 'Content',
                  labelStyle: TextStyle(color: Color(0xFF0C5217)),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10.0),
                    borderSide: BorderSide(color: Color(0xFF0C5217)),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10.0),
                    borderSide: BorderSide(
                      color: Color(0xFF0C5217),
                      width: 2.0,
                    ),
                  ),
                ),
                maxLines: 8,
              ),
              SizedBox(height: 24.0),
              _buildRatingStars(),
              SizedBox(height: 24.0),
              Center(
                child: ElevatedButton(
                  onPressed: () {
                    showDialog(
                      context: context,
                      builder: (context) => AlertDialog(
                        title: Text('Confirm Save'),
                        content: Text('Do you want to save this note?'),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.of(context).pop(),
                            child: Text('Cancel'),
                          ),
                          TextButton(
                            onPressed: () {
                              if (widget.note != null) {
                                widget.note!.title = titleController.text;
                                widget.note!.content = contentController.text;
                                widget.note!.rating = _rating;
                                Navigator.of(context).pop();
                                Navigator.of(context).pop(widget.note);
                              } else {
                                Note newNote = Note(
                                  title: titleController.text,
                                  content: contentController.text,
                                  date: formattedDate,
                                  rating: _rating,
                                );
                                Navigator.of(context).pop();
                                Navigator.of(context).pop(newNote);
                              }
                            },
                            child: Text('Save'),
                          ),
                        ],
                      ),
                    );
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Color(0xFF0C5217),
                    padding:
                        EdgeInsets.symmetric(horizontal: 48.0, vertical: 16.0),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(30.0),
                    ),
                  ),
                  child: Text(
                    'Save Note',
                    style: TextStyle(color: Colors.white, fontSize: 18.0),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    titleController.dispose();
    contentController.dispose();
    super.dispose();
  }
}
