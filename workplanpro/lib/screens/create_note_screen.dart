import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/note.dart';

class CreateNoteScreen extends StatefulWidget {
  @override
  _CreateNoteScreenState createState() => _CreateNoteScreenState();
}

class _CreateNoteScreenState extends State<CreateNoteScreen> {
  DateTime currentDate = DateTime.now();
  int _rating = 0;

  TextEditingController titleController = TextEditingController();
  TextEditingController contentController = TextEditingController();

  @override
  Widget build(BuildContext context) {
    String formattedDate = DateFormat('dd MMM. yyyy').format(currentDate);

    return Scaffold(
      appBar: AppBar(
        backgroundColor: Color(0xFF0C5217),
        title: Text(
          'NOTE',
          style: TextStyle(color: Colors.white),
        ),
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: Padding(
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
            SizedBox(height: 8.0),
            TextFormField(
              controller: titleController,
              decoration: InputDecoration(
                labelText: 'Title',
              ),
            ),
            SizedBox(height: 8.0),
            TextFormField(
              controller: contentController,
              decoration: InputDecoration(
                labelText: 'Content',
              ),
              maxLines: 5,
            ),
            SizedBox(height: 16.0),
            Text(
              'Importance:',
              style: TextStyle(
                fontSize: 18.0,
                fontWeight: FontWeight.bold,
              ),
            ),
            Row(
              children: List.generate(3, (index) {
                return IconButton(
                  onPressed: () {
                    setState(() {
                      _rating = index + 1;
                    });
                  },
                  icon: Icon(
                    index < _rating ? Icons.star : Icons.star_border,
                    color: Color(0xFF0C5217),
                  ),
                );
              }),
            ),
            Spacer(),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                ElevatedButton(
                  onPressed: () {
                    // Delete functionality can be added
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Color(0xFFD15353),
                  ),
                  child: Text(
                    'Delete',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                ElevatedButton(
                  onPressed: () {
                    // Create a new note and return it to the previous screen
                    if (titleController.text.isNotEmpty &&
                        contentController.text.isNotEmpty) {
                      Note newNote = Note(
                        date: formattedDate,
                        title: titleController.text,
                        content: contentController.text,
                        rating: _rating,
                      );
                      Navigator.pop(context, newNote);
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Color(0xFF40884B),
                  ),
                  child: Text(
                    'Save',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
