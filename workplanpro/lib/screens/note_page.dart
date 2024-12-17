import 'package:flutter/material.dart';
import 'package:motion_tab_bar_v2/motion-tab-bar.dart';
import 'package:intl/intl.dart';
import 'create_note_screen.dart';
import '../models/note.dart';
import 'home_page.dart';
import 'calendar_page.dart';
import 'group_page.dart';
import 'account_page.dart';
import '../services/note_database.dart';
import 'package:shimmer/shimmer.dart';

class NotePage extends StatefulWidget {
  final String username;
  final String userEmail;

  const NotePage({Key? key, required this.username, required this.userEmail})
      : super(key: key);

  @override
  _NotePageState createState() => _NotePageState();
}

class _NotePageState extends State<NotePage> {
  int _currentIndex = 2;
  final NoteDatabase _noteDatabase = NoteDatabase();
  List<Note> notes = [];
  bool _isLoading = true;
  String _searchQuery = '';
  String _dateSortBy = 'newest';
  String _prioritySortBy = 'none';
  TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadNotes();
  }

  Future<void> _loadNotes() async {
    setState(() => _isLoading = true);
    try {
      final loadedNotes = await _noteDatabase.loadNotes();
      setState(() {
        notes = loadedNotes;
        _applySorting();
        _isLoading = false;
      });
    } catch (e) {
      print('Error loading notes: $e');
      setState(() => _isLoading = false);
    }
  }

  void _applySorting() {
    notes.sort((a, b) {
      if (_prioritySortBy != 'none') {
        int ratingCompare = _prioritySortBy == 'most_important'
            ? b.rating.compareTo(a.rating)
            : a.rating.compareTo(b.rating);
        if (ratingCompare != 0) return ratingCompare;
      }

      DateTime dateA = DateFormat('dd MMM. yyyy').parse(a.date);
      DateTime dateB = DateFormat('dd MMM. yyyy').parse(b.date);
      return _dateSortBy == 'newest'
          ? dateB.compareTo(dateA)
          : dateA.compareTo(dateB);
    });
  }

  List<Note> _getFilteredNotes() {
    return notes
        .where((note) =>
            note.title.toLowerCase().contains(_searchQuery.toLowerCase()))
        .toList();
  }

  void _showFilterDialog() {
    String tempDateSort = _dateSortBy;
    String tempPrioritySort = _prioritySortBy;

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: Text('Filter Notes'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Sort By Date:',
                      style: TextStyle(fontWeight: FontWeight.bold)),
                  RadioListTile(
                    title: Text('Newest First'),
                    value: 'newest',
                    groupValue: tempDateSort,
                    onChanged: (value) => setState(() => tempDateSort = value!),
                  ),
                  RadioListTile(
                    title: Text('Oldest First'),
                    value: 'oldest',
                    groupValue: tempDateSort,
                    onChanged: (value) => setState(() => tempDateSort = value!),
                  ),
                  SizedBox(height: 16),
                  Text('Sort By Priority:',
                      style: TextStyle(fontWeight: FontWeight.bold)),
                  RadioListTile(
                    title: Text('Most Important'),
                    value: 'most_important',
                    groupValue: tempPrioritySort,
                    onChanged: (value) =>
                        setState(() => tempPrioritySort = value!),
                  ),
                  RadioListTile(
                    title: Text('Least Important'),
                    value: 'least_important',
                    groupValue: tempPrioritySort,
                    onChanged: (value) =>
                        setState(() => tempPrioritySort = value!),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  style: TextButton.styleFrom(
                    foregroundColor: Colors.red[400],
                  ),
                  child: Text('Cancel'),
                ),
                ElevatedButton(
                  onPressed: () {
                    this.setState(() {
                      _dateSortBy = tempDateSort;
                      _prioritySortBy = tempPrioritySort;
                      _applySorting();
                    });
                    Navigator.pop(context);
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Color(0xFF40884B),
                  ),
                  child: Text('Apply', style: TextStyle(color: Colors.white)),
                ),
              ],
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: NestedScrollView(
        headerSliverBuilder: (context, innerBoxIsScrolled) => [
          SliverAppBar(
            expandedHeight: 180.0,
            floating: false,
            pinned: true,
            flexibleSpace: FlexibleSpaceBar(
              centerTitle: true,
              title: Text(
                'My Notes',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                ),
              ),
              background: _buildNotesHeader(),
            ),
            // Removed filter icon
          ),
        ],
        body: _isLoading ? _buildLoadingState() : _buildNotesList(),
      ),
      floatingActionButton: _buildFloatingActionButton(),
      bottomNavigationBar: _buildBottomNavigationBar(),
    );
  }

  Widget _buildFloatingActionButton() {
    return FloatingActionButton.extended(
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
      backgroundColor: Color(0xFF2C8C4B),
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
    );
  }

  Widget _buildNotesHeader() {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFF2C8C4B), Color(0xFF4CAF50)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
            child: TextField(
              controller: _searchController,
              onChanged: (value) {
                setState(() {
                  _searchQuery = value;
                });
              },
              decoration: InputDecoration(
                hintText: 'Search notes...',
                hintStyle: TextStyle(color: Colors.white70),
                prefixIcon: Icon(Icons.search, color: Colors.white),
                fillColor: Colors.white24,
                filled: true,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(30),
                  borderSide: BorderSide.none,
                ),
              ),
              style: TextStyle(color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNotesList() {
    final filteredNotes = _getFilteredNotes();
    return ListView.builder(
      itemCount: filteredNotes.length,
      itemBuilder: (context, index) {
        final note = filteredNotes[index];
        return _buildNoteCard(note, index);
      },
    );
  }

  Widget _buildNoteCard(Note note, int index) {
    return Container(
      margin: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.green.shade50, Colors.green.shade100],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(15),
        boxShadow: [
          BoxShadow(
            color: Colors.green.shade200.withOpacity(0.5),
            blurRadius: 10,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: ListTile(
        contentPadding: EdgeInsets.all(16),
        title: Text(
          note.title,
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: Color(0xFF0C5217),
            fontSize: 18,
          ),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(height: 8),
            Text(
              note.date,
              style: TextStyle(
                color: Colors.grey.shade600,
                fontSize: 14,
              ),
            ),
            SizedBox(height: 8),
            Row(
              children: List.generate(3, (i) {
                return Icon(
                  i < note.rating ? Icons.star : Icons.star_border,
                  color: i < note.rating ? Color(0xFF0C5217) : Colors.grey,
                  size: 20,
                );
              }),
            ),
          ],
        ),
        trailing: Icon(
          Icons.chevron_right,
          color: Color(0xFF0C5217),
        ),
        onTap: () => _showNoteDetail(context, note, index),
      ),
    );
  }

  Widget _buildLoadingState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Shimmer.fromColors(
            baseColor: Colors.green.shade200,
            highlightColor: Colors.green.shade50,
            child: Container(
              width: 300,
              height: 100,
              decoration: BoxDecoration(
                color: Colors.green.shade100,
                borderRadius: BorderRadius.circular(15),
              ),
            ),
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
                          size: 24,
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

  Widget _buildBottomNavigationBar() {
    return MotionTabBar(
      labels: const ["Home", "Account", "Notes", "Calendar", "Groups"],
      icons: const [
        Icons.home,
        Icons.person,
        Icons.book,
        Icons.calendar_today,
        Icons.group
      ],
      initialSelectedTab: "Notes",
      tabIconColor: const Color(0xFF0C5217),
      tabSelectedColor: Colors.green,
      onTabItemSelected: (int index) {
        switch (index) {
          case 0:
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(
                builder: (context) => HomePage(
                  username: widget.username,
                  userEmail: widget.userEmail,
                ),
              ),
            );
            break;
          case 1:
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(
                builder: (context) => AccountPage(
                  initialUsername: widget.username,
                  userEmail: widget.userEmail,
                ),
              ),
            );
            break;
          case 2:
            break;
          case 3:
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(
                builder: (context) => CalendarPage(
                  username: widget.username,
                  userEmail: widget.userEmail,
                ),
              ),
            );
            break;
          case 4:
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(
                builder: (context) => GroupPage(
                  username: widget.username,
                  userEmail: widget.userEmail,
                ),
              ),
            );
            break;
        }
      },
    );
  }
}
