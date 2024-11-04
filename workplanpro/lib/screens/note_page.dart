import 'package:flutter/material.dart';
import 'create_note_screen.dart';
import '../models/note.dart';
import 'home_page.dart';
import 'calendar_page.dart';
import 'group_page.dart';
import 'account_page.dart';
import '../services/note_database.dart';


class NotePage extends StatefulWidget {
  @override
  _NotePageState createState() => _NotePageState();
}

class _NotePageState extends State<NotePage> {
  int _currentIndex = 2;
  final NoteDatabase _noteDatabase = NoteDatabase();
  List<Note> notes = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadNotes();
  }

  Future<void> _loadNotes() async {
    setState(() {
      _isLoading = true;
    });
    
    try {
      final loadedNotes = await _noteDatabase.loadNotes();
      setState(() {
        notes = loadedNotes;
        _isLoading = false;
      });
    } catch (e) {
      print('Error loading notes: $e');
      setState(() {
        _isLoading = false;
      });
    }
  }

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
                  'Important',
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
                  'Routine',
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
            child: _isLoading
              ? Center(child: CircularProgressIndicator(color: Color(0xFF0C5217)))
              : ListView.builder(
                  itemCount: notes.length,
                  itemBuilder: (context, index) {
                    final note = notes[index];
                    return GestureDetector(
                      onTap: () {
                        _showNoteDetail(context, note, index);
                      },
                      child: Card(
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
                                    i < note.rating
                                        ? Icons.star
                                        : Icons.star_border,
                                    color: i < note.rating
                                        ? Color(0xFF0C5217)
                                        : Colors.grey,
                                  );
                                }),
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () async {
          final newNote = await Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => CreateNoteScreen()),
          );

          if (newNote != null && newNote is Note) {
            setState(() {
              notes.insert(0, newNote);
            });
            await _noteDatabase.saveNotes(notes);
          }
        },
        backgroundColor: Color(0xFF0C5217),
        icon: Icon(Icons.add, color: Colors.white),
        label: Text(
          'New Note',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(30.0)),
        ),
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        onTap: (index) {
          setState(() {
            _currentIndex = index;
          });
          switch (index) {
            case 0:
              Navigator.pushReplacement(
                  context, MaterialPageRoute(builder: (context) => HomePage()));
              break;
            case 1:
              Navigator.pushReplacement(context,
                  MaterialPageRoute(builder: (context) => AccountPage()));
              break;
            case 2:
              break;
            case 3:
              Navigator.pushReplacement(context,
                  MaterialPageRoute(builder: (context) => CalendarPage()));
              break;
            case 4:
              Navigator.pushReplacement(context,
                  MaterialPageRoute(builder: (context) => GroupPage()));
              break;
          }
        },
        selectedItemColor: Colors.white,
        unselectedItemColor: Color(0xFF0C5217),
        backgroundColor: Colors.white,
        type: BottomNavigationBarType.fixed,
        items: [
          BottomNavigationBarItem(
            icon: _buildNavBarItem(Icons.home, 'Home', 0),
            label: '',
          ),
          BottomNavigationBarItem(
            icon: _buildNavBarItem(Icons.person, 'Account', 1),
            label: '',
          ),
          BottomNavigationBarItem(
            icon: _buildNavBarItem(Icons.book, 'Note', 2),
            label: '',
          ),
          BottomNavigationBarItem(
            icon: _buildNavBarItem(Icons.calendar_today, 'Calendar', 3),
            label: '',
          ),
          BottomNavigationBarItem(
            icon: _buildNavBarItem(Icons.group, 'Group', 4),
            label: '',
          ),
        ],
      ),
    );
  }

  void _showNoteDetail(BuildContext context, Note note, int index) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(25.0)),
      ),
      builder: (BuildContext context) {
        return DraggableScrollableSheet(
          expand: false,
          initialChildSize: 0.6,
          minChildSize: 0.4,
          maxChildSize: 0.9,
          builder: (context, scrollController) {
            return SingleChildScrollView(
              controller: scrollController,
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Note Detail',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 20.0,
                            color: Color(0xFF0C5217),
                          ),
                        ),
                        IconButton(
                          icon: Icon(Icons.close, color: Colors.grey),
                          onPressed: () {
                            Navigator.pop(context);
                          },
                        ),
                      ],
                    ),
                    SizedBox(height: 16.0),
                    Text(
                      note.title,
                      style: TextStyle(
                        fontSize: 18.0,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    SizedBox(height: 8.0),
                    Text(
                      note.content,
                      style: TextStyle(fontSize: 16.0),
                    ),
                    SizedBox(height: 16.0),
                    Row(
                      children: List.generate(3, (i) {
                        return Icon(
                          i < note.rating ? Icons.star : Icons.star_border,
                          color:
                              i < note.rating ? Color(0xFF0C5217) : Colors.grey,
                        );
                      }),
                    ),
                    SizedBox(height: 16.0),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        ElevatedButton(
                          onPressed: () async {
                            Navigator.pop(context);
                            final updatedNote = await Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => CreateNoteScreen(
                                  note: note,
                                ),
                              ),
                            );

                            if (updatedNote != null && updatedNote is Note) {
                              setState(() {
                                notes[index] = updatedNote;
                              });
                              await _noteDatabase.saveNotes(notes);
                            }
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Color(0xFF0C5217),
                          ),
                          child: Text('Edit',
                              style: TextStyle(color: Colors.white)),
                        ),
                        SizedBox(width: 8.0),
                        ElevatedButton(
                          onPressed: () {
                            _showDeleteConfirmationDialog(context, note, index);
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.red,
                          ),
                          child: Text('Delete',
                              style: TextStyle(color: Colors.white)),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  void _showDeleteConfirmationDialog(
      BuildContext context, Note note, int index) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text('Confirm Delete'),
          content: Text('Are you sure you want to delete this note?'),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
              },
              child: Text('Cancel'),
            ),
            TextButton(
              onPressed: () async {
                setState(() {
                  notes.removeAt(index);
                });
                await _noteDatabase.saveNotes(notes);
                Navigator.of(context).pop();
                Navigator.of(context).pop();
              },
              child: Text('Delete', style: TextStyle(color: Colors.red)),
            ),
          ],
        );
      },
    );
  }

  Widget _buildNavBarItem(IconData icon, String label, int index) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.symmetric(vertical: 5),
      decoration: BoxDecoration(
        color: _currentIndex == index ? Color(0xFF0C5217) : Colors.transparent,
        borderRadius: BorderRadius.circular(0),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon,
              color: _currentIndex == index ? Colors.white : Color(0xFF0C5217)),
          Text(
            label,
            style: TextStyle(
                color:
                    _currentIndex == index ? Colors.white : Color(0xFF0C5217)),
          )
        ],
      ),
    );
  }
}