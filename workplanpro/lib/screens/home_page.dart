import 'package:flutter/material.dart';
import 'create_note_screen.dart';
import '../models/note.dart';

class HomePage extends StatelessWidget {
  final List<Note> notes = [
    Note(date: '08 ม.ค.', title: 'หัวข้อ 1', content: 'เนื้อหา 1', rating: 0),
    Note(date: '09 ม.ค.', title: 'หัวข้อ 2', content: 'เนื้อหา 2', rating: 3),
    Note(date: '10 ม.ค.', title: 'หัวข้อ 3', content: 'เนื้อหา 3', rating: 0),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Color(0xFF0C5217),
        title: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10.0),
          child: Container(
            height: 40.0,
            child: Opacity(
              opacity: 0.3,
              child: TextField(
                decoration: InputDecoration(
                  filled: true,
                  fillColor: Colors.white,
                  hintText: 'Search...',
                  prefixIcon: Icon(Icons.search, color: Color(0xFF0C5217)),
                  contentPadding: EdgeInsets.symmetric(vertical: 10.0),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(30.0),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
      body: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              ElevatedButton(
                onPressed: () {},
                style: ElevatedButton.styleFrom(
                  backgroundColor: Color(0xFF0C5217),
                ),
                child: Text(
                  'สำคัญมาก',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              ElevatedButton(
                onPressed: () {},
                style: ElevatedButton.styleFrom(
                  backgroundColor: Color(0xFF0C5217),
                ),
                child: Text(
                  'ทำประจำ',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          Expanded(
            child: ListView.builder(
              itemCount: notes.length,
              itemBuilder: (context, index) {
                final note = notes[index];
                return Card(
                  margin: EdgeInsets.all(8.0),
                  child: Padding(
                    padding: EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(note.date,
                            style: TextStyle(
                                fontSize: 18, fontWeight: FontWeight.bold)),
                        Text(note.title, style: TextStyle(fontSize: 16)),
                        SizedBox(height: 8.0),
                        Row(
                          children: List.generate(3, (i) {
                            return Icon(
                              i < note.rating ? Icons.star : Icons.star_border,
                              color: i < note.rating
                                  ? Color(0xFF0C5217)
                                  : Colors.grey,
                            );
                          }),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
      floatingActionButton: Padding(
        padding: const EdgeInsets.only(bottom: 10.0),
        child: ElevatedButton.icon(
          onPressed: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                  builder: (context) =>
                      CreateNoteScreen()),
            );
          },
          style: ElevatedButton.styleFrom(
            backgroundColor: Color(0xFF0C5217),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(30),
            ),
            padding: EdgeInsets.symmetric(
                horizontal: 20, vertical: 10),
          ),
          icon: Icon(Icons.add, color: Colors.white),
          label: Text(
            "New note",
            style: TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ),

      bottomNavigationBar: BottomNavigationBar(
        items: [
          BottomNavigationBarItem(icon: Icon(Icons.home), label: 'Home'),
          BottomNavigationBarItem(icon: Icon(Icons.person), label: 'Account'),
          BottomNavigationBarItem(
              icon: Icon(Icons.notifications), label: 'Notification'),
          BottomNavigationBarItem(
              icon: Icon(Icons.calendar_today), label: 'Calendar'),
          BottomNavigationBarItem(icon: Icon(Icons.group), label: 'Group'),
        ],
        selectedItemColor: Color(0xFF0C5217),
        unselectedItemColor: Colors.grey,
      ),
    );
  }
}
